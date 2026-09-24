import 'package:flutter/foundation.dart';

import '../models/complaint.dart';
import '../services/complaint_service.dart';

class ComplaintProvider extends ChangeNotifier {
  ComplaintProvider({ComplaintService? complaintService})
    : _complaintService = complaintService ?? ComplaintService();

  final ComplaintService _complaintService;
  List<Complaint> _complaints = const [];
  bool _isLoading = false;
  bool _isLoadingPage = false;
  bool _isSupporting = false;
  String? _errorMessage;
  String? _supportErrorMessage;
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  bool _hasNext = false;
  bool _hasPrevious = false;
  String? _statusFilter;
  String? _priorityFilter;
  bool _mineOnly = false;

  List<Complaint> get complaints => _complaints;
  bool get isLoading => _isLoading;
  bool get isLoadingPage => _isLoadingPage;
  bool get isSupporting => _isSupporting;
  String? get errorMessage => _errorMessage;
  String? get supportErrorMessage => _supportErrorMessage;
  int get page => _page;
  int get pages => _pages;
  int get total => _total;
  bool get hasNext => _hasNext;
  bool get hasPrevious => _hasPrevious;
  String? get statusFilter => _statusFilter;
  String? get priorityFilter => _priorityFilter;
  bool get isMineOnly => _mineOnly;
  int get totalCount => _complaints.length;
  int get activeCount => _complaints
      .where((item) => item.status != 'RESOLVED' && item.status != 'CLOSED')
      .length;
  int get inProgressCount =>
      _complaints.where((item) => item.status == 'IN_PROGRESS').length;
  int get resolvedCount =>
      _complaints.where((item) => item.status == 'RESOLVED').length;
  int get supportCount =>
      _complaints.fold(0, (total, item) => total + item.supportCount);

  Future<void> loadComplaints({bool refresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    _page = 1;
    notifyListeners();
    try {
      final result = await _fetchPage(1);
      _applyPage(result, replace: true);
    } on ComplaintException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Unable to load complaints. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setFilters({String? status, String? priority}) async {
    _statusFilter = status;
    _priorityFilter = priority;
    await loadComplaints(refresh: true);
  }

  Future<void> setMineOnly(bool value) async {
    if (_mineOnly == value) return;
    _mineOnly = value;
    await loadComplaints(refresh: true);
  }

  Future<void> loadNextPage() async {
    if (_isLoadingPage || !_hasNext) return;
    _isLoadingPage = true;
    notifyListeners();
    try {
      final result = await _fetchPage(_page + 1);
      _applyPage(result, replace: false);
    } on ComplaintException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Unable to load more complaints.';
    } finally {
      _isLoadingPage = false;
      notifyListeners();
    }
  }

  Future<bool> supportComplaint(int complaintId) async {
    if (_isSupporting) return false;
    _isSupporting = true;
    _supportErrorMessage = null;
    notifyListeners();
    try {
      final supportCount = await _complaintService.supportComplaint(
        complaintId,
      );
      final index = _complaints.indexWhere(
        (complaint) => complaint.complaintId == complaintId,
      );
      if (index >= 0) {
        final complaint = _complaints[index];
        _complaints = [
          ..._complaints.sublist(0, index),
          Complaint.fromJson({
            'complaint_id': complaint.complaintId,
            'organization_id': complaint.organizationId,
            'student_id': complaint.studentId,
            'department_id': complaint.departmentId,
            'supervisor_id': complaint.supervisorId,
            'title': complaint.title,
            'description': complaint.description,
            'location': complaint.location,
            'ml_priority': complaint.mlPriority,
            'final_priority': complaint.finalPriority,
            'status': complaint.status,
            'support_count': supportCount,
            'deadline': complaint.deadline?.toIso8601String(),
            'resolved_at': complaint.resolvedAt?.toIso8601String(),
            'student_feedback': complaint.studentFeedback,
            'created_at': complaint.createdAt?.toIso8601String(),
            'updated_at': complaint.updatedAt?.toIso8601String(),
            'student_name': complaint.studentName,
            'department_name': complaint.departmentName,
          }),
          ..._complaints.sublist(index + 1),
        ];
      }
      return true;
    } on ComplaintException catch (error) {
      _supportErrorMessage = error.message;
      return false;
    } catch (_) {
      _supportErrorMessage = 'Unable to support this complaint.';
      return false;
    } finally {
      _isSupporting = false;
      notifyListeners();
    }
  }

  Future<ComplaintPage> _fetchPage(int page) {
    return _complaintService.fetchComplaints(
      page: page,
      perPage: 20,
      status: _statusFilter,
      finalPriority: _priorityFilter,
      mine: _mineOnly ? true : null,
    );
  }

  void _applyPage(ComplaintPage result, {required bool replace}) {
    _complaints = replace
        ? result.complaints
        : [..._complaints, ...result.complaints];
    _page = result.page;
    _pages = result.pages;
    _total = result.total;
    _hasNext = result.hasNext;
    _hasPrevious = result.hasPrevious;
  }
}
