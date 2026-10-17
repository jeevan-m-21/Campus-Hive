import 'package:flutter/foundation.dart';

import '../models/complaint.dart';
import '../models/complaint_comment.dart';
import '../models/department.dart';
import '../services/complaint_service.dart';

class AdminComplaintProvider extends ChangeNotifier {
  AdminComplaintProvider({ComplaintService? complaintService})
    : _complaintService = complaintService ?? ComplaintService();

  final ComplaintService _complaintService;

  List<Complaint> _complaints = [];
  List<Department> _departments = [];
  bool _isLoading = false;
  bool _isLoadingDepartments = false;
  String? _errorMessage;

  // Pagination
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  bool _hasNext = false;
  bool _hasPrevious = false;
  static const int _perPage = 20;

  // Filters
  String _statusFilter = 'ALL';
  String _priorityFilter = 'ALL';
  int? _departmentFilter;
  String _searchQuery = '';

  // Comments cache by complaintId
  final Map<int, List<ComplaintComment>> _comments = {};
  final Map<int, bool> _loadingComments = {};

  // Dashboard statistics state
  AdminDashboardStats? _dashboardStats;
  bool _isLoadingDashboard = false;
  String? _dashboardErrorMessage;
  List<Complaint> _allOrgComplaints = [];

  List<Complaint> get complaints => _complaints;
  List<Department> get departments => _departments;
  bool get isLoading => _isLoading;
  bool get isLoadingDepartments => _isLoadingDepartments;
  String? get errorMessage => _errorMessage;

  AdminDashboardStats? get dashboardStats => _dashboardStats;
  bool get isLoadingDashboard => _isLoadingDashboard;
  String? get dashboardErrorMessage => _dashboardErrorMessage;
  List<Complaint> get allOrgComplaints => _allOrgComplaints;

  int get page => _page;
  int get pages => _pages;
  int get total => _total;
  bool get hasNext => _hasNext;
  bool get hasPrevious => _hasPrevious;

  String get statusFilter => _statusFilter;
  String get priorityFilter => _priorityFilter;
  int? get departmentFilter => _departmentFilter;
  String get searchQuery => _searchQuery;

  List<Complaint> get filteredComplaints {
    if (_searchQuery.isEmpty) return _complaints;

    final query = _searchQuery.toLowerCase();
    return _complaints.where((c) {
      final matchTitle = c.title.toLowerCase().contains(query);
      final matchDesc = c.description.toLowerCase().contains(query);
      final matchStudent =
          c.studentName?.toLowerCase().contains(query) ?? false;
      final matchDept =
          c.departmentName?.toLowerCase().contains(query) ?? false;
      final matchLoc = c.location?.toLowerCase().contains(query) ?? false;
      final matchId = '${c.complaintId}'.contains(query);

      return matchTitle ||
          matchDesc ||
          matchStudent ||
          matchDept ||
          matchLoc ||
          matchId;
    }).toList();
  }

  Future<void> loadDepartments() async {
    if (_departments.isNotEmpty) return;
    _isLoadingDepartments = true;
    notifyListeners();

    try {
      _departments = await _complaintService.fetchDepartments();
    } catch (_) {
      // Non-critical, fallback to empty list
    } finally {
      _isLoadingDepartments = false;
      notifyListeners();
    }
  }

