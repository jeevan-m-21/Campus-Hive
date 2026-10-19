import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campushive_app/features/org_admin/widgets/admin_complaint_card.dart';
import 'package:campushive_app/features/student/home/widgets/complaint_feed_card.dart';
import 'package:campushive_app/features/supervisor/widgets/supervisor_complaint_card.dart';
import 'package:campushive_app/models/complaint.dart';

Complaint _buildComplaint({
  required int id,
  required String supervisorName,
  required DateTime? deadline,
}) {
  return Complaint(
    complaintId: id,
    organizationId: 1,
    studentId: 1,
    departmentId: 2,
    supervisorId: 12,
    supervisorName: supervisorName,
    title: 'Water leakage in Block B 3rd floor laboratory',
    description:
        'Continuous leakage from ceiling pipe threatening electrical equipment.',
    location: 'Block B, Lab 304',
    mlPriority: 'HIGH',
    finalPriority: 'HIGH',
    status: 'ASSIGNED',
    supportCount: 15,
    deadline: deadline,
    resolvedAt: null,
    studentFeedback: null,
    createdAt: DateTime(2026, 10, 15, 10, 30),
    updatedAt: DateTime(2026, 10, 15, 10, 30),
    studentName: 'Aarav Patel',
    departmentName: 'Facilities & Maintenance',
    category: 'Maintenance',
  );
}

void main() {
  group('Complaint Card Responsive Layout & Overflow Tests', () {
    const longSupervisorName =
        'Dr. Alexander Bartholomew Montgomery-Smith III (Chief Technical Supervisor for Campus Facilities and Infrastructure)';
    final testDeadline = DateTime(2026, 10, 25);

    testWidgets(
      'AdminComplaintCard renders without RenderFlex overflow on narrow 320px width',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final complaint = _buildComplaint(
          id: 101,
          supervisorName: longSupervisorName,
          deadline: testDeadline,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: AdminComplaintCard(complaint: complaint),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must not throw any RenderFlex overflow exceptions
        expect(tester.takeException(), isNull);

        // Supervisor information must be present
        expect(
          find.text('Supervisor: $longSupervisorName'),
          findsOneWidget,
        );

        // Deadline must be readable and present
        expect(find.text('Due 25/10/2026'), findsOneWidget);

        // Verify card rendered within available width
        final cardBox = tester.getRect(find.byType(AdminComplaintCard));
        expect(cardBox.width, lessThanOrEqualTo(320));
      },
    );

    testWidgets(
      'AdminComplaintCard renders without RenderFlex overflow on standard 360px mobile width',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final complaint = _buildComplaint(
          id: 102,
          supervisorName: longSupervisorName,
          deadline: testDeadline,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: AdminComplaintCard(complaint: complaint),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text('Supervisor: $longSupervisorName'),
          findsOneWidget,
        );
        expect(find.text('Due 25/10/2026'), findsOneWidget);

        final cardBox = tester.getRect(find.byType(AdminComplaintCard));
        expect(cardBox.width, lessThanOrEqualTo(360));
      },
    );

    testWidgets(
      'AdminComplaintCard renders on wide tablet width (600px) with single row layout without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(600, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final complaint = _buildComplaint(
          id: 103,
          supervisorName: longSupervisorName,
          deadline: testDeadline,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 600,
                  child: AdminComplaintCard(complaint: complaint),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text('Supervisor: $longSupervisorName'),
          findsOneWidget,
        );
        expect(find.text('Due 25/10/2026'), findsOneWidget);
      },
    );

    testWidgets(
      'AdminComplaintCard renders gracefully when deadline is null',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final complaint = _buildComplaint(
          id: 104,
          supervisorName: longSupervisorName,
          deadline: null,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: AdminComplaintCard(complaint: complaint),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text('Supervisor: $longSupervisorName'),
          findsOneWidget,
        );
        expect(find.textContaining('Due'), findsNothing);
      },
    );

    testWidgets(
      'SupervisorComplaintCard renders without RenderFlex overflow on narrow 300px width',
      (tester) async {
        tester.view.physicalSize = const Size(300, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final complaint = _buildComplaint(
          id: 105,
          supervisorName: longSupervisorName,
          deadline: testDeadline,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: SupervisorComplaintCard(complaint: complaint),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Workspace'), findsOneWidget);
        expect(find.text('Due 25/10/2026'), findsOneWidget);

        final cardBox = tester.getRect(find.byType(SupervisorComplaintCard));
        expect(cardBox.width, lessThanOrEqualTo(300));
      },
    );

    testWidgets(
      'ComplaintFeedCard renders without RenderFlex overflow on narrow 300px width',
      (tester) async {
        tester.view.physicalSize = const Size(300, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final complaint = _buildComplaint(
          id: 106,
          supervisorName: longSupervisorName,
          deadline: testDeadline,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: ComplaintFeedCard(complaint: complaint),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text('Water leakage in Block B 3rd floor laboratory'),
          findsOneWidget,
        );

        final cardBox = tester.getRect(find.byType(ComplaintFeedCard));
        expect(cardBox.width, lessThanOrEqualTo(300));
      },
    );
  });
}
