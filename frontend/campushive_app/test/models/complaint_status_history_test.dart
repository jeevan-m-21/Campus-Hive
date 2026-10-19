import 'package:flutter_test/flutter_test.dart';
import 'package:campushive_app/models/complaint_status_history.dart';

void main() {
  group('ComplaintStatusHistory Model Tests', () {
    test('parses full json correctly', () {
      final json = {
        'history_id': 10,
        'complaint_id': 101,
        'old_status': 'PENDING',
        'new_status': 'IN_PROGRESS',
        'remarks': 'Investigation in progress by maintenance crew.',
        'updated_at': '2026-10-18T14:30:00.000Z',
        'updated_by': 5,
        'updater_name': 'Chief Supervisor John',
      };

      final history = ComplaintStatusHistory.fromJson(json);

      expect(history.historyId, 10);
      expect(history.complaintId, 101);
      expect(history.oldStatus, 'PENDING');
      expect(history.newStatus, 'IN_PROGRESS');
      expect(history.remarks, 'Investigation in progress by maintenance crew.');
      expect(history.updatedAt, DateTime.parse('2026-10-18T14:30:00.000Z'));
      expect(history.updatedBy, 5);
      expect(history.updaterName, 'Chief Supervisor John');

      final serialized = history.toJson();
      expect(serialized['history_id'], 10);
      expect(serialized['complaint_id'], 101);
      expect(serialized['old_status'], 'PENDING');
      expect(serialized['new_status'], 'IN_PROGRESS');
      expect(serialized['remarks'], 'Investigation in progress by maintenance crew.');
      expect(serialized['updated_by'], 5);
      expect(serialized['updater_name'], 'Chief Supervisor John');
    });

    test('handles null and optional fields safely', () {
      final json = {
        'history_id': 11,
        'complaint_id': 102,
        'new_status': 'PENDING',
      };

      final history = ComplaintStatusHistory.fromJson(json);

      expect(history.historyId, 11);
      expect(history.complaintId, 102);
      expect(history.oldStatus, isNull);
      expect(history.newStatus, 'PENDING');
      expect(history.remarks, isNull);
      expect(history.updatedAt, isNull);
      expect(history.updatedBy, isNull);
      expect(history.updaterName, isNull);

      final serialized = history.toJson();
      expect(serialized['history_id'], 11);
      expect(serialized['complaint_id'], 102);
      expect(serialized['new_status'], 'PENDING');
      expect(serialized['old_status'], isNull);
      expect(serialized['remarks'], isNull);
    });
  });
}
