import 'package:go_router/go_router.dart';

import '../features/auth/landing_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/splash_screen.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const landing = '/landing';
  static const login = '/login';
  static const register = '/register';

  static GoRouter router() {
    return GoRouter(
      initialLocation: splash,
      routes: [
        GoRoute(
          path: splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: landing,
          builder: (context, state) => const LandingScreen(),
        ),
        GoRoute(path: login, builder: (context, state) => const LoginScreen()),
        GoRoute(
          path: register,
          builder: (context, state) => const RegisterScreen(),
        ),
      ],
    );
  }
}
