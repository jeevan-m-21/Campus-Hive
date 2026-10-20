import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_test/flutter_test.dart';

import 'package:campushive_app/core/network/api_client.dart';
import 'package:campushive_app/core/network/api_endpoints.dart';
import 'package:campushive_app/core/network/api_exception.dart';
import 'package:campushive_app/core/storage/secure_storage.dart';
import 'package:campushive_app/providers/auth_provider.dart';
import 'package:campushive_app/services/auth_service.dart';
import '../core/storage/secure_storage_test.dart';

class FakeMultipartApiClient extends ApiClient {
  FakeMultipartApiClient({
    this.multipartResponse,
    this.multipartException,
  });

  Map<String, dynamic>? multipartResponse;
  ApiException? multipartException;
  int multipartCallCount = 0;
  String? lastPath;
  String? lastToken;
  String? lastFilePath;
  String? lastFileField;

  @override
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String idToken,
    required String filePath,
    String fileField = 'image',
  }) async {
    multipartCallCount++;
    lastPath = path;
    lastToken = idToken;
    lastFilePath = filePath;
    lastFileField = fileField;
    if (multipartException != null) throw multipartException!;
    return multipartResponse ?? {};
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
  group('Profile Picture Upload Service and Provider Tests', () {
    late FakeFlutterSecureStorage fakeStorageImpl;
    late SecureStorage secureStorage;
    late FakeMultipartApiClient fakeApiClient;
    late FakeFirebaseAuth fakeAuth;
    late AuthService authService;
    late AuthProvider authProvider;

    setUp(() {
      fakeStorageImpl = FakeFlutterSecureStorage();
      secureStorage = SecureStorage(storage: fakeStorageImpl);
      fakeApiClient = FakeMultipartApiClient();
      fakeAuth = FakeFirebaseAuth(
        currentUser: FakeUser(token: 'valid-jwt-token'),
      );
      authService = AuthService(
        apiClient: fakeApiClient,
        secureStorage: secureStorage,
        firebaseAuth: fakeAuth,
      );
      authProvider = AuthProvider(authService: authService);
    });

    test('AuthService.uploadProfileImage sends multipart POST to /auth/profile-image and saves session', () async {
      fakeApiClient.multipartResponse = {
        'success': true,
        'message': 'Profile picture updated successfully.',
        'data': {
          'image_url': '/uploads/profile/uuid-12345.png',
          'user': {
            'user_id': 101,
            'full_name': 'Jeevan Kumar',
            'phone': '9876543210',
            'role': 'STUDENT',
            'profile_image': '/uploads/profile/uuid-12345.png',
            'is_active': true,
          },
        },
      };

      final session = await authService.uploadProfileImage('/local/path/avatar.png');

      expect(fakeApiClient.multipartCallCount, 1);
      expect(fakeApiClient.lastPath, ApiEndpoints.uploadProfileImage);
      expect(fakeApiClient.lastToken, 'valid-jwt-token');
      expect(fakeApiClient.lastFilePath, '/local/path/avatar.png');
      expect(fakeApiClient.lastFileField, 'image');

      expect(session.user['profile_image'], '/uploads/profile/uuid-12345.png');
      expect(session.role, 'STUDENT');

      // Verify stored session was updated
      final stored = await secureStorage.readSession();
      expect(stored, isNotNull);
      expect(stored!.user?['profile_image'], '/uploads/profile/uuid-12345.png');
    });

    test('AuthService.uploadProfileImage throws AuthException when user is not logged in', () async {
      fakeAuth.currentUser = null;

      expect(
        () => authService.uploadProfileImage('/local/path/avatar.png'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('must be logged in'),
          ),
        ),
      );
      expect(fakeApiClient.multipartCallCount, 0);
    });

    test('AuthService.uploadProfileImage propagates backend validation errors', () async {
      fakeApiClient.multipartException = const ApiException(
        statusCode: 400,
        code: 'validation_error',
        message: 'File size exceeds 5MB limit.',
      );

      expect(
        () => authService.uploadProfileImage('/local/path/huge.png'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'File size exceeds 5MB limit.',
          ),
        ),
      );
    });

    test('AuthProvider.uploadProfileImage updates session state and notifies listeners', () async {
      fakeApiClient.multipartResponse = {
        'success': true,
        'message': 'Profile picture updated successfully.',
        'data': {
          'image_url': '/uploads/profile/new-avatar.jpg',
          'user': {
            'user_id': 101,
            'full_name': 'Jeevan Kumar',
            'role': 'STUDENT',
            'profile_image': '/uploads/profile/new-avatar.jpg',
            'is_active': true,
          },
        },
      };

      int notifications = 0;
      authProvider.addListener(() {
        notifications++;
      });

      expect(authProvider.isLoading, isFalse);

      final result = await authProvider.uploadProfileImage('/local/new.jpg');

      expect(result.user['profile_image'], '/uploads/profile/new-avatar.jpg');
      expect(authProvider.session?.user['profile_image'], '/uploads/profile/new-avatar.jpg');
      expect(authProvider.isLoading, isFalse);
      expect(notifications, greaterThanOrEqualTo(2));
    });
  });
}
