class Organization {
  const Organization({
    required this.organizationId,
    required this.organizationName,
    required this.organizationCode,
    this.emailDomain,
  });

  final int organizationId;
  final String organizationName;
  final String organizationCode;
  final String? emailDomain;

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      organizationId: _int(json['organization_id']),
      organizationName: json['organization_name']?.toString() ?? '',
      organizationCode: json['organization_code']?.toString() ?? '',
      emailDomain: _nullableString(json['email_domain']),
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Organization &&
          runtimeType == other.runtimeType &&
          organizationId == other.organizationId;

  @override
  int get hashCode => organizationId.hashCode;
}
