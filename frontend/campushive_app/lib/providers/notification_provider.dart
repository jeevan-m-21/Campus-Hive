import 'package:flutter/foundation.dart';

import '../models/notification.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({NotificationService? notificationService})
    : _notificationService = notificationService ?? NotificationService();

  final NotificationService _notificationService;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => _notifications.isEmpty;

  Future<void> load({bool refresh = false}) async {
    if (!refresh && _notifications.isNotEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _notificationService.fetchNotifications(),
        _notificationService.fetchUnreadCount(),
      ]);
      _notifications = results[0] as List<AppNotification>;
      _unreadCount = results[1] as int;
    } on NotificationException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Unable to load notifications.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUnreadCount() async {
    try {
      _unreadCount = await _notificationService.fetchUnreadCount();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAsRead(int notificationId) async {
    final index = _notifications.indexWhere(
      (n) => n.notificationId == notificationId,
    );
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      if (_unreadCount > 0) _unreadCount--;
      notifyListeners();
    }

    try {
      await _notificationService.markAsRead(notificationId);
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    _notifications = [for (final n in _notifications) n.copyWith(isRead: true)];
    _unreadCount = 0;
    notifyListeners();

    try {
      await _notificationService.markAllAsRead();
    } catch (_) {}
  }

  Future<void> deleteNotification(int notificationId) async {
    final index = _notifications.indexWhere(
      (n) => n.notificationId == notificationId,
    );
    if (index != -1) {
      final wasUnread = !_notifications[index].isRead;
      _notifications.removeAt(index);
      if (wasUnread && _unreadCount > 0) _unreadCount--;
      notifyListeners();
    }

    try {
      await _notificationService.deleteNotification(notificationId);
    } catch (_) {}
  }
}
