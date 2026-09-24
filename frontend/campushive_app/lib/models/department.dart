class Department {
  const Department({
    required this.departmentId,
    required this.departmentName,
    this.description,
  });

  final int departmentId;
  final String departmentName;
  final String? description;

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      departmentId: _int(json['department_id']),
      departmentName: json['department_name']?.toString() ?? '',
      description: _nullableString(json['description']),
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
