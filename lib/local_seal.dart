import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-GCM for text stored on the phone. The key lives in the Android keystore.
class LocalSeal {
  LocalSeal({FlutterSecureStorage? storage, this.memoryKey})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: false,
                storageNamespace: 'spectrumwhisper',
              ),
            );

  static const prefix = 'SWENC1:';
  static const _keyName = 'catalog-key';

  final FlutterSecureStorage _storage;
  final List<int>? memoryKey;
  final AesGcm _algorithm = AesGcm.with256bits();
  SecretKey? _cached;

  bool isSealed(String stored) => stored.startsWith(prefix);

  Future<String> sealText(String plain) async {
    final box = await _algorithm.encrypt(
      utf8.encode(plain),
      secretKey: await _key(),
    );
    final packed = Uint8List(box.nonce.length + box.mac.bytes.length + box.cipherText.length);
    packed.setAll(0, box.nonce);
    packed.setAll(box.nonce.length, box.mac.bytes);
    packed.setAll(box.nonce.length + box.mac.bytes.length, box.cipherText);
    return '$prefix${base64Encode(packed)}';
  }

  /// Opens a sealed value. Older plain JSON is returned unchanged so it can be rewritten.
  Future<String> openText(String stored) async {
    if (!isSealed(stored)) return stored;
    final packed = base64Decode(stored.substring(prefix.length));
    if (packed.length < 12 + 16) {
      throw const FormatException('Sealed value is too short.');
    }
    final nonce = packed.sublist(0, 12);
    final mac = Mac(packed.sublist(12, 28));
    final cipherText = packed.sublist(28);
    final clear = await _algorithm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: await _key(),
    );
    return utf8.decode(clear);
  }

  Future<SecretKey> _key() async {
    final existing = _cached;
    if (existing != null) return existing;
    final injected = memoryKey;
    if (injected != null) {
      final key = SecretKey(injected);
      _cached = key;
      return key;
    }
    if (!Platform.isAndroid) {
      final key = SecretKey(_desktopKey);
      _cached = key;
      return key;
    }
    final saved = await _storage.read(key: _keyName);
    if (saved != null && saved.isNotEmpty) {
      final key = SecretKey(base64Decode(saved));
      _cached = key;
      return key;
    }
    final fresh = await _algorithm.newSecretKey();
    final bytes = await fresh.extractBytes();
    await _storage.write(key: _keyName, value: base64Encode(bytes));
    _cached = SecretKey(bytes);
    return _cached!;
  }
}

/// Used only when this code runs off Android, such as the desktop test runner.
/// The phone keeps its key in the Android keystore.
final List<int> _desktopKey = List<int>.generate(32, (i) => (0xA5 ^ (i * 13 + 7)) & 0xff);
