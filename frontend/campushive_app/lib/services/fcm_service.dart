import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';
import '../providers/auth_provider.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Top-level background message handler.
  // The system notification is automatically displayed by Android if notification payload exists.
}

class FcmService {
  FcmService({
    FirebaseMessaging? messaging,
    AuthService? authService,
    ApiClient? apiClient,
    SecureStorage? secureStorage,
    Stream<RemoteMessage>? onMessageStream,
    Stream<RemoteMessage>? onMessageOpenedAppStream,
    Stream<String>? onTokenRefreshStream,
    Future<RemoteMessage?> Function()? initialMessageGetter,
    Future<String?> Function()? tokenGetter,
    Future<NotificationSettings> Function()? permissionRequester,
    bool registerBackgroundHandler = true,
  })  : _messaging = messaging,
        _authService = authService,
        _apiClient = apiClient ?? ApiClient(),
        _secureStorage = secureStorage ?? SecureStorage(),
        _onMessageStream = onMessageStream,
        _onMessageOpenedAppStream = onMessageOpenedAppStream,
        _onTokenRefreshStream = onTokenRefreshStream,
        _initialMessageGetter = initialMessageGetter,
        _tokenGetter = tokenGetter,
        _permissionRequester = permissionRequester,
        _registerBackgroundHandler = registerBackgroundHandler;

  static FcmService? _instance;
  static FcmService get instance => _instance ??= FcmService();
  static set instance(FcmService service) => _instance = service;

  final FirebaseMessaging? _messaging;
  final AuthService? _authService;
  final ApiClient _apiClient;
  final SecureStorage _secureStorage;
  final Stream<RemoteMessage>? _onMessageStream;
  final Stream<RemoteMessage>? _onMessageOpenedAppStream;
  final Stream<String>? _onTokenRefreshStream;
  final Future<RemoteMessage?> Function()? _initialMessageGetter;
  final Future<String?> Function()? _tokenGetter;
  final Future<NotificationSettings> Function()? _permissionRequester;
  final bool _registerBackgroundHandler;

  FirebaseMessaging get _fcm => _messaging ?? FirebaseMessaging.instance;

  Stream<RemoteMessage> get _foregroundStream =>
      _onMessageStream ?? FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get _messageOpenedStream =>
      _onMessageOpenedAppStream ?? FirebaseMessaging.onMessageOpenedApp;

  Stream<String> get _tokenRefreshStream =>
      _onTokenRefreshStream ?? _fcm.onTokenRefresh;

  bool _isInitialized = false;
  String? _registeredToken;
  Map<String, dynamic>? _pendingNotificationData;
  bool _isHandlingTap = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;

  void Function(RemoteMessage message)? onForegroundMessage;
  void Function(Map<String, dynamic> data)? onNotificationTapped;

  String? get registeredToken => _registeredToken;
  bool get isInitialized => _isInitialized;
  Map<String, dynamic>? get pendingNotificationData => _pendingNotificationData;

  void setPendingNotificationData(Map<String, dynamic>? data) {
    _pendingNotificationData = data;
  }

  Map<String, dynamic>? consumePendingNotificationData() {
    final data = _pendingNotificationData;
    _pendingNotificationData = null;
    return data;
  }

  Future<void> initialize({
    void Function(RemoteMessage message)? onForegroundMessage,
    void Function(Map<String, dynamic> data)? onNotificationTapped,
  }) async {
    if (onForegroundMessage != null) {
      this.onForegroundMessage = onForegroundMessage;
    }
    if (onNotificationTapped != null) {
      this.onNotificationTapped = onNotificationTapped;
    }

    if (_isInitialized) return;

    if (_registerBackgroundHandler) {
      try {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      } catch (_) {}
    }

    try {
      _foregroundSub?.cancel();
      _foregroundSub = _foregroundStream.listen((message) {
        handleForegroundMessage(message);
      });
    } catch (_) {}

    try {
      _messageOpenedSub?.cancel();
      _messageOpenedSub = _messageOpenedStream.listen((message) {
        handleNotificationTap(message.data);
      });
    } catch (_) {}

    try {
      final initialMessage = _initialMessageGetter != null
          ? await _initialMessageGetter()
          : await _fcm.getInitialMessage();
      if (initialMessage != null && initialMessage.data.isNotEmpty) {
        _pendingNotificationData = initialMessage.data;
        onNotificationTapped?.call(initialMessage.data);
      }
    } catch (_) {}

    _isInitialized = true;
  }

