class AppNotification {
  const AppNotification({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  final int notificationId;
  final int userId;
  final String title;
  final String message;
  final String notificationType;
  final int? referenceId;
  final bool isRead;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      notificationId: _int(json['notification_id']),
      userId: _int(json['user_id']),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      notificationType: json['notification_type']?.toString() ?? 'SYSTEM',
      referenceId: _nullableInt(json['reference_id']),
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: _date(json['created_at']),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      notificationId: notificationId,
      userId: userId,
      title: title,
      message: message,
      notificationType: notificationType,
      referenceId: referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static int? _nullableInt(Object? value) =>
      value is num ? value.toInt() : null;

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
