import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _idTokenKey = 'firebase_id_token';
  static const _userKey = 'campushive_user';
  static const _roleKey = 'campushive_role';

  final FlutterSecureStorage _storage;

  Future<void> writeSession({
    required String idToken,
    required Map<String, dynamic> user,
  }) async {
    await _storage.write(key: _idTokenKey, value: idToken);
    await _storage.write(key: _userKey, value: jsonEncode(user));
    await _storage.write(key: _roleKey, value: user['role'] as String?);
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _idTokenKey),
      _storage.delete(key: _userKey),
      _storage.delete(key: _roleKey),
    ]);
  }
}