  Future<String?> requestPermissionAndGetToken() async {
    try {
      if (_tokenGetter != null) {
        return await _tokenGetter();
      }

      final settings = _permissionRequester != null
          ? await _permissionRequester()
          : await _fcm.requestPermission(
              alert: true,
              badge: true,
              sound: true,
              provisional: false,
            );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        return await _fcm.getToken();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> registerToken([String? token]) async {
    final fcmToken = token ?? await requestPermissionAndGetToken();
    if (fcmToken == null || fcmToken.isEmpty) return false;
    if (fcmToken == _registeredToken) return true;

    try {
      final auth = _authService ?? AuthService(apiClient: _apiClient);
      final success = await auth.updateFcmToken(fcmToken);
      if (success) {
        _registeredToken = fcmToken;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> onUserAuthenticated() async {
    try {
      final token = await requestPermissionAndGetToken();
      if (token != null && token.isNotEmpty) {
        await registerToken(token);
      }
      _listenToTokenRefresh();
    } catch (_) {
      // Non-fatal: registration failure must never block login
    }
  }

  void onUserSignedOut() {
    _registeredToken = null;
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  void _listenToTokenRefresh() {
    _tokenRefreshSub?.cancel();
    try {
      _tokenRefreshSub = _tokenRefreshStream.listen((newToken) {
        registerToken(newToken);
      });
    } catch (_) {}
  }

  void handleForegroundMessage(RemoteMessage message) {
    onForegroundMessage?.call(message);
  }

  String? resolveUserRoleSync([String? explicitRole]) {
    if (explicitRole != null && explicitRole.isNotEmpty) {
      return explicitRole;
    }

    final ctx = AppRoutes.rootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        final session = Provider.of<AuthProvider>(ctx, listen: false).session;
        if (session != null && session.role.isNotEmpty) {
          return session.role;
        }
      } catch (_) {}
    }

    return null;
  }

  Future<String?> resolveUserRole([String? explicitRole]) async {
    final syncRole = resolveUserRoleSync(explicitRole);
    if (syncRole != null) return syncRole;

    try {
      final stored = await _secureStorage.readSession();
      if (stored?.role != null && stored!.role!.isNotEmpty) {
        return stored.role;
      }
    } catch (_) {}

    return null;
  }

  bool isSessionRestoring() {
    final ctx = AppRoutes.rootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        final auth = Provider.of<AuthProvider>(ctx, listen: false);
        if (auth.isRestoring || !auth.isInitialized) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<void> handleNotificationTap(
    Map<String, dynamic> data, {
    String? role,
    void Function(String route)? navigate,
  }) async {
    if (_isHandlingTap) return;
    _isHandlingTap = true;

    try {
      onNotificationTapped?.call(data);

      var effectiveRole = resolveUserRoleSync(role);
      effectiveRole ??= await resolveUserRole(role);

      final targetRoute =
          resolveRouteForNotification(data, role: effectiveRole);

      if (navigate != null) {
        navigate(targetRoute);
        return;
      }

      if (isSessionRestoring()) {
        _pendingNotificationData = data;
        return;
      }

      try {
        AppRoutes.routerInstance.push(targetRoute);
      } catch (_) {
        // Graceful fallback: stage pending notification if router cannot navigate yet
        _pendingNotificationData = data;
      }
    } finally {
      _isHandlingTap = false;
    }
  }

  static String resolveRouteForNotification(
    Map<String, dynamic> data, {
    String? role,
  }) {
    final rawType = data['notification_type']?.toString().toUpperCase();
    final rawRefId = data['reference_id']?.toString();
    final refId = rawRefId != null ? int.tryParse(rawRefId) : null;
    final normalizedRole = role?.toUpperCase();

    if (rawType == 'COMPLAINT') {
      if (refId != null && refId > 0) {
        if (normalizedRole == 'SUPERVISOR') {
          return AppRoutes.supervisorComplaintDetail(refId);
        } else if (normalizedRole == 'ORG_ADMIN' ||
            normalizedRole == 'SUPER_ADMIN') {
          return AppRoutes.adminComplaintDetail(refId);
        }
        return AppRoutes.studentComplaintDetail(refId);
      }
      if (normalizedRole == 'SUPERVISOR') return AppRoutes.supervisorQueue;
      if (normalizedRole == 'ORG_ADMIN') return AppRoutes.adminComplaints;
      return AppRoutes.studentComplaints;
    }

    if (rawType == 'ANNOUNCEMENT') {
      if (refId != null &&
          refId > 0 &&
          (normalizedRole == 'STUDENT' || normalizedRole == null)) {
        return AppRoutes.studentAnnouncementDetail(refId);
      }
      if (normalizedRole == 'SUPERVISOR') {
        return AppRoutes.supervisorAnnouncements;
      }
      if (normalizedRole == 'ORG_ADMIN') return AppRoutes.adminAnnouncements;
      return AppRoutes.studentAnnouncements;
    }

    if (rawType == 'LOST_FOUND') {
      if (refId != null && refId > 0) {
        return AppRoutes.studentLostFoundDetail(refId);
      }
      return AppRoutes.studentLostFound;
    }

    // Role-based notification screen fallbacks
    if (normalizedRole == 'SUPERVISOR') return AppRoutes.supervisorNotifications;
    if (normalizedRole == 'ORG_ADMIN') return AppRoutes.adminNotifications;
    return AppRoutes.studentNotifications;
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub?.cancel();
    _foregroundSub = null;
    _messageOpenedSub?.cancel();
    _messageOpenedSub = null;
  }
}
