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
  bool _isLoadingPage = false;
  String? _errorMessage;
  bool _unreadOnly = false;
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  bool _hasNext = false;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get isLoadingPage => _isLoadingPage;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => _notifications.isEmpty;
  bool get unreadOnly => _unreadOnly;
  int get page => _page;
  int get pages => _pages;
  int get total => _total;
  bool get hasNext => _hasNext;

  Future<void> load({bool refresh = false}) async {
    if (!refresh && _notifications.isNotEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    _page = 1;
    notifyListeners();

    try {
      final results = await Future.wait([
        _notificationService.fetchNotificationPage(
          page: 1,
          perPage: 20,
          unreadOnly: _unreadOnly,
        ),
        _notificationService.fetchUnreadCount(),
      ]);
      final pageResult = results[0] as NotificationPage;
      _notifications = pageResult.notifications;
      _page = pageResult.page;
      _pages = pageResult.pages;
      _total = pageResult.total;
      _hasNext = pageResult.hasNext;
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

  Future<void> setUnreadOnly(bool value) async {
    if (_unreadOnly == value) return;
    _unreadOnly = value;
    await load(refresh: true);
  }

  Future<void> loadNextPage() async {
    if (_isLoadingPage || !_hasNext) return;
    _isLoadingPage = true;
    notifyListeners();

    try {
      final pageResult = await _notificationService.fetchNotificationPage(
        page: _page + 1,
        perPage: 20,
        unreadOnly: _unreadOnly,
      );
      _notifications = [..._notifications, ...pageResult.notifications];
      _page = pageResult.page;
      _pages = pageResult.pages;
      _total = pageResult.total;
      _hasNext = pageResult.hasNext;
    } on NotificationException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Unable to load more notifications.';
    } finally {
      _isLoadingPage = false;
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
    if (index == -1) return;
    if (_notifications[index].isRead) return;

    final original = _notifications[index];
    _notifications[index] = original.copyWith(isRead: true);
    if (_unreadCount > 0) _unreadCount--;
    notifyListeners();

    try {
      await _notificationService.markAsRead(notificationId);
      await loadUnreadCount();
    } catch (e) {
      // Revert optimistic update
      _notifications[index] = original;
      _unreadCount++;
      notifyListeners();
      rethrow;
    }
  }

  Future<int> markAllAsRead() async {
    final previousList = List<AppNotification>.from(_notifications);
    final previousUnread = _unreadCount;

    _notifications = [for (final n in _notifications) n.copyWith(isRead: true)];
    _unreadCount = 0;
    notifyListeners();

    try {
      final count = await _notificationService.markAllAsRead();
      await loadUnreadCount();
      return count;
    } catch (e) {
      _notifications = previousList;
      _unreadCount = previousUnread;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    final index = _notifications.indexWhere(
      (n) => n.notificationId == notificationId,
    );
    if (index == -1) return;

    final removed = _notifications[index];
    final wasUnread = !removed.isRead;
    _notifications.removeAt(index);
    if (wasUnread && _unreadCount > 0) _unreadCount--;
    if (_total > 0) _total--;
    notifyListeners();

    try {
      await _notificationService.deleteNotification(notificationId);
      await loadUnreadCount();
    } catch (e) {
      _notifications.insert(index, removed);
      if (wasUnread) _unreadCount++;
      _total++;
      notifyListeners();
      rethrow;
    }
  }
}
