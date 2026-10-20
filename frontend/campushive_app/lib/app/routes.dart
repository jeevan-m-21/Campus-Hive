import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/org_admin/admin_shell.dart';
import '../features/org_admin/complaints/admin_complaint_detail_screen.dart';
import '../features/org_admin/notifications/admin_notifications_screen.dart';
import '../features/org_admin/users/admin_supervisors_screen.dart';
import '../features/auth/landing_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/student/student_shell.dart';
import '../features/student/announcements/announcement_detail_screen.dart';
import '../features/student/complaints/complaint_detail_screen.dart';
import '../features/student/complaints/report_issue_screen.dart';
import '../features/student/lost_found/lost_found_detail_screen.dart';
import '../features/student/lost_found/report_lost_found_screen.dart';
import '../features/student/notifications/student_notifications_screen.dart';
import '../features/student/profile/my_complaints_activity_screen.dart';
import '../features/student/profile/my_lost_found_activity_screen.dart';
import '../features/supervisor/complaints/supervisor_complaint_detail_screen.dart';
import '../features/supervisor/notifications/supervisor_notifications_screen.dart';
import '../features/supervisor/supervisor_shell.dart';

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
  static const studentNotifications = '/student/notifications';
  static const studentReportIssue = '/student/report-issue';
  static const studentReportLostFound = '/student/report-lost-found';
  static const studentMyComplaints = '/student/activity/complaints';
  static const studentMyLostFound = '/student/activity/lost-found';

  // Supervisor Routes
  static const supervisorDashboard = '/supervisor/dashboard';
  static const supervisorQueue = '/supervisor/queue';
  static const supervisorAnnouncements = '/supervisor/announcements';
  static const supervisorProfile = '/supervisor/profile';
  static const supervisorNotifications = '/supervisor/notifications';

  // Admin Routes
  static const adminDashboard = '/admin/dashboard';
  static const adminComplaints = '/admin/complaints';
  static const adminAnnouncements = '/admin/announcements';
  static const adminProfile = '/admin/profile';
  static const adminNotifications = '/admin/notifications';
  static const adminSupervisors = '/admin/supervisors';

  static String studentComplaintDetail(int complaintId) =>
      '/student/complaints/$complaintId';

  static String studentLostFoundDetail(int itemId) =>
      '/student/lost-found/$itemId';

  static String studentAnnouncementDetail(int announcementId) =>
      '/student/announcements/$announcementId';

  static String supervisorComplaintDetail(int complaintId) =>
      '/supervisor/complaints/$complaintId';

  static String adminComplaintDetail(int complaintId) =>
      '/admin/complaints/$complaintId';

  static String adminAnnouncementDetail(int announcementId) =>
      '/admin/announcements/$announcementId';

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static GoRouter? _activeRouter;

  static GoRouter get routerInstance => _activeRouter ?? router();

  static GoRouter router() {
    _activeRouter = GoRouter(
      navigatorKey: rootNavigatorKey,
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
        // Student Routes
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
        GoRoute(
          path: studentNotifications,
          builder: (context, state) => const StudentNotificationsScreen(),
        ),
        GoRoute(
          path: studentReportIssue,
          builder: (context, state) => const ReportIssueScreen(),
        ),
        GoRoute(
          path: studentReportLostFound,
          builder: (context, state) => const ReportLostFoundScreen(),
        ),
        GoRoute(
          path: studentMyComplaints,
          builder: (context, state) => const MyComplaintsActivityScreen(),
        ),
        GoRoute(
          path: studentMyLostFound,
          builder: (context, state) => const MyLostFoundActivityScreen(),
        ),
        GoRoute(
          path: '/student/complaints/:complaintId',
          builder: (context, state) => ComplaintDetailScreen(
            complaintId: int.parse(state.pathParameters['complaintId']!),
          ),
        ),
        GoRoute(
          path: '/student/lost-found/:itemId',
          builder: (context, state) => LostFoundDetailScreen(
            itemId: int.tryParse(state.pathParameters['itemId'] ?? '') ?? 0,
          ),
        ),
        GoRoute(
          path: '/student/announcements/:announcementId',
          builder: (context, state) => AnnouncementDetailScreen(
            announcementId:
                int.tryParse(state.pathParameters['announcementId'] ?? '') ?? 0,
          ),
        ),
        // Supervisor Routes
        GoRoute(
          path: supervisorDashboard,
          builder: (context, state) =>
              const SupervisorShellScreen(selectedIndex: 0),
        ),
        GoRoute(
          path: supervisorQueue,
          builder: (context, state) =>
              const SupervisorShellScreen(selectedIndex: 1),
        ),
        GoRoute(
          path: supervisorAnnouncements,
          builder: (context, state) =>
              const SupervisorShellScreen(selectedIndex: 2),
        ),
        GoRoute(
          path: supervisorProfile,
          builder: (context, state) =>
              const SupervisorShellScreen(selectedIndex: 3),
        ),
        GoRoute(
          path: supervisorNotifications,
          builder: (context, state) => const SupervisorNotificationsScreen(),
        ),
        GoRoute(
          path: '/supervisor/complaints/:complaintId',
          builder: (context, state) => SupervisorComplaintDetailScreen(
            complaintId: int.parse(state.pathParameters['complaintId']!),
          ),
        ),
        // Admin Routes
        GoRoute(
          path: adminDashboard,
          builder: (context, state) => const AdminShellScreen(selectedIndex: 0),
        ),
        GoRoute(
          path: adminComplaints,
          builder: (context, state) => const AdminShellScreen(selectedIndex: 1),
        ),
        GoRoute(
          path: adminAnnouncements,
          builder: (context, state) => const AdminShellScreen(selectedIndex: 2),
        ),
        GoRoute(
          path: adminProfile,
          builder: (context, state) => const AdminShellScreen(selectedIndex: 3),
        ),
        GoRoute(
          path: adminNotifications,
          builder: (context, state) => const AdminNotificationsScreen(),
        ),
        GoRoute(
          path: '/admin/complaints/:complaintId',
          builder: (context, state) => AdminComplaintDetailScreen(
            complaintId: int.parse(state.pathParameters['complaintId']!),
          ),
        ),
        GoRoute(
          path: '/admin/announcements/:announcementId',
          builder: (context, state) => AnnouncementDetailScreen(
            announcementId:
                int.tryParse(state.pathParameters['announcementId'] ?? '') ?? 0,
          ),
        ),
        GoRoute(
          path: adminSupervisors,
          builder: (context, state) => const AdminSupervisorsScreen(),
        ),
      ],
    );
    return _activeRouter!;
  }
}
