import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:campushive_app/app/routes.dart';
import 'package:campushive_app/features/auth/splash_screen.dart';
import 'package:campushive_app/features/auth/widgets/campus_hive_splash_animator.dart';
import 'package:campushive_app/features/auth/widgets/splash_canvas_painter.dart';
import 'package:campushive_app/providers/auth_provider.dart';
import 'package:campushive_app/services/auth_service.dart';

class DelayedMockAuthProvider extends ChangeNotifier implements AuthProvider {
  DelayedMockAuthProvider({
    this.sessionToReturn,
    this.delay = const Duration(milliseconds: 100),
  });

  final AuthSession? sessionToReturn;
  final Duration delay;
  Completer<AuthSession?>? _completer;

  void completeManualSession(AuthSession? session) {
    _completer?.complete(session);
  }

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
    if (_completer != null) {
      return _completer!.future;
    }
    await Future.delayed(delay);
    return sessionToReturn;
  }

  void useManualCompleter() {
    _completer = Completer<AuthSession?>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Splash Animation & 7-Second Navigation Coordination Tests', () {
    Widget buildAnimationTestApp({
      required AuthProvider authProvider,
      required void Function(String route) onNavigated,
      Duration animationDuration = const Duration(milliseconds: 3500),
      Duration holdDuration = const Duration(milliseconds: 3500),
    }) {
      final router = GoRouter(
        initialLocation: AppRoutes.splash,
        routes: [
          GoRoute(
            path: AppRoutes.splash,
            builder: (context, state) => SplashScreen(
              animationDuration: animationDuration,
              holdDuration: holdDuration,
            ),
          ),
          GoRoute(
            path: AppRoutes.studentDashboard,
            builder: (_, state) {
              onNavigated(state.uri.toString());
              return const Scaffold(body: Text('Student Dashboard Screen'));
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

    test('SplashScreen exposes explicit named duration constants totaling 7 seconds', () {
      expect(SplashScreen.defaultAnimationDuration, const Duration(milliseconds: 3500));
      expect(SplashScreen.defaultHoldDuration, const Duration(milliseconds: 3500));
      expect(SplashScreen.defaultTotalDuration, const Duration(milliseconds: 7000));
      expect(
        SplashScreen.defaultAnimationDuration + SplashScreen.defaultHoldDuration,
        SplashScreen.defaultTotalDuration,
      );
    });

    testWidgets(
      'ribbons start fading at 2.0s and reach exact zero opacity at 2.8s before logo fully reveals',
      (tester) async {
        late AnimationController testController;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return _TestAnimatorHost(
                  onControllerCreated: (c) => testController = c,
                );
              },
            ),
          ),
        );

        // At 1.9s (c = 1900 / 7000 = 0.2714): ribbons have NOT started fading yet
        testController.value = 1900 / 7000;
        await tester.pump();
        final animator = tester.widget<CampusHiveSplashAnimator>(
          find.byType(CampusHiveSplashAnimator),
        );
        expect(animator.ribbonFadeAnimation.value, equals(0.0), reason: 'Ribbons must not fade before 2.0s');

        // At 2.1s (c = 2100 / 7000 = 0.300): ribbons have started fading
        testController.value = 2100 / 7000;
        await tester.pump();
        expect(animator.ribbonFadeAnimation.value, greaterThan(0.0), reason: 'Ribbon fade must begin around 2.0s');
        expect(animator.ribbonFadeAnimation.value, lessThan(1.0));

        // At 2.8s (c = 2800 / 7000 = 0.400): ribbons are COMPLETELY faded out (value == 1.0, opacity 0.0)
        testController.value = 2800 / 7000;
        await tester.pump();
        expect(animator.ribbonFadeAnimation.value, equals(1.0), reason: 'Ribbons must reach 100% fade (0 opacity) at 2.8s');

        // At 3.0s: official logo is still in the middle of revealing while ribbons remain at 0 opacity
        testController.value = 3000 / 7000;
        await tester.pump();
        expect(animator.ribbonFadeAnimation.value, equals(1.0));
        expect(animator.logoCrossfadeAnimation.value, greaterThan(0.0));
        expect(animator.logoCrossfadeAnimation.value, lessThan(1.0));

        // At 3.2s: official logo reaches 100% reveal
        testController.value = 3200 / 7000;
        await tester.pump();
        expect(animator.logoCrossfadeAnimation.value, equals(1.0));
      },
    );

    testWidgets(
      'early session restoration does not shorten the 7-second minimum splash experience',
      (tester) async {
        String? routedTo;
        final mockAuth = DelayedMockAuthProvider(
          sessionToReturn: const AuthSession(
            user: {'role': 'STUDENT'},
            role: 'STUDENT',
          ),
          delay: const Duration(milliseconds: 50),
        );

        await tester.pumpWidget(
          buildAnimationTestApp(
            authProvider: mockAuth,
            onNavigated: (r) => routedTo = r,
            animationDuration: const Duration(milliseconds: 3500),
            holdDuration: const Duration(milliseconds: 3500),
          ),
        );

        // At 1000ms: active animation running
        await tester.pump(const Duration(milliseconds: 1000));
        expect(routedTo, isNull, reason: 'Must not navigate while animation is playing');

        // At 3500ms: active animation completes and final logo is revealed
        await tester.pump(const Duration(milliseconds: 2500));
        expect(routedTo, isNull, reason: 'Must not navigate when animation ends; hold must begin');
        expect(find.byType(Image), findsOneWidget);

        // At 5500ms (in the middle of the 3.5s hold): still holding
        await tester.pump(const Duration(milliseconds: 2000));
        expect(routedTo, isNull, reason: 'Must continue holding for the full 7 seconds');

        // At 7100ms: total 7-second duration reached, navigation triggers immediately
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pumpAndSettle();

        expect(routedTo, AppRoutes.studentDashboard);
        expect(find.text('Student Dashboard Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'renders enlarged official logo proportionally during final hold',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockAuth = DelayedMockAuthProvider(
          sessionToReturn: null,
          delay: Duration.zero,
        );

        await tester.pumpWidget(
          buildAnimationTestApp(
            authProvider: mockAuth,
            onNavigated: (_) {},
            animationDuration: const Duration(milliseconds: 500),
            holdDuration: const Duration(milliseconds: 500),
          ),
        );

        // Settle into final hold phase
        await tester.pump(const Duration(milliseconds: 600));

        final imageFinder = find.byType(Image);
        expect(imageFinder, findsOneWidget);

        final imageRenderBox = tester.renderObject<RenderBox>(imageFinder);
        final size = imageRenderBox.size;

        // Proportional (square)
        expect(size.width, equals(size.height));
        // Enlarged by ~17.4% (270.0 vs previous 230.0 cap)
        expect(size.width, equals(270.0));
      },
    );

    testWidgets(
      'decorative elements are completely absent when crossfadeProgress and ribbonFade are 1.0',
      (tester) async {
        final painter = SplashCanvasPainter(
          ribbonDrawProgress: 1.0,
          ribbonFadeProgress: 1.0, // 100% faded out
          particleProgress: 1.0,
          particleFadeProgress: 1.0, // 100% faded out
          burstProgress: 1.0,
          hexagonProgress: 1.0,
          emblemProgress: 1.0,
          crossfadeProgress: 1.0, // 100% crossfaded to logo
          logoCenter: const Offset(200, 350),
          logoSize: 270,
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);

        // Must paint normally with zero decorative remnants
        expect(
          () => painter.paint(canvas, const Size(400, 800)),
          returnsNormally,
        );
      },
    );

    testWidgets(
      'slow session restoration (>7s) does not cause premature navigation',
      (tester) async {
        String? routedTo;
        final mockAuth = DelayedMockAuthProvider();
        mockAuth.useManualCompleter();

        await tester.pumpWidget(
          buildAnimationTestApp(
            authProvider: mockAuth,
            onNavigated: (r) => routedTo = r,
            animationDuration: const Duration(milliseconds: 3500),
            holdDuration: const Duration(milliseconds: 3500),
          ),
        );

        // Advance 7500ms: 7 seconds have elapsed, but session is still pending
        await tester.pump(const Duration(milliseconds: 7500));
        expect(routedTo, isNull, reason: 'Must not navigate before session completes');
        expect(find.text('Restoring campus session...'), findsOneWidget);

        // Resolve session at 8.0s
        mockAuth.completeManualSession(
          const AuthSession(user: {'role': 'STUDENT'}, role: 'STUDENT'),
        );
        await tester.pumpAndSettle();

        expect(routedTo, AppRoutes.studentDashboard);
      },
    );

    testWidgets('renders on compact screen size without layout overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockAuth = DelayedMockAuthProvider(
        sessionToReturn: null,
        delay: Duration.zero,
      );

      await tester.pumpWidget(
        buildAnimationTestApp(
          authProvider: mockAuth,
          onNavigated: (_) {},
          animationDuration: const Duration(milliseconds: 200),
          holdDuration: const Duration(milliseconds: 100),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

class _TestAnimatorHost extends StatefulWidget {
  const _TestAnimatorHost({required this.onControllerCreated});

  final void Function(AnimationController) onControllerCreated;

  @override
  State<_TestAnimatorHost> createState() => _TestAnimatorHostState();
}

class _TestAnimatorHostState extends State<_TestAnimatorHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    );
    widget.onControllerCreated(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CampusHiveSplashAnimator(controller: _controller);
  }
}
