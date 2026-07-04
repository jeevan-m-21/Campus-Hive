/// Custom exceptions for error handling

/// Base exception class
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;

  AppException({required this.message, this.code, this.originalException});

  @override
  String toString() => message;
}

/// Network-related exceptions
class NetworkException extends AppException {
  NetworkException({required String message, String? code})
    : super(message: message, code: code ?? 'NETWORK_ERROR');
}

/// Server exception (5xx errors)
class ServerException extends AppException {
  final int statusCode;

  ServerException({
    required String message,
    required this.statusCode,
    String? code,
  }) : super(message: message, code: code ?? 'SERVER_ERROR');
}

/// Client exception (4xx errors)
class ClientException extends AppException {
  final int statusCode;

  ClientException({
    required String message,
    required this.statusCode,
    String? code,
  }) : super(message: message, code: code ?? 'CLIENT_ERROR');
}

/// Authentication exception
class AuthException extends AppException {
  AuthException({required String message, String? code})
    : super(message: message, code: code ?? 'AUTH_ERROR');
}

/// Validation exception
class ValidationException extends AppException {
  ValidationException({required String message, String? code})
    : super(message: message, code: code ?? 'VALIDATION_ERROR');
}

/// Cache exception
class CacheException extends AppException {
  CacheException({required String message, String? code})
    : super(message: message, code: code ?? 'CACHE_ERROR');
}

/// Firebase exception
class FirebaseException extends AppException {
  FirebaseException({required String message, String? code})
    : super(message: message, code: code ?? 'FIREBASE_ERROR');
}

/// Timeout exception
class TimeoutException extends AppException {
  TimeoutException({required String message, String? code})
    : super(message: message, code: code ?? 'TIMEOUT_ERROR');
}

/// Unknown exception
class UnknownException extends AppException {
  UnknownException({required String message, String? code})
    : super(message: message, code: code ?? 'UNKNOWN_ERROR');
}
