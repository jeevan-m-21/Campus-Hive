class LostFoundComment {
  const LostFoundComment({
    required this.messageId,
    required this.itemId,
    required this.senderId,
    required this.message,
    required this.messageType,
    required this.imageUrl,
    required this.sentAt,
    this.senderName,
  });

  final int messageId;
  final int itemId;
  final int senderId;
  final String message;
  final String messageType;
  final String? imageUrl;
  final DateTime? sentAt;
  final String? senderName;

  factory LostFoundComment.fromJson(Map<String, dynamic> json) {
    return LostFoundComment(
      messageId: _int(json['message_id']),
      itemId: _int(json['item_id']),
      senderId: _int(json['sender_id']),
      message: json['message']?.toString() ?? '',
      messageType: json['message_type']?.toString() ?? 'TEXT',
      imageUrl: _nullableString(json['image_url']),
      sentAt: json['sent_at'] is String
          ? DateTime.tryParse(json['sent_at'] as String)
          : null,
      senderName: _nullableString(json['sender_name']),
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
