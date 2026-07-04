/// Authentication Provider
/// Manages authentication state using Provider pattern

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campus_hive/data/models/auth_models.dart';
import 'package:campus_hive/data/services/api_service.dart';
import 'package:campus_hive/data/services/auth_service.dart';
import 'package:campus_hive/data/services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  late AuthService _authService;
  late ApiService _apiService;
  late NotificationService _notificationService;

  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider({
    required AuthService authService,
    required ApiService apiService,
    required NotificationService notificationService,
  }) {
    _authService = authService;
    _apiService = apiService;
    _notificationService = notificationService;

    // Check if already authenticated
    _checkAuthStatus();
  }

  /// Check if user is already authenticated
  Future<void> _checkAuthStatus() async {
    if (_authService.isAuthenticated) {
      _isAuthenticated = true;
      _apiService.setAccessToken(_authService.accessToken!);

      // Load user data
      final userId = _getUserIdFromStorage();
      if (userId != null) {
        // You would load user details from API here if needed
        _isAuthenticated = true;
      }
    }
    notifyListeners();
  }

  /// Login user
  Future<bool> login({
    required String email,
    required String password,
    String? deviceId,
    String? fcmToken,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.login(
        email: email,
        password: password,
        deviceId: deviceId,
        fcmToken: fcmToken,
      );

      _user = response.user;
      _isAuthenticated = true;
      _isLoading = false;
      _error = null;

      // Initialize Firebase Messaging
      await _notificationService.initializeFirebaseMessaging();

      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  /// Register new user
  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    String? lastName,
    String? phone,
    required String organizationId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        organizationId: organizationId,
      );

      _isLoading = false;
      _error = null;

      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _isAuthenticated = false;
    _error = null;
    notifyListeners();
  }

  /// Refresh token
  Future<bool> refreshToken() async {
    try {
      await _authService.refreshAccessToken();
      return true;
    } catch (e) {
      _error = 'Token refresh failed';
      notifyListeners();
      return false;
    }
  }

  /// Get user ID from storage
  String? _getUserIdFromStorage() {
    // This would be implemented properly with SharedPreferences
    // For now, returns null
    return null;
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
