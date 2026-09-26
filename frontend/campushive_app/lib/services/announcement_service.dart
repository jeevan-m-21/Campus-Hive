import 'package:firebase_auth/firebase_auth.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../models/announcement.dart';

class AnnouncementService {
  AnnouncementService({ApiClient? apiClient, FirebaseAuth? firebaseAuth})
    : _apiClient = apiClient ?? ApiClient(),
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final ApiClient _apiClient;
  final FirebaseAuth _firebaseAuth;

  Future<AnnouncementPage> fetchAnnouncements({
    required int page,
    required int perPage,
    bool? important,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AnnouncementException('Please sign in again.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const AnnouncementException('Please sign in again.');
    }
    try {
      final response = await _apiClient.get(
        ApiEndpoints.announcements,
        idToken: token,
        queryParameters: {
          'page': '$page',
          'per_page': '$perPage',
          if (important == true) 'important': 'true',
        },
      );
      final data = response['data'];
      if (data is! Map<String, dynamic> || data['data'] is! List) {
        throw const AnnouncementException(
          'The server returned invalid announcements.',
        );
      }
      final pagination = data['pagination'];
      if (pagination is! Map<String, dynamic>) {
        throw const AnnouncementException(
          'The server returned invalid pagination.',
        );
      }
      return AnnouncementPage(
        announcements: (data['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map(Announcement.fromJson)
            .toList(),
        page: _int(pagination['page'], page),
        pages: _int(pagination['pages'], 1),
        total: _int(pagination['total'], 0),
        hasNext: pagination['has_next'] == true,
        hasPrevious: pagination['has_prev'] == true,
      );
    } on ApiException catch (error) {
      throw AnnouncementException(error.message);
    }
  }

  Future<({bool isLiked, int likeCount})> toggleLike(int announcementId) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AnnouncementException('Please sign in again.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const AnnouncementException('Please sign in again.');
    }
    try {
      final response = await _apiClient.post(
        ApiEndpoints.likeAnnouncement(announcementId),
        idToken: token,
        body: const {},
      );
      final data = response['data'];
      if (data is! Map<String, dynamic>) {
        throw const AnnouncementException('Invalid response from server.');
      }
      return (
        isLiked: data['is_liked'] == true,
        likeCount: _int(data['like_count'], 0),
      );
    } on ApiException catch (error) {
      throw AnnouncementException(error.message);
    }
  }

  static int _int(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;
}

class AnnouncementPage {
  const AnnouncementPage({
    required this.announcements,
    required this.page,
    required this.pages,
    required this.total,
    required this.hasNext,
    required this.hasPrevious,
  });
  final List<Announcement> announcements;
  final int page;
  final int pages;
  final int total;
  final bool hasNext;
  final bool hasPrevious;
}

class AnnouncementException implements Exception {
  const AnnouncementException(this.message);
  final String message;
}
