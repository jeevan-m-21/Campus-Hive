import 'package:firebase_auth/firebase_auth.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../models/notification.dart';

class NotificationService {
  NotificationService({ApiClient? apiClient, FirebaseAuth? firebaseAuth})
    : _apiClient = apiClient ?? ApiClient(),
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final ApiClient _apiClient;
  final FirebaseAuth _firebaseAuth;

  Future<NotificationPage> fetchNotificationPage({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
    String? type,
  }) async {
    final response = await _authenticatedGet(
      ApiEndpoints.notifications,
      queryParameters: {
        'page': '$page',
        'per_page': '$perPage',
        if (unreadOnly) 'unread_only': 'true',
        if (type != null && type.isNotEmpty) 'type': type,
      },
    );

    final data = response['data'];
    if (data is! Map<String, dynamic> || data['data'] is! List) {
      return NotificationPage(
        notifications: const [],
        page: page,
        pages: 1,
        total: 0,
        hasNext: false,
        hasPrevious: false,
      );
    }

    final pagination = data['pagination'];
    final paginationMap = pagination is Map<String, dynamic>
        ? pagination
        : <String, dynamic>{};

    return NotificationPage(
      notifications: (data['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList(),
      page: _int(paginationMap['page'], page),
      pages: _int(paginationMap['pages'], 1),
      total: _int(paginationMap['total'], 0),
      hasNext: paginationMap['has_next'] == true,
      hasPrevious: paginationMap['has_prev'] == true,
    );
  }

  Future<List<AppNotification>> fetchNotifications({
    int page = 1,
    int perPage = 30,
    bool unreadOnly = false,
    String? type,
  }) async {
    final result = await fetchNotificationPage(
      page: page,
      perPage: perPage,
      unreadOnly: unreadOnly,
      type: type,
    );
    return result.notifications;
  }

  Future<int> fetchUnreadCount() async {
    final response = await _authenticatedGet(
      ApiEndpoints.notificationsUnreadCount,
    );
    final data = response['data'];
    if (data is Map<String, dynamic> && data['count'] is num) {
      return (data['count'] as num).toInt();
    }
    return 0;
  }

  Future<AppNotification> markAsRead(int notificationId) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const NotificationException('Please sign in again.');
    }
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const NotificationException('Please sign in again.');
    }

    try {
      final response = await _apiClient.patch(
        ApiEndpoints.markNotificationRead(notificationId),
        idToken: idToken,
        body: const {},
      );
      final data = response['data'];
      if (data is! Map<String, dynamic>) {
        throw const NotificationException('Invalid response from server.');
      }
      return AppNotification.fromJson(data);
    } on ApiException catch (e) {
      throw NotificationException(e.message);
    }
  }

  Future<int> markAllAsRead() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const NotificationException('Please sign in again.');
    }
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const NotificationException('Please sign in again.');
    }

    try {
      final response = await _apiClient.patch(
        ApiEndpoints.notificationsReadAll,
        idToken: idToken,
        body: const {},
      );
      final data = response['data'];
      if (data is Map<String, dynamic> && data['updated_count'] is num) {
        return (data['updated_count'] as num).toInt();
      }
      return 0;
    } on ApiException catch (e) {
      throw NotificationException(e.message);
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const NotificationException('Please sign in again.');
    }
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const NotificationException('Please sign in again.');
    }

    try {
      await _apiClient.delete(
        ApiEndpoints.deleteNotification(notificationId),
        idToken: idToken,
      );
    } on ApiException catch (e) {
      throw NotificationException(e.message);
    }
  }

  Future<Map<String, dynamic>> _authenticatedGet(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const NotificationException('Please sign in again.');
    }
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const NotificationException('Please sign in again.');
    }
    try {
      return await _apiClient.get(
        path,
        idToken: idToken,
        queryParameters: queryParameters,
      );
    } on ApiException catch (error) {
      throw NotificationException(error.message);
    }
  }

  static int _int(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;
}

class NotificationPage {
  const NotificationPage({
    required this.notifications,
    required this.page,
    required this.pages,
    required this.total,
    required this.hasNext,
    required this.hasPrevious,
  });

  final List<AppNotification> notifications;
  final int page;
  final int pages;
  final int total;
  final bool hasNext;
  final bool hasPrevious;
}

class NotificationException implements Exception {
  const NotificationException(this.message);
  final String message;
}
