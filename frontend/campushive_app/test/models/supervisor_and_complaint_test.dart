import 'package:flutter_test/flutter_test.dart';
import 'package:campushive_app/models/complaint.dart';
import 'package:campushive_app/models/supervisor.dart';

void main() {
  group('Supervisor Model Tests', () {
    test('parses json correctly with complete fields', () {
      final json = {
        'user_id': 15,
        'full_name': 'Elec Supervisor',
        'email': 'elec.sup@college.edu',
        'department_id': 2,
        'department_name': 'Electrical',
        'phone': '9876543210',
        'is_active': true,
      };

      final supervisor = Supervisor.fromJson(json);

      expect(supervisor.userId, 15);
      expect(supervisor.fullName, 'Elec Supervisor');
      expect(supervisor.email, 'elec.sup@college.edu');
      expect(supervisor.departmentId, 2);
      expect(supervisor.departmentName, 'Electrical');
      expect(supervisor.phone, '9876543210');
      expect(supervisor.isActive, isTrue);
    });

    test('parses json with null or missing optional fields safely', () {
      final json = {
        'user_id': 20,
        'full_name': 'General Supervisor',
        'email': 'gen@college.edu',
      };

      final supervisor = Supervisor.fromJson(json);

      expect(supervisor.userId, 20);
      expect(supervisor.fullName, 'General Supervisor');
      expect(supervisor.email, 'gen@college.edu');
      expect(supervisor.departmentId, isNull);
      expect(supervisor.departmentName, isNull);
      expect(supervisor.phone, isNull);
      expect(supervisor.isActive, isTrue);
    });
  });

  group('Complaint Model Supervisor & Category Fields', () {
    test('parses supervisor_name and category correctly from json', () {
      final json = {
        'complaint_id': 101,
        'organization_id': 1,
        'student_id': 5,
        'department_id': 2,
        'supervisor_id': 15,
        'supervisor_name': 'Elec Supervisor',
        'category': 'Electrical Issues',
        'title': 'Power outage in lab',
        'description': 'Main breaker tripped',
        'location': 'Lab 302',
        'ml_priority': 'HIGH',
        'final_priority': 'HIGH',
        'status': 'ASSIGNED',
        'support_count': 3,
        'is_supported': false,
        'student_name': 'Jane Student',
        'department_name': 'Electrical',
      };

      final complaint = Complaint.fromJson(json);

      expect(complaint.complaintId, 101);
      expect(complaint.supervisorId, 15);
      expect(complaint.supervisorName, 'Elec Supervisor');
      expect(complaint.category, 'Electrical Issues');
      expect(complaint.status, 'ASSIGNED');
    });

    test('handles null supervisor_name and category safely', () {
      final json = {
        'complaint_id': 102,
        'organization_id': 1,
        'student_id': 5,
        'department_id': 2,
        'title': 'Water leakage',
        'description': 'Pipe leaking in washroom',
        'status': 'PENDING',
        'support_count': 0,
      };

      final complaint = Complaint.fromJson(json);

      expect(complaint.complaintId, 102);
      expect(complaint.supervisorId, isNull);
      expect(complaint.supervisorName, isNull);
      expect(complaint.category, isNull);
      expect(complaint.status, 'PENDING');
    });
  });
}
