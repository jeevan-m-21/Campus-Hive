class LostFound {
  const LostFound({
    required this.itemId,
    required this.organizationId,
    required this.postedBy,
    required this.posterName,
    required this.itemType,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.dateOfIncident,
    required this.status,
    required this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.imageCount,
    required this.images,
  });

  final int itemId;
  final int organizationId;
  final int postedBy;
  final String? posterName;
  final String itemType;
  final String title;
  final String description;
  final String? category;
  final String? location;
  final DateTime? dateOfIncident;
  final String status;
  final DateTime? resolvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int imageCount;
  final List<LostFoundImage> images;

  factory LostFound.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    return LostFound(
      itemId: _int(json['item_id']),
      organizationId: _int(json['organization_id']),
      postedBy: _int(json['posted_by']),
      posterName: _stringOrNull(json['poster_name']),
      itemType: _string(json['item_type']),
      title: _string(json['title']),
      description: _string(json['description']),
      category: _stringOrNull(json['category']),
      location: _stringOrNull(json['location']),
      dateOfIncident: _date(json['date_of_incident']),
      status: _string(json['status']),
      resolvedAt: _date(json['resolved_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      imageCount: _int(json['image_count']),
      images: rawImages is List
          ? rawImages
                .whereType<Map<String, dynamic>>()
                .map(LostFoundImage.fromJson)
                .toList()
          : const [],
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;
  static String _string(Object? value) => value?.toString() ?? '';
  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

class LostFoundImage {
  const LostFoundImage({required this.imageId, required this.imageUrl});

  final int imageId;
  final String imageUrl;

  factory LostFoundImage.fromJson(Map<String, dynamic> json) {
    return LostFoundImage(
      imageId: json['image_id'] is num ? (json['image_id'] as num).toInt() : 0,
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }
}
