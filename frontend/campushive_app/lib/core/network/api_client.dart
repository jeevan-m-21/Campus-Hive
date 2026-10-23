import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Builds a fully-qualified [Uri] from [path] and optional [queryParameters].
  ///
  /// Guarantees:
  /// - Strips any trailing slashes from the configured [AppConstants.apiBaseUrl].
  /// - Ensures the `/api/v1` segment is present without creating duplicates.
  /// - Ensures a leading slash before the endpoint path.
  static Uri buildUri(String path, [Map<String, String>? queryParameters]) {
    final rawBase = AppConstants.apiBaseUrl.trim();
    var sanitizedBase = rawBase.isEmpty
        ? 'https://13.207.228.106/api/v1'
        : rawBase;

    // Remove any trailing slashes from the base URL
    while (sanitizedBase.endsWith('/')) {
      sanitizedBase = sanitizedBase.substring(0, sanitizedBase.length - 1);
    }

    // Ensure the base URL includes /api/v1 if not already present
    if (!sanitizedBase.endsWith('/api/v1')) {
      sanitizedBase = '$sanitizedBase/api/v1';
    }

    // Process the path: prevent duplicate /api/v1 segments
    var sanitizedPath = path.trim();
    if (sanitizedPath.startsWith('/api/v1/')) {
      sanitizedPath = sanitizedPath.substring('/api/v1'.length);
    } else if (sanitizedPath == '/api/v1') {
      sanitizedPath = '';
    }

    // Ensure path has exactly one leading slash if non-empty
    if (sanitizedPath.isNotEmpty && !sanitizedPath.startsWith('/')) {
      sanitizedPath = '/$sanitizedPath';
    }

    final parsedUri = Uri.parse('$sanitizedBase$sanitizedPath');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return parsedUri.replace(queryParameters: queryParameters);
    }
    return parsedUri;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    String? idToken,
    Map<String, String>? queryParameters,
  }) async {
    final uri = buildUri(path, queryParameters);
    final headers = <String, String>{};
    if (idToken != null && idToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $idToken';
    }
    final response = await _client.get(
      uri,
      headers: headers,
    );

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    String? idToken,
    required Map<String, dynamic> body,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (idToken != null && idToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $idToken';
    }
    final response = await _client.post(
      buildUri(path),
      headers: headers,
      body: jsonEncode(body),
    );

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    required String idToken,
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.patch(
      buildUri(path),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    required String idToken,
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.delete(
      buildUri(path),
      headers: {
        'Authorization': 'Bearer $idToken',
        if (body != null) 'Content-Type': 'application/json',
      },
      body: body != null ? jsonEncode(body) : null,
    );

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String idToken,
    required String filePath,
    String fileField = 'image',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      buildUri(path),
    );
    request.headers['Authorization'] = 'Bearer $idToken';
    request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> responseBody = <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) responseBody = decoded;
    } on FormatException {
      responseBody = <String, dynamic>{};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        code: responseBody['error'] as String? ?? 'request_failed',
        message: responseBody['message'] as String? ?? 'Request failed.',
      );
    }

    return responseBody;
  }
}
