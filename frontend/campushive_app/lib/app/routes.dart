import 'package:go_router/go_router.dart';

import '../features/auth/landing_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/student/student_shell.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const landing = '/landing';
  static const login = '/login';
  static const register = '/register';
  static const studentDashboard = '/student/dashboard';
  static const studentComplaints = '/student/complaints';
  static const studentLostFound = '/student/lost-found';
  static const studentAnnouncements = '/student/announcements';
  static const studentProfile = '/student/profile';

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
        GoRoute(
          path: studentDashboard,
          builder: (context, state) =>
              const StudentShellScreen(selectedIndex: 0),
        ),
        GoRoute(
          path: studentComplaints,
          builder: (context, state) =>
              const StudentShellScreen(selectedIndex: 1),
        ),
        GoRoute(
          path: studentLostFound,
          builder: (context, state) =>
              const StudentShellScreen(selectedIndex: 2),
        ),
        GoRoute(
          path: studentAnnouncements,
          builder: (context, state) =>
              const StudentShellScreen(selectedIndex: 3),
        ),
        GoRoute(
          path: studentProfile,
          builder: (context, state) =>
              const StudentShellScreen(selectedIndex: 4),
        ),
      ],
    );
  }
}
