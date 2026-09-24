class Announcement {
  const Announcement({
    required this.announcementId,
    required this.organizationId,
    required this.createdBy,
    required this.title,
    required this.description,
    required this.attachmentUrl,
    required this.attachmentType,
    required this.isImportant,
    required this.createdAt,
    required this.updatedAt,
  });

  final int announcementId;
  final int organizationId;
  final int createdBy;
  final String title;
  final String description;
  final String? attachmentUrl;
  final String attachmentType;
  final bool isImportant;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      announcementId: _int(json['announcement_id']),
      organizationId: _int(json['organization_id']),
      createdBy: _int(json['created_by']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      attachmentUrl: _stringOrNull(json['attachment_url']),
      attachmentType: json['attachment_type']?.toString() ?? 'NONE',
      isImportant: json['is_important'] == true,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;
  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
