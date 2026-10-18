import 'package:flutter_test/flutter_test.dart';

import 'package:campushive_app/app/routes.dart';
import 'package:campushive_app/core/network/api_endpoints.dart';
import 'package:campushive_app/models/announcement.dart';

void main() {
  group('Announcement Models and Endpoints', () {
    test('ApiEndpoints helpers generate expected paths for announcements', () {
      expect(ApiEndpoints.announcements, '/announcements');
      expect(ApiEndpoints.announcementDetail(5), '/announcements/5');
      expect(ApiEndpoints.likeAnnouncement(5), '/announcements/5/like');
      expect(ApiEndpoints.updateAnnouncement(5), '/announcements/5');
      expect(ApiEndpoints.deleteAnnouncement(5), '/announcements/5');
    });

    test('AppRoutes helper generates expected route paths', () {
      expect(
        AppRoutes.studentAnnouncementDetail(12),
        '/student/announcements/12',
      );
      expect(AppRoutes.adminAnnouncementDetail(12), '/admin/announcements/12');
    });

    test('Announcement.fromJson parses complete payload correctly', () {
      final json = {
        'announcement_id': 12,
        'organization_id': 1,
        'created_by': 3,
        'title': 'Campus Tech Symposium 2026',
        'description': 'Annual tech symposium scheduled for next week.',
        'attachment_url': '/uploads/announcements/poster.png',
        'attachment_type': 'IMAGE',
        'is_important': true,
        'like_count': 15,
        'is_liked': true,
        'created_at': '2026-10-18T10:30:00',
        'updated_at': '2026-10-18T12:00:00',
      };

      final announcement = Announcement.fromJson(json);

      expect(announcement.announcementId, 12);
      expect(announcement.organizationId, 1);
      expect(announcement.createdBy, 3);
      expect(announcement.title, 'Campus Tech Symposium 2026');
      expect(
        announcement.description,
        'Annual tech symposium scheduled for next week.',
      );
      expect(announcement.attachmentUrl, '/uploads/announcements/poster.png');
      expect(announcement.attachmentType, 'IMAGE');
      expect(announcement.isImportant, isTrue);
      expect(announcement.likeCount, 15);
      expect(announcement.isLiked, isTrue);
      expect(announcement.createdAt, DateTime(2026, 10, 18, 10, 30, 0));
      expect(announcement.updatedAt, DateTime(2026, 10, 18, 12, 0, 0));
    });

    test('Announcement.fromJson handles PDF attachment and nulls safely', () {
      final json = {
        'announcement_id': '7',
        'organization_id': '1',
        'created_by': '2',
        'title': 'Academic Calendar',
        'description': 'See attached schedule PDF.',
        'attachment_url': 'https://example.com/calendar.pdf',
        'attachment_type': 'PDF',
        'is_important': false,
        'like_count': '0',
        'is_liked': false,
        'created_at': null,
        'updated_at': null,
      };

      final announcement = Announcement.fromJson(json);

      expect(announcement.announcementId, 7);
      expect(announcement.title, 'Academic Calendar');
      expect(announcement.attachmentType, 'PDF');
      expect(announcement.attachmentUrl, 'https://example.com/calendar.pdf');
      expect(announcement.isImportant, isFalse);
      expect(announcement.likeCount, 0);
      expect(announcement.isLiked, isFalse);
      expect(announcement.createdAt, isNull);
      expect(announcement.updatedAt, isNull);
    });

    test(
      'Announcement.fromJson handles NONE attachment type with empty url',
      () {
        final json = {
          'announcement_id': 9,
          'organization_id': 1,
          'created_by': 1,
          'title': 'Library Hours Extended',
          'description': 'Library will remain open until midnight.',
          'attachment_url': '',
          'attachment_type': null,
          'is_important': false,
          'like_count': 3,
          'is_liked': false,
          'created_at': '2026-10-17T08:00:00',
          'updated_at': null,
        };

        final announcement = Announcement.fromJson(json);

        expect(announcement.announcementId, 9);
        expect(announcement.attachmentType, 'NONE');
        expect(announcement.attachmentUrl, isNull);
        expect(announcement.attachments, isEmpty);
      },
    );

    test('Announcement.fromJson parses multiple attachments correctly', () {
      final json = {
        'announcement_id': 20,
        'organization_id': 1,
        'created_by': 2,
        'title': 'Campus Fest Schedule & Guidelines',
        'description': 'Details regarding events and rules.',
        'attachment_url': '/uploads/announcements/poster.jpg',
        'attachment_type': 'IMAGE',
        'is_important': true,
        'like_count': 50,
        'is_liked': false,
        'created_at': '2026-10-18T10:00:00',
        'updated_at': null,
        'attachments': [
          {
            'attachment_id': 101,
            'announcement_id': 20,
            'attachment_type': 'IMAGE',
            'attachment_url': '/uploads/announcements/poster.jpg',
            'original_filename': 'fest_poster.jpg',
            'mime_type': 'image/jpeg',
            'file_size': 204800,
            'created_at': '2026-10-18T10:00:00',
          },
          {
            'attachment_id': 102,
            'announcement_id': 20,
            'attachment_type': 'PDF',
            'attachment_url': '/uploads/announcements/rules.pdf',
            'original_filename': 'event_rules.pdf',
            'mime_type': 'application/pdf',
            'file_size': 1048576,
            'created_at': '2026-10-18T10:01:00',
          },
          {
            'attachment_id': 103,
            'announcement_id': 20,
            'attachment_type': 'LINK',
            'attachment_url': 'https://fest.campus.edu',
            'original_filename': 'https://fest.campus.edu',
            'mime_type': null,
            'file_size': null,
            'created_at': '2026-10-18T10:02:00',
          },
        ],
      };

      final announcement = Announcement.fromJson(json);

      expect(announcement.announcementId, 20);
      expect(announcement.attachments.length, 3);
      expect(announcement.attachments[0].attachmentType, 'IMAGE');
      expect(announcement.attachments[0].originalFilename, 'fest_poster.jpg');
      expect(announcement.attachments[0].fileSize, 204800);
      expect(announcement.attachments[1].attachmentType, 'PDF');
      expect(announcement.attachments[1].originalFilename, 'event_rules.pdf');
      expect(announcement.attachments[2].attachmentType, 'LINK');
      expect(
        announcement.attachments[2].attachmentUrl,
        'https://fest.campus.edu',
      );
    });

    test(
      'Announcement.fromJson synthesizes attachment for legacy payloads',
      () {
        final json = {
          'announcement_id': 25,
          'organization_id': 1,
          'created_by': 2,
          'title': 'Legacy Circular',
          'description': 'Circular from previous term.',
          'attachment_url': '/uploads/announcements/legacy_notice.pdf',
          'attachment_type': 'PDF',
          'is_important': false,
          'like_count': 2,
          'is_liked': false,
          'created_at': '2026-09-01T10:00:00',
          'updated_at': null,
          // Notice 'attachments' key is omitted completely
        };

        final announcement = Announcement.fromJson(json);

        expect(announcement.attachments.length, 1);
        expect(announcement.attachments.first.attachmentType, 'PDF');
        expect(
          announcement.attachments.first.attachmentUrl,
          '/uploads/announcements/legacy_notice.pdf',
        );
      },
    );

    test('Announcement.copyWith preserves and updates fields correctly', () {
      const original = Announcement(
        announcementId: 30,
        organizationId: 1,
        createdBy: 2,
        title: 'Original Title',
        description: 'Original Description',
        attachmentUrl: '/uploads/a.png',
        attachmentType: 'IMAGE',
        isImportant: false,
        likeCount: 5,
        isLiked: false,
        createdAt: null,
        updatedAt: null,
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        likeCount: 6,
        isLiked: true,
      );

      expect(updated.announcementId, 30);
      expect(updated.title, 'Updated Title');
      expect(updated.description, 'Original Description');
      expect(updated.likeCount, 6);
      expect(updated.isLiked, isTrue);
      expect(updated.attachmentUrl, '/uploads/a.png');
    });

    test('ApiEndpoints includes new announcement attachment endpoints', () {
      expect(
        ApiEndpoints.uploadAnnouncementAttachment,
        '/announcements/upload-attachment',
      );
      expect(
        ApiEndpoints.announcementAttachments(42),
        '/announcements/42/attachments',
      );
      expect(
        ApiEndpoints.deleteAnnouncementAttachment(42, 99),
        '/announcements/42/attachments/99',
      );
    });
  });
}