  Future<void> loadComplaints({bool refresh = false, int? targetPage}) async {
    if (!refresh && _complaints.isNotEmpty && targetPage == null) return;

    if (targetPage != null) {
      _page = targetPage;
    } else if (refresh) {
      _page = 1;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final pageResult = await _complaintService.fetchComplaints(
        page: _page,
        perPage: _perPage,
        status: _statusFilter == 'ALL' ? null : _statusFilter,
        finalPriority: _priorityFilter == 'ALL' ? null : _priorityFilter,
        departmentId: _departmentFilter,
      );

      _complaints = pageResult.complaints;
      _page = pageResult.page;
      _pages = pageResult.pages;
      _total = pageResult.total;
      _hasNext = pageResult.hasNext;
      _hasPrevious = pageResult.hasPrevious;
    } on ComplaintException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Unable to load organization complaints.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> nextPage() async {
    if (!_hasNext || _isLoading) return;
    await loadComplaints(targetPage: _page + 1);
  }

  Future<void> previousPage() async {
    if (!_hasPrevious || _isLoading) return;
    await loadComplaints(targetPage: _page - 1);
  }

  Future<void> goToPage(int p) async {
    if (p < 1 || p > _pages || p == _page || _isLoading) return;
    await loadComplaints(targetPage: p);
  }

  void setStatusFilter(String status) {
    if (_statusFilter == status) return;
    _statusFilter = status;
    _page = 1;
    loadComplaints(refresh: true);
  }

  void setPriorityFilter(String priority) {
    if (_priorityFilter == priority) return;
    _priorityFilter = priority;
    _page = 1;
    loadComplaints(refresh: true);
  }

  void setDepartmentFilter(int? departmentId) {
    if (_departmentFilter == departmentId) return;
    _departmentFilter = departmentId;
    _page = 1;
    loadComplaints(refresh: true);
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = 'ALL';
    _priorityFilter = 'ALL';
    _departmentFilter = null;
    _searchQuery = '';
    _page = 1;
    loadComplaints(refresh: true);
  }

  Future<Complaint?> getOrFetchComplaint(
    int complaintId, {
    bool force = false,
  }) async {
    if (!force) {
      final existing = _complaints
          .where((c) => c.complaintId == complaintId)
          .firstOrNull;
      if (existing != null) return existing;
    }

    try {
      final fresh = await _complaintService.fetchComplaint(complaintId);
      final index = _complaints.indexWhere((c) => c.complaintId == complaintId);
      if (index != -1) {
        _complaints[index] = fresh;
      } else {
        _complaints.insert(0, fresh);
      }
      notifyListeners();
      return fresh;
    } catch (_) {
      return null;
    }
  }

  Future<Complaint> updateComplaint(
    int complaintId, {
    String? status,
    String? finalPriority,
    String? remarks,
    DateTime? deadline,
    bool clearDeadline = false,
    int? departmentId,
    int? supervisorId,
    bool clearSupervisor = false,
  }) async {
    final updated = await _complaintService.updateComplaint(
      complaintId,
      status: status,
      finalPriority: finalPriority,
      remarks: remarks,
      deadline: deadline,
      clearDeadline: clearDeadline,
      departmentId: departmentId,
      supervisorId: supervisorId,
      clearSupervisor: clearSupervisor,
    );

    final index = _complaints.indexWhere((c) => c.complaintId == complaintId);
    if (index != -1) {
      _complaints[index] = updated;
    } else {
      _complaints.insert(0, updated);
    }

    final orgIndex = _allOrgComplaints.indexWhere(
      (c) => c.complaintId == complaintId,
    );
    if (orgIndex != -1) {
      _allOrgComplaints[orgIndex] = updated;
      _computeDashboardStats(
        _dashboardStats?.total ?? _allOrgComplaints.length,
      );
    }

    notifyListeners();
    return updated;
  }

  Future<void> loadDashboardStats({bool refresh = false}) async {
    if (!refresh && _dashboardStats != null) return;

    _isLoadingDashboard = true;
    _dashboardErrorMessage = null;
    notifyListeners();

    try {
      // 1. Fetch first page with maximum allowed page size (100)
      final firstPage = await _complaintService.fetchComplaints(
        page: 1,
        perPage: 100,
      );

      final List<Complaint> fullList = [...firstPage.complaints];

      // 2. If there are more pages, fetch remaining pages to ensure 100% complete dataset
      if (firstPage.pages > 1) {
        final remainingFutures = <Future<ComplaintPage>>[];
        for (int p = 2; p <= firstPage.pages; p++) {
          remainingFutures.add(
            _complaintService.fetchComplaints(page: p, perPage: 100),
          );
        }
        final results = await Future.wait(remainingFutures);
        for (final res in results) {
          fullList.addAll(res.complaints);
        }
      }

      _allOrgComplaints = fullList;
      _computeDashboardStats(firstPage.total);
    } on ComplaintException catch (e) {
      _dashboardErrorMessage = e.message;
    } catch (_) {
      _dashboardErrorMessage = 'Unable to load live dashboard statistics.';
    } finally {
      _isLoadingDashboard = false;
      notifyListeners();
    }
  }

  void _computeDashboardStats(int authoritativeTotal) {
    int pending = 0;
    int assigned = 0;
    int inProgress = 0;
    int resolved = 0;
    int reopened = 0;
    int escalated = 0;
    int closed = 0;
    int highPriority = 0;
    final List<Complaint> activeHighPriority = [];

    for (final c in _allOrgComplaints) {
      final s = c.status.toUpperCase();
      switch (s) {
        case 'PENDING':
          pending++;
          break;
        case 'ASSIGNED':
          assigned++;
          break;
        case 'IN_PROGRESS':
          inProgress++;
          break;
        case 'RESOLVED':
          resolved++;
          break;
        case 'REOPENED':
          reopened++;
          break;
        case 'ESCALATED':
          escalated++;
          break;
        case 'CLOSED':
          closed++;
          break;
      }

      if (c.finalPriority?.toUpperCase() == 'HIGH') {
        highPriority++;
        if (s != 'RESOLVED' && s != 'CLOSED') {
          activeHighPriority.add(c);
        }
      }
    }

    _dashboardStats = AdminDashboardStats(
      total: authoritativeTotal,
      pending: pending,
      assigned: assigned,
      inProgress: inProgress,
      resolved: resolved,
      reopened: reopened,
      escalated: escalated,
      closed: closed,
      highPriority: highPriority,
      recentComplaints: _allOrgComplaints.take(5).toList(),
      activeHighPriorityComplaints: activeHighPriority,
    );
  }

  List<ComplaintComment> getComments(int complaintId) =>
      _comments[complaintId] ?? [];

  bool isLoadingComments(int complaintId) =>
      _loadingComments[complaintId] == true;

  Future<void> loadComments(int complaintId, {bool refresh = false}) async {
    if (!refresh && _comments.containsKey(complaintId)) return;
    _loadingComments[complaintId] = true;
    notifyListeners();

    try {
      final comments = await _complaintService.fetchComments(complaintId);
      _comments[complaintId] = comments;
    } catch (_) {
      _comments[complaintId] = [];
    } finally {
      _loadingComments[complaintId] = false;
      notifyListeners();
    }
  }

  Future<ComplaintComment> addComment(int complaintId, String message) async {
    final comment = await _complaintService.addComment(complaintId, message);
    final current = _comments[complaintId] ?? [];
    _comments[complaintId] = [...current, comment];
    notifyListeners();
    return comment;
  }
}

class AdminDashboardStats {
  const AdminDashboardStats({
    required this.total,
    required this.pending,
    required this.assigned,
    required this.inProgress,
    required this.resolved,
    required this.reopened,
    required this.escalated,
    required this.closed,
    required this.highPriority,
    required this.recentComplaints,
    required this.activeHighPriorityComplaints,
  });

  final int total;
  final int pending;
  final int assigned;
  final int inProgress;
  final int resolved;
  final int reopened;
  final int escalated;
  final int closed;
  final int highPriority;
  final List<Complaint> recentComplaints;
  final List<Complaint> activeHighPriorityComplaints;

  int get activeTickets =>
      pending + assigned + inProgress + reopened + escalated;
}
