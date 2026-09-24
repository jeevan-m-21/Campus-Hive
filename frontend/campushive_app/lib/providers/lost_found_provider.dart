import 'package:flutter/foundation.dart';

import '../models/lost_found.dart';
import '../services/lost_found_service.dart';

class LostFoundProvider extends ChangeNotifier {
  LostFoundProvider({LostFoundService? service})
    : _service = service ?? LostFoundService();
  final LostFoundService _service;
  List<LostFound> _items = const [];
  bool _loading = false, _loadingPage = false;
  String? _error, _status, _itemType;
  String _search = '';
  bool _mineOnly = false;
  int _page = 1, _pages = 1, _total = 0;
  bool _hasNext = false;
  List<LostFound> get items => _items;
  bool get isLoading => _loading;
  bool get isLoadingPage => _loadingPage;
  String? get errorMessage => _error;
  String? get statusFilter => _status;
  String? get itemTypeFilter => _itemType;
  String get search => _search;
  bool get isMineOnly => _mineOnly;
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
    } on LostFoundException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Unable to load lost and found items.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setFilters({
    String? status,
    String? itemType,
    String? search,
  }) async {
    _status = status;
    _itemType = itemType;
    _search = search ?? _search;
    await load(refresh: true);
  }

  Future<void> setMineOnly(bool value) async {
    if (_mineOnly == value) return;
    _mineOnly = value;
    await load(refresh: true);
  }

  Future<void> loadNextPage() async {
    if (_loadingPage || !_hasNext) return;
    _loadingPage = true;
    notifyListeners();
    try {
      _apply(await _fetch(_page + 1), replace: false);
    } on LostFoundException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Unable to load more items.';
    } finally {
      _loadingPage = false;
      notifyListeners();
    }
  }

  Future<LostFoundPage> _fetch(int page) => _service.fetchItems(
    page: page,
    perPage: 20,
    status: _status,
    itemType: _itemType,
    search: _search,
    mine: _mineOnly ? true : null,
  );

  void _apply(LostFoundPage result, {required bool replace}) {
    _items = replace ? result.items : [..._items, ...result.items];
    _page = result.page;
    _pages = result.pages;
    _total = result.total;
    _hasNext = result.hasNext;
  }
}
