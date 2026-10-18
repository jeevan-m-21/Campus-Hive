import 'package:flutter_test/flutter_test.dart';

import 'package:campushive_app/core/network/api_endpoints.dart';
import 'package:campushive_app/models/lost_found.dart';
import 'package:campushive_app/models/lost_found_comment.dart';

void main() {
  group('LostFound Models and Endpoints', () {
    test('ApiEndpoints helpers generate expected paths', () {
      expect(ApiEndpoints.lostFoundDetail(8), '/lost-found/8');
      expect(ApiEndpoints.lostFoundComments(8), '/lost-found/8/comments');
      expect(ApiEndpoints.addLostFoundComment(8), '/lost-found/8/comments');
      expect(ApiEndpoints.updateLostFound(8), '/lost-found/8');
    });

    test('LostFound.fromJson parses backend detail response correctly', () {
      final json = {
        'item_id': 8,
        'organization_id': 1,
        'posted_by': 1,
        'poster_name': 'Test User',
        'item_type': 'LOST',
        'title': 'Orbit Calculator',
        'description': 'I forgot my calculator in the reading room.',
        'category': 'Personal Belongings',
        'location': 'Reading room',
        'date_of_incident': '2026-10-17',
        'status': 'OPEN',
        'resolved_at': null,
        'created_at': '2026-10-18T19:09:39',
        'updated_at': '2026-10-18T19:09:39',
        'image_count': 1,
        'images': [
          {
            'image_id': 2,
            'item_id': 8,
            'image_url':
                '/uploads/complaints/e9d9c659b11d459b856314ec4a43f125.jpg',
            'uploaded_at': '2026-10-18T19:09:39',
          },
        ],
      };

      final item = LostFound.fromJson(json);

      expect(item.itemId, 8);
      expect(item.organizationId, 1);
      expect(item.postedBy, 1);
      expect(item.posterName, 'Test User');
      expect(item.itemType, 'LOST');
      expect(item.title, 'Orbit Calculator');
      expect(item.description, 'I forgot my calculator in the reading room.');
      expect(item.category, 'Personal Belongings');
      expect(item.location, 'Reading room');
      expect(item.dateOfIncident, DateTime(2026, 10, 17));
      expect(item.status, 'OPEN');
      expect(item.resolvedAt, isNull);
      expect(item.createdAt, DateTime(2026, 10, 18, 19, 9, 39));
      expect(item.images.length, 1);
      expect(item.images.first.imageId, 2);
      expect(
        item.images.first.imageUrl,
        '/uploads/complaints/e9d9c659b11d459b856314ec4a43f125.jpg',
      );
    });

    test('LostFoundComment.fromJson parses comment payload correctly', () {
      final json = {
        'message_id': 4,
        'item_id': 8,
        'sender_id': 2,
        'sender_name': 'Student Two',
        'message': 'I saw it near table 4 yesterday.',
        'message_type': 'TEXT',
        'image_url': null,
        'sent_at': '2026-10-18T20:15:00',
      };

      final comment = LostFoundComment.fromJson(json);

      expect(comment.messageId, 4);
      expect(comment.itemId, 8);
      expect(comment.senderId, 2);
      expect(comment.senderName, 'Student Two');
      expect(comment.message, 'I saw it near table 4 yesterday.');
      expect(comment.messageType, 'TEXT');
      expect(comment.imageUrl, isNull);
      expect(comment.sentAt, DateTime(2026, 10, 18, 20, 15, 0));
    });
  });
}
