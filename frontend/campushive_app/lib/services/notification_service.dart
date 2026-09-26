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

  Future<List<AppNotification>> fetchNotifications({
    int page = 1,
    int perPage = 30,
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
    final items = data is Map<String, dynamic> ? data['data'] : data;
    if (items is! List) {
      return [];
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
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
}

class NotificationException implements Exception {
  const NotificationException(this.message);
  final String message;
}
