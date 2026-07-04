/// API Service for making HTTP requests to backend

import 'package:dio/dio.dart';
import 'package:campus_hive/core/constants/app_constants.dart';
import 'package:campus_hive/core/errors/exceptions.dart';

class ApiService {
  late Dio _dio;
  String? _accessToken;

  ApiService() {
    _initializeDio();
  }

  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.fullApiUrl,
        connectTimeout: Duration(seconds: ApiConstants.connectionTimeout),
        receiveTimeout: Duration(seconds: ApiConstants.requestTimeout),
        contentType: 'application/json',
      ),
    );

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add authorization header
          if (_accessToken != null) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          return handler.next(error);
        },
      ),
    );
  }

  /// Set access token for future requests
  void setAccessToken(String token) {
    _accessToken = token;
  }

  /// Clear access token
  void clearAccessToken() {
    _accessToken = null;
  }

  /// GET request
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST request
  Future<dynamic> post(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PATCH request
  Future<dynamic> patch(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.patch(
        endpoint,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE request
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.delete(
        endpoint,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload file
  Future<dynamic> uploadFile(
    String endpoint, {
    required String filePath,
    Map<String, String>? additionalFields,
  }) async {
    try {
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        if (additionalFields != null) ...additionalFields,
      });

      final response = await _dio.post(endpoint, data: formData);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle successful response
  dynamic _handleResponse(Response response) {
    if (response.statusCode == null) {
      throw ServerException(message: 'No response from server', statusCode: 0);
    }

    if (response.statusCode! >= 200 && response.statusCode! < 300) {
      return response.data;
    }

    throw ServerException(
      message: response.data?['message'] ?? 'Server error',
      statusCode: response.statusCode ?? 0,
    );
  }

  /// Handle error response
  AppException _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return TimeoutException(message: 'Connection timeout');
      case DioExceptionType.receiveTimeout:
        return TimeoutException(message: 'Request timeout');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        final message = error.response?.data?['message'] ?? 'Unknown error';

        if (statusCode >= 500) {
          return ServerException(message: message, statusCode: statusCode);
        } else if (statusCode >= 400) {
          if (statusCode == 401) {
            return AuthException(message: 'Unauthorized');
          }
          return ClientException(message: message, statusCode: statusCode);
        }
        break;
      case DioExceptionType.unknown:
        return NetworkException(
          message: error.error?.toString() ?? 'Unknown error',
        );
      default:
        return NetworkException(message: 'Network error');
    }

    return UnknownException(message: 'An unknown error occurred');
  }
}
