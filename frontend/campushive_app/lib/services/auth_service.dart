import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../core/storage/secure_storage.dart';
import '../models/academic_department.dart';
import '../models/email_verification.dart';
import '../models/organization.dart';

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
  }) : _firebaseAuth = firebaseAuth,
       _apiClient = apiClient ?? ApiClient(),
       _secureStorage = secureStorage ?? SecureStorage();

  final FirebaseAuth? _firebaseAuth;
  final ApiClient _apiClient;
  final SecureStorage _secureStorage;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;

  static const inactivityDuration = Duration(days: 3);
  static const maxSessionDuration = Duration(days: 7);

  Future<List<Organization>> getPublicOrganizations() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.publicOrganizations);
      final data = response['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(Organization.fromJson)
          .toList();
    } on ApiException catch (error) {
      throw AuthException(_backendMessage(error));
    } catch (_) {
      throw const AuthNetworkException(
        'Unable to load organizations. Please check your connection.',
      );
    }
  }

  Future<List<AcademicDepartment>> getAcademicDepartments(
    int organizationId,
  ) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.academicDepartments(organizationId),
      );
      final data = response['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(AcademicDepartment.fromJson)
          .toList();
    } on ApiException catch (error) {
      throw AuthException(_backendMessage(error));
    } catch (_) {
      throw const AuthNetworkException(
        'Unable to load departments. Please check your connection.',
      );
    }
  }

  Future<OtpSendResult> sendRegistrationOtp({
    required String email,
    required int organizationId,
    required int academicDepartmentId,
    required String identifier,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.sendRegistrationOtp,
        body: {
          'email': email.trim().toLowerCase(),
          'organization_id': organizationId,
          'academic_department_id': academicDepartmentId,
          'usn_or_employee_id': identifier.trim(),
        },
      );
      final data = response['data'];
      if (data is! Map<String, dynamic>) {
        throw const AuthException('Invalid response from server.');
      }
      return OtpSendResult.fromJson(data);
    } on ApiException catch (error) {
      throw AuthException(_backendMessage(error));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthNetworkException(
        'Unable to send verification code. Please check your connection.',
      );
    }
  }

  Future<OtpVerificationResult> verifyRegistrationOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.verifyRegistrationOtp,
        body: {
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
        },
      );
      final data = response['data'];
      if (data is! Map<String, dynamic>) {
        throw const AuthException('Invalid response from server.');
      }
      return OtpVerificationResult.fromJson(data);
    } on ApiException catch (error) {
      throw AuthException(_backendMessage(error));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthNetworkException(
        'Unable to verify code. Please check your connection.',
      );
    }
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String fullName,
    required String identifier,
    required String phone,
    required int organizationId,
    required int academicDepartmentId,
    String? verificationToken,
    String? fcmToken,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw const AuthException('Unable to complete Firebase registration.');
    }

    final idToken = await firebaseUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      await _cleanupCreatedFirebaseUser(firebaseUser);
      throw const AuthException('Unable to obtain Firebase ID token.');
    }

    try {
      final body = <String, dynamic>{
        'organization_id': organizationId,
        'academic_department_id': academicDepartmentId,
        'full_name': fullName,
        'usn_or_employee_id': identifier,
        'phone': phone,
        'role': 'STUDENT',
      };
      if (verificationToken != null && verificationToken.trim().isNotEmpty) {
        body['verification_token'] = verificationToken.trim();
      }
      if (fcmToken != null && fcmToken.trim().isNotEmpty) {
        body['fcm_token'] = fcmToken.trim();
      }

      final response = await _apiClient.post(
        ApiEndpoints.register,
        idToken: idToken,
        body: body,
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

      final nowUtc = DateTime.now().toUtc();
      await _secureStorage.writeSession(
        idToken: idToken,
        user: user,
        sessionCreatedAt: nowUtc,
        lastActiveAt: nowUtc,
      );
      return AuthSession(user: user, role: role);
    } on ApiException catch (error) {
      await _cleanupCreatedFirebaseUser(firebaseUser);
      throw AuthException(_backendMessage(error));
    } catch (e) {
      await _cleanupCreatedFirebaseUser(firebaseUser);
      if (e is AuthException) rethrow;
      throw const AuthException(
        'Unable to complete registration. Please try again.',
      );
    }
  }

  Future<void> _cleanupCreatedFirebaseUser(User firebaseUser) async {
    try {
      await firebaseUser.delete();
    } catch (_) {
      try {
        await _auth.signOut();
      } catch (_) {}
    }
  }

  Future<AuthSession> login({
    required String email,
    required String password,
    required String identifier,
    String? fcmToken,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw const AuthException('Unable to complete Firebase sign-in.');
    }

    final idToken = await firebaseUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      await _auth.signOut();
      throw const AuthException('Unable to obtain Firebase ID token.');
    }

    try {
      final body = <String, dynamic>{'usn_or_employee_id': identifier};
      if (fcmToken != null && fcmToken.trim().isNotEmpty) {
        body['fcm_token'] = fcmToken.trim();
      }

      final response = await _apiClient.post(
        ApiEndpoints.login,
        idToken: idToken,
        body: body,
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

      final nowUtc = DateTime.now().toUtc();
      await _secureStorage.writeSession(
        idToken: idToken,
        user: user,
        sessionCreatedAt: nowUtc,
        lastActiveAt: nowUtc,
      );
      return AuthSession(user: user, role: role);
    } on ApiException catch (error) {
      if (error.code == 'invalid_identifier') {
        await _auth.signOut();
      }
      throw AuthException(_backendMessage(error));
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
  }

  Future<AuthSession> getCurrentUser(String idToken) async {
    final response = await _apiClient.get(ApiEndpoints.me, idToken: idToken);
    final data = response['data'];
    final user = data is Map<String, dynamic> ? data['user'] : null;
    if (user is! Map<String, dynamic>) {
      throw const AuthException('The server returned an invalid user session.');
    }

    final role = user['role'];
    final isActive = user['is_active'] == true;
    if (role is! String || role.isEmpty || !isActive) {
      throw const AuthException('User account is inactive or role is invalid.');
    }

    return AuthSession(user: user, role: role);
  }

  Future<AuthSession> updateProfile({
    String? fullName,
    String? phone,
    String? profileImage,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw const AuthException('You must be logged in to update your profile.');
    }
    final idToken = await firebaseUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Unable to obtain authentication token.');
    }

    final body = <String, dynamic>{};
    if (fullName != null) {
      body['full_name'] = fullName;
    }
    if (phone != null) {
      body['phone'] = phone;
    }
    if (profileImage != null) {
      body['profile_image'] = profileImage;
    }

    try {
      final response = await _apiClient.patch(
        ApiEndpoints.updateProfile,
        idToken: idToken,
        body: body,
      );
      final data = response['data'];
      final user = data is Map<String, dynamic> ? data['user'] : null;
      if (user is! Map<String, dynamic>) {
        throw const AuthException(
          'The server returned an invalid user response.',
        );
      }

      final role = user['role'];
      if (role is! String || role.isEmpty) {
        throw const AuthException('The server returned an invalid user role.');
      }

      final stored = await _secureStorage.readSession();
      final nowUtc = DateTime.now().toUtc();
      await _secureStorage.writeSession(
        idToken: idToken,
        user: user,
        sessionCreatedAt: stored?.sessionCreatedAt ?? nowUtc,
        lastActiveAt: nowUtc,
      );

      return AuthSession(user: user, role: role);
    } on ApiException catch (error) {
      final msg = error.message.isNotEmpty && error.message != 'Request failed.'
          ? error.message
          : 'Unable to update profile. Please try again.';
      throw AuthException(msg);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthNetworkException(
        'Unable to update profile. Please check your connection.',
      );
    }
  }

  Future<AuthSession> uploadProfileImage(String filePath) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw const AuthException(
        'You must be logged in to update your profile picture.',
      );
    }
    final idToken = await firebaseUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Unable to obtain authentication token.');
    }

    try {
      final response = await _apiClient.postMultipart(
        ApiEndpoints.uploadProfileImage,
        idToken: idToken,
        filePath: filePath,
        fileField: 'image',
      );
      final data = response['data'];
      final user = data is Map<String, dynamic> ? data['user'] : null;
      if (user is! Map<String, dynamic>) {
        throw const AuthException(
          'The server returned an invalid user response.',
        );
      }

      final role = user['role'];
      if (role is! String || role.isEmpty) {
        throw const AuthException('The server returned an invalid user role.');
      }

      final stored = await _secureStorage.readSession();
      final nowUtc = DateTime.now().toUtc();
      await _secureStorage.writeSession(
        idToken: idToken,
        user: user,
        sessionCreatedAt: stored?.sessionCreatedAt ?? nowUtc,
        lastActiveAt: nowUtc,
      );

      return AuthSession(user: user, role: role);
    } on ApiException catch (error) {
      final msg = error.message.isNotEmpty && error.message != 'Request failed.'
          ? error.message
          : 'Unable to upload profile picture. Please try again.';
      throw AuthException(msg);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthNetworkException(
        'Unable to upload profile picture. Please check your connection.',
      );
    }
  }

  Future<AuthSession?> restoreSession() async {
    // 1. Read stored session metadata
    final stored = await _secureStorage.readSession();
    if (stored == null) {
      await signOut();
      return null;
    }

    final nowUtc = DateTime.now().toUtc();

    // 2. Check 3 days inactivity
    if (stored.lastActiveAt == null ||
        nowUtc.difference(stored.lastActiveAt!) > inactivityDuration) {
      await signOut();
      return null;
    }

    // 3. Check 7 days maximum session duration
    if (stored.sessionCreatedAt == null ||
        nowUtc.difference(stored.sessionCreatedAt!) > maxSessionDuration) {
      await signOut();
      return null;
    }

    // 4. Check Firebase currentUser
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      await signOut();
      return null;
    }

    // 5. Request fresh Firebase ID token
    String? idToken;
    try {
      idToken = await firebaseUser.getIdToken();
    } catch (_) {
      await signOut();
      return null;
    }

    if (idToken == null || idToken.isEmpty) {
      await signOut();
      return null;
    }

    // 6 & 7. Call GET /api/v1/auth/me to validate backend and retrieve authoritative user & role
    try {
      final session = await getCurrentUser(idToken);

      // 8. Update last-active timestamp only after successful validation
      final updatedActive = DateTime.now().toUtc();
      await _secureStorage.updateLastActive(updatedActive);

      // Refresh stored user metadata with latest profile while preserving session creation time
      await _secureStorage.writeSession(
        idToken: idToken,
        user: session.user,
        sessionCreatedAt: stored.sessionCreatedAt,
        lastActiveAt: updatedActive,
      );

      return session;
    } on ApiException catch (error) {
      // 9. If definitive 401 or 403, account is revoked/invalid -> sign out
      if (error.statusCode == 401 || error.statusCode == 403) {
        await signOut();
        return null;
      }
      throw AuthNetworkException(
        error.message.isNotEmpty
            ? error.message
            : 'Server error verifying session (${error.statusCode}).',
      );
    } catch (e) {
      if (e is AuthException) {
        await signOut();
        return null;
      }
      throw const AuthNetworkException(
        'Unable to connect to server. Please check your network.',
      );
    }
  }

  Future<bool> updateFcmToken(String fcmToken) async {
    final cleanToken = fcmToken.trim();
    if (cleanToken.isEmpty) {
      debugPrint('[AuthService] updateFcmToken called with empty token.');
      return false;
    }
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      debugPrint('[AuthService] updateFcmToken skipped: no current Firebase user.');
      return false;
    }
    final idToken = await firebaseUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      debugPrint('[AuthService] updateFcmToken skipped: unable to obtain ID token.');
      return false;
    }

    try {
      await _apiClient.post(
        ApiEndpoints.updateFcmToken,
        idToken: idToken,
        body: {'fcm_token': cleanToken},
      );
      final masked = cleanToken.length > 6
          ? '${cleanToken.substring(0, 6)}... (len: ${cleanToken.length})'
          : '***';
      debugPrint('[AuthService] FCM token successfully updated on backend: $masked');
      return true;
    } catch (e) {
      debugPrint('[AuthService] Failed to update FCM token on backend: $e');
      return false;
    }
  }

  Future<void> recordActivity() async {
    final nowUtc = DateTime.now().toUtc();
    await _secureStorage.updateLastActive(nowUtc);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _secureStorage.clearSession();
  }

  String _backendMessage(ApiException error) {
    if (error.code == 'invalid_identifier') {
      return 'Invalid USN or employee ID.';
    }
    if (error.code == 'invalid_otp') {
      return error.message.isNotEmpty
          ? error.message
          : 'Invalid verification code.';
    }
    if (error.code == 'otp_expired') {
      return 'Verification code has expired. Please request a new code.';
    }
    if (error.code == 'attempts_exceeded') {
      return 'Maximum verification attempts exceeded. Please request a new code.';
    }
    if (error.code == 'cooldown_active' ||
        error.code == 'rate_limit_exceeded') {
      return error.message.isNotEmpty
          ? error.message
          : 'Too many requests. Please wait before trying again.';
    }
    if (error.code == 'email_delivery_failed') {
      return 'Unable to send verification email. Please check your email address or try again later.';
    }
    if (error.code == 'missing_verification_token' ||
        error.code == 'invalid_verification_token') {
      return 'Email verification token is invalid or expired. Please verify your email again.';
    }
    if (error.code == 'verification_token_expired') {
      return 'Email verification has expired. Please verify your email again.';
    }
    if (error.code == 'email_mismatch' || error.code == 'data_tampered') {
      return 'Registration details do not match verified email. Please verify again.';
    }
    if (error.statusCode == 403) {
      return error.message.isNotEmpty
          ? error.message
          : 'This account is not authorized.';
    }
    if (error.statusCode >= 500) {
      return 'CampusHive is temporarily unavailable.';
    }
    if (error.statusCode == 401) {
      return error.message.isNotEmpty
          ? error.message
          : 'Authentication failed. Please try again.';
    }
    if (error.message.isNotEmpty && error.message != 'Request failed.') {
      return error.message;
    }
    return 'Unable to complete request.';
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

class AuthNetworkException implements Exception {
  const AuthNetworkException(this.message);

  final String message;
}
