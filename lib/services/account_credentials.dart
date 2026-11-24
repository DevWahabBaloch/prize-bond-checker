import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

enum CredentialProblem { missing, corrupted, invalidKeyMaterial, unavailable }

class CredentialException implements Exception {
  const CredentialException(this.problem);

  final CredentialProblem problem;

  bool get canRecover => problem != CredentialProblem.unavailable;

  String get message => switch (problem) {
    CredentialProblem.missing => 'This account’s PIN key is missing. Ask the local administrator to recover the PIN.',
    CredentialProblem.corrupted => 'This account’s PIN credential is damaged. Ask the local administrator to recover the PIN.',
    CredentialProblem.invalidKeyMaterial => 'This account’s PIN key is invalid. Ask the local administrator to recover the PIN.',
    CredentialProblem.unavailable => 'Device secure storage is unavailable. Unlock the device and try again.',
  };
}

class AccountCredentials {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
  );
  static const _androidKeys = MethodChannel('prize_bond/pin_keystore');
  static const _androidVerifier = 'hmac-android-v3';
  static const _sharedKeyName = 'prize_bond_pin_verifier_key_v1';
  static final _digestPattern = RegExp(r'^[a-f0-9]{64}$');

  static bool isPin(String pin) => pin.length == 4 && RegExp(r'^\d{4}$').hasMatch(pin);

  static bool isLegacy(String verifier) => _digestPattern.hasMatch(verifier);

  // A fresh slot lets Hive commit the new verifier without overwriting a key still referenced by any account.
  static Future<String> create(String accountId, String pin) async {
    final generation = const Uuid().v4();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final result = await _androidMac(accountId, generation, pin: pin, create: true);
      return '$_androidVerifier:$generation:${result.check}:${result.pinDigest}';
    }
    final name = _accountKeyName(accountId, generation);
    final key = Hive.generateSecureKey();
    final encodedKey = base64UrlEncode(key);
    await _useSecureStorage(() => _storage.write(key: name, value: encodedKey));
    final confirmedKey = await _readKey(name);
    final fingerprint = sha256.convert(key).toString();
    if (!_equal(sha256.convert(confirmedKey).toString(), fingerprint)) {
      throw const CredentialException(CredentialProblem.corrupted);
    }
    return 'hmac-v2:$generation:$fingerprint:${_mac(key, accountId, generation, pin)}';
  }

  static Future<void> checkCredential(String accountId, String verifier) async {
    if (!isLegacy(verifier)) await _checkVerifier(accountId, verifier);
  }

  static Future<bool> matches(String accountId, String verifier, String pin) async {
    final validPin = isPin(pin);
    if (isLegacy(verifier)) return validPin && matchesDigest(verifier, pin);
    return _checkVerifier(accountId, verifier, pin: validPin ? pin : null);
  }

  static Future<bool> _checkVerifier(String accountId, String verifier, {String? pin}) async {
    final parts = verifier.split(':');
    final v1 = parts.first == 'hmac-v1' && parts.length == 3;
    final v2 = parts.first == 'hmac-v2' && parts.length == 4;
    final android = parts.first == _androidVerifier && parts.length == 4;
    if ((!v1 && !v2 && !android) ||
        !Uuid.isValidUUID(fromString: parts[1]) ||
        !_digestPattern.hasMatch(parts.last) ||
        (!v1 && !_digestPattern.hasMatch(parts[2]))) {
      throw const CredentialException(CredentialProblem.corrupted);
    }
    final generation = parts[1];
    if (android) {
      final result = await _androidMac(accountId, generation, pin: pin);
      if (!_equal(result.check, parts[2])) throw const CredentialException(CredentialProblem.corrupted);
      return result.pinDigest != null && _equal(result.pinDigest!, parts.last);
    }

    final key = await _readKey(v2 ? _accountKeyName(accountId, generation) : _sharedKeyName);
    if (v2 && !_equal(sha256.convert(key).toString(), parts[2])) {
      throw const CredentialException(CredentialProblem.corrupted);
    }
    return pin != null && _equal(_mac(key, accountId, generation, pin), parts.last);
  }

  static Future<({String check, String? pinDigest})> _androidMac(
    String accountId,
    String generation, {
    String? pin,
    bool create = false,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) throw const CredentialException(CredentialProblem.missing);
    final result = await _useSecureStorage(
      () => _androidKeys.invokeMapMethod<String, String>(create ? 'create' : 'read', {
        'accountId': accountId,
        'generation': generation,
        'pin': pin,
      }),
    );
    if (result == null) {
      throw CredentialException(create ? CredentialProblem.unavailable : CredentialProblem.missing);
    }
    final check = result['check'];
    final pinDigest = result['pinDigest'];
    if (check == null ||
        !_digestPattern.hasMatch(check) ||
        (pin != null && (pinDigest == null || !_digestPattern.hasMatch(pinDigest)))) {
      throw const CredentialException(CredentialProblem.corrupted);
    }
    return (check: check, pinDigest: pinDigest);
  }

  static String _accountKeyName(String id, String generation) => 'prize_bond_pin_verifier_key_v2_${id}_$generation';

  static Future<List<int>> _readKey(String name) async {
    final encoded = await _useSecureStorage(() => _storage.read(key: name));
    if (encoded == null) throw const CredentialException(CredentialProblem.missing);
    final List<int> key;
    try {
      key = base64Url.decode(encoded);
    } on FormatException {
      throw const CredentialException(CredentialProblem.corrupted);
    }
    if (key.length != 32) throw const CredentialException(CredentialProblem.invalidKeyMaterial);
    return key;
  }

  static Future<T> _useSecureStorage<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException catch (error) {
      final details = error.details;
      // The native plugins report decoding failures with the Keychain OSStatus or the Android exception type.
      if (error.code == 'invalid-pin-key' ||
          (error.code == 'Unexpected security result code' && details == -26275) ||
          (error.code == 'Exception encountered' &&
              details is String &&
              (details.contains('javax.crypto.AEADBadTagException') || details.contains('javax.crypto.BadPaddingException')))) {
        throw const CredentialException(CredentialProblem.corrupted);
      }
      throw const CredentialException(CredentialProblem.unavailable);
    } on MissingPluginException {
      throw const CredentialException(CredentialProblem.unavailable);
    }
  }

  static bool matchesDigest(String verifier, String secret) {
    return _equal(verifier, sha256.convert(utf8.encode(secret)).toString());
  }

  static String _mac(List<int> key, String accountId, String salt, String pin) {
    return Hmac(sha256, key).convert(utf8.encode('$accountId:$salt:$pin')).toString();
  }

  static bool _equal(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return difference == 0;
  }
}
