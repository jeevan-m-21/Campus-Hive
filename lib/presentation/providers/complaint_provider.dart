/// Complaint Provider
/// Manages complaint-related state

import 'package:flutter/foundation.dart';
import 'package:campus_hive/data/models/complaint_model.dart';
import 'package:campus_hive/data/services/complaint_service.dart';

class ComplaintProvider extends ChangeNotifier {
  late ComplaintService _complaintService;

  List<Complaint> _complaints = [];
  Complaint? _selectedComplaint;
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;

  // Getters
  List<Complaint> get complaints => _complaints;
  Complaint? get selectedComplaint => _selectedComplaint;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  ComplaintProvider({required ComplaintService complaintService}) {
    _complaintService = complaintService;
  }

  /// Load complaints
  Future<void> loadComplaints({
    String? status,
    String? category,
    bool refresh = false,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _complaints.clear();
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newComplaints = await _complaintService.getComplaints(
        page: _currentPage,
        status: status,
        category: category,
      );

      if (newComplaints.isEmpty) {
        _hasMore = false;
      } else {
        _complaints.addAll(newComplaints);
        _currentPage++;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Load complaint details
  Future<void> loadComplaintDetails(String complaintId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedComplaint = await _complaintService.getComplaintDetails(
        complaintId,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Create complaint
  Future<bool> createComplaint({
    required String category,
    required String title,
    required String description,
    String? location,
    List<String>? imageUrls,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final complaint = await _complaintService.createComplaint(
        category: category,
        title: title,
        description: description,
        location: location,
        imageUrls: imageUrls,
      );

      _complaints.insert(0, complaint);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update complaint status
  Future<bool> updateComplaintStatus({
    required String complaintId,
    required String status,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await _complaintService.updateComplaint(
        complaintId: complaintId,
        status: status,
      );

      // Update in list
      final index = _complaints.indexWhere((c) => c.id == complaintId);
      if (index != -1) {
        _complaints[index] = updated;
      }

      // Update selected if same complaint
      if (_selectedComplaint?.id == complaintId) {
        _selectedComplaint = updated;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Vote on complaint
  Future<bool> voteOnComplaint({
    required String complaintId,
    required String voteType,
  }) async {
    try {
      await _complaintService.voteOnComplaint(
        complaintId: complaintId,
        voteType: voteType,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Add comment
  Future<bool> addComment({
    required String complaintId,
    required String comment,
  }) async {
    try {
      await _complaintService.addComment(
        complaintId: complaintId,
        comment: comment,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset provider
  void reset() {
    _complaints.clear();
    _selectedComplaint = null;
    _currentPage = 1;
    _hasMore = true;
    _error = null;
    _isLoading = false;
  }
}
