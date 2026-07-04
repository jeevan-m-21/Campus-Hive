/// Authentication models

class LoginRequest {
  final String email;
  final String password;
  final String? deviceId;
  final String? fcmToken;

  LoginRequest({
    required this.email,
    required this.password,
    this.deviceId,
    this.fcmToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'device_id': deviceId,
      'fcm_token': fcmToken,
    };
  }
}

class LoginResponse {
  final AuthTokens tokens;
  final User user;

  LoginResponse({required this.tokens, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      tokens: AuthTokens.fromJson(json['tokens'] ?? {}),
      user: User.fromJson(json['user'] ?? {}),
    );
  }
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      tokenType: json['token_type'] ?? 'Bearer',
      expiresIn: json['expires_in'] ?? 86400,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
    };
  }
}

class RegisterRequest {
  final String email;
  final String password;
  final String firstName;
  final String? lastName;
  final String? phone;
  final String organizationId;
  final String role;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.firstName,
    this.lastName,
    this.phone,
    required this.organizationId,
    this.role = 'student',
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'organization_id': organizationId,
      'role': role,
    };
  }
}

// Import User class
class User {
  final String id;
  final String email;
  final String firstName;
  final String? lastName;
  final String phone;
  final String? profilePhotoUrl;
  final String role;
  final String organizationId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.email,
    required this.firstName,
    this.lastName,
    required this.phone,
    this.profilePhotoUrl,
    required this.role,
    required this.organizationId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'],
      phone: json['phone'] ?? '',
      profilePhotoUrl: json['profile_photo_url'],
      role: json['role'] ?? '',
      organizationId: json['organization_id'] ?? '',
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  String get fullName => '$firstName ${lastName ?? ''}'.trim();
}
