import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bible_journey/state/app_state.dart';
import 'package:bible_journey/core/encrypted_backup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String source, encrypted;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance())..load();
    state.notes['0:1:1'] = 'ملاحظة سرية مع English';
    source = state.exportBackup();
    encrypted =
        await EncryptedBackup.encrypt(source, 'correct horse battery staple');
    state.dispose();
  });
  test(
      'authenticated encrypted backup round trip preserves Arabic and all data',
      () async {
    expect(encrypted, isNot(contains('ملاحظة سرية')));
    final back = await EncryptedBackup.decrypt(
        encrypted, 'correct horse battery staple');
    expect(back.data, jsonDecode(source)['data']);
    final envelope = jsonDecode(encrypted);
    expect(base64Decode(envelope['nonce']).length, 12);
    expect(base64Decode(envelope['salt']).length, 16);
  }, timeout: const Timeout(Duration(minutes: 2)));
  test('wrong passwords and ciphertext modifications are rejected', () async {
    await expectLater(
        EncryptedBackup.decrypt(encrypted, 'a completely wrong password'),
        throwsFormatException);
    final value = jsonDecode(encrypted),
        bytes = base64Decode(jsonDecode(encrypted)['ciphertext']);
    bytes[0] ^= 1;
    value['ciphertext'] = base64Encode(bytes);
    await expectLater(
        EncryptedBackup.decrypt(
            jsonEncode(value), 'correct horse battery staple'),
        throwsFormatException);
  }, timeout: const Timeout(Duration(minutes: 2)));
  test(
      'malicious KDF cost and short export passwords fail before expensive work',
      () async {
    final value = jsonDecode(encrypted);
    value['iterations'] = 2000000000;
    await expectLater(
        EncryptedBackup.decrypt(
            jsonEncode(value), 'correct horse battery staple'),
        throwsFormatException);
    await expectLater(
        EncryptedBackup.encrypt(source, 'short'), throwsFormatException);
  });
}
