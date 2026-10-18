import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campushive_app/core/storage/secure_storage.dart';

class FakeFlutterSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SecureStorage Tests', () {
    late FakeFlutterSecureStorage fakeStorage;
    late SecureStorage storage;

    setUp(() {
      fakeStorage = FakeFlutterSecureStorage();
      storage = SecureStorage(storage: fakeStorage);
    });

    test('readSession returns null when storage is empty', () async {
      final session = await storage.readSession();
      expect(session, isNull);
    });

    test(
      'writeSession and readSession correctly round-trip all data and timestamps',
      () async {
        final created = DateTime.utc(2026, 10, 15, 8, 30, 0);
        final active = DateTime.utc(2026, 10, 18, 14, 0, 0);

        await storage.writeSession(
          idToken: 'test-firebase-token',
          user: {'user_id': 10, 'full_name': 'Test User', 'role': 'STUDENT'},
          sessionCreatedAt: created,
          lastActiveAt: active,
        );

        final session = await storage.readSession();
        expect(session, isNotNull);
        expect(session!.idToken, 'test-firebase-token');
        expect(session.role, 'STUDENT');
        expect(session.user?['user_id'], 10);
        expect(session.user?['full_name'], 'Test User');
        expect(session.sessionCreatedAt, created);
        expect(session.lastActiveAt, active);
        expect(session.hasTimestamps, isTrue);
      },
    );

    test('updateLastActive updates only lastActiveAt timestamp', () async {
      final created = DateTime.utc(2026, 10, 15, 8, 30, 0);
      final active1 = DateTime.utc(2026, 10, 16, 9, 0, 0);
      final active2 = DateTime.utc(2026, 10, 18, 17, 45, 0);

      await storage.writeSession(
        idToken: 'token-xyz',
        user: {'role': 'ORG_ADMIN'},
        sessionCreatedAt: created,
        lastActiveAt: active1,
      );

      await storage.updateLastActive(active2);

      final session = await storage.readSession();
      expect(session?.sessionCreatedAt, created);
      expect(session?.lastActiveAt, active2);
    });

    test('clearSession removes all session keys and timestamps', () async {
      await storage.writeSession(
        idToken: 'token-abc',
        user: {'role': 'SUPERVISOR'},
      );

      expect(await storage.readSession(), isNotNull);

      await storage.clearSession();

      expect(await storage.readSession(), isNull);
    });
  });
}
