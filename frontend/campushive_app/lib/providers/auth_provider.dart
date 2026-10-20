import 'package:flutter/foundation.dart';

import '../models/academic_department.dart';
import '../models/organization.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;
  AuthSession? _session;
  bool _isLoading = false;
  bool _isRestoring = false;
  bool _isInitialized = false;
  String? _restoreError;
  Future<AuthSession?>? _restorationFuture;

  AuthSession? get session => _session;
  bool get isLoading => _isLoading;
  bool get isRestoring => _isRestoring;
  bool get isInitialized => _isInitialized;
  String? get restoreError => _restoreError;

  Future<AuthSession?> restoreSession() {
    if (_restorationFuture != null) {
      return _restorationFuture!;
    }
    _restorationFuture = _performRestoreSession();
    return _restorationFuture!;
  }

  Future<AuthSession?> _performRestoreSession() async {
    _isRestoring = true;
    _restoreError = null;
    notifyListeners();

    try {
      final session = await _authService.restoreSession();
      _session = session;
      _isInitialized = true;
      return session;
    } on AuthNetworkException catch (e) {
      _restoreError = e.message;
      _isInitialized = true;
      rethrow;
    } catch (_) {
      _session = null;
      _isInitialized = true;
      return null;
    } finally {
      _isRestoring = false;
      _restorationFuture = null;
      notifyListeners();
    }
  }

  Future<List<Organization>> getPublicOrganizations() =>
      _authService.getPublicOrganizations();

  Future<List<AcademicDepartment>> getAcademicDepartments(int organizationId) =>
      _authService.getAcademicDepartments(organizationId);

  Future<AuthSession> register({
    required String email,
    required String password,
    required String fullName,
    required String identifier,
    required String phone,
    required int organizationId,
    required int academicDepartmentId,
  }) async {
    _isLoading = true;
    _restoreError = null;
    notifyListeners();
    try {
      final session = await _authService.register(
        email: email,
        password: password,
        fullName: fullName,
        identifier: identifier,
        phone: phone,
        organizationId: organizationId,
        academicDepartmentId: academicDepartmentId,
      );
      _session = session;
      _isInitialized = true;
      return session;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AuthSession> login({
    required String email,
    required String password,
    required String identifier,
  }) async {
    _isLoading = true;
    _restoreError = null;
    notifyListeners();
    try {
      final session = await _authService.login(
        email: email,
        password: password,
        identifier: identifier,
      );
      _session = session;
      _isInitialized = true;
      return session;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AuthSession> updateProfile({
    String? fullName,
    String? phone,
    String? profileImage,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final updatedSession = await _authService.updateProfile(
        fullName: fullName,
        phone: phone,
        profileImage: profileImage,
      );
      _session = updatedSession;
      return updatedSession;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AuthSession> uploadProfileImage(String filePath) async {
    _isLoading = true;
    notifyListeners();
    try {
      final updatedSession = await _authService.uploadProfileImage(filePath);
      _session = updatedSession;
      return updatedSession;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _session = null;
    _restoreError = null;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> recordActivity() async {
    if (_session != null) {
      await _authService.recordActivity();
    }
  }
}
