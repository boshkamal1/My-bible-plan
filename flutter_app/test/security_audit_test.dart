import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:bible_journey/core/data_backup.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bible_journey/core/planner.dart';
import 'package:bible_journey/core/sync_merge.dart';
import 'package:bible_journey/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState state;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = AppState(await SharedPreferences.getInstance())..load();
  });
  tearDown(() => state.dispose());
  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m));
  Map<String, dynamic> empty() => copy(state.toMap(cloud: true));

  test('profiles remain separate across A, B, guest and reload', () async {
    state.notes['0:1:1'] = 'Legacy guest note';
    await state.switchAccount('A');
    expect(state.notes, isEmpty);
    expect(state.hasGuestData, true);
    state.setNote('0:1:1', 'A private note');
    await state.switchAccount('B');
    expect(state.notes, isEmpty);
    state.setNote('0:1:2', 'B private note');
    await state.switchAccount('A');
    expect(state.notes, {'0:1:1': 'A private note'});
    await state.switchAccount(null);
    expect(state.notes, {'0:1:1': 'Legacy guest note'});
    await state.switchAccount('B');
    expect(state.notes, {'0:1:2': 'B private note'});
    await state.flush();
    final reopened = AppState(state.prefs)..load();
    expect(reopened.notes['0:1:1'], 'Legacy guest note');
    await reopened.switchAccount('A');
    expect(reopened.notes, {'0:1:1': 'A private note'});
    reopened.dispose();
  });

  test('guest data moves only after explicit import and keeps both conflicts',
      () async {
    state.notes['0:1:1'] = 'Guest version';
    await state.switchAccount('A');
    state.setNote('0:1:1', 'Account version');
    expect(state.notes['0:1:1'], 'Account version');
    await state.importGuest();
    expect(state.notes['0:1:1'], 'Account version');
    final conflict = jsonDecode(state.syncConflicts['notes|0:1:1']!);
    expect(conflict['versions'],
        containsAll(['Guest version', 'Account version']));
    expect(state.hasGuestData, false);
    await state.switchAccount('B');
    expect(state.notes, isEmpty);
  });

  test('a delayed acknowledgement cannot apply to a different profile',
      () async {
    await state.switchAccount('A');
    state.setNote('0:1:1', 'A only');
    final sent = empty(), remote = copy(sent), session = state.sessionRevision;
    remote['notes'] = {'0:1:1': 'Late A response'};
    await state.switchAccount('B');
    state.setNote('0:1:2', 'B only');
    await state.acceptSynced(sent, remote,
        expectedUid: 'A', expectedSession: session);
    expect(state.notes, {'0:1:2': 'B only'});
    expect(state.syncBase, isEmpty);
  });

  test('canonical cloud hashes ignore map order and detect corrupted entries',
      () {
    final a = empty(), b = empty();
    a['notes'] = {'0:1:2': 'Second', '0:1:1': 'First'};
    b['notes'] = {'0:1:1': 'First', '0:1:2': 'Second'};
    expect(readingHash(a), readingHash(b));
    a['contentHash'] = readingHash(a);
    DataBackup.normalizeState(a, settings: state.toMap()['settings']);
    a['notes']['0:1:1'] = 'Changed';
    expect(
        () => DataBackup.normalizeState(a, settings: state.toMap()['settings']),
        throwsFormatException);
    b['t'] = 999;
    expect(readingDataHash(b), readingDataHash({...b, 't': 0}));
  });

  test('invalid conflicting alternatives are rejected before reaching the UI',
      () {
    final bad = empty();
    bad['conflicts'] = {
      'journey|plan': jsonEncode({
        'field': 'journey',
        'key': 'plan',
        'versions': [
          {'setup': 42}
        ]
      })
    };
    expect(
        () =>
            DataBackup.normalizeState(bad, settings: state.toMap()['settings']),
        throwsFormatException);
    bad['conflicts'] = {
      'notes|0:1:1': jsonEncode({
        'field': 'notes',
        'key': '0:1:1',
        'versions': [42]
      })
    };
    expect(
        () =>
            DataBackup.normalizeState(bad, settings: state.toMap()['settings']),
        throwsFormatException);
  });

  test(
      'a restore completing after an account switch cannot change the new profile',
      () async {
    await state.switchAccount('A');
    final backup = DataBackup.decode(state.exportBackup());
    backup.data['notes'] = {'0:1:1': 'Restored A'};
    final original = SharedPreferencesStorePlatform.instance;
    final store = _DelayedStore(original);
    SharedPreferencesStorePlatform.instance = store;
    try {
      final restore = state.restoreBackup(backup);
      final rejected = expectLater(restore, throwsStateError);
      await store.started.future;
      await state.switchAccount('B');
      state.setNote('0:1:2', 'B only');
      store.release.complete();
      await rejected;
      expect(state.activeUid, 'B');
      expect(state.notes, {'0:1:2': 'B only'});
    } finally {
      SharedPreferencesStorePlatform.instance = original;
    }
  });

  test('Firestore SDK timestamps in protocol metadata do not break later syncs',
      () {
    final raw = empty();
    raw['notes'] = {'0:1:1': 'Synced note'};
    raw['contentHash'] = readingHash(raw);
    raw['revision'] = 2;
    raw['syncVersion'] = 2;
    raw['updatedAt'] = Timestamp.now();
    final checked =
        DataBackup.normalizeState(raw, settings: state.toMap()['settings']);
    expect(checked['notes'], {'0:1:1': 'Synced note'});
    expect(checked.containsKey('updatedAt'), false);
    expect(raw['updatedAt'], isA<Timestamp>());
    expect(raw['revision'], 2);
  });

  test('malformed remote is rejected atomically with the local state intact',
      () {
    state.notes['0:1:1'] = 'Keep me';
    final before = state.exportBackup();
    expect(
        state.applyRemote({
          'done': {'0:1': 42},
          'setup': null,
          't': 1,
          'notes': {'0:1:1': []}
        }),
        false);
    expect(state.notes['0:1:1'], 'Keep me');
    expect(
        jsonDecode(state.exportBackup())['data'], jsonDecode(before)['data']);
    expect(state.dataError, 'invalid-remote-data');
  });

  test('independent offline notes merge in either order without using clocks',
      () {
    final base = empty(), left = empty(), right = empty();
    left['notes'] = {'0:1:1': 'Left'};
    right['notes'] = {'0:1:2': 'Right'};
    left['t'] = 8640000000000000;
    right['t'] = 1;
    for (final m in [
      mergeReading(base, left, right),
      mergeReading(base, right, left)
    ]) {
      expect(m['notes'], {'0:1:1': 'Left', '0:1:2': 'Right'});
      expect(m['conflicts'], isEmpty);
    }
  });

  test(
      'same note conflicts preserve alternatives and explicit resolution persists',
      () async {
    final base = empty(), left = empty(), right = empty();
    base['notes'] = {'0:1:1': 'Original'};
    left['notes'] = {'0:1:1': 'Left'};
    right['notes'] = {'0:1:1': 'Right'};
    final merged = mergeReading(base, left, right);
    state.applyRemote(merged);
    final record = jsonDecode(state.syncConflicts['notes|0:1:1']!);
    expect(record['versions'], containsAll(['Left', 'Right']));
    final version = (record['versions'] as List).indexOf('Right');
    state.resolveConflict('notes|0:1:1', version);
    expect(state.notes['0:1:1'], 'Right');
    expect(state.syncConflicts, isEmpty);
    final exported = DataBackup.decode(state.exportBackup());
    expect(exported.data['notes']['0:1:1'], 'Right');
    final resolved = mergeReading(merged, state.toMap(cloud: true), merged);
    expect(resolved['conflicts'], isEmpty);
  });

  test(
      'delete versus concurrent edit is visible and both versions survive backup',
      () {
    final base = empty(), left = empty(), right = empty();
    base['notes'] = {'0:1:1': 'Original'};
    right['notes'] = {'0:1:1': 'Remote edit'};
    final merged = mergeReading(base, left, right);
    final record = jsonDecode(merged['conflicts']['notes|0:1:1']);
    expect(record['versions'], containsAll([null, 'Remote edit']));
    state.applyRemote(merged);
    expect(
        DataBackup.decode(state.exportBackup()).data['conflicts'], isNotEmpty);
  });

  test('acknowledged and in-flight reading time is never counted twice',
      () async {
    final base = empty(), left = empty(), right = empty();
    base['secs'] = {'2026-11-05': 10};
    left['secs'] = {'2026-11-05': 20};
    right['secs'] = {'2026-11-05': 15};
    final merged = mergeReading(base, left, right);
    expect(merged['secs']['2026-11-05'], 25);
    final repeat = mergeReading(merged, merged, merged);
    expect(repeat['secs']['2026-11-05'], 25);
  });

  test('fresh account pulls existing cloud data without a journey conflict',
      () async {
    final remote = empty();
    remote['notes'] = {'0:1:1': 'Cloud note'};
    state.applyRemote(remote);
    expect(state.notes['0:1:1'], 'Cloud note');
    expect(state.syncConflicts, isEmpty);
  });

  test('different plans preserve both full assignments for explicit choice',
      () async {
    final prefs = state.prefs;
    final other = AppState(prefs)..load();
    state.newJourney(const Setup(
        scope: 'all',
        days: 100,
        start: '2026-11-05',
        first: '2026-11-05',
        reserveWithinDuration: true));
    other.newJourney(const Setup(
        scope: 'nt',
        days: 90,
        start: '2026-11-05',
        first: '2026-11-05',
        reserveWithinDuration: true));
    final merged =
        mergeReading({}, state.toMap(cloud: true), other.toMap(cloud: true));
    final record = jsonDecode(merged['conflicts']['journey|plan']);
    expect(record['versions'].length, 2);
    state.applyRemote(merged);
    state.resolveConflict('journey|plan', 1);
    expect(state.setup!.scope, 'nt');
    expect(state.days.length, other.days.length);
    expect(state.days.map((d) => d.map((c) => c.key).toList()).toList(),
        other.days.map((d) => d.map((c) => c.key).toList()).toList());
    other.dispose();
  });

  test('deleted profile is removed without erasing another profile or guest',
      () async {
    state.notes['0:1:1'] = 'Guest';
    await state.switchAccount('A');
    state.notes['0:1:1'] = 'A';
    await state.switchAccount('B');
    state.notes['0:1:1'] = 'B';
    await state.switchAccount('A');
    await state.forgetDeletedAccount('A');
    expect(state.notes['0:1:1'], 'Guest');
    expect(state.prefs.getString('jb-v2:user:A'), isNull);
    await state.switchAccount('B');
    expect(state.notes['0:1:1'], 'B');
  });

  test('oversized backup and invalid book selection fail validation', () {
    expect(() => DataBackup.decode('x' * (DataBackup.maxBytes + 1)),
        throwsFormatException);
    state.newJourney(const Setup(start: '2026-11-05', first: '2026-11-05'));
    final envelope = jsonDecode(state.exportBackup());
    envelope['data']['setup']['selectedBooks'] = [100];
    expect(
        () => DataBackup.decode(jsonEncode(envelope)), throwsFormatException);
  });
}

class _DelayedStore extends SharedPreferencesStorePlatform {
  _DelayedStore(this.delegate);
  final SharedPreferencesStorePlatform delegate;
  final started = Completer<void>(), release = Completer<void>();
  bool block = true;
  @override
  Future<bool> clear() => delegate.clear();
  @override
  Future<bool> remove(String key) => delegate.remove(key);
  @override
  Future<Map<String, Object>> getAll() => delegate.getAll();
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (block && value is String && value.contains('Restored A')) {
      block = false;
      started.complete();
      await release.future;
    }
    return delegate.setValue(type, key, value);
  }
}
