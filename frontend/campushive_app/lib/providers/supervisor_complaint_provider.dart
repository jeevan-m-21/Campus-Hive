import 'package:flutter/foundation.dart';

import '../models/complaint.dart';
import '../models/complaint_comment.dart';
import '../services/complaint_service.dart';

class SupervisorComplaintProvider extends ChangeNotifier {
  SupervisorComplaintProvider({ComplaintService? complaintService})
    : _complaintService = complaintService ?? ComplaintService();

  final ComplaintService _complaintService;

  List<Complaint> _complaints = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _statusFilter = 'ALL';
  String _priorityFilter = 'ALL';
  String _searchQuery = '';

  // Comments cache by complaintId
  final Map<int, List<ComplaintComment>> _comments = {};
  final Map<int, bool> _loadingComments = {};

  List<Complaint> get complaints => _complaints;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get statusFilter => _statusFilter;
  String get priorityFilter => _priorityFilter;
  String get searchQuery => _searchQuery;

  List<Complaint> get filteredComplaints {
    return _complaints.where((c) {
      if (_statusFilter != 'ALL' &&
          c.status.toUpperCase() != _statusFilter.toUpperCase()) {
        return false;
      }
      if (_priorityFilter != 'ALL' &&
          (c.finalPriority?.toUpperCase() != _priorityFilter.toUpperCase())) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = c.title.toLowerCase().contains(query);
        final matchDesc = c.description.toLowerCase().contains(query);
        final matchStudent =
            c.studentName?.toLowerCase().contains(query) ?? false;
        final matchDept =
            c.departmentName?.toLowerCase().contains(query) ?? false;
        final matchLoc = c.location?.toLowerCase().contains(query) ?? false;
        if (!matchTitle &&
            !matchDesc &&
            !matchStudent &&
            !matchDept &&
            !matchLoc) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // Work Stats
  int get totalAssigned => _complaints.length;
  int get pendingCount => _countStatus('PENDING');
  int get inProgressCount => _countStatus('IN_PROGRESS');
  int get resolvedCount => _countStatus('RESOLVED');
  int get reopenedCount => _countStatus('REOPENED');
  int get escalatedCount => _countStatus('ESCALATED');
  int get closedCount => _countStatus('CLOSED');

  int _countStatus(String status) {
    return _complaints
        .where((c) => c.status.toUpperCase() == status.toUpperCase())
        .length;
  }

  Future<void> loadComplaints({bool refresh = false}) async {
    if (!refresh && _complaints.isNotEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final page = await _complaintService.fetchComplaints(
        page: 1,
        perPage: 100,
      );
      _complaints = page.complaints;
    } on ComplaintException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Unable to load assigned complaints.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setPriorityFilter(String priority) {
    _priorityFilter = priority;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = 'ALL';
    _priorityFilter = 'ALL';
    _searchQuery = '';
    notifyListeners();
  }

  Future<Complaint?> getOrFetchComplaint(int complaintId) async {
    final existing = _complaints
        .where((c) => c.complaintId == complaintId)
        .firstOrNull;
    if (existing != null) return existing;

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
  }) async {
    final updated = await _complaintService.updateComplaint(
      complaintId,
      status: status,
      finalPriority: finalPriority,
      remarks: remarks,
      deadline: deadline,
    );

    final index = _complaints.indexWhere((c) => c.complaintId == complaintId);
    if (index != -1) {
      _complaints[index] = updated;
    } else {
      _complaints.insert(0, updated);
    }
    notifyListeners();
    return updated;
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
