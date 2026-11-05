import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bible_journey/core/data_backup.dart';
import 'package:bible_journey/core/planner.dart';
import 'package:bible_journey/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState source;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    source = AppState(await SharedPreferences.getInstance())..load();
    source.newJourney(const Setup(
        scope: 'all',
        days: 100,
        start: '2026-11-05',
        first: '2026-11-05',
        selectedBooks: [0, 20, 49],
        bookOrder: [49, 20, 0],
        reserveWithinDuration: true));
    source.done['49:1'] = '2026-11-05';
    source.notes['49:1:2'] = 'تأمل عربي — English note';
    source.hl['49:1:2'] = 3;
    source.fav.add('49:1:2');
    source.hist.add('2026-11-04');
    source.secs['2026-11-05'] = 120;
    source.badgeDates['first'] = '';
  });
  tearDown(() => source.dispose());

  test('portable round-trip preserves every assignment, note and setting',
      () async {
    final backup = DataBackup.decode(source.exportBackup());
    expect(backup.completed, 1);
    expect(backup.noteCount, 1);
    expect(backup.readingDays, 93);
    final target = AppState(await SharedPreferences.getInstance())..load();
    await target.restoreBackup(backup);
    expect(target.notes, source.notes);
    expect(target.done, source.done);
    expect(target.hl, source.hl);
    expect(target.fav, source.fav);
    expect(target.secs, source.secs);
    expect(target.badgeDates, source.badgeDates);
    expect(target.setup!.bookOrder, [49, 20, 0]);
    expect(target.days.map((d) => d.map((c) => c.key).toList()).toList(),
        source.days.map((d) => d.map((c) => c.key).toList()).toList());
    final reopened = AppState(await SharedPreferences.getInstance())..load();
    expect(reopened.notes, source.notes);
    expect(reopened.days.length, 93);
    target.dispose();
    reopened.dispose();
  });

  test('data without a reading plan can also be restored', () async {
    final target = AppState(await SharedPreferences.getInstance())..load();
    final exported = DataBackup.decode(target.exportBackup());
    expect(exported.readingDays, isNull);
    await source.restoreBackup(exported);
    expect(source.hasPlan, false);
    expect(source.notes, isEmpty);
    target.dispose();
  });

  test('malformed data is rejected before changing current data', () async {
    final original = source.exportBackup();
    for (final change in <void Function(Map<String, dynamic>)>[
      (e) => e['version'] = 99,
      (e) => e['data']['setup']['days'] = 1000000000,
      (e) => e['data']['done']['99:1'] = '2026-11-05',
      (e) => e['data']['hist'] = ['2026-02-31'],
      (e) => e['data']['settings']['fs'] = 999,
      (e) => e['data']['hl']['49:1:2'] = 4,
      (e) => e['data']['plan'].removeLast(),
      (e) => e['data']['plan'][0] += ',49:1',
      (e) => e['data']['notes'] = [],
    ]) {
      final envelope = jsonDecode(original) as Map<String, dynamic>;
      change(envelope);
      expect(
          () => DataBackup.decode(jsonEncode(envelope)), throwsFormatException);
      expect(source.notes['49:1:2'], 'تأمل عربي — English note');
      expect(source.days.length, 93);
    }
    final preview = DataBackup.decode(original);
    preview.data['hl']['49:1:2'] = 500;
    await expectLater(source.restoreBackup(preview), throwsFormatException);
    expect(source.hl['49:1:2'], 3);
  });

  test('new Arabic translation choices survive backup and restore', () async {
    final target = AppState(await SharedPreferences.getInstance())..load();
    for (final id in ['gna', 'svd']) {
      source.setTranslation(id);
      await target.restoreBackup(DataBackup.decode(source.exportBackup()));
      expect(target.translation, id);
      expect(target.days.length, source.days.length);
    }
    target.dispose();
  });
  test('removed Jesuit preference migrates on load and old backup restore',
      () async {
    final oldData = jsonDecode(source.exportBackup()) as Map<String, dynamic>;
    oldData['data']['settings']['tr'] = 'jesuit';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jb-v1', jsonEncode(oldData['data']));
    final reopened = AppState(prefs)..load();
    expect(reopened.translation, 'svd');
    expect(reopened.notes, source.notes);
    await reopened.restoreBackup(DataBackup.decode(jsonEncode(oldData)));
    expect(reopened.translation, 'svd');
    expect(reopened.done, source.done);
    expect(reopened.days.length, source.days.length);
    expect(
        jsonDecode(reopened.exportBackup())['data']['settings']['tr'], 'svd');
    reopened.dispose();
  });
}
