class AnnouncementAttachment {
  const AnnouncementAttachment({
    this.attachmentId,
    this.announcementId,
    required this.attachmentType,
    required this.attachmentUrl,
    this.originalFilename,
    this.mimeType,
    this.fileSize,
    this.createdAt,
  });

  final int? attachmentId;
  final int? announcementId;
  final String attachmentType;
  final String attachmentUrl;
  final String? originalFilename;
  final String? mimeType;
  final int? fileSize;
  final DateTime? createdAt;

  factory AnnouncementAttachment.fromJson(Map<String, dynamic> json) {
    return AnnouncementAttachment(
      attachmentId: _intOrNull(json['attachment_id']),
      announcementId: _intOrNull(json['announcement_id']),
      attachmentType:
          json['attachment_type']?.toString().toUpperCase() ?? 'NONE',
      attachmentUrl: json['attachment_url']?.toString().trim() ?? '',
      originalFilename: _stringOrNull(json['original_filename']),
      mimeType: _stringOrNull(json['mime_type']),
      fileSize: _intOrNull(json['file_size']),
      createdAt: _date(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (attachmentId != null) 'attachment_id': attachmentId,
      if (announcementId != null) 'announcement_id': announcementId,
      'attachment_type': attachmentType,
      'attachment_url': attachmentUrl,
      if (originalFilename != null) 'original_filename': originalFilename,
      if (mimeType != null) 'mime_type': mimeType,
      if (fileSize != null) 'file_size': fileSize,
    };
  }

  static int? _intOrNull(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
