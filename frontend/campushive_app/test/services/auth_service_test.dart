import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_test/flutter_test.dart';

import 'package:campushive_app/core/network/api_client.dart';
import 'package:campushive_app/core/network/api_exception.dart';
import 'package:campushive_app/core/storage/secure_storage.dart';
import 'package:campushive_app/providers/auth_provider.dart';
import 'package:campushive_app/services/auth_service.dart';
import '../core/storage/secure_storage_test.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient({this.getResponse, this.getException});

  Map<String, dynamic>? getResponse;
  ApiException? getException;
  int getCallCount = 0;

  @override
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    String? idToken,
  }) async {
    getCallCount++;
    if (getException != null) throw getException!;
    return getResponse ?? {};
  }
}

class FakeUser implements User {
  FakeUser({this.token = 'fresh-firebase-token', this.throwOnToken = false});

  final String token;
  final bool throwOnToken;

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async {
    if (throwOnToken) throw Exception('Firebase token error');
    return token;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseAuth implements FirebaseAuth {
  FakeFirebaseAuth({this.currentUser});

  @override
  User? currentUser;
  int signOutCount = 0;

  @override
  Future<void> signOut() async {
    signOutCount++;
    currentUser = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AuthService & AuthProvider Persistent Login Tests', () {
    late FakeFlutterSecureStorage fakeStorageImpl;
    late SecureStorage secureStorage;
    late FakeApiClient fakeApiClient;
    late FakeFirebaseAuth fakeAuth;
    late AuthService authService;

    setUp(() {
      fakeStorageImpl = FakeFlutterSecureStorage();
      secureStorage = SecureStorage(storage: fakeStorageImpl);
      fakeApiClient = FakeApiClient();
      fakeAuth = FakeFirebaseAuth(currentUser: FakeUser());
      authService = AuthService(
        firebaseAuth: fakeAuth,
        apiClient: fakeApiClient,
        secureStorage: secureStorage,
      );
    });

    test(
      'restoreSession restores session when active within 3 days and 7 days total',
      () async {
        final now = DateTime.now().toUtc();
        final created = now.subtract(const Duration(days: 2));
        final lastActive = now.subtract(const Duration(hours: 1));

        await secureStorage.writeSession(
          idToken: 'stored-token',
          user: {'user_id': 1, 'role': 'STUDENT', 'is_active': true},
          sessionCreatedAt: created,
          lastActiveAt: lastActive,
        );

        fakeApiClient.getResponse = {
          'data': {
            'user': {
              'user_id': 1,
              'role': 'STUDENT',
              'full_name': 'Alice Student',
              'is_active': true,
            },
          },
        };

        final session = await authService.restoreSession();

        expect(session, isNotNull);
        expect(session!.role, 'STUDENT');
        expect(session.user['full_name'], 'Alice Student');
        expect(fakeAuth.signOutCount, 0);

        // Verify last_active_at was updated to now
        final storedAfter = await secureStorage.readSession();
        expect(storedAfter?.lastActiveAt?.isAfter(lastActive), isTrue);
        expect(storedAfter?.sessionCreatedAt, created);
      },
    );

    test(
      'restoreSession fails and signs out when Firebase currentUser is missing',
      () async {
        fakeAuth.currentUser = null;

        final now = DateTime.now().toUtc();
        await secureStorage.writeSession(
          idToken: 'stored-token',
          user: {'role': 'STUDENT'},
          sessionCreatedAt: now.subtract(const Duration(days: 1)),
          lastActiveAt: now.subtract(const Duration(hours: 2)),
        );

        final session = await authService.restoreSession();

        expect(session, isNull);
        expect(fakeAuth.signOutCount, 1);
        expect(await secureStorage.readSession(), isNull);
      },
    );

    test(
      'restoreSession fails and signs out when session metadata is missing',
      () async {
        final session = await authService.restoreSession();

        expect(session, isNull);
        expect(fakeAuth.signOutCount, 1);
        expect(await secureStorage.readSession(), isNull);
      },
    );

    test(
      'restoreSession fails and signs out when inactivity exceeds 3 days',
      () async {
        final now = DateTime.now().toUtc();
        // Inactive for 3 days and 2 hours
        final created = now.subtract(const Duration(days: 4));
        final lastActive = now.subtract(const Duration(days: 3, hours: 2));

        await secureStorage.writeSession(
          idToken: 'stored-token',
          user: {'role': 'STUDENT'},
          sessionCreatedAt: created,
          lastActiveAt: lastActive,
        );

        final session = await authService.restoreSession();

        expect(session, isNull);
        expect(fakeAuth.signOutCount, 1);
        expect(await secureStorage.readSession(), isNull);
      },
    );

    test(
      'restoreSession fails and signs out when session creation exceeds 7 days',
      () async {
        final now = DateTime.now().toUtc();
        // Created 7 days and 1 hour ago, even though active 10 minutes ago
        final created = now.subtract(const Duration(days: 7, hours: 1));
        final lastActive = now.subtract(const Duration(minutes: 10));

        await secureStorage.writeSession(
          idToken: 'stored-token',
          user: {'role': 'ORG_ADMIN'},
          sessionCreatedAt: created,
          lastActiveAt: lastActive,
        );

        final session = await authService.restoreSession();

        expect(session, isNull);
        expect(fakeAuth.signOutCount, 1);
        expect(await secureStorage.readSession(), isNull);
      },
    );

    test(
      'restoreSession clears session and signs out when backend returns 401',
      () async {
        final now = DateTime.now().toUtc();
        await secureStorage.writeSession(
          idToken: 'stored-token',
          user: {'role': 'STUDENT'},
          sessionCreatedAt: now.subtract(const Duration(days: 1)),
          lastActiveAt: now.subtract(const Duration(hours: 1)),
        );

        fakeApiClient.getException = const ApiException(
          statusCode: 401,
          code: 'invalid_token',
          message: 'Token has been revoked.',
        );

        final session = await authService.restoreSession();

        expect(session, isNull);
        expect(fakeAuth.signOutCount, 1);
        expect(await secureStorage.readSession(), isNull);
      },
    );

    test(
      'restoreSession clears session and signs out when backend returns 403 or inactive',
      () async {
        final now = DateTime.now().toUtc();
        await secureStorage.writeSession(
          idToken: 'stored-token',
          user: {'role': 'STUDENT'},
          sessionCreatedAt: now.subtract(const Duration(days: 1)),
          lastActiveAt: now.subtract(const Duration(hours: 1)),
        );

        fakeApiClient.getResponse = {
          'data': {
            'user': {
              'user_id': 1,
              'role': 'STUDENT',
              'is_active': false, // Deactivated account
            },
          },
        };

        final session = await authService.restoreSession();

        expect(session, isNull);
        expect(fakeAuth.signOutCount, 1);
        expect(await secureStorage.readSession(), isNull);
      },
    );

    test(
      'restoreSession throws AuthNetworkException and preserves storage on network outage',
      () async {
        final now = DateTime.now().toUtc();
        final created = now.subtract(const Duration(days: 1));
        final lastActive = now.subtract(const Duration(hours: 1));

        await secureStorage.writeSession(
          idToken: 'stored-token',
          user: {'role': 'STUDENT'},
          sessionCreatedAt: created,
          lastActiveAt: lastActive,
        );

        fakeApiClient.getException = const ApiException(
          statusCode: 503,
          code: 'service_unavailable',
          message: 'CampusHive is temporarily offline.',
        );

        expect(
          () => authService.restoreSession(),
          throwsA(isA<AuthNetworkException>()),
        );

        // Verify that local credentials and session were NOT deleted
        expect(fakeAuth.signOutCount, 0);
        final storedAfter = await secureStorage.readSession();
        expect(storedAfter, isNotNull);
        expect(storedAfter?.sessionCreatedAt, created);
      },
    );

    test('explicit signOut clears FirebaseAuth and SecureStorage', () async {
      await secureStorage.writeSession(
        idToken: 'token',
        user: {'role': 'STUDENT'},
      );

      await authService.signOut();

      expect(fakeAuth.signOutCount, 1);
      expect(fakeAuth.currentUser, isNull);
      expect(await secureStorage.readSession(), isNull);
    });

    test(
      'AuthProvider prevents duplicate concurrent restoreSession calls',
      () async {
        final now = DateTime.now().toUtc();
        await secureStorage.writeSession(
          idToken: 'stored-token',
          user: {'role': 'STUDENT', 'is_active': true},
          sessionCreatedAt: now.subtract(const Duration(days: 1)),
          lastActiveAt: now.subtract(const Duration(hours: 1)),
        );

        fakeApiClient.getResponse = {
          'data': {
            'user': {'user_id': 1, 'role': 'STUDENT', 'is_active': true},
          },
        };

        final provider = AuthProvider(authService: authService);

        // Trigger two restoration calls concurrently
        final future1 = provider.restoreSession();
        final future2 = provider.restoreSession();

        final results = await Future.wait([future1, future2]);

        expect(results[0]?.role, 'STUDENT');
        expect(results[1]?.role, 'STUDENT');
        expect(fakeApiClient.getCallCount, 1); // Only called once!
      },
    );
  });
}
