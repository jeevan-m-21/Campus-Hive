import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:campushive_app/features/student/announcements/announcement_detail_screen.dart';
import 'package:campushive_app/models/announcement.dart';
import 'package:campushive_app/models/announcement_attachment.dart';
import 'package:campushive_app/providers/auth_provider.dart';
import 'package:campushive_app/services/auth_service.dart';

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  _FakeAuthProvider(this._role);

  final String _role;

  @override
  AuthSession? get session =>
      AuthSession(user: {'id': 1, 'email': 'user@example.com'}, role: _role);

  @override
  bool get isLoading => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Announcement Detail Screen Tests', () {
    const testAnnouncement = Announcement(
      announcementId: 55,
      organizationId: 1,
      createdBy: 2,
      title: 'Graduation Day Ceremony',
      description: 'The annual convocation ceremony schedule and guidelines.',
      attachmentUrl: '/uploads/announcements/banner.jpg',
      attachmentType: 'IMAGE',
      isImportant: true,
      likeCount: 42,
      isLiked: false,
      createdAt: null,
      updatedAt: null,
      attachments: [
        AnnouncementAttachment(
          attachmentId: 1,
          announcementId: 55,
          attachmentType: 'IMAGE',
          attachmentUrl: 'https://example.com/banner.jpg',
          originalFilename: 'banner.jpg',
        ),
        AnnouncementAttachment(
          attachmentId: 2,
          announcementId: 55,
          attachmentType: 'PDF',
          attachmentUrl: 'https://example.com/guidelines.pdf',
          originalFilename: 'guidelines.pdf',
          fileSize: 1048576,
        ),
        AnnouncementAttachment(
          attachmentId: 3,
          announcementId: 55,
          attachmentType: 'LINK',
          attachmentUrl: 'https://convocation.campus.edu',
          originalFilename: 'https://convocation.campus.edu',
        ),
      ],
    );

    testWidgets('ORG_ADMIN sees Edit Announcement action button', (
      tester,
    ) async {
      final fakeAuth = _FakeAuthProvider('ORG_ADMIN');

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: fakeAuth,
          child: const MaterialApp(
            home: AnnouncementDetailScreen(
              announcementId: 55,
              initialAnnouncement: testAnnouncement,
            ),
          ),
        ),
      );

      expect(find.text('Graduation Day Ceremony'), findsOneWidget);
      expect(find.byTooltip('Edit Notice'), findsOneWidget);
    });

    testWidgets('STUDENT does not see Edit Announcement action button', (
      tester,
    ) async {
      final fakeAuth = _FakeAuthProvider('STUDENT');

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: fakeAuth,
          child: const MaterialApp(
            home: AnnouncementDetailScreen(
              announcementId: 55,
              initialAnnouncement: testAnnouncement,
            ),
          ),
        ),
      );

      expect(find.text('Graduation Day Ceremony'), findsOneWidget);
      expect(find.byTooltip('Edit Notice'), findsNothing);
    });

    testWidgets('Displays multiple attachments (Image, PDF, Link) correctly', (
      tester,
    ) async {
      final fakeAuth = _FakeAuthProvider('STUDENT');

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: fakeAuth,
          child: const MaterialApp(
            home: AnnouncementDetailScreen(
              announcementId: 55,
              initialAnnouncement: testAnnouncement,
            ),
          ),
        ),
      );

      expect(find.text('Attachment Image'), findsOneWidget);
      expect(find.text('guidelines.pdf'), findsOneWidget);
      expect(find.text('PDF Document • 1.0 MB'), findsOneWidget);
      expect(find.byTooltip('Open PDF'), findsOneWidget);
      expect(find.text('https://convocation.campus.edu'), findsOneWidget);
      expect(find.byTooltip('Visit link'), findsOneWidget);
    });
  });
}
