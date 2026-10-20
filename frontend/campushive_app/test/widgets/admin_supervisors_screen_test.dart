import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:campushive_app/features/org_admin/users/admin_supervisors_screen.dart';
import 'package:campushive_app/models/department.dart';
import 'package:campushive_app/models/supervisor.dart';
import 'package:campushive_app/providers/admin_complaint_provider.dart';
import 'package:campushive_app/providers/notification_provider.dart';
import 'package:campushive_app/services/complaint_service.dart';

class MockNotificationProvider extends ChangeNotifier
    implements NotificationProvider {
  @override
  int get unreadCount => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAdminComplaintProvider extends ChangeNotifier
    implements AdminComplaintProvider {
  MockAdminComplaintProvider({
    List<Supervisor>? supervisors,
    List<Department>? departments,
  })  : _supervisors = supervisors ?? [],
        _departments = departments ?? [];

  List<Supervisor> _supervisors;
  final List<Department> _departments;
  bool _isLoadingSupervisors = false;
  String? _supervisorsErrorMessage;

  int createSupervisorCallCount = 0;
  String? lastCreatedName;
  String? lastCreatedEmail;
  String? lastCreatedPassword;
  String? lastCreatedEmployeeId;
  int? lastCreatedDepartmentId;
  String? lastCreatedPhone;
  bool shouldThrowOnCreate = false;
  String errorMessageToThrow = 'Creation failed';

  @override
  List<Supervisor> get supervisors => _supervisors;

  @override
  List<Department> get departments => _departments;

  @override
  bool get isLoadingSupervisors => _isLoadingSupervisors;

  @override
  String? get supervisorsErrorMessage => _supervisorsErrorMessage;

  @override
  Future<List<Supervisor>> loadSupervisors({
    bool force = false,
    int? departmentId,
  }) async {
    return _supervisors;
  }

  @override
  Future<void> loadDepartments() async {}

  @override
  Future<Supervisor> createSupervisor({
    required String fullName,
    required String email,
    required String password,
    required String employeeId,
    required int departmentId,
    String? phone,
  }) async {
    createSupervisorCallCount++;
    lastCreatedName = fullName;
    lastCreatedEmail = email;
    lastCreatedPassword = password;
    lastCreatedEmployeeId = employeeId;
    lastCreatedDepartmentId = departmentId;
    lastCreatedPhone = phone;

    if (shouldThrowOnCreate) {
      throw ComplaintException(errorMessageToThrow);
    }

    final created = Supervisor(
      userId: 99,
      fullName: fullName,
      email: email,
      departmentId: departmentId,
      departmentName: 'Electrical',
      phone: phone,
      employeeId: employeeId,
      isActive: true,
    );
    _supervisors = [..._supervisors, created];
    notifyListeners();
    return created;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget buildTestWidget({
    required MockAdminComplaintProvider complaintProvider,
    MockNotificationProvider? notificationProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AdminComplaintProvider>.value(
          value: complaintProvider,
        ),
        ChangeNotifierProvider<NotificationProvider>.value(
          value: notificationProvider ?? MockNotificationProvider(),
        ),
      ],
      child: const MaterialApp(
        home: AdminSupervisorsScreen(),
      ),
    );
  }

  group('AdminSupervisorsScreen Widget Tests', () {
    testWidgets('renders empty state when no supervisors exist', (tester) async {
      final provider = MockAdminComplaintProvider(supervisors: []);

      await tester.pumpWidget(buildTestWidget(complaintProvider: provider));
      await tester.pumpAndSettle();

      expect(find.text('Supervisor Management'), findsOneWidget);
      expect(find.text('No Supervisors Yet'), findsOneWidget);
      expect(find.byKey(const Key('add_supervisor_fab')), findsOneWidget);
    });

    testWidgets('renders list of supervisor cards with badges', (tester) async {
      final provider = MockAdminComplaintProvider(
        supervisors: [
          const Supervisor(
            userId: 1,
            fullName: 'Alice Electrician',
            email: 'alice@ksit.edu.in',
            departmentId: 1,
            departmentName: 'Electrical Maintenance',
            phone: '9876543210',
            employeeId: 'EMP_ELEC_01',
            isActive: true,
          ),
          const Supervisor(
            userId: 2,
            fullName: 'Bob Cleaner',
            email: 'bob@ksit.edu.in',
            departmentId: 2,
            departmentName: 'Housekeeping',
            employeeId: 'EMP_HK_01',
            isActive: false,
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(complaintProvider: provider));
      await tester.pumpAndSettle();

      expect(find.text('Alice Electrician'), findsOneWidget);
      expect(find.text('alice@ksit.edu.in'), findsOneWidget);
      expect(find.text('Electrical Maintenance'), findsOneWidget);
      expect(find.text('EMP_ELEC_01'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      expect(find.text('Bob Cleaner'), findsOneWidget);
      expect(find.text('Housekeeping'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
    });

    testWidgets('FAB opens Add Supervisor dialog and validates required fields',
        (tester) async {
      final provider = MockAdminComplaintProvider(
        departments: [
          const Department(
            departmentId: 1,
            departmentName: 'Electrical Maintenance',
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(complaintProvider: provider));
      await tester.pumpAndSettle();

      // Tap FAB
      await tester.tap(find.byKey(const Key('add_supervisor_fab')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Add Supervisor'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('submit_supervisor_button')), findsOneWidget);

      // Tap submit with empty fields
      await tester.ensureVisible(find.byKey(const Key('submit_supervisor_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submit_supervisor_button')));
      await tester.pumpAndSettle();

      expect(find.text('Full name is required'), findsOneWidget);
      expect(find.text('Employee ID is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(provider.createSupervisorCallCount, 0);
    });

    testWidgets('successfully creates supervisor and closes dialog',
        (tester) async {
      final provider = MockAdminComplaintProvider(
        departments: [
          const Department(
            departmentId: 1,
            departmentName: 'Electrical Maintenance',
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(complaintProvider: provider));
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.byKey(const Key('add_supervisor_fab')));
      await tester.pumpAndSettle();

      // Enter form values
      await tester.enterText(
        find.byKey(const Key('supervisor_name_field')),
        'Charlie Sparks',
      );
      await tester.enterText(
        find.byKey(const Key('supervisor_employee_id_field')),
        'EMP_SPARKS_01',
      );
      await tester.enterText(
        find.byKey(const Key('supervisor_email_field')),
        'charlie@ksit.edu.in',
      );
      await tester.enterText(
        find.byKey(const Key('supervisor_password_field')),
        'SecurePass123!',
      );

      // Select department from dropdown
      await tester.tap(find.byKey(const Key('supervisor_department_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Electrical Maintenance').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('supervisor_phone_field')),
        '9988776655',
      );

      // Submit
      await tester.ensureVisible(find.byKey(const Key('submit_supervisor_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submit_supervisor_button')));
      await tester.pumpAndSettle();

      // Verify provider call
      expect(provider.createSupervisorCallCount, 1);
      expect(provider.lastCreatedName, 'Charlie Sparks');
      expect(provider.lastCreatedEmployeeId, 'EMP_SPARKS_01');
      expect(provider.lastCreatedEmail, 'charlie@ksit.edu.in');
      expect(provider.lastCreatedPassword, 'SecurePass123!');
      expect(provider.lastCreatedDepartmentId, 1);
      expect(provider.lastCreatedPhone, '9988776655');

      // Verify success snackbar and dialog closed
      expect(find.text('Supervisor account created successfully!'), findsOneWidget);
      expect(find.text('Charlie Sparks'), findsOneWidget);
    });

    testWidgets('shows error feedback inside dialog when creation fails',
        (tester) async {
      final provider = MockAdminComplaintProvider(
        departments: [
          const Department(
            departmentId: 1,
            departmentName: 'Electrical Maintenance',
          ),
        ],
      );
      provider.shouldThrowOnCreate = true;
      provider.errorMessageToThrow = 'A user with this email already exists.';

      await tester.pumpWidget(buildTestWidget(complaintProvider: provider));
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.byKey(const Key('add_supervisor_fab')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('supervisor_name_field')),
        'Duplicate Person',
      );
      await tester.enterText(
        find.byKey(const Key('supervisor_employee_id_field')),
        'EMP_DUP_01',
      );
      await tester.enterText(
        find.byKey(const Key('supervisor_email_field')),
        'existing@ksit.edu.in',
      );
      await tester.enterText(
        find.byKey(const Key('supervisor_password_field')),
        'Password123!',
      );

      await tester.tap(find.byKey(const Key('supervisor_department_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Electrical Maintenance').last);
      await tester.pumpAndSettle();

      // Submit
      await tester.ensureVisible(find.byKey(const Key('submit_supervisor_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submit_supervisor_button')));
      await tester.pumpAndSettle();

      // Error banner visible in dialog
      expect(find.text('A user with this email already exists.'), findsOneWidget);
      // Dialog remains open
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Add Supervisor'),
        ),
        findsOneWidget,
      );
    });
  });
}
