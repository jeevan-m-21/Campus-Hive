import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:campushive_app/app/routes.dart';
import 'package:campushive_app/core/theme/app_colors.dart';
import 'package:campushive_app/core/widgets/app_button.dart';
import 'package:campushive_app/core/widgets/logout_confirmation_dialog.dart';
import 'package:campushive_app/features/org_admin/widgets/admin_app_bar.dart';
import 'package:campushive_app/features/student/profile/student_profile_screen.dart';
import 'package:campushive_app/features/supervisor/widgets/supervisor_app_bar.dart';
import 'package:campushive_app/providers/auth_provider.dart';
import 'package:campushive_app/providers/notification_provider.dart';
import 'package:campushive_app/services/auth_service.dart';

class MockAuthProviderForLogout extends ChangeNotifier implements AuthProvider {
  MockAuthProviderForLogout({
    AuthSession? initialSession,
    this.shouldThrow = false,
  }) : _session = initialSession ??
            const AuthSession(
              user: {'full_name': 'Test User', 'role': 'STUDENT'},
              role: 'STUDENT',
            );

  AuthSession? _session;
  int signOutCallCount = 0;
  bool shouldThrow;

  @override
  AuthSession? get session => _session;

  @override
  bool get isLoading => false;

  @override
  bool get isRestoring => false;

  @override
  bool get isInitialized => true;

