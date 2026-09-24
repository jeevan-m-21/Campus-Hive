import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;
  AuthSession? _session;
  bool _isLoading = false;

  AuthSession? get session => _session;
  bool get isLoading => _isLoading;

  Future<AuthSession> login({
    required String email,
    required String password,
    required String identifier,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final session = await _authService.login(
        email: email,
        password: password,
        identifier: identifier,
      );
      _session = session;
      return session;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _session = null;
    notifyListeners();
  }
}
