import 'package:flutter/foundation.dart';

import '../models/complaint.dart';
import '../services/complaint_service.dart';

class ComplaintProvider extends ChangeNotifier {
  ComplaintProvider({ComplaintService? complaintService})
    : _complaintService = complaintService ?? ComplaintService();

  final ComplaintService _complaintService;
  List<Complaint> _complaints = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Complaint> get complaints => _complaints;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
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
    if (_isLoading && !refresh) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _complaints = await _complaintService.fetchComplaints();
    } on ComplaintException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Unable to load complaints. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
