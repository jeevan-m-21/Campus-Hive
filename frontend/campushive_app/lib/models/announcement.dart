import 'announcement_attachment.dart';

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
    this.likeCount = 0,
    this.isLiked = false,
    this.attachments = const [],
  });

  final int announcementId;
  final int organizationId;
  final int createdBy;
  final String title;
  final String description;
  final String? attachmentUrl;
  final String attachmentType;
  final bool isImportant;
  final int likeCount;
  final bool isLiked;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<AnnouncementAttachment> attachments;

  Announcement copyWith({
    int? announcementId,
    int? organizationId,
    int? createdBy,
    String? title,
    String? description,
    String? attachmentUrl,
    String? attachmentType,
    bool? isImportant,
    int? likeCount,
    bool? isLiked,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AnnouncementAttachment>? attachments,
  }) {
    return Announcement(
      announcementId: announcementId ?? this.announcementId,
      organizationId: organizationId ?? this.organizationId,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      description: description ?? this.description,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      isImportant: isImportant ?? this.isImportant,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachments: attachments ?? this.attachments,
    );
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final parsedAttachments = <AnnouncementAttachment>[];
    if (json['attachments'] is List) {
      for (final item in (json['attachments'] as List)) {
        if (item is Map<String, dynamic>) {
          parsedAttachments.add(AnnouncementAttachment.fromJson(item));
        } else if (item is Map) {
          parsedAttachments.add(
            AnnouncementAttachment.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final rawUrl = _stringOrNull(json['attachment_url']);
    final rawType = json['attachment_type']?.toString().toUpperCase() ?? 'NONE';

    // Legacy synthesis: if no attachments array returned, but legacy attachment exists
    if (parsedAttachments.isEmpty && rawUrl != null && rawType != 'NONE') {
      parsedAttachments.add(
        AnnouncementAttachment(attachmentType: rawType, attachmentUrl: rawUrl),
      );
    }

    // Effective primary attachment for legacy views/cards
    final effectiveUrl =
        rawUrl ??
        (parsedAttachments.isNotEmpty
            ? parsedAttachments.first.attachmentUrl
            : null);
    final effectiveType = (rawType != 'NONE')
        ? rawType
        : (parsedAttachments.isNotEmpty
              ? parsedAttachments.first.attachmentType
              : 'NONE');

    return Announcement(
      announcementId: _int(json['announcement_id']),
      organizationId: _int(json['organization_id']),
      createdBy: _int(json['created_by']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      attachmentUrl: effectiveUrl,
      attachmentType: effectiveType,
      isImportant: json['is_important'] == true,
      likeCount: _int(json['like_count']),
      isLiked: json['is_liked'] == true,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      attachments: parsedAttachments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'announcement_id': announcementId,
      'organization_id': organizationId,
      'created_by': createdBy,
      'title': title,
      'description': description,
      'attachment_url': attachmentUrl,
      'attachment_type': attachmentType,
      'is_important': isImportant,
      'like_count': likeCount,
      'is_liked': isLiked,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
