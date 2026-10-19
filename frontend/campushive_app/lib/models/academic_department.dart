class AcademicDepartment {
  const AcademicDepartment({
    required this.academicDepartmentId,
    required this.organizationId,
    required this.departmentName,
    required this.departmentCode,
  });

  final int academicDepartmentId;
  final int organizationId;
  final String departmentName;
  final String departmentCode;

  factory AcademicDepartment.fromJson(Map<String, dynamic> json) {
    return AcademicDepartment(
      academicDepartmentId: _int(json['academic_department_id']),
      organizationId: _int(json['organization_id']),
      departmentName: json['department_name']?.toString() ?? '',
      departmentCode: json['department_code']?.toString() ?? '',
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AcademicDepartment &&
          runtimeType == other.runtimeType &&
          academicDepartmentId == other.academicDepartmentId;

  @override
  int get hashCode => academicDepartmentId.hashCode;
}
