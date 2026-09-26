import 'package:flutter/foundation.dart';

import '../models/announcement.dart';
import '../services/announcement_service.dart';

class AnnouncementProvider extends ChangeNotifier {
  AnnouncementProvider({AnnouncementService? service})
    : _service = service ?? AnnouncementService();

  final AnnouncementService _service;
  List<Announcement> _items = const [];
  bool _loading = false, _loadingPage = false;
  String? _error;
  bool _importantOnly = false;
  int _page = 1, _pages = 1, _total = 0;
  bool _hasNext = false;

  List<Announcement> get items => _items;
  bool get isLoading => _loading;
  bool get isLoadingPage => _loadingPage;
  String? get errorMessage => _error;
  bool get importantOnly => _importantOnly;
  int get page => _page;
  int get pages => _pages;
  int get total => _total;
  bool get hasNext => _hasNext;

  Future<void> load({bool refresh = false}) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _page = 1;
    notifyListeners();
    try {
      _apply(await _fetch(1), replace: true);
    } on AnnouncementException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Unable to load announcements.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setImportantOnly(bool value) async {
    _importantOnly = value;
    await load(refresh: true);
  }

  Future<void> loadNextPage() async {
    if (_loadingPage || !_hasNext) return;
    _loadingPage = true;
    notifyListeners();
    try {
      _apply(await _fetch(_page + 1), replace: false);
    } on AnnouncementException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Unable to load more announcements.';
    } finally {
      _loadingPage = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(int announcementId) async {
    try {
      final result = await _service.toggleLike(announcementId);
      final index = _items.indexWhere(
        (a) => a.announcementId == announcementId,
      );
      if (index >= 0) {
        final current = _items[index];
        _items = [
          ..._items.sublist(0, index),
          Announcement(
            announcementId: current.announcementId,
            organizationId: current.organizationId,
            createdBy: current.createdBy,
            title: current.title,
            description: current.description,
            attachmentUrl: current.attachmentUrl,
            attachmentType: current.attachmentType,
            isImportant: current.isImportant,
            likeCount: result.likeCount,
            isLiked: result.isLiked,
            createdAt: current.createdAt,
            updatedAt: current.updatedAt,
          ),
          ..._items.sublist(index + 1),
        ];
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<AnnouncementPage> _fetch(int page) => _service.fetchAnnouncements(
    page: page,
    perPage: 20,
    important: _importantOnly,
  );

  void _apply(AnnouncementPage result, {required bool replace}) {
    _items = replace
        ? result.announcements
        : [..._items, ...result.announcements];
    _page = result.page;
    _pages = result.pages;
    _total = result.total;
    _hasNext = result.hasNext;
  }
}
