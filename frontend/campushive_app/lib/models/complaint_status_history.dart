class ComplaintStatusHistory {
  const ComplaintStatusHistory({
    required this.historyId,
    required this.complaintId,
    required this.newStatus,
    this.updatedBy,
    this.oldStatus,
    this.remarks,
    this.updatedAt,
    this.updaterName,
  });

  final int historyId;
  final int complaintId;
  final String? oldStatus;
  final String newStatus;
  final String? remarks;
  final DateTime? updatedAt;
  final int? updatedBy;
  final String? updaterName;

  factory ComplaintStatusHistory.fromJson(Map<String, dynamic> json) {
    return ComplaintStatusHistory(
      historyId: _int(json['history_id']),
      complaintId: _int(json['complaint_id']),
      oldStatus: _nullableString(json['old_status']),
      newStatus: _string(json['new_status']),
      remarks: _nullableString(json['remarks']),
      updatedAt: _parseDateTime(json['updated_at']),
      updatedBy: _nullableInt(json['updated_by']),
      updaterName: _nullableString(json['updater_name']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'history_id': historyId,
      'complaint_id': complaintId,
      'old_status': oldStatus,
      'new_status': newStatus,
      'remarks': remarks,
      'updated_at': updatedAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updater_name': updaterName,
    };
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int? _nullableInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String _string(Object? value) {
    if (value is String) return value;
    return '';
  }

  static String? _nullableString(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
