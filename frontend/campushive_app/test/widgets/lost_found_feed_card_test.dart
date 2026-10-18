import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:campushive_app/features/student/home/widgets/lost_found_feed_card.dart';
import 'package:campushive_app/models/lost_found.dart';

void main() {
  testWidgets('LostFoundFeedCard navigates to studentLostFoundDetail on tap', (
    tester,
  ) async {
    const item = LostFound(
      itemId: 42,
      organizationId: 1,
      postedBy: 2,
      posterName: 'Alice',
      itemType: 'LOST',
      title: 'Lost Calculator',
      description: 'Blue calculator lost in lab',
      category: 'Electronics',
      location: 'Lab 3',
      dateOfIncident: null,
      status: 'OPEN',
      resolvedAt: null,
      createdAt: null,
      updatedAt: null,
      imageCount: 0,
      images: [],
    );

    String? navigatedRoute;

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: LostFoundFeedCard(item: item)),
        ),
        GoRoute(
          path: '/student/lost-found/:itemId',
          builder: (context, state) {
            navigatedRoute = state.uri.toString();
            return const Scaffold(body: Text('Detail Screen'));
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Lost Calculator'), findsOneWidget);

    await tester.tap(find.text('Lost Calculator'));
    await tester.pumpAndSettle();

    expect(navigatedRoute, '/student/lost-found/42');
    expect(find.text('Detail Screen'), findsOneWidget);
  });
}
