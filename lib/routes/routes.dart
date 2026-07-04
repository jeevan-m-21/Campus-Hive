/// App routing configuration
/// Defines all routes for the application

class Routes {
  // Authentication routes
  static const String login = '/login';
  static const String register = '/register';
  static const String resetPassword = '/reset-password';

  // Main app routes
  static const String home = '/home';
  static const String complaints = '/complaints';
  static const String complaintDetails = '/complaints/:id';
  static const String createComplaint = '/create-complaint';
  static const String lostFound = '/lost-found';
  static const String lostFoundDetails = '/lost-found/:id';
  static const String announcements = '/announcements';
  static const String profile = '/profile';
  static const String settings = '/settings';

  // Admin/Supervisor routes
  static const String dashboard = '/dashboard';
  static const String analytics = '/analytics';
  static const String management = '/management';

  // Common routes
  static const String splash = '/';
  static const String notFound = '/404';
}

/// Named route arguments
class RouteArguments {
  static const String complaintId = 'complaintId';
  static const String userId = 'userId';
  static const String postId = 'postId';
}
