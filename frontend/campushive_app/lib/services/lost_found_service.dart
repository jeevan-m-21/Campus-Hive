import 'package:firebase_auth/firebase_auth.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../models/lost_found.dart';

class LostFoundService {
  LostFoundService({ApiClient? apiClient, FirebaseAuth? firebaseAuth})
    : _apiClient = apiClient ?? ApiClient(),
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final ApiClient _apiClient;
  final FirebaseAuth _firebaseAuth;

  Future<LostFoundPage> fetchItems({
    required int page,
    required int perPage,
    String? status,
    String? itemType,
    String? search,
    bool? mine,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const LostFoundException('Please sign in again.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const LostFoundException('Please sign in again.');
    }
    try {
      final response = await _apiClient.get(
        ApiEndpoints.lostFound,
        idToken: token,
        queryParameters: {
          'page': '$page',
          'per_page': '$perPage',
          if (status != null && status.isNotEmpty) 'status': status,
          if (itemType != null && itemType.isNotEmpty) 'item_type': itemType,
          if (search != null && search.isNotEmpty) 'search': search,
          if (mine == true) 'mine': 'true',
        },
      );
      final data = response['data'];
      if (data is! Map<String, dynamic> || data['data'] is! List) {
        throw const LostFoundException('The server returned invalid items.');
      }
      final pagination = data['pagination'];
      if (pagination is! Map<String, dynamic>) {
        throw const LostFoundException(
          'The server returned invalid pagination.',
        );
      }
      return LostFoundPage(
        items: (data['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map(LostFound.fromJson)
            .toList(),
        page: _int(pagination['page'], page),
        pages: _int(pagination['pages'], 1),
        total: _int(pagination['total'], 0),
        hasNext: pagination['has_next'] == true,
        hasPrevious: pagination['has_prev'] == true,
      );
    } on ApiException catch (error) {
      throw LostFoundException(error.message);
    }
  }

  Future<String> uploadImage(String filePath) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const LostFoundException('Please sign in again.');
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const LostFoundException('Please sign in again.');
    }
    try {
      final response = await _apiClient.postMultipart(
        ApiEndpoints.uploadComplaintImage,
        idToken: idToken,
        filePath: filePath,
      );
      final data = response['data'];
      final imageUrl = data is Map<String, dynamic> ? data['image_url'] : null;
      if (imageUrl is! String) {
        throw const LostFoundException(
          'Failed to retrieve uploaded image URL.',
        );
      }
      return imageUrl;
    } on ApiException catch (error) {
      throw LostFoundException(error.message);
    }
  }

  Future<LostFound> createItem({
    required String itemType,
    required String title,
    required String description,
    String? category,
    String? location,
    String? dateOfIncident,
    String? imageUrl,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const LostFoundException('Please sign in again.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const LostFoundException('Please sign in again.');
    }

    try {
      final response = await _apiClient.post(
        ApiEndpoints.lostFound,
        idToken: token,
        body: {
          'item_type': itemType,
          'title': title,
          'description': description,
          if (category != null && category.isNotEmpty) 'category': category,
          if (location != null && location.isNotEmpty) 'location': location,
          if (dateOfIncident != null && dateOfIncident.isNotEmpty)
            'date_of_incident': dateOfIncident,
          if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        },
      );
      final data = response['data'];
      if (data is! Map<String, dynamic>) {
        throw const LostFoundException('Failed to parse created item.');
      }
      return LostFound.fromJson(data);
    } on ApiException catch (error) {
      throw LostFoundException(error.message);
    }
  }

  static int _int(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;
}

class LostFoundPage {
  const LostFoundPage({
    required this.items,
    required this.page,
    required this.pages,
    required this.total,
    required this.hasNext,
    required this.hasPrevious,
  });
  final List<LostFound> items;
  final int page;
  final int pages;
  final int total;
  final bool hasNext;
  final bool hasPrevious;
}

class LostFoundException implements Exception {
  const LostFoundException(this.message);
  final String message;
}
