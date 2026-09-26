abstract final class ApiEndpoints {
  static const login = '/auth/login';
  static const complaints = '/complaints';
  static const complaintDepartments = '/complaints/departments';
  static const uploadComplaintImage = '/complaints/upload-image';
  static const lostFound = '/lost-found';
  static const announcements = '/announcements';
  static const notifications = '/notifications';
  static const notificationsUnreadCount = '/notifications/unread-count';
  static const notificationsReadAll = '/notifications/read-all';

  static String supportComplaint(int complaintId) =>
      '$complaints/$complaintId/support';

  static String complaintDetail(int complaintId) => '$complaints/$complaintId';

  static String updateComplaint(int complaintId) => '$complaints/$complaintId';

  static String complaintComments(int complaintId) =>
      '$complaints/$complaintId/comments';

  static String addComplaintComment(int complaintId) =>
      '$complaints/$complaintId/comments';

  static String likeAnnouncement(int announcementId) =>
      '$announcements/$announcementId/like';

  static String markNotificationRead(int notificationId) =>
      '$notifications/$notificationId/read';

  static String deleteNotification(int notificationId) =>
      '$notifications/$notificationId';
}
