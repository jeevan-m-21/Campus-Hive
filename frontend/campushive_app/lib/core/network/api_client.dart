import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> get(
    String path, {
    required String idToken,
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.apiBaseUrl}$path',
    ).replace(queryParameters: queryParameters);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    );

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    required String idToken,
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConstants.apiBaseUrl}$path'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
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
      Uri.parse('${AppConstants.apiBaseUrl}$path'),
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
      Uri.parse('${AppConstants.apiBaseUrl}$path'),
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
      Uri.parse('${AppConstants.apiBaseUrl}$path'),
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
