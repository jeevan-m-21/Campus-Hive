class Supervisor {
  const Supervisor({
    required this.userId,
    required this.fullName,
    required this.email,
    this.departmentId,
    this.departmentName,
    this.phone,
    this.employeeId,
    this.isActive = true,
  });

  final int userId;
  final String fullName;
  final String email;
  final int? departmentId;
  final String? departmentName;
  final String? phone;
  final String? employeeId;
  final bool isActive;

  factory Supervisor.fromJson(Map<String, dynamic> json) {
    return Supervisor(
      userId: _int(json['user_id']),
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      departmentId: _nullableInt(json['department_id']),
      departmentName: _nullableString(json['department_name']),
      phone: _nullableString(json['phone']),
      employeeId: _nullableString(
        json['usn_or_employee_id'] ?? json['employee_id'],
      ),
      isActive: json['is_active'] != false,
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static int? _nullableInt(Object? value) =>
      value is num ? value.toInt() : null;

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
