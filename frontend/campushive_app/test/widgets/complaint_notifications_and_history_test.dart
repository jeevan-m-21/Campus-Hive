import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:campushive_app/app/routes.dart';
import 'package:campushive_app/core/widgets/status_history_timeline.dart';
import 'package:campushive_app/features/student/complaints/complaint_detail_screen.dart';
import 'package:campushive_app/features/student/notifications/student_notifications_screen.dart';
import 'package:campushive_app/features/student/widgets/student_app_bar.dart';
import 'package:campushive_app/models/complaint.dart';
import 'package:campushive_app/models/complaint_comment.dart';
import 'package:campushive_app/models/complaint_status_history.dart';
import 'package:campushive_app/models/notification.dart';
import 'package:campushive_app/providers/auth_provider.dart';
import 'package:campushive_app/providers/notification_provider.dart';
import 'package:campushive_app/services/auth_service.dart';
import 'package:campushive_app/services/complaint_service.dart';
import 'package:campushive_app/services/notification_service.dart';

class FakeNotificationService implements NotificationService {
  FakeNotificationService({
    this.initialNotifications = const [],
    this.initialUnreadCount = 0,
    this.shouldThrow = false,
  });

  List<AppNotification> initialNotifications;
  int initialUnreadCount;
  bool shouldThrow;
  int markAsReadCallCount = 0;
  int markAllAsReadCallCount = 0;

  @override
  Future<NotificationPage> fetchNotificationPage({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
    String? type,
  }) async {
    if (shouldThrow) {
      throw const NotificationException('Failed to load notifications');
    }
    final items = unreadOnly
        ? initialNotifications.where((n) => !n.isRead).toList()
        : initialNotifications;
    return NotificationPage(
      notifications: items,
      page: page,
      pages: 1,
      total: items.length,
      hasNext: false,
      hasPrevious: false,
    );
  }

  @override
  Future<int> fetchUnreadCount() async {
    if (shouldThrow) return 0;
    return initialUnreadCount;
  }

  @override
  Future<AppNotification> markAsRead(int notificationId) async {
    markAsReadCallCount++;
    initialUnreadCount = (initialUnreadCount > 0) ? initialUnreadCount - 1 : 0;
    final item = initialNotifications.firstWhere(
      (n) => n.notificationId == notificationId,
      orElse: () => AppNotification(
        notificationId: notificationId,
        userId: 10,
        title: 'Title',
        message: 'Message',
        notificationType: 'SYSTEM',
        referenceId: null,
        isRead: true,
        createdAt: DateTime.now(),
      ),
    );
    return item.copyWith(isRead: true);
  }

  @override
  Future<int> markAllAsRead() async {
    markAllAsReadCallCount++;
    final count = initialUnreadCount;
    initialUnreadCount = 0;
    return count;
  }

