abstract final class ApiEndpoints {
  static const login = '/auth/login';
  static const complaints = '/complaints';
  static const complaintDepartments = '/complaints/departments';
  static const uploadComplaintImage = '/complaints/upload-image';
  static const lostFound = '/lost-found';
  static const announcements = '/announcements';

  static String supportComplaint(int complaintId) =>
      '$complaints/$complaintId/support';

  static String complaintDetail(int complaintId) => '$complaints/$complaintId';

  static String complaintComments(int complaintId) =>
      '$complaints/$complaintId/comments';

  static String addComplaintComment(int complaintId) =>
      '$complaints/$complaintId/comments';

  static String likeAnnouncement(int announcementId) =>
      '$announcements/$announcementId/like';
}
