/// Core constants for the application
/// API endpoints, timeouts, error codes, etc.

class ApiConstants {
  /// API Base URL
  static const String baseUrl = 'http://localhost:5000';
  // For production: 'https://api.campushive.com'

  /// API version prefix
  static const String apiVersion = '/api/v1';

  /// Full API endpoint
  static const String fullApiUrl = baseUrl + apiVersion;

  /// Request timeout in seconds
  static const int requestTimeout = 30;

  /// Connection timeout in seconds
  static const int connectionTimeout = 15;

  /// API Endpoints
  static const String authLogin = '/auth/login';
  static const String authRegister = '/auth/register';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';

  static const String complaints = '/complaints';
  static const String complaintsVote = '/complaints/:id/vote';
  static const String complaintsComment = '/complaints/:id/comments';
  static const String complaintsUpdate = '/complaints/:id';

  static const String lostFound = '/lost-found';
  static const String lostFoundClaim = '/lost-found/:id/claim';

  static const String notifications = '/notifications';
  static const String announcements = '/announcements';
  static const String analytics = '/analytics/dashboard';
}

class AppConstants {
  /// App name
  static const String appName = 'CampusHive';

  /// App version
  static const String appVersion = '1.0.0';

  /// Default page size for pagination
  static const int pageSize = 20;

  /// Token expiration time in hours
  static const int tokenExpirationHours = 24;

  /// Refresh token expiration in days
  static const int refreshTokenExpirationDays = 30;
}

class ValidationConstants {
  /// Password minimum length
  static const int passwordMinLength = 8;

  /// Email validation regex
  static const String emailRegex =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

  /// Phone validation regex
  static const String phoneRegex = r'^\+?[\d\s\-()]{10,}$';
}

class ComplaintConstants {
  /// Complaint categories
  static const List<String> categories = [
    'Electrical',
    'Housekeeping',
    'Transport',
    'Hostel',
    'Internet',
    'Security',
    'Other',
  ];

  /// Complaint statuses
  static const List<String> statuses = [
    'Pending',
    'Assigned',
    'In Progress',
    'Resolved',
    'Closed',
  ];

  /// Priority levels
  static const List<String> priorities = ['Low', 'Medium', 'High'];
}

class StorageConstants {
  /// Firebase Storage bucket for complaint images
  static const String complaintImagesPath = 'complaints/images';

  /// Firebase Storage bucket for lost & found images
  static const String lostFoundImagesPath = 'lost-found/images';

  /// Firebase Storage bucket for profile photos
  static const String profilePhotosPath = 'users/profile-photos';

  /// Max image upload size in MB
  static const int maxImageSizeMB = 50;
}

class UserRoles {
  static const String superAdmin = 'super_admin';
  static const String admin = 'admin';
  static const String supervisor = 'supervisor';
  static const String student = 'student';
}