  @override
  Future<void> deleteNotification(int notificationId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeComplaintService implements ComplaintService {
  FakeComplaintService({
    required this.complaint,
    this.history = const [],
  });

  final Complaint complaint;
  final List<ComplaintStatusHistory> history;

  @override
  Future<Complaint> fetchComplaint(int complaintId) async {
    return complaint;
  }

  @override
  Future<List<ComplaintStatusHistory>> fetchStatusHistory(int complaintId) async {
    return history;
  }

  @override
  Future<List<ComplaintComment>> fetchComments(int complaintId) async {
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthService extends AuthService {
  FakeAuthService(this._session);

  final AuthSession? _session;

  @override
  Future<AuthSession?> restoreSession() async => _session;
}

Complaint _buildComplaint({
  required int id,
  required String status,
  String? feedback,
}) {
  return Complaint(
    complaintId: id,
    organizationId: 1,
    studentId: 10,
    departmentId: 2,
    supervisorId: 5,
    supervisorName: 'Supervisor Mike',
    title: 'Broken fan in Room 201',
    description: 'Ceiling fan making strange grinding noise.',
    location: 'Room 201',
    mlPriority: 'MEDIUM',
    finalPriority: 'MEDIUM',
    status: status,
    supportCount: 3,
    deadline: DateTime(2026, 10, 25),
    resolvedAt: status == 'RESOLVED' ? DateTime(2026, 10, 18, 11, 0) : null,
    studentFeedback: feedback,
    createdAt: DateTime(2026, 10, 15, 10, 0),
    updatedAt: DateTime(2026, 10, 18, 11, 0),
    studentName: 'John Doe',
    departmentName: 'Electrical',
    category: 'Electrical Issues',
  );
}

void main() {
  group('Student AppBar Notification Bell & Unread Badge Tests', () {
    testWidgets('renders notification bell with unread badge and navigates on tap', (tester) async {
      final fakeService = FakeNotificationService(
        initialUnreadCount: 3,
        initialNotifications: [
          AppNotification(
            notificationId: 1,
            userId: 10,
            title: 'Complaint Resolved',
            message: 'Your complaint #42 was resolved.',
            notificationType: 'COMPLAINT',
            referenceId: 42,
            isRead: false,
            createdAt: DateTime.now(),
          ),
        ],
      );
      final notifProvider = NotificationProvider(notificationService: fakeService);
      await notifProvider.load();

      String? navigatedRoute;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              appBar: StudentAppBar(title: 'CampusHive'),
              body: Text('Student Dashboard'),
            ),
          ),
          GoRoute(
            path: AppRoutes.studentNotifications,
            builder: (context, state) {
              navigatedRoute = state.uri.toString();
              return const Scaffold(body: Text('Student Notifications Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: notifProvider,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Verify bell icon is present
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      // Verify badge text shows '3'
      expect(find.text('3'), findsOneWidget);

      // Tap the bell icon
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();

      expect(navigatedRoute, AppRoutes.studentNotifications);
      expect(find.text('Student Notifications Screen'), findsOneWidget);
    });
  });

  group('StudentNotificationsScreen State & Interaction Tests', () {
    testWidgets('displays empty state when there are no notifications', (tester) async {
      final fakeService = FakeNotificationService(
        initialNotifications: [],
        initialUnreadCount: 0,
      );
      final provider = NotificationProvider(notificationService: fakeService);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: StudentNotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No notifications'), findsOneWidget);
    });

    testWidgets('displays error state and retries on press', (tester) async {
      final fakeService = FakeNotificationService(
        shouldThrow: true,
      );
      final provider = NotificationProvider(notificationService: fakeService);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: StudentNotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load notifications'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Fix service and tap retry
      fakeService.shouldThrow = false;
      fakeService.initialNotifications = [
        AppNotification(
          notificationId: 10,
          userId: 10,
          title: 'Supervisor Assigned',
          message: 'Supervisor Mike was assigned to #42',
          notificationType: 'COMPLAINT',
          referenceId: 42,
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ];

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Supervisor Assigned'), findsOneWidget);
      expect(find.text('Supervisor Mike was assigned to #42'), findsOneWidget);
    });

    testWidgets('marks notification as read on tap and navigates to complaint', (tester) async {
      final fakeService = FakeNotificationService(
        initialUnreadCount: 1,
        initialNotifications: [
          AppNotification(
            notificationId: 15,
            userId: 10,
            title: 'Complaint In Progress',
            message: 'Investigation started for #42',
            notificationType: 'COMPLAINT',
            referenceId: 42,
            isRead: false,
            createdAt: DateTime.now(),
          ),
        ],
      );
      final provider = NotificationProvider(notificationService: fakeService);

      String? navigatedRoute;
      final router = GoRouter(
        initialLocation: '/student/notifications',
        routes: [
          GoRoute(
            path: '/student/notifications',
            builder: (context, state) => const StudentNotificationsScreen(),
          ),
          GoRoute(
            path: '/student/complaints/:complaintId',
            builder: (context, state) {
              navigatedRoute = state.uri.toString();
              return const Scaffold(body: Text('Complaint Detail'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complaint In Progress'), findsOneWidget);

      // Tap the notification
      await tester.tap(find.text('Complaint In Progress'));
      await tester.pumpAndSettle();

      expect(fakeService.markAsReadCallCount, 1);
      expect(navigatedRoute, AppRoutes.studentComplaintDetail(42));
      expect(find.text('Complaint Detail'), findsOneWidget);
    });

    testWidgets('mark all as read button calls provider', (tester) async {
      final fakeService = FakeNotificationService(
        initialUnreadCount: 2,
        initialNotifications: [
          AppNotification(
            notificationId: 21,
            userId: 10,
            title: 'Notice 1',
            message: 'Msg 1',
            notificationType: 'SYSTEM',
            referenceId: null,
            isRead: false,
            createdAt: DateTime.now(),
          ),
          AppNotification(
            notificationId: 22,
            userId: 10,
            title: 'Notice 2',
            message: 'Msg 2',
            notificationType: 'SYSTEM',
            referenceId: null,
            isRead: false,
            createdAt: DateTime.now(),
          ),
        ],
      );
      final provider = NotificationProvider(notificationService: fakeService);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: StudentNotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find mark all read text button
      final markAllBtn = find.text('Mark all read');
      expect(markAllBtn, findsOneWidget);

      await tester.tap(markAllBtn);
      await tester.pumpAndSettle();

      expect(fakeService.markAllAsReadCallCount, 1);
    });
  });

  group('StatusHistoryTimeline Widget Tests', () {
    testWidgets('renders empty history placeholder when history is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusHistoryTimeline(history: []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Status History'), findsOneWidget);
      expect(find.text('No status updates recorded yet.'), findsOneWidget);
    });

    testWidgets('renders timeline entries with previous & new status, actor, timestamp, remarks', (tester) async {
      final history = [
        ComplaintStatusHistory(
          historyId: 1,
          complaintId: 42,
          oldStatus: null,
          newStatus: 'PENDING',
          remarks: 'Initial complaint logged into queue.',
          updatedAt: DateTime(2026, 10, 16, 10, 0),
          updatedBy: 10,
          updaterName: 'Student John',
        ),
        ComplaintStatusHistory(
          historyId: 2,
          complaintId: 42,
          oldStatus: 'PENDING',
          newStatus: 'ASSIGNED',
          remarks: 'Auto-assigned to Electrical Department supervisor.',
          updatedAt: DateTime(2026, 10, 16, 10, 5),
          updatedBy: null,
          updaterName: null,
        ),
        ComplaintStatusHistory(
          historyId: 3,
          complaintId: 42,
          oldStatus: 'ASSIGNED',
          newStatus: 'IN_PROGRESS',
          remarks: 'Technician dispatched to inspection location.',
          updatedAt: DateTime(2026, 10, 17, 14, 30),
          updatedBy: 5,
          updaterName: 'Supervisor Mike',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatusHistoryTimeline(history: history),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Status History'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Assigned'), findsWidgets);
      expect(find.text('In Progress'), findsWidgets);
      expect(find.text('by Student John'), findsOneWidget);
      expect(find.text('by Supervisor Mike'), findsOneWidget);
      expect(find.text('Initial complaint logged into queue.'), findsOneWidget);
      expect(find.text('Auto-assigned to Electrical Department supervisor.'), findsOneWidget);
      expect(find.text('Technician dispatched to inspection location.'), findsOneWidget);
    });

    testWidgets('renders cleanly without RenderFlex overflow on narrow 320px width', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final history = [
        ComplaintStatusHistory(
          historyId: 1,
          complaintId: 42,
          oldStatus: 'IN_PROGRESS',
          newStatus: 'RESOLVED',
          remarks: 'Replaced electrical capacitor and verified fan rotation speeds at max load.',
          updatedAt: DateTime(2026, 10, 18, 11, 0),
          updatedBy: 5,
          updaterName: 'Senior Master Supervisor Alexander Bartholomew Montgomery-Smith III',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: StatusHistoryTimeline(history: history),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Status History'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
    });
  });

  group('Complaint Detail Status History & Feedback Integration Tests', () {
    testWidgets('displays StatusHistoryTimeline and Satisfied/Reopen feedback buttons when RESOLVED', (tester) async {
      final complaint = _buildComplaint(id: 42, status: 'RESOLVED');
      final history = [
        ComplaintStatusHistory(
          historyId: 1,
          complaintId: 42,
          oldStatus: 'IN_PROGRESS',
          newStatus: 'RESOLVED',
          remarks: 'Issue fixed by electrician.',
          updatedAt: DateTime(2026, 10, 18, 11, 0),
          updatedBy: 5,
          updaterName: 'Supervisor Mike',
        ),
      ];

      final fakeComplaintService = FakeComplaintService(
        complaint: complaint,
        history: history,
      );

      final authService = FakeAuthService(
        const AuthSession(
          user: {'user_id': 10, 'full_name': 'John Doe'},
          role: 'STUDENT',
        ),
      );
      final authProvider = AuthProvider(authService: authService);
      await authProvider.restoreSession();

      final notifProvider = NotificationProvider(
        notificationService: FakeNotificationService(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: notifProvider),
          ],
          child: MaterialApp(
            home: ComplaintDetailScreen(
              complaintId: 42,
              service: fakeComplaintService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Status History Timeline is rendered
      expect(find.textContaining('Status History'), findsOneWidget);
      expect(find.text('Issue fixed by electrician.'), findsOneWidget);

      // Verify Resolution Card is rendered with Satisfied & Reopen buttons
      expect(find.text('Complaint Resolved'), findsOneWidget);
      expect(find.text('Are you satisfied with how this complaint was resolved?'), findsOneWidget);
      expect(find.text('Satisfied'), findsOneWidget);
      expect(find.text('Reopen'), findsOneWidget);
    });

    testWidgets('hides StatusHistoryTimeline and feedback buttons when viewing another student complaint', (tester) async {
      // Complaint owned by student 10
      final complaint = _buildComplaint(id: 42, status: 'RESOLVED');
      final history = [
        ComplaintStatusHistory(
          historyId: 1,
          complaintId: 42,
          oldStatus: 'IN_PROGRESS',
          newStatus: 'RESOLVED',
          remarks: 'Issue fixed by electrician.',
          updatedAt: DateTime(2026, 10, 18, 11, 0),
          updatedBy: 5,
          updaterName: 'Supervisor Mike',
        ),
      ];

      final fakeComplaintService = FakeComplaintService(
        complaint: complaint,
        history: history,
      );

      // Current logged-in student is student 99 (different student / non-owner)
      final authService = FakeAuthService(
        const AuthSession(
          user: {'user_id': 99, 'full_name': 'Other Student'},
          role: 'STUDENT',
        ),
      );
      final authProvider = AuthProvider(authService: authService);
      await authProvider.restoreSession();

      final notifProvider = NotificationProvider(
        notificationService: FakeNotificationService(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: notifProvider),
          ],
          child: MaterialApp(
            home: ComplaintDetailScreen(
              complaintId: 42,
              service: fakeComplaintService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify public complaint details are visible
      expect(find.text('Broken fan in Room 201'), findsOneWidget);
      expect(find.text('Ceiling fan making strange grinding noise.'), findsOneWidget);

      // Verify private Status History Timeline is NOT rendered
      expect(find.textContaining('Status History'), findsNothing);
      expect(find.text('Issue fixed by electrician.'), findsNothing);

      // Verify owner-only Resolution Feedback card is NOT rendered
      expect(find.text('Complaint Resolved'), findsNothing);
      expect(find.text('Satisfied'), findsNothing);
      expect(find.text('Reopen'), findsNothing);
    });
  });
}
