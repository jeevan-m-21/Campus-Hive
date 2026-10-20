import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campushive_app/core/network/api_client.dart';
import 'package:campushive_app/core/network/api_endpoints.dart';
import 'package:campushive_app/core/network/api_exception.dart';
import 'package:campushive_app/core/storage/secure_storage.dart';
import 'package:campushive_app/services/auth_service.dart';
import 'package:campushive_app/services/fcm_service.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient({this.postResponse, this.postException});

  Map<String, dynamic>? postResponse;
  ApiException? postException;
  int postCallCount = 0;
  String? lastPostPath;
  String? lastPostIdToken;
  Map<String, dynamic>? lastPostBody;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    required String idToken,
    required Map<String, dynamic> body,
  }) async {
    postCallCount++;
    lastPostPath = path;
    lastPostIdToken = idToken;
    lastPostBody = body;
    if (postException != null) throw postException!;
    return postResponse ?? {'success': true};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUser implements User {
  FakeUser({this.idToken = 'valid-firebase-id-token'});

  final String idToken;

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => idToken;

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

class FakeAuthService extends AuthService {
  FakeAuthService({this.shouldSucceed = true});

  final bool shouldSucceed;
  int updateFcmTokenCallCount = 0;
  String? lastUpdatedToken;

  @override
  Future<bool> updateFcmToken(String fcmToken) async {
    updateFcmTokenCallCount++;
    lastUpdatedToken = fcmToken;
    return shouldSucceed;
  }
}

class FakeSecureStorage extends SecureStorage {
  FakeSecureStorage({this.storedSession});

  StoredSession? storedSession;

  @override
  Future<StoredSession?> readSession() async => storedSession;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FcmService Token Registration Tests', () {
    test('registerToken sends token via AuthService and updates registeredToken', () async {
      final fakeAuth = FakeAuthService(shouldSucceed: true);
      final fcmService = FcmService(authService: fakeAuth);

      final result = await fcmService.registerToken('device_token_abc_123');

      expect(result, isTrue);
      expect(fakeAuth.updateFcmTokenCallCount, equals(1));
      expect(fakeAuth.lastUpdatedToken, equals('device_token_abc_123'));
      expect(fcmService.registeredToken, equals('device_token_abc_123'));
    });

    test('registerToken deduplicates and skips call when token is already registered', () async {
      final fakeAuth = FakeAuthService(shouldSucceed: true);
      final fcmService = FcmService(authService: fakeAuth);

      await fcmService.registerToken('device_token_abc_123');
      expect(fakeAuth.updateFcmTokenCallCount, equals(1));

      // Second call with same token
      final result2 = await fcmService.registerToken('device_token_abc_123');
      expect(result2, isTrue);
      expect(fakeAuth.updateFcmTokenCallCount, equals(1)); // Skipped second call
    });

    test('registerToken returns false on AuthService failure and preserves null registeredToken', () async {
      final fakeAuth = FakeAuthService(shouldSucceed: false);
      final fcmService = FcmService(authService: fakeAuth);

      final result = await fcmService.registerToken('failed_token');

      expect(result, isFalse);
      expect(fakeAuth.updateFcmTokenCallCount, equals(1));
      expect(fcmService.registeredToken, isNull);
    });

    test('registerToken with null or empty token returns false', () async {
      final fakeAuth = FakeAuthService();
      final fcmService = FcmService(
        authService: fakeAuth,
        tokenGetter: () async => null,
      );

      final result = await fcmService.registerToken(null);
      expect(result, isFalse);
      expect(fakeAuth.updateFcmTokenCallCount, equals(0));

      final resultEmpty = await fcmService.registerToken('');
      expect(resultEmpty, isFalse);
      expect(fakeAuth.updateFcmTokenCallCount, equals(0));
    });

    test('onUserSignedOut clears registeredToken and cancels listener', () async {
      final fakeAuth = FakeAuthService();
      final fcmService = FcmService(authService: fakeAuth);

      await fcmService.registerToken('test_tok');
      expect(fcmService.registeredToken, equals('test_tok'));

      fcmService.onUserSignedOut();
      expect(fcmService.registeredToken, isNull);
    });
  });

  group('FcmService Token Refresh Stream Tests', () {
    test('Token refresh stream automatically re-registers new token', () async {
      final refreshController = StreamController<String>.broadcast();
      final fakeAuth = FakeAuthService();
      final fcmService = FcmService(
        authService: fakeAuth,
        onTokenRefreshStream: refreshController.stream,
        tokenGetter: () async => 'initial_token',
      );

      await fcmService.onUserAuthenticated();
      expect(fakeAuth.updateFcmTokenCallCount, equals(1));
      expect(fakeAuth.lastUpdatedToken, equals('initial_token'));

      // Emit new token on refresh stream
      refreshController.add('rotated_new_token_789');
      await pumpEventQueue();

      expect(fakeAuth.updateFcmTokenCallCount, equals(2));
      expect(fakeAuth.lastUpdatedToken, equals('rotated_new_token_789'));
      expect(fcmService.registeredToken, equals('rotated_new_token_789'));

      await refreshController.close();
      fcmService.dispose();
    });
  });

  group('FcmService Notification Handling & Tap Tests', () {
    test('Foreground message stream invokes onForegroundMessage callback', () async {
      final foregroundController = StreamController<RemoteMessage>.broadcast();
      final fcmService = FcmService(
        onMessageStream: foregroundController.stream,
        registerBackgroundHandler: false,
      );

      RemoteMessage? receivedMessage;
      await fcmService.initialize(
        onForegroundMessage: (msg) {
          receivedMessage = msg;
        },
      );

      final testMessage = const RemoteMessage(
        messageId: 'msg_foreground_1',
        data: {'notification_type': 'COMPLAINT', 'reference_id': '10'},
      );

      foregroundController.add(testMessage);
      await pumpEventQueue();

      expect(receivedMessage, isNotNull);
      expect(receivedMessage!.messageId, equals('msg_foreground_1'));
      expect(receivedMessage!.data['notification_type'], equals('COMPLAINT'));

      await foregroundController.close();
      fcmService.dispose();
    });

    test('Background notification tap stream invokes onNotificationTapped callback', () async {
      final openedController = StreamController<RemoteMessage>.broadcast();
      final fcmService = FcmService(
        onMessageOpenedAppStream: openedController.stream,
        registerBackgroundHandler: false,
      );

      Map<String, dynamic>? tappedData;
      await fcmService.initialize(
        onNotificationTapped: (data) {
          tappedData = data;
        },
      );

      final testMessage = const RemoteMessage(
        messageId: 'msg_opened_2',
        data: {'notification_type': 'ANNOUNCEMENT', 'reference_id': '5'},
      );

      openedController.add(testMessage);
      await pumpEventQueue();

      expect(tappedData, isNotNull);
      expect(tappedData!['notification_type'], equals('ANNOUNCEMENT'));
      expect(tappedData!['reference_id'], equals('5'));

      await openedController.close();
      fcmService.dispose();
    });

    test('Terminated state initial message triggers onNotificationTapped on initialize', () async {
      final fcmService = FcmService(
        initialMessageGetter: () async => const RemoteMessage(
          messageId: 'msg_initial_3',
          data: {'notification_type': 'LOST_FOUND', 'reference_id': '77'},
        ),
        registerBackgroundHandler: false,
      );

      Map<String, dynamic>? tappedData;
      await fcmService.initialize(
        onNotificationTapped: (data) {
          tappedData = data;
        },
      );

      expect(tappedData, isNotNull);
      expect(tappedData!['notification_type'], equals('LOST_FOUND'));
      expect(tappedData!['reference_id'], equals('77'));

      fcmService.dispose();
    });
  });

  group('FcmService Route Resolution Tests', () {
    test('Resolves complaint routes correctly across student, supervisor, and admin roles', () {
      expect(
        FcmService.resolveRouteForNotification(
          {'notification_type': 'COMPLAINT', 'reference_id': '42'},
          role: 'STUDENT',
        ),
        equals('/student/complaints/42'),
      );

      expect(
        FcmService.resolveRouteForNotification(
          {'notification_type': 'COMPLAINT', 'reference_id': '42'},
          role: 'SUPERVISOR',
        ),
        equals('/supervisor/complaints/42'),
      );

      expect(
        FcmService.resolveRouteForNotification(
          {'notification_type': 'COMPLAINT', 'reference_id': '42'},
          role: 'ORG_ADMIN',
        ),
        equals('/admin/complaints/42'),
      );
    });

    test('Resolves announcement routes correctly for student and staff', () {
      expect(
        FcmService.resolveRouteForNotification(
          {'notification_type': 'ANNOUNCEMENT', 'reference_id': '15'},
          role: 'STUDENT',
        ),
        equals('/student/announcements/15'),
      );

      expect(
        FcmService.resolveRouteForNotification(
          {'notification_type': 'ANNOUNCEMENT', 'reference_id': '15'},
          role: 'SUPERVISOR',
        ),
        equals('/supervisor/announcements'),
      );

      expect(
        FcmService.resolveRouteForNotification(
          {'notification_type': 'ANNOUNCEMENT', 'reference_id': '15'},
          role: 'ORG_ADMIN',
        ),
        equals('/admin/announcements'),
      );
    });

    test('Resolves lost & found routes correctly', () {
      expect(
        FcmService.resolveRouteForNotification(
          {'notification_type': 'LOST_FOUND', 'reference_id': '8'},
          role: 'STUDENT',
        ),
        equals('/student/lost-found/8'),
      );
    });

    test('Falls back to notifications screen when reference_id is missing or type is unknown', () {
      expect(
        FcmService.resolveRouteForNotification({}, role: 'STUDENT'),
        equals('/student/notifications'),
      );

      expect(
        FcmService.resolveRouteForNotification({}, role: 'SUPERVISOR'),
        equals('/supervisor/notifications'),
      );

      expect(
        FcmService.resolveRouteForNotification({}, role: 'ORG_ADMIN'),
        equals('/admin/notifications'),
      );
    });

    test('handleNotificationTap calls custom navigate callback with resolved route', () {
      final fcmService = FcmService();
      String? navigatedRoute;

      fcmService.handleNotificationTap(
        {'notification_type': 'COMPLAINT', 'reference_id': '99'},
        role: 'STUDENT',
        navigate: (route) {
          navigatedRoute = route;
        },
      );

      expect(navigatedRoute, equals('/student/complaints/99'));
    });
  });

  group('FcmService Notification Tap & Deep Linking Navigation Tests', () {
    test('handleNotificationTap without explicit role resolves role from SecureStorage', () async {
      final fakeStorage = FakeSecureStorage(
        storedSession: const StoredSession(
          role: 'SUPERVISOR',
          user: {'role': 'SUPERVISOR', 'user_id': 3},
        ),
      );
      final fcmService = FcmService(secureStorage: fakeStorage);
      String? navigatedRoute;

      await fcmService.handleNotificationTap(
        {'notification_type': 'COMPLAINT', 'reference_id': '31'},
        navigate: (route) {
          navigatedRoute = route;
        },
      );

      expect(navigatedRoute, equals('/supervisor/complaints/31'));
    });

    test('re-entrancy guard prevents infinite recursion if onNotificationTapped re-triggers tap', () async {
      late FcmService fcmService;
      int tapCount = 0;
      int navigationCount = 0;
      String? navigatedRoute;

      fcmService = FcmService();
      fcmService.onNotificationTapped = (data) {
        tapCount++;
        // Simulating regression: callback calls handleNotificationTap
        fcmService.handleNotificationTap(
          data,
          role: 'SUPERVISOR',
          navigate: (route) {
            navigationCount++;
            navigatedRoute = route;
          },
        );
      };

      await fcmService.handleNotificationTap(
        {'notification_type': 'COMPLAINT', 'reference_id': '31'},
        role: 'SUPERVISOR',
        navigate: (route) {
          navigationCount++;
          navigatedRoute = route;
        },
      );

      expect(tapCount, equals(1));
      expect(navigationCount, equals(1));
      expect(navigatedRoute, equals('/supervisor/complaints/31'));
    });

    test('initialMessage stages pendingNotificationData and consumePendingNotificationData clears it', () async {
      final fcmService = FcmService(
        initialMessageGetter: () async => const RemoteMessage(
          messageId: 'msg_initial_9',
          data: {'notification_type': 'COMPLAINT', 'reference_id': '45'},
        ),
        registerBackgroundHandler: false,
      );

      await fcmService.initialize();

      expect(fcmService.pendingNotificationData, isNotNull);
      expect(fcmService.pendingNotificationData!['reference_id'], equals('45'));

      final consumed = fcmService.consumePendingNotificationData();
      expect(consumed, isNotNull);
      expect(consumed!['reference_id'], equals('45'));
      expect(fcmService.pendingNotificationData, isNull);
    });

    test('normal launch without initialMessage leaves pendingNotificationData null', () async {
      final fcmService = FcmService(
        initialMessageGetter: () async => null,
        registerBackgroundHandler: false,
      );

      await fcmService.initialize();

      expect(fcmService.pendingNotificationData, isNull);
      expect(fcmService.consumePendingNotificationData(), isNull);
    });

    test('sequential notification taps are processed without blocking future taps', () async {
      final fcmService = FcmService();
      final navigatedRoutes = <String>[];

      await fcmService.handleNotificationTap(
        {'notification_type': 'COMPLAINT', 'reference_id': '101'},
        role: 'SUPERVISOR',
        navigate: (route) => navigatedRoutes.add(route),
      );

      await fcmService.handleNotificationTap(
        {'notification_type': 'ANNOUNCEMENT', 'reference_id': '202'},
        role: 'SUPERVISOR',
        navigate: (route) => navigatedRoutes.add(route),
      );

      expect(navigatedRoutes, equals([
        '/supervisor/complaints/101',
        '/supervisor/announcements',
      ]));
    });
  });

  group('AuthService updateFcmToken Integration Tests', () {
    test('AuthService.updateFcmToken calls POST /auth/update-fcm-token with idToken in header', () async {
      final fakeApi = FakeApiClient(postResponse: {'success': true});
      final fakeUser = FakeUser(idToken: 'auth_jwt_token_123');
      final fakeAuth = FakeFirebaseAuth(currentUser: fakeUser);
      final authService = AuthService(
        apiClient: fakeApi,
        firebaseAuth: fakeAuth,
      );

      final success = await authService.updateFcmToken('device_fcm_token_xyz');

      expect(success, isTrue);
      expect(fakeApi.postCallCount, equals(1));
      expect(fakeApi.lastPostPath, equals(ApiEndpoints.updateFcmToken));
      expect(fakeApi.lastPostIdToken, equals('auth_jwt_token_123'));
      expect(fakeApi.lastPostBody, equals({'fcm_token': 'device_fcm_token_xyz'}));
    });

    test('AuthService.updateFcmToken fails gracefully when no Firebase user is logged in', () async {
      final fakeApi = FakeApiClient();
      final fakeAuth = FakeFirebaseAuth(currentUser: null);
      final authService = AuthService(
        apiClient: fakeApi,
        firebaseAuth: fakeAuth,
      );

      final success = await authService.updateFcmToken('some_token');

      expect(success, isFalse);
      expect(fakeApi.postCallCount, equals(0));
    });
  });
}
