import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campushive_app/core/network/api_client.dart';
import 'package:campushive_app/core/network/api_endpoints.dart';
import 'package:campushive_app/services/complaint_service.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient({
    this.getResponse,
    this.postResponse,
    this.patchResponse,
  });

  Map<String, dynamic>? getResponse;
  Map<String, dynamic>? postResponse;
  Map<String, dynamic>? patchResponse;

  String? lastGetPath;
  Map<String, String>? lastGetQueryParams;
  String? lastPostPath;
  Map<String, dynamic>? lastPostBody;
  String? lastPatchPath;
  Map<String, dynamic>? lastPatchBody;

  @override
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    String? idToken,
  }) async {
    lastGetPath = endpoint;
    lastGetQueryParams = queryParameters;
    return getResponse ?? {};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    required String idToken,
    required Map<String, dynamic> body,
  }) async {
    lastPostPath = path;
    lastPostBody = body;
    return postResponse ?? {};
  }

  @override
  Future<Map<String, dynamic>> patch(
    String path, {
    required String idToken,
    required Map<String, dynamic> body,
  }) async {
    lastPatchPath = path;
    lastPatchBody = body;
    return patchResponse ?? {};
  }
}

class FakeUser implements User {
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
  User? currentUser;

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

  group('ComplaintService Supervisor & Assignment Integration', () {
    test('fetchSupervisors calls endpoint and maps supervisors', () async {
      fakeApi.getResponse = {
        'status': 'success',
        'data': [
          {
            'user_id': 10,
            'full_name': 'Alice Supervisor',
            'email': 'alice@college.edu',
            'department_id': 1,
            'department_name': 'Housekeeping',
            'phone': '1234567890',
            'is_active': true,
          },
          {
            'user_id': 11,
            'full_name': 'Bob Supervisor',
            'email': 'bob@college.edu',
            'department_id': 2,
            'department_name': 'Electrical',
            'phone': null,
            'is_active': true,
          },
        ],
      };

      final supervisors = await service.fetchSupervisors(departmentId: 1);

      expect(fakeApi.lastGetPath, ApiEndpoints.complaintSupervisors);
      expect(fakeApi.lastGetQueryParams?['department_id'], '1');
      expect(supervisors.length, 2);
      expect(supervisors[0].fullName, 'Alice Supervisor');
      expect(supervisors[0].departmentName, 'Housekeeping');
      expect(supervisors[1].fullName, 'Bob Supervisor');
    });

    test('designateDepartmentSupervisor sends POST with supervisor_id', () async {
      fakeApi.postResponse = {
        'status': 'success',
        'data': {
          'message': 'Supervisor designated successfully.',
          'assigned_complaints_count': 3,
        },
      };

      final res = await service.designateDepartmentSupervisor(2, 11);

      expect(
        fakeApi.lastPostPath,
        ApiEndpoints.designateDepartmentSupervisor(2),
      );
      expect(fakeApi.lastPostBody?['supervisor_id'], 11);
      expect(res['assigned_complaints_count'], 3);
    });

    test('updateComplaint sends supervisor_id or null clearSupervisor', () async {
      fakeApi.patchResponse = {
        'status': 'success',
        'data': {
          'complaint_id': 42,
          'organization_id': 1,
          'student_id': 5,
          'department_id': 2,
          'supervisor_id': 11,
          'supervisor_name': 'Bob Supervisor',
          'title': 'Test title',
          'description': 'Test desc',
          'status': 'ASSIGNED',
          'support_count': 0,
        },
      };

      final updated = await service.updateComplaint(42, supervisorId: 11);

      expect(fakeApi.lastPatchPath, ApiEndpoints.updateComplaint(42));
      expect(fakeApi.lastPatchBody?['supervisor_id'], 11);
      expect(updated.supervisorId, 11);
      expect(updated.supervisorName, 'Bob Supervisor');

      // Test clear supervisor
      await service.updateComplaint(42, clearSupervisor: true);
      expect(fakeApi.lastPatchBody?['supervisor_id'], isNull);
    });
  });
}
