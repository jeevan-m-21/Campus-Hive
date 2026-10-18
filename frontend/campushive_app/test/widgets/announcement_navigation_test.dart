import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:campushive_app/app/routes.dart';
import 'package:campushive_app/features/org_admin/announcements/widgets/admin_announcement_card.dart';
import 'package:campushive_app/features/student/home/widgets/announcement_feed_card.dart';
import 'package:campushive_app/models/announcement.dart';

void main() {
  group('Announcement Navigation Tests', () {
    testWidgets(
      'AnnouncementFeedCard navigates to studentAnnouncementDetail on card tap',
      (tester) async {
        const item = Announcement(
          announcementId: 101,
          organizationId: 1,
          createdBy: 1,
          title: 'Campus Marathon 2026',
          description: 'Registration opens tomorrow morning.',
          attachmentUrl: null,
          attachmentType: 'NONE',
          isImportant: true,
          likeCount: 12,
          isLiked: false,
          createdAt: null,
          updatedAt: null,
        );

        String? navigatedRoute;

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const Scaffold(body: AnnouncementFeedCard(item: item)),
            ),
            GoRoute(
              path: '/student/announcements/:announcementId',
              builder: (context, state) {
                navigatedRoute = state.uri.toString();
                return const Scaffold(body: Text('Announcement Detail Screen'));
              },
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        expect(find.text('Campus Marathon 2026'), findsOneWidget);
        expect(find.text('IMPORTANT'), findsOneWidget);

        // Tap the card body (title)
        await tester.tap(find.text('Campus Marathon 2026'));
        await tester.pumpAndSettle();

        expect(navigatedRoute, AppRoutes.studentAnnouncementDetail(101));
        expect(find.text('Announcement Detail Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'AdminAnnouncementCard navigates to adminAnnouncementDetail on card body tap',
      (tester) async {
        const item = Announcement(
          announcementId: 202,
          organizationId: 1,
          createdBy: 1,
          title: 'Admin Notice: Fee Deadline',
          description: 'Tuition fees must be paid by end of month.',
          attachmentUrl: null,
          attachmentType: 'NONE',
          isImportant: false,
          likeCount: 5,
          isLiked: false,
          createdAt: null,
          updatedAt: null,
        );

        String? navigatedRoute;
        var editCalled = false;
        var deleteCalled = false;

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: AdminAnnouncementCard(
                  item: item,
                  onEdit: () => editCalled = true,
                  onDelete: () => deleteCalled = true,
                ),
              ),
            ),
            GoRoute(
              path: '/admin/announcements/:announcementId',
              builder: (context, state) {
                navigatedRoute = state.uri.toString();
                return const Scaffold(body: Text('Admin Detail Screen'));
              },
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        expect(find.text('Admin Notice: Fee Deadline'), findsOneWidget);

        // Tap the card body
        await tester.tap(find.text('Admin Notice: Fee Deadline'));
        await tester.pumpAndSettle();

        expect(navigatedRoute, AppRoutes.adminAnnouncementDetail(202));
        expect(find.text('Admin Detail Screen'), findsOneWidget);
        expect(editCalled, isFalse);
        expect(deleteCalled, isFalse);
      },
    );

    testWidgets(
      'AdminAnnouncementCard edit and delete actions do not trigger navigation',
      (tester) async {
        const item = Announcement(
          announcementId: 203,
          organizationId: 1,
          createdBy: 1,
          title: 'Campus Workshop',
          description: 'AI workshop on Saturday.',
          attachmentUrl: null,
          attachmentType: 'NONE',
          isImportant: false,
          likeCount: 0,
          isLiked: false,
          createdAt: null,
          updatedAt: null,
        );

        String? navigatedRoute;
        var editCount = 0;
        var deleteCount = 0;

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: AdminAnnouncementCard(
                  item: item,
                  onEdit: () => editCount++,
                  onDelete: () => deleteCount++,
                ),
              ),
            ),
            GoRoute(
              path: '/admin/announcements/:announcementId',
              builder: (context, state) {
                navigatedRoute = state.uri.toString();
                return const Scaffold(body: Text('Admin Detail Screen'));
              },
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));

        // Tap the edit icon button
        await tester.tap(find.byTooltip('Edit Announcement'));
        await tester.pumpAndSettle();

        expect(editCount, 1);
        expect(navigatedRoute, isNull);

        // Tap the delete icon button
        await tester.tap(find.byTooltip('Delete Announcement'));
        await tester.pumpAndSettle();

        expect(deleteCount, 1);
        expect(navigatedRoute, isNull);
      },
    );
  });
}
