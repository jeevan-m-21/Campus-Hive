import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:campushive_app/app/routes.dart';
import 'package:campushive_app/features/auth/register_screen.dart';
import 'package:campushive_app/models/academic_department.dart';
import 'package:campushive_app/models/organization.dart';
import 'package:campushive_app/providers/auth_provider.dart';
import 'package:campushive_app/services/auth_service.dart';

class MockAuthProviderForRegister extends ChangeNotifier implements AuthProvider {
  MockAuthProviderForRegister({
    this.organizations = const [],
    this.departments = const [],
    this.sessionToReturn,
  });

  List<Organization> organizations;
  List<AcademicDepartment> departments;
  AuthSession? sessionToReturn;

  int getOrgsCallCount = 0;
  int getDeptsCallCount = 0;
  int registerCallCount = 0;

  @override
  bool get isLoading => false;

  @override
  Future<List<Organization>> getPublicOrganizations() async {
    getOrgsCallCount++;
    return organizations;
  }

  @override
  Future<List<AcademicDepartment>> getAcademicDepartments(int organizationId) async {
    getDeptsCallCount++;
    return departments;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String fullName,
    required String identifier,
    required String phone,
    required int organizationId,
    required int academicDepartmentId,
  }) async {
    registerCallCount++;
    return sessionToReturn ??
        const AuthSession(
          user: {'user_id': 1, 'role': 'STUDENT'},
          role: 'STUDENT',
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('RegisterScreen Widget Tests', () {
    Widget buildTestApp({
      required MockAuthProviderForRegister authProvider,
      void Function(String route)? onNavigated,
    }) {
      final router = GoRouter(
        initialLocation: AppRoutes.register,
        routes: [
          GoRoute(
            path: AppRoutes.register,
            builder: (context, state) => const RegisterScreen(),
          ),
          GoRoute(
            path: AppRoutes.studentDashboard,
            builder: (_, state) {
              onNavigated?.call(state.uri.toString());
              return const Scaffold(body: Text('Student Dashboard'));
            },
          ),
        ],
      );

      return ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );
    }

    testWidgets('loads organizations and renders form fields', (tester) async {
      final mockProvider = MockAuthProviderForRegister(
        organizations: [
          const Organization(
            organizationId: 1,
            organizationName: 'KS Institute of Technology',
            organizationCode: 'KSIT',
            emailDomain: 'ksit.edu.in',
          ),
        ],
      );

      await tester.pumpWidget(buildTestApp(authProvider: mockProvider));
      await tester.pumpAndSettle();

      expect(mockProvider.getOrgsCallCount, 1);
      expect(find.text('Create your student account'), findsOneWidget);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('USN / Student ID'), findsOneWidget);
      expect(find.text('Organization'), findsOneWidget);
      expect(find.text('Academic department'), findsOneWidget);
      expect(find.text('Create student account'), findsOneWidget);
    });

    testWidgets('shows validation errors when submitting empty form', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetPhysicalSize);

      final mockProvider = MockAuthProviderForRegister();

      await tester.pumpWidget(buildTestApp(authProvider: mockProvider));
      await tester.pumpAndSettle();

      final submitFinder = find.text('Create student account');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(find.text('Full name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Phone is required'), findsOneWidget);
      expect(find.text('USN or Student ID is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });
  });
}
