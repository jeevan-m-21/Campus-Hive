import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:firebase_auth/firebase_auth.dart' as fb show User;
import 'package:flutter_test/flutter_test.dart';

import 'package:campushive_app/core/network/api_client.dart';
import 'package:campushive_app/core/network/api_endpoints.dart';
import 'package:campushive_app/core/network/api_exception.dart';
import 'package:campushive_app/models/supervisor.dart';
import 'package:campushive_app/providers/admin_complaint_provider.dart';
import 'package:campushive_app/services/complaint_service.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient({
    this.getResponse,
    this.postResponse,
    this.throwApiException = false,
    this.apiExceptionMessage = 'API Error',
  });

  Map<String, dynamic>? getResponse;
  Map<String, dynamic>? postResponse;
  bool throwApiException;
  String apiExceptionMessage;

  String? lastGetPath;
  String? lastPostPath;
  Map<String, dynamic>? lastPostBody;

  @override
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    String? idToken,
  }) async {
    lastGetPath = endpoint;
    if (throwApiException) {
      throw ApiException(
        statusCode: 400,
        code: 'error',
        message: apiExceptionMessage,
      );
    }
    return getResponse ?? {'status': 'success', 'data': []};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    required String idToken,
    required Map<String, dynamic> body,
  }) async {
    lastPostPath = path;
    lastPostBody = body;
    if (throwApiException) {
      throw ApiException(
        statusCode: 400,
        code: 'error',
        message: apiExceptionMessage,
      );
    }
    return postResponse ?? {};
  }
}

class FakeUser implements fb.User {
  FakeUser({this.token = 'test-token'});
  final String token;

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async => token;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseAuth implements FirebaseAuth {
  FakeFirebaseAuth({this.currentUser});

  @override
  fb.User? currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeApiClient fakeApi;
  late FakeFirebaseAuth fakeAuth;
  late ComplaintService service;

  setUp(() {
    fakeApi = FakeApiClient();
    fakeAuth = FakeFirebaseAuth(currentUser: FakeUser());
    service = ComplaintService(apiClient: fakeApi, firebaseAuth: fakeAuth);
  });

  group('ComplaintService.createSupervisor', () {
    test('sends correct body to ApiEndpoints.complaintSupervisors and returns Supervisor', () async {
      fakeApi.postResponse = {
        'status': 'success',
        'message': 'Supervisor created successfully',
        'data': {
          'supervisor': {
            'user_id': 42,
            'full_name': 'Sarah Electrical',
            'email': 'sarah@ksit.edu.in',
            'department_id': 1,
            'department_name': 'Electrical Maintenance',
            'phone': '9876543210',
            'usn_or_employee_id': 'EMP_ELEC_42',
            'is_active': true,
          },
        },
      };

      final supervisor = await service.createSupervisor(
        fullName: 'Sarah Electrical',
        email: 'sarah@ksit.edu.in',
        password: 'Password123!',
        employeeId: 'EMP_ELEC_42',
        departmentId: 1,
        phone: '9876543210',
      );

      expect(fakeApi.lastPostPath, ApiEndpoints.complaintSupervisors);
      expect(fakeApi.lastPostBody, {
        'full_name': 'Sarah Electrical',
        'email': 'sarah@ksit.edu.in',
        'password': 'Password123!',
        'usn_or_employee_id': 'EMP_ELEC_42',
        'department_id': 1,
        'phone': '9876543210',
      });

      expect(supervisor.userId, 42);
      expect(supervisor.fullName, 'Sarah Electrical');
      expect(supervisor.email, 'sarah@ksit.edu.in');
      expect(supervisor.departmentId, 1);
      expect(supervisor.departmentName, 'Electrical Maintenance');
      expect(supervisor.employeeId, 'EMP_ELEC_42');
      expect(supervisor.phone, '9876543210');
      expect(supervisor.isActive, isTrue);
    });

    test('throws ComplaintException on API failure', () async {
      fakeApi.throwApiException = true;
      fakeApi.apiExceptionMessage = 'A user with this email already exists.';

      expect(
        () => service.createSupervisor(
          fullName: 'Test',
          email: 'duplicate@ksit.edu.in',
          password: 'Password123!',
          employeeId: 'EMP99',
          departmentId: 1,
        ),
        throwsA(isA<ComplaintException>().having(
          (e) => e.message,
          'message',
          'A user with this email already exists.',
        )),
      );
    });
  });

  group('AdminComplaintProvider.createSupervisor', () {
    test('creates supervisor and refreshes supervisors list', () async {
      fakeApi.postResponse = {
        'status': 'success',
        'data': {
          'supervisor': {
            'user_id': 50,
            'full_name': 'New Staff',
            'email': 'newstaff@ksit.edu.in',
            'department_id': 2,
            'department_name': 'Housekeeping',
            'usn_or_employee_id': 'EMP_HK_50',
            'is_active': true,
          },
        },
      };

      fakeApi.getResponse = {
        'status': 'success',
        'data': [
          {
            'user_id': 50,
            'full_name': 'New Staff',
            'email': 'newstaff@ksit.edu.in',
            'department_id': 2,
            'department_name': 'Housekeeping',
            'usn_or_employee_id': 'EMP_HK_50',
            'is_active': true,
          },
        ],
      };

      final provider = AdminComplaintProvider(complaintService: service);

      final result = await provider.createSupervisor(
        fullName: 'New Staff',
        email: 'newstaff@ksit.edu.in',
        password: 'Password123!',
        employeeId: 'EMP_HK_50',
        departmentId: 2,
      );

      expect(result.userId, 50);
      expect(provider.supervisors.length, 1);
      expect(provider.supervisors.first.fullName, 'New Staff');
      expect(provider.isLoadingSupervisors, isFalse);
      expect(provider.supervisorsErrorMessage, isNull);
    });

    test('sets error message and rethrows on failure', () async {
      fakeApi.throwApiException = true;
      fakeApi.apiExceptionMessage = 'Department not found in your organization.';

      final provider = AdminComplaintProvider(complaintService: service);

      expect(
        () => provider.createSupervisor(
          fullName: 'Staff',
          email: 'staff@ksit.edu.in',
          password: 'Password123!',
          employeeId: 'EMP01',
          departmentId: 99,
        ),
        throwsA(isA<ComplaintException>()),
      );

      // Await next microtask to verify error message
      await pumpEventQueue();
      expect(provider.supervisorsErrorMessage, 'Department not found in your organization.');
      expect(provider.isLoadingSupervisors, isFalse);
    });
  });
}
