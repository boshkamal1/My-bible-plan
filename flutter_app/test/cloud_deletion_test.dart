import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bible_journey/services/cloud.dart';
import 'package:bible_journey/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState state;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = AppState(await SharedPreferences.getInstance())..load();
    await state.switchAccount('A');
    state.setNote('0:1:1', 'Preserve until identity confirmation');
    await state.flush();
  });
  tearDown(() => state.dispose());

  for (final provider in ['password', 'google.com']) {
    test(
        '$provider reauthentication failure returns before any data access or deletion',
        () async {
      final user = _User(provider), cloud = _Cloud(user);
      final before = state.exportBackup();
      // No Firebase app or Firestore exists in this test. Any premature backend
      // access would fail instead of returning the reauthentication error.
      expect(await cloud.deleteAccount(state, password: 'synthetic password'),
          'confirmation-cancelled');
      expect(user.confirmations, 1);
      expect(user.deleted, false);
      expect(
          state.exportBackup().contains('Preserve until identity confirmation'),
          true);
      expect(state.toMap()['notes'], jsonDecode(before)['data']['notes']);
      expect(state.prefs.getBool('jb-delete-pending:A'), isNull);
      cloud.dispose();
    });
  }
  test('missing password makes no confirmation or destructive call', () async {
    final user = _User('password'), cloud = _Cloud(user);
    expect(await cloud.deleteAccount(state), 'password-required');
    expect(user.confirmations, 0);
    expect(user.deleted, false);
    expect(state.notes.length, 1);
    cloud.dispose();
  });
}

class _Info extends Fake implements UserInfo {
  _Info(this.providerId);
  @override
  final String providerId;
}

class _User extends Fake implements User {
  _User(this.provider);
  final String provider;
  int confirmations = 0;
  bool deleted = false;
  @override
  String get uid => 'A';
  @override
  String get email => 'synthetic@example.invalid';
  @override
  List<UserInfo> get providerData => [_Info(provider)];
  Future<UserCredential> _cancel() async {
    confirmations++;
    throw FirebaseAuthException(code: 'confirmation-cancelled');
  }

  @override
  Future<UserCredential> reauthenticateWithCredential(
          AuthCredential credential) =>
      _cancel();
  @override
  Future<UserCredential> reauthenticateWithProvider(AuthProvider provider) =>
      _cancel();
  @override
  Future<UserCredential> reauthenticateWithPopup(AuthProvider provider) =>
      _cancel();
  @override
  Future<void> delete() async {
    deleted = true;
  }
}

class _Cloud extends Cloud {
  _Cloud(User current) {
    user = current;
  }
  @override
  bool get signedIn => true;
}
