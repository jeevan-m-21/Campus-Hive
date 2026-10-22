class OtpSendResult {
  const OtpSendResult({
    required this.email,
    required this.expiresInSeconds,
    required this.resendCooldownSeconds,
  });

  final String email;
  final int expiresInSeconds;
  final int resendCooldownSeconds;

  factory OtpSendResult.fromJson(Map<String, dynamic> json) {
    return OtpSendResult(
      email: json['email']?.toString() ?? '',
      expiresInSeconds: (json['expires_in_seconds'] as num?)?.toInt() ?? 300,
      resendCooldownSeconds:
          (json['resend_cooldown_seconds'] as num?)?.toInt() ?? 60,
    );
  }
}

class OtpVerificationResult {
  const OtpVerificationResult({
    required this.email,
    required this.verificationToken,
    required this.expiresInSeconds,
  });

  final String email;
  final String verificationToken;
  final int expiresInSeconds;

  factory OtpVerificationResult.fromJson(Map<String, dynamic> json) {
    return OtpVerificationResult(
      email: json['email']?.toString() ?? '',
      verificationToken: json['verification_token']?.toString() ?? '',
      expiresInSeconds: (json['expires_in_seconds'] as num?)?.toInt() ?? 900,
    );
  }
}

class RegistrationData {
  const RegistrationData({
    required this.email,
    required this.password,
    required this.fullName,
    required this.identifier,
    required this.phone,
    required this.organizationId,
    required this.academicDepartmentId,
    this.initialCooldownSeconds = 60,
  });

  final String email;
  final String password;
  final String fullName;
  final String identifier;
  final String phone;
  final int organizationId;
  final int academicDepartmentId;
  final int initialCooldownSeconds;

  @override
  String toString() =>
      'RegistrationData(email: $email, orgId: $organizationId, deptId: $academicDepartmentId, usn: $identifier)';
}