  @override
  String? get restoreError => null;

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    if (shouldThrow) {
      throw const AuthException('Network error during logout');
    }
    _session = null;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockNotificationProvider extends ChangeNotifier
    implements NotificationProvider {
  @override
  int get unreadCount => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    LogoutConfirmationDialog.resetDialogStateForTesting();
  });

  Widget buildTestApp({
    required MockAuthProviderForLogout authProvider,
    required Widget child,
    void Function(String route)? onNavigated,
  }) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => child,
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) {
            onNavigated?.call(state.uri.toString());
            return const Scaffold(body: Text('Login Screen'));
          },
        ),
      ],
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => MockNotificationProvider(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  group('LogoutConfirmationDialog UI & Styling Tests', () {
    testWidgets('renders title, message, and distinct green and red buttons', (
      tester,
    ) async {
      final mockAuth = MockAuthProviderForLogout();

      await tester.pumpWidget(
        buildTestApp(
          authProvider: mockAuth,
          child: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => LogoutConfirmationDialog.show(ctx),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify Dialog Content
      expect(find.text('Log out?'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to log out of your CampusHive account?',
        ),
        findsOneWidget,
      );

      // Verify Stay Button (Green)
      final stayBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('logout_stay_button')),
      );
      expect(
        stayBtn.style?.backgroundColor?.resolve({}),
        equals(AppColors.success),
      );
      expect(find.text('Stay'), findsOneWidget);

      // Verify Log Out Button (Red)
      final logOutBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('logout_confirm_button')),
      );
      expect(
        logOutBtn.style?.backgroundColor?.resolve({}),
        equals(AppColors.error),
      );
      expect(find.text('Log Out'), findsOneWidget);
    });
  });

  group('LogoutConfirmationDialog Interaction & Dismissal Tests', () {
    testWidgets('tapping Stay closes the dialog without logging out', (
      tester,
    ) async {
      final mockAuth = MockAuthProviderForLogout();

      await tester.pumpWidget(
        buildTestApp(
          authProvider: mockAuth,
          child: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => LogoutConfirmationDialog.show(ctx),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);

      // Tap Stay
      await tester.tap(find.byKey(const Key('logout_stay_button')));
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.text('Log out?'), findsNothing);
      // No logout was performed
      expect(mockAuth.signOutCallCount, equals(0));
      expect(find.text('Login Screen'), findsNothing);
    });

    testWidgets('tapping barrier outside dialog dismisses without logging out', (
      tester,
    ) async {
      final mockAuth = MockAuthProviderForLogout();

      await tester.pumpWidget(
        buildTestApp(
          authProvider: mockAuth,
          child: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => LogoutConfirmationDialog.show(ctx),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);

      // Tap outside dialog at top-left corner
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsNothing);
      expect(mockAuth.signOutCallCount, equals(0));
      expect(find.text('Login Screen'), findsNothing);
    });

    testWidgets(
      'tapping Log Out invokes signOut and navigates to login screen',
      (tester) async {
        final mockAuth = MockAuthProviderForLogout();
        String? navigatedRoute;

        await tester.pumpWidget(
          buildTestApp(
            authProvider: mockAuth,
            onNavigated: (r) => navigatedRoute = r,
            child: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => LogoutConfirmationDialog.show(ctx),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Log out?'), findsOneWidget);

        // Tap Log Out
        await tester.tap(find.byKey(const Key('logout_confirm_button')));
        await tester.pumpAndSettle();

        expect(mockAuth.signOutCallCount, equals(1));
        expect(navigatedRoute, equals(AppRoutes.login));
        expect(find.text('Login Screen'), findsOneWidget);
      },
    );

    testWidgets('prevents multiple logout dialogs from opening simultaneously', (
      tester,
    ) async {
      final mockAuth = MockAuthProviderForLogout();

      await tester.pumpWidget(
        buildTestApp(
          authProvider: mockAuth,
          child: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  // Trigger twice concurrently
                  LogoutConfirmationDialog.show(ctx);
                  LogoutConfirmationDialog.show(ctx);
                },
                child: const Text('Open Dialogs'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialogs'));
      await tester.pumpAndSettle();

      // Only ONE dialog instance exists
      expect(find.text('Log out?'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.byKey(const Key('logout_stay_button')));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsNothing);
      expect(LogoutConfirmationDialog.isDialogShowing, isFalse);

      // A subsequent tap can cleanly open the dialog again
      await tester.tap(find.text('Open Dialogs'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);
    });

    testWidgets('shows SnackBar when signOut throws an asynchronous error', (
      tester,
    ) async {
      final mockAuth = MockAuthProviderForLogout(shouldThrow: true);

      await tester.pumpWidget(
        buildTestApp(
          authProvider: mockAuth,
          child: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => LogoutConfirmationDialog.show(ctx),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('logout_confirm_button')));
      await tester.pumpAndSettle();

      // Error was handled safely without uncaught exception
      expect(mockAuth.signOutCallCount, equals(1));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('Failed to log out: Network error during logout'),
        findsOneWidget,
      );
      expect(find.text('Login Screen'), findsNothing);
      expect(LogoutConfirmationDialog.isDialogShowing, isFalse);
    });
  });

  group('Entry Point Confirmation Dialog Integration Tests', () {
    testWidgets('SupervisorAppBar logout icon triggers confirmation dialog', (
      tester,
    ) async {
      final mockAuth = MockAuthProviderForLogout();

      await tester.pumpWidget(
        buildTestApp(
          authProvider: mockAuth,
          child: const Scaffold(
            appBar: SupervisorAppBar(title: 'Supervisor Home'),
            body: Center(child: Text('Supervisor Screen')),
          ),
        ),
      );

      expect(find.byTooltip('Sign out'), findsOneWidget);

      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to log out of your CampusHive account?',
        ),
        findsOneWidget,
      );

      // Tap Stay
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsNothing);
      expect(mockAuth.signOutCallCount, equals(0));
    });

    testWidgets('AdminAppBar logout icon triggers confirmation dialog', (
      tester,
    ) async {
      final mockAuth = MockAuthProviderForLogout();

      await tester.pumpWidget(
        buildTestApp(
          authProvider: mockAuth,
          child: const Scaffold(
            appBar: AdminAppBar(title: 'Admin Home'),
            body: Center(child: Text('Admin Screen')),
          ),
        ),
      );

      expect(find.byTooltip('Sign out'), findsOneWidget);

      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to log out of your CampusHive account?',
        ),
        findsOneWidget,
      );

      // Tap Stay
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsNothing);
      expect(mockAuth.signOutCallCount, equals(0));
    });

    testWidgets(
      'StudentProfileScreen logout button triggers confirmation dialog',
      (tester) async {
        final mockAuth = MockAuthProviderForLogout();

        await tester.pumpWidget(
          buildTestApp(
            authProvider: mockAuth,
            child: const Scaffold(
              body: StudentProfileScreen(),
            ),
          ),
        );

        expect(find.widgetWithText(AppButton, 'Log out'), findsOneWidget);
        await tester.ensureVisible(find.widgetWithText(AppButton, 'Log out'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(AppButton, 'Log out'));
        await tester.pumpAndSettle();

        expect(find.text('Log out?'), findsOneWidget);
        expect(
          find.text(
            'Are you sure you want to log out of your CampusHive account?',
          ),
          findsOneWidget,
        );

        // Tap Stay
        await tester.tap(find.text('Stay'));
        await tester.pumpAndSettle();

        expect(find.text('Log out?'), findsNothing);
        expect(mockAuth.signOutCallCount, equals(0));
      },
    );
  });
}
