class Complaint {
  const Complaint({
    required this.complaintId,
    required this.organizationId,
    required this.studentId,
    required this.departmentId,
    required this.supervisorId,
    required this.title,
    required this.description,
    required this.location,
    required this.mlPriority,
    required this.finalPriority,
    required this.status,
    required this.supportCount,
    required this.deadline,
    required this.resolvedAt,
    required this.studentFeedback,
    required this.createdAt,
    required this.updatedAt,
    required this.studentName,
    required this.departmentName,
    this.imageUrl,
    this.isSupported = false,
  });

  final int complaintId;
  final int organizationId;
  final int studentId;
  final int departmentId;
  final int? supervisorId;
  final String title;
  final String description;
  final String? location;
  final String? imageUrl;
  final String? mlPriority;
  final String? finalPriority;
  final String status;
  final int supportCount;
  final bool isSupported;
  final DateTime? deadline;
  final DateTime? resolvedAt;
  final String? studentFeedback;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? studentName;
  final String? departmentName;

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      complaintId: _int(json['complaint_id']),
      organizationId: _int(json['organization_id']),
      studentId: _int(json['student_id']),
      departmentId: _int(json['department_id']),
      supervisorId: _nullableInt(json['supervisor_id']),
      title: _string(json['title']),
      description: _string(json['description']),
      location: _nullableString(json['location']),
      imageUrl: _nullableString(json['image_url']),
      mlPriority: _nullableString(json['ml_priority']),
      finalPriority: _nullableString(json['final_priority']),
      status: _string(json['status']),
      supportCount: _int(json['support_count']),
      isSupported: json['is_supported'] == true,
      deadline: _date(json['deadline']),
      resolvedAt: _date(json['resolved_at']),
      studentFeedback: _nullableString(json['student_feedback']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      studentName: _nullableString(json['student_name']),
      departmentName: _nullableString(json['department_name']),
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static int? _nullableInt(Object? value) =>
      value is num ? value.toInt() : null;

  static String _string(Object? value) => value?.toString() ?? '';

  static String? _nullableString(Object? value) {
    final text = value?.toString();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
