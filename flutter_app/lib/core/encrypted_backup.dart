import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'data_backup.dart';

class EncryptedBackup {
  static const format = 'bible-journey-encrypted-backup';
  static const iterations = 600000;
  static const maxEnvelopeBytes = 15 * 1024 * 1024;
  static bool isEncrypted(String source) {
    final value = jsonDecode(source);
    return value is Map && value['format'] == format;
  }

  static List<int> _random(int length) {
    final random = Random.secure();
    return List.generate(length, (_) => random.nextInt(256));
  }

  static Future<SecretKey> _key(String password, List<int> salt) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256)
          .deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  static Future<String> encrypt(String plaintext, String password) async {
    if (password.length < 12 || password.length > 1024) {
      throw const FormatException('Use a password of at least 12 characters');
    }
    DataBackup.decode(plaintext);
    final salt = _random(16), nonce = _random(12);
    final box = await AesGcm.with256bits().encrypt(utf8.encode(plaintext),
        secretKey: await _key(password, salt),
        nonce: nonce,
        aad: utf8.encode('$format:1'));
    return jsonEncode({
      'format': format,
      'version': 1,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': iterations,
      'cipher': 'AES-256-GCM',
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(box.cipherText),
      'tag': base64Encode(box.mac.bytes)
    });
  }

  static Future<DataBackup> decrypt(String source, String password) async {
    try {
      if (utf8.encode(source).length > maxEnvelopeBytes ||
          password.length > 1024) {
        throw const FormatException('Invalid encrypted backup');
      }
      final value = jsonDecode(source);
      if (value is! Map ||
          value['format'] != format ||
          value['version'] != 1 ||
          value['kdf'] != 'PBKDF2-HMAC-SHA256' ||
          value['iterations'] != iterations ||
          value['cipher'] != 'AES-256-GCM')
        throw const FormatException('Unsupported encryption');
      List<int> bytes(String field) => base64Decode(value[field] as String);
      final salt = bytes('salt'),
          nonce = bytes('nonce'),
          tag = bytes('tag'),
          ciphertext = bytes('ciphertext');
      if (salt.length != 16 ||
          nonce.length != 12 ||
          tag.length != 16 ||
          ciphertext.length > DataBackup.maxBytes) {
        throw const FormatException('Invalid encrypted backup');
      }
      final plaintext = await AesGcm.with256bits().decrypt(
          SecretBox(ciphertext, nonce: nonce, mac: Mac(tag)),
          secretKey: await _key(password, salt),
          aad: utf8.encode('$format:1'));
      return DataBackup.decode(utf8.decode(plaintext));
    } catch (_) {
      throw const FormatException('Wrong password or damaged encrypted backup');
    }
  }
}
