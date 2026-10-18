import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredSession {
  const StoredSession({
    this.idToken,
    this.user,
    this.role,
    this.sessionCreatedAt,
    this.lastActiveAt,
  });

  final String? idToken;
  final Map<String, dynamic>? user;
  final String? role;
  final DateTime? sessionCreatedAt;
  final DateTime? lastActiveAt;

  bool get hasTimestamps => sessionCreatedAt != null && lastActiveAt != null;
}

class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _idTokenKey = 'firebase_id_token';
  static const _userKey = 'campushive_user';
  static const _roleKey = 'campushive_role';
  static const _sessionCreatedAtKey = 'session_created_at';
  static const _lastActiveAtKey = 'last_active_at';

  final FlutterSecureStorage _storage;

  Future<void> writeSession({
    required String idToken,
    required Map<String, dynamic> user,
    DateTime? sessionCreatedAt,
    DateTime? lastActiveAt,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final created = sessionCreatedAt ?? nowUtc;
    final active = lastActiveAt ?? nowUtc;

    await Future.wait([
      _storage.write(key: _idTokenKey, value: idToken),
      _storage.write(key: _userKey, value: jsonEncode(user)),
      _storage.write(key: _roleKey, value: user['role'] as String?),
      _storage.write(
        key: _sessionCreatedAtKey,
        value: created.toIso8601String(),
      ),
      _storage.write(key: _lastActiveAtKey, value: active.toIso8601String()),
    ]);
  }

  Future<void> updateLastActive(DateTime timestamp) async {
    await _storage.write(
      key: _lastActiveAtKey,
      value: timestamp.toUtc().toIso8601String(),
    );
  }

  Future<StoredSession?> readSession() async {
    final values = await Future.wait([
      _storage.read(key: _idTokenKey),
      _storage.read(key: _userKey),
      _storage.read(key: _roleKey),
      _storage.read(key: _sessionCreatedAtKey),
      _storage.read(key: _lastActiveAtKey),
    ]);

    final idToken = values[0];
    final userRaw = values[1];
    final role = values[2];
    final createdAtRaw = values[3];
    final lastActiveRaw = values[4];

    if (idToken == null && userRaw == null && role == null) {
      return null;
    }

    Map<String, dynamic>? user;
    if (userRaw != null && userRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(userRaw);
        if (decoded is Map<String, dynamic>) {
          user = decoded;
        }
      } catch (_) {}
    }

    final createdAt = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw)?.toUtc()
        : null;
    final lastActive = lastActiveRaw != null
        ? DateTime.tryParse(lastActiveRaw)?.toUtc()
        : null;

    return StoredSession(
      idToken: idToken,
      user: user,
      role: role,
      sessionCreatedAt: createdAt,
      lastActiveAt: lastActive,
    );
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _idTokenKey),
      _storage.delete(key: _userKey),
      _storage.delete(key: _roleKey),
      _storage.delete(key: _sessionCreatedAtKey),
      _storage.delete(key: _lastActiveAtKey),
    ]);
  }
}
