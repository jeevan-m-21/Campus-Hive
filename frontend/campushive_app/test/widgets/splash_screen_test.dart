import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:campushive_app/app/routes.dart';
import 'package:campushive_app/features/auth/splash_screen.dart';
import 'package:campushive_app/providers/auth_provider.dart';
import 'package:campushive_app/services/auth_service.dart';
import 'package:campushive_app/services/fcm_service.dart';

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  MockAuthProvider({this.sessionToReturn, this.errorToThrow});

  AuthSession? sessionToReturn;
  Exception? errorToThrow;
  int restoreCallCount = 0;

  @override
  AuthSession? get session => sessionToReturn;

  @override
  bool get isLoading => false;

  @override
  bool get isRestoring => false;

  @override
  bool get isInitialized => true;

  @override
  String? get restoreError => null;

  @override
  Future<AuthSession?> restoreSession() async {
    restoreCallCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return sessionToReturn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SplashScreen Persistent Login Navigation Tests', () {
    Widget buildTestApp({
      required MockAuthProvider authProvider,
      required void Function(String route) onNavigated,
    }) {
      final router = GoRouter(
        initialLocation: AppRoutes.splash,
        routes: [
          GoRoute(
            path: AppRoutes.splash,
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(
            path: AppRoutes.studentDashboard,
            builder: (_, state) {
              onNavigated(state.uri.toString());
              return const Scaffold(body: Text('Student Dashboard Screen'));
            },
          ),
          GoRoute(
            path: AppRoutes.supervisorDashboard,
            builder: (_, state) {
              onNavigated(state.uri.toString());
              return const Scaffold(body: Text('Supervisor Dashboard Screen'));
            },
          ),
          GoRoute(
            path: AppRoutes.adminDashboard,
            builder: (_, state) {
              onNavigated(state.uri.toString());
              return const Scaffold(body: Text('Admin Dashboard Screen'));
            },
          ),
          GoRoute(
            path: AppRoutes.landing,
            builder: (_, state) {
              onNavigated(state.uri.toString());
              return const Scaffold(body: Text('Landing Screen'));
            },
          ),
        ],
      );

      return ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('routes to studentDashboard when restored user is STUDENT', (
      tester,
    ) async {
      String? routedTo;
      final mockAuth = MockAuthProvider(
        sessionToReturn: const AuthSession(
          user: {'role': 'STUDENT'},
          role: 'STUDENT',
        ),
      );

      await tester.pumpWidget(
        buildTestApp(authProvider: mockAuth, onNavigated: (r) => routedTo = r),
      );
      await tester.pumpAndSettle();

      expect(mockAuth.restoreCallCount, 1);
      expect(routedTo, AppRoutes.studentDashboard);
      expect(find.text('Student Dashboard Screen'), findsOneWidget);
    });

    testWidgets(
      'routes to supervisorDashboard when restored user is SUPERVISOR',
      (tester) async {
        String? routedTo;
        final mockAuth = MockAuthProvider(
          sessionToReturn: const AuthSession(
            user: {'role': 'SUPERVISOR'},
            role: 'SUPERVISOR',
          ),
        );

        await tester.pumpWidget(
          buildTestApp(
            authProvider: mockAuth,
            onNavigated: (r) => routedTo = r,
          ),
        );
        await tester.pumpAndSettle();

        expect(mockAuth.restoreCallCount, 1);
        expect(routedTo, AppRoutes.supervisorDashboard);
        expect(find.text('Supervisor Dashboard Screen'), findsOneWidget);
      },
    );

    testWidgets('routes to adminDashboard when restored user is ORG_ADMIN', (
      tester,
    ) async {
      String? routedTo;
      final mockAuth = MockAuthProvider(
        sessionToReturn: const AuthSession(
          user: {'role': 'ORG_ADMIN'},
          role: 'ORG_ADMIN',
        ),
      );

      await tester.pumpWidget(
        buildTestApp(authProvider: mockAuth, onNavigated: (r) => routedTo = r),
      );
      await tester.pumpAndSettle();

      expect(mockAuth.restoreCallCount, 1);
      expect(routedTo, AppRoutes.adminDashboard);
      expect(find.text('Admin Dashboard Screen'), findsOneWidget);
    });

    testWidgets('routes to adminDashboard when restored user is SUPER_ADMIN', (
      tester,
    ) async {
      String? routedTo;
      final mockAuth = MockAuthProvider(
        sessionToReturn: const AuthSession(
          user: {'role': 'SUPER_ADMIN'},
          role: 'SUPER_ADMIN',
        ),
      );

      await tester.pumpWidget(
        buildTestApp(authProvider: mockAuth, onNavigated: (r) => routedTo = r),
      );
      await tester.pumpAndSettle();

      expect(mockAuth.restoreCallCount, 1);
      expect(routedTo, AppRoutes.adminDashboard);
      expect(find.text('Admin Dashboard Screen'), findsOneWidget);
    });

    testWidgets('routes to landing when no active session exists', (
      tester,
    ) async {
      String? routedTo;
      final mockAuth = MockAuthProvider(sessionToReturn: null);

      await tester.pumpWidget(
        buildTestApp(authProvider: mockAuth, onNavigated: (r) => routedTo = r),
      );
      await tester.pumpAndSettle();

      expect(mockAuth.restoreCallCount, 1);
      expect(routedTo, AppRoutes.landing);
      expect(find.text('Landing Screen'), findsOneWidget);
    });

    testWidgets(
      'displays network error with retry button on AuthNetworkException',
      (tester) async {
        final mockAuth = MockAuthProvider(
          errorToThrow: const AuthNetworkException('Server unreachable'),
        );

        await tester.pumpWidget(
          buildTestApp(authProvider: mockAuth, onNavigated: (_) {}),
        );
        await tester.pumpAndSettle();

        expect(find.text('Connection Issue'), findsOneWidget);
        expect(find.text('Server unreachable'), findsOneWidget);
        expect(find.text('Retry Connection'), findsOneWidget);
        expect(find.text('Continue to Sign In'), findsOneWidget);

        // Now clear the error and simulate successful retry
        mockAuth.errorToThrow = null;
        mockAuth.sessionToReturn = const AuthSession(
          user: {'role': 'STUDENT'},
          role: 'STUDENT',
        );

        await tester.tap(find.text('Retry Connection'));
        await tester.pumpAndSettle();

        expect(mockAuth.restoreCallCount, 2);
        expect(find.text('Student Dashboard Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'consumes pending notification and navigates to complaint detail on cold start',
      (tester) async {
        final mockAuth = MockAuthProvider(
          sessionToReturn: const AuthSession(
            user: {'role': 'SUPERVISOR'},
            role: 'SUPERVISOR',
          ),
        );

        FcmService.instance.setPendingNotificationData({
          'notification_type': 'COMPLAINT',
          'reference_id': '31',
        });

        final router = GoRouter(
          initialLocation: AppRoutes.splash,
          routes: [
            GoRoute(
              path: AppRoutes.splash,
              builder: (context, state) => const SplashScreen(),
            ),
            GoRoute(
              path: AppRoutes.supervisorDashboard,
              builder: (_, state) {
                return const Scaffold(body: Text('Supervisor Dashboard Screen'));
              },
            ),
            GoRoute(
              path: '/supervisor/complaints/:complaintId',
              builder: (_, state) {
                return Scaffold(
                  body: Text(
                    'Complaint Detail ${state.pathParameters['complaintId']}',
                  ),
                );
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuth,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(FcmService.instance.pendingNotificationData, isNull);
        expect(find.text('Complaint Detail 31'), findsOneWidget);
      },
    );
  });
}
