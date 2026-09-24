import 'package:firebase_auth/firebase_auth.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../core/storage/secure_storage.dart';

class AuthSession {
  const AuthSession({required this.user, required this.role});

  final Map<String, dynamic> user;
  final String role;
}

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    ApiClient? apiClient,
    SecureStorage? secureStorage,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _apiClient = apiClient ?? ApiClient(),
       _secureStorage = secureStorage ?? SecureStorage();

  final FirebaseAuth _firebaseAuth;
  final ApiClient _apiClient;
  final SecureStorage _secureStorage;

  Future<AuthSession> login({
    required String email,
    required String password,
    required String identifier,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw const AuthException('Unable to complete Firebase sign-in.');
    }

    final idToken = await firebaseUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      await _firebaseAuth.signOut();
      throw const AuthException('Unable to obtain Firebase ID token.');
    }

    try {
      final response = await _apiClient.post(
        ApiEndpoints.login,
        idToken: idToken,
        body: {'usn_or_employee_id': identifier},
      );
      final data = response['data'];
      final user = data is Map<String, dynamic> ? data['user'] : null;
      if (user is! Map<String, dynamic>) {
        throw const AuthException(
          'The server returned an invalid user session.',
        );
      }

      final role = user['role'];
      if (role is! String || role.isEmpty) {
        throw const AuthException('The server returned an invalid user role.');
      }

      await _secureStorage.writeSession(idToken: idToken, user: user);
      return AuthSession(user: user, role: role);
    } on ApiException catch (error) {
      if (error.code == 'invalid_identifier') {
        await _firebaseAuth.signOut();
      }
      throw AuthException(_backendMessage(error));
    } catch (_) {
      await _firebaseAuth.signOut();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _secureStorage.clearSession();
  }

  String _backendMessage(ApiException error) {
    if (error.code == 'invalid_identifier') {
      return 'Invalid USN or employee ID.';
    }
    if (error.statusCode == 403) {
      return 'This account is not authorized.';
    }
    if (error.statusCode >= 500) {
      return 'CampusHive is temporarily unavailable.';
    }
    if (error.statusCode == 401) {
      return 'Authentication failed. Please try again.';
    }
    return 'Unable to complete sign-in.';
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}
