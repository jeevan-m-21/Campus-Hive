/// Complaint Service
/// Handles complaint-related API calls

import 'package:campus_hive/core/constants/app_constants.dart';
import 'package:campus_hive/data/models/complaint_model.dart';
import 'package:campus_hive/data/services/api_service.dart';

class ComplaintService {
  final ApiService apiService;

  ComplaintService({required this.apiService});

  /// Get list of complaints
  Future<List<Complaint>> getComplaints({
    int page = 1,
    int perPage = ApiConstants.pageSize,
    String? status,
    String? category,
  }) async {
    try {
      final response = await apiService.get(
        ApiConstants.complaints,
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (status != null) 'status': status,
          if (category != null) 'category': category,
        },
      );

      final List<dynamic> complaintsList = response['data'] ?? [];
      return complaintsList
          .map((json) => Complaint.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get single complaint details
  Future<Complaint> getComplaintDetails(String complaintId) async {
    try {
      final response = await apiService.get(
        '${ApiConstants.complaints}/$complaintId',
      );

      return Complaint.fromJson(response['data'] ?? response);
    } catch (e) {
      rethrow;
    }
  }

  /// Create new complaint
  Future<Complaint> createComplaint({
    required String category,
    required String title,
    required String description,
    String? location,
    List<String>? imageUrls,
  }) async {
    try {
      final response = await apiService.post(
        ApiConstants.complaints,
        data: {
          'category': category,
          'title': title,
          'description': description,
          'location': location,
          'image_urls': imageUrls,
        },
      );

      return Complaint.fromJson(response['data'] ?? response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update complaint
  Future<Complaint> updateComplaint({
    required String complaintId,
    String? status,
    String? resolutionNotes,
  }) async {
    try {
      final response = await apiService.patch(
        '${ApiConstants.complaints}/$complaintId',
        data: {
          if (status != null) 'status': status,
          if (resolutionNotes != null) 'resolution_notes': resolutionNotes,
        },
      );

      return Complaint.fromJson(response['data'] ?? response);
    } catch (e) {
      rethrow;
    }
  }

  /// Vote on complaint
  Future<void> voteOnComplaint({
    required String complaintId,
    required String voteType, // 'upvote' or 'downvote'
  }) async {
    try {
      await apiService.post(
        '${ApiConstants.complaints}/$complaintId/vote',
        data: {'vote_type': voteType},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Add comment to complaint
  Future<void> addComment({
    required String complaintId,
    required String comment,
  }) async {
    try {
      await apiService.post(
        '${ApiConstants.complaints}/$complaintId/comments',
        data: {'comment': comment},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Escalate complaint
  Future<void> escalateComplaint(String complaintId) async {
    try {
      await apiService.post('${ApiConstants.complaints}/$complaintId/escalate');
    } catch (e) {
      rethrow;
    }
  }
}
