abstract final class ApiEndpoints {
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const sendRegistrationOtp = '/auth/otp/send-registration-otp';
  static const verifyRegistrationOtp = '/auth/otp/verify-registration-otp';
  static const me = '/auth/me';
  static const updateProfile = '/auth/profile';
  static const uploadProfileImage = '/auth/profile-image';
  static const updateFcmToken = '/auth/update-fcm-token';
  static const publicOrganizations = '/organizations/public';
  static String academicDepartments(int organizationId) =>
      '/organizations/$organizationId/academic-departments';
  static const complaints = '/complaints';
  static const complaintDepartments = '/complaints/departments';
  static const complaintSupervisors = '$complaints/supervisors';
  static String designateDepartmentSupervisor(int departmentId) =>
      '$complaintDepartments/$departmentId/supervisor';
  static const uploadComplaintImage = '/complaints/upload-image';
  static const uploadAnnouncementAttachment =
      '/announcements/upload-attachment';
  static const lostFound = '/lost-found';
  static const uploadLostFoundImage = '$lostFound/upload-image';
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

  static String complaintHistory(int complaintId) =>
      '$complaints/$complaintId/history';

  static String studentFeedback(int complaintId) =>
      '$complaints/$complaintId/feedback';

  static String reopenComplaint(int complaintId) =>
      '$complaints/$complaintId/reopen';

  static String likeAnnouncement(int announcementId) =>
      '$announcements/$announcementId/like';

  static String announcementDetail(int announcementId) =>
      '$announcements/$announcementId';

  static String updateAnnouncement(int announcementId) =>
      '$announcements/$announcementId';

  static String deleteAnnouncement(int announcementId) =>
      '$announcements/$announcementId';

  static String announcementAttachments(int announcementId) =>
      '$announcements/$announcementId/attachments';

  static String deleteAnnouncementAttachment(
    int announcementId,
    int attachmentId,
  ) => '$announcements/$announcementId/attachments/$attachmentId';

  static String markNotificationRead(int notificationId) =>
      '$notifications/$notificationId/read';

  static String deleteNotification(int notificationId) =>
      '$notifications/$notificationId';

  static String lostFoundDetail(int itemId) => '$lostFound/$itemId';

  static String lostFoundComments(int itemId) => '$lostFound/$itemId/comments';

  static String addLostFoundComment(int itemId) =>
      '$lostFound/$itemId/comments';

  static String updateLostFound(int itemId) => '$lostFound/$itemId';
}
