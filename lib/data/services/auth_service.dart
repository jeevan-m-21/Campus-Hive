/// Authentication Service
/// Handles user authentication and token management

import 'package:shared_preferences/shared_preferences.dart';
import 'package:campus_hive/core/constants/app_constants.dart';
import 'package:campus_hive/data/models/auth_models.dart';
import 'package:campus_hive/data/services/api_service.dart';

class AuthService {
  final ApiService apiService;
  final SharedPreferences prefs;

  AuthService({required this.apiService, required this.prefs});

  /// Check if user is authenticated
  bool get isAuthenticated {
    return accessToken != null && accessToken!.isNotEmpty;
  }

  /// Get stored access token
  String? get accessToken {
    return prefs.getString('access_token');
  }

  /// Get stored refresh token
  String? get refreshToken {
    return prefs.getString('refresh_token');
  }

  /// Get stored user
  User? get storedUser {
    final userJson = prefs.getString('user_data');
    if (userJson == null) return null;

    // Parse JSON (requires json_decode)
    // For now, return null
    return null;
  }

  /// Login user
  Future<LoginResponse> login({
    required String email,
    required String password,
    String? deviceId,
    String? fcmToken,
  }) async {
    final request = LoginRequest(
      email: email,
      password: password,
      deviceId: deviceId,
      fcmToken: fcmToken,
    );

    try {
      final response = await apiService.post(
        ApiConstants.authLogin,
        data: request.toJson(),
      );

      final loginResponse = LoginResponse.fromJson(response);

      // Store tokens and user data
      await _storeAuthData(loginResponse);

      // Update API service token
      apiService.setAccessToken(loginResponse.tokens.accessToken);

      return loginResponse;
    } catch (e) {
      rethrow;
    }
  }

  /// Register new user
  Future<LoginResponse> register({
    required String email,
    required String password,
    required String firstName,
    String? lastName,
    String? phone,
    required String organizationId,
  }) async {
    final request = RegisterRequest(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      organizationId: organizationId,
      role: 'student',
    );

    try {
      final response = await apiService.post(
        ApiConstants.authRegister,
        data: request.toJson(),
      );

      // Registration returns user data but not tokens
      // Redirect to login after successful registration
      return LoginResponse.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Refresh access token
  Future<AuthTokens> refreshAccessToken() async {
    try {
      final response = await apiService.post(
        ApiConstants.authRefresh,
        data: {'refresh_token': refreshToken},
      );

      final tokens = AuthTokens.fromJson(response['tokens'] ?? {});

      // Update stored tokens
      await prefs.setString('access_token', tokens.accessToken);
      await prefs.setString('refresh_token', tokens.refreshToken);

      // Update API service token
      apiService.setAccessToken(tokens.accessToken);

      return tokens;
    } catch (e) {
      // If refresh fails, user needs to login again
      await logout();
      rethrow;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      // Call logout endpoint if needed
      await apiService.post(ApiConstants.authLogout);
    } catch (e) {
      // Continue logout even if API call fails
    }

    // Clear local data
    await _clearAuthData();
    apiService.clearAccessToken();
  }

  /// Store authentication data
  Future<void> _storeAuthData(LoginResponse response) async {
    await prefs.setString('access_token', response.tokens.accessToken);
    await prefs.setString('refresh_token', response.tokens.refreshToken);
    await prefs.setString(
      'token_expiry',
      DateTime.now()
          .add(Duration(seconds: response.tokens.expiresIn))
          .toIso8601String(),
    );

    // Store user data as JSON (you'll need json_serializable)
    // For now, store key fields
    await prefs.setString('user_id', response.user.id);
    await prefs.setString('user_email', response.user.email);
    await prefs.setString('user_role', response.user.role);
    await prefs.setString('organization_id', response.user.organizationId);
  }

  /// Clear stored authentication data
  Future<void> _clearAuthData() async {
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('token_expiry');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    await prefs.remove('organization_id');
  }

  /// Check if token is expired
  bool isTokenExpired() {
    final expiryString = prefs.getString('token_expiry');
    if (expiryString == null) return true;

    final expiry = DateTime.parse(expiryString);
    return DateTime.now().isAfter(expiry);
  }
}
