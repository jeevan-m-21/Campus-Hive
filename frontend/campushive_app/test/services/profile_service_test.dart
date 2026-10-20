import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_test/flutter_test.dart';

import 'package:campushive_app/core/network/api_client.dart';
import 'package:campushive_app/core/network/api_endpoints.dart';
import 'package:campushive_app/core/network/api_exception.dart';
import 'package:campushive_app/core/storage/secure_storage.dart';
import 'package:campushive_app/providers/auth_provider.dart';
import 'package:campushive_app/services/auth_service.dart';
import '../core/storage/secure_storage_test.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient({
    this.patchResponse,
    this.patchException,
  });

  Map<String, dynamic>? patchResponse;
  ApiException? patchException;
  int patchCallCount = 0;
  String? lastPatchPath;
  String? lastPatchToken;
  Map<String, dynamic>? lastPatchBody;

  @override
  Future<Map<String, dynamic>> patch(
    String path, {
    required String idToken,
    required Map<String, dynamic> body,
  }) async {
    patchCallCount++;
    lastPatchPath = path;
    lastPatchToken = idToken;
    lastPatchBody = body;
    if (patchException != null) throw patchException!;
    return patchResponse ?? {};
  }
}

class FakeUser implements User {
  FakeUser({this.token = 'mock-id-token'});

  final String token;

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => token;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseAuth implements FirebaseAuth {
  FakeFirebaseAuth({this.currentUser});

  @override
  User? currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Profile Editing Service and Provider Tests', () {
    late FakeFlutterSecureStorage fakeStorageImpl;
    late SecureStorage secureStorage;
    late FakeApiClient fakeApiClient;
    late FakeFirebaseAuth fakeAuth;
    late AuthService authService;
    late AuthProvider authProvider;

    setUp(() {
      fakeStorageImpl = FakeFlutterSecureStorage();
      secureStorage = SecureStorage(storage: fakeStorageImpl);
      fakeApiClient = FakeApiClient();
      fakeAuth = FakeFirebaseAuth(currentUser: FakeUser(token: 'valid-jwt-token'));
      authService = AuthService(
        apiClient: fakeApiClient,
        secureStorage: secureStorage,
        firebaseAuth: fakeAuth,
      );
      authProvider = AuthProvider(authService: authService);
    });

    test('AuthService.updateProfile sends PATCH to /auth/profile and saves session', () async {
      fakeApiClient.patchResponse = {
        'success': true,
        'message': 'Profile updated successfully.',
        'data': {
          'user': {
            'user_id': 101,
            'full_name': 'Jeevan Updated',
            'phone': '9876543210',
            'role': 'STUDENT',
            'is_active': true,
          },
        },
      };

      final session = await authService.updateProfile(
        fullName: 'Jeevan Updated',
        phone: '9876543210',
      );

      expect(fakeApiClient.patchCallCount, 1);
      expect(fakeApiClient.lastPatchPath, ApiEndpoints.updateProfile);
      expect(fakeApiClient.lastPatchToken, 'valid-jwt-token');
      expect(fakeApiClient.lastPatchBody, {
        'full_name': 'Jeevan Updated',
        'phone': '9876543210',
      });

      expect(session.user['full_name'], 'Jeevan Updated');
      expect(session.role, 'STUDENT');

      // Verify stored session was updated
      final stored = await secureStorage.readSession();
      expect(stored, isNotNull);
      expect(stored!.user?['full_name'], 'Jeevan Updated');
      expect(stored.user?['phone'], '9876543210');
    });

    test('AuthService.updateProfile throws AuthException when not authenticated', () async {
      fakeAuth.currentUser = null;

      expect(
        () => authService.updateProfile(fullName: 'New Name'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('must be logged in'),
          ),
        ),
      );
      expect(fakeApiClient.patchCallCount, 0);
    });

    test('AuthService.updateProfile propagates backend validation errors', () async {
      fakeApiClient.patchException = const ApiException(
        statusCode: 400,
        code: 'validation_error',
        message: "Field 'role' cannot be modified.",
      );

      expect(
        () => authService.updateProfile(fullName: 'Name'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            "Field 'role' cannot be modified.",
          ),
        ),
      );
    });

    test('AuthProvider.updateProfile updates session state and notifies listeners', () async {
      fakeApiClient.patchResponse = {
        'success': true,
        'message': 'Profile updated successfully.',
        'data': {
          'user': {
            'user_id': 101,
            'full_name': 'Mohan Kumar',
            'phone': '9111122222',
            'role': 'SUPERVISOR',
            'is_active': true,
          },
        },
      };

      int notifications = 0;
      authProvider.addListener(() {
        notifications++;
      });

      expect(authProvider.isLoading, isFalse);

      final result = await authProvider.updateProfile(
        fullName: 'Mohan Kumar',
        phone: '9111122222',
      );

      expect(result.user['full_name'], 'Mohan Kumar');
      expect(authProvider.session?.user['full_name'], 'Mohan Kumar');
      expect(authProvider.session?.user['phone'], '9111122222');
      expect(authProvider.session?.role, 'SUPERVISOR');
      expect(authProvider.isLoading, isFalse);
      expect(notifications, greaterThanOrEqualTo(2)); // start loading + finished loading
    });
  });
}
