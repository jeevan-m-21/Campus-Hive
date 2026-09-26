import 'package:firebase_auth/firebase_auth.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../models/complaint.dart';
import '../models/complaint_comment.dart';
import '../models/department.dart';

class ComplaintService {
  ComplaintService({ApiClient? apiClient, FirebaseAuth? firebaseAuth})
    : _apiClient = apiClient ?? ApiClient(),
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final ApiClient _apiClient;
  final FirebaseAuth _firebaseAuth;

  Future<ComplaintPage> fetchComplaints({
    required int page,
    required int perPage,
    String? status,
    String? finalPriority,
    int? departmentId,
    bool? mine,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const ComplaintException('Please sign in again.');

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const ComplaintException('Please sign in again.');
    }

    late final Map<String, dynamic> response;
    try {
      response = await _apiClient.get(
        ApiEndpoints.complaints,
        idToken: idToken,
        queryParameters: {
          'page': '$page',
          'per_page': '$perPage',
          if (status != null && status.isNotEmpty) 'status': status,
          if (finalPriority != null && finalPriority.isNotEmpty)
            'final_priority': finalPriority,
          if (departmentId != null) 'department_id': '$departmentId',
          if (mine == true) 'mine': 'true',
        },
      );
    } on ApiException catch (error) {
      throw ComplaintException(error.message);
    }
    final data = response['data'];
    final items = data is Map<String, dynamic> ? data['data'] : null;
    if (items is! List) {
      throw const ComplaintException('The server returned invalid complaints.');
    }
    final complaints = items
        .whereType<Map<String, dynamic>>()
        .map(Complaint.fromJson)
        .toList();
    final pagination = data['pagination'];
    if (pagination is! Map<String, dynamic>) {
      throw const ComplaintException('The server returned invalid pagination.');
    }
    return ComplaintPage(
      complaints: complaints,
      page: _int(pagination['page'], page),
      pages: _int(pagination['pages'], 1),
      total: _int(pagination['total'], complaints.length),
      hasNext: pagination['has_next'] == true,
      hasPrevious: pagination['has_prev'] == true,
    );
  }

  Future<int> supportComplaint(int complaintId) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const ComplaintException('Please sign in again.');
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const ComplaintException('Please sign in again.');
    }
    late final Map<String, dynamic> response;
    try {
      response = await _apiClient.post(
        ApiEndpoints.supportComplaint(complaintId),
        idToken: idToken,
        body: const {},
      );
    } on ApiException catch (error) {
      throw ComplaintException(error.message);
    }
    final data = response['data'];
    final supportCount = data is Map<String, dynamic>
        ? data['support_count']
        : null;
    if (supportCount is! num) {
      throw const ComplaintException(
        'The server returned invalid support data.',
      );
    }
    return supportCount.toInt();
  }

  Future<Complaint> fetchComplaint(int complaintId) async {
    final response = await _authenticatedGet(
      ApiEndpoints.complaintDetail(complaintId),
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ComplaintException(
        'The server returned invalid complaint data.',
      );
    }
    return Complaint.fromJson(data);
  }

  Future<List<ComplaintComment>> fetchComments(int complaintId) async {
    final response = await _authenticatedGet(
      ApiEndpoints.complaintComments(complaintId),
    );
    final data = response['data'];
    if (data is! List) {
      throw const ComplaintException('The server returned invalid comments.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(ComplaintComment.fromJson)
        .toList();
  }

  Future<ComplaintComment> addComment(int complaintId, String message) async {
    final response = await _authenticatedPost(
      ApiEndpoints.addComplaintComment(complaintId),
      body: {'message': message},
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ComplaintException(
        'The server returned invalid comment data.',
      );
    }
    return ComplaintComment.fromJson(data);
  }

  Future<List<Department>> fetchDepartments() async {
    final response = await _authenticatedGet(ApiEndpoints.complaintDepartments);
    final data = response['data'];
    if (data is! List) {
      throw const ComplaintException(
        'The server returned invalid departments.',
      );
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(Department.fromJson)
        .toList();
  }

  Future<String> uploadImage(String filePath) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const ComplaintException('Please sign in again.');
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const ComplaintException('Please sign in again.');
    }
    try {
      final response = await _apiClient.postMultipart(
        ApiEndpoints.uploadComplaintImage,
        idToken: idToken,
        filePath: filePath,
      );
      final data = response['data'];
      final imageUrl = data is Map<String, dynamic> ? data['image_url'] : null;
      if (imageUrl is! String) {
        throw const ComplaintException(
          'Failed to retrieve uploaded image URL.',
        );
      }
      return imageUrl;
    } on ApiException catch (error) {
      throw ComplaintException(error.message);
    }
  }

  Future<Complaint> createComplaint({
    required int departmentId,
    required String title,
    required String description,
    String? location,
    String? imageUrl,
  }) async {
    final response = await _authenticatedPost(
      ApiEndpoints.complaints,
      body: {
        'department_id': departmentId,
        'title': title,
        'description': description,
        if (location != null && location.isNotEmpty) 'location': location,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
      },
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ComplaintException(
        'The server returned invalid complaint data.',
      );
    }
    return Complaint.fromJson(data);
  }

  Future<Complaint> updateComplaint(
    int complaintId, {
    String? status,
    String? finalPriority,
    String? remarks,
    DateTime? deadline,
    String? title,
    String? description,
    String? location,
  }) async {
    final response = await _authenticatedPatch(
      ApiEndpoints.updateComplaint(complaintId),
      body: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (finalPriority != null && finalPriority.isNotEmpty)
          'final_priority': finalPriority,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        if (deadline != null) 'deadline': deadline.toIso8601String(),
        if (title != null && title.isNotEmpty) 'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (location != null && location.isNotEmpty) 'location': location,
      },
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ComplaintException(
        'The server returned invalid complaint data.',
      );
    }
    return Complaint.fromJson(data);
  }

  Future<Map<String, dynamic>> _authenticatedGet(String path) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const ComplaintException('Please sign in again.');
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const ComplaintException('Please sign in again.');
    }
    try {
      return await _apiClient.get(path, idToken: idToken);
    } on ApiException catch (error) {
      throw ComplaintException(error.message);
    }
  }

  Future<Map<String, dynamic>> _authenticatedPost(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const ComplaintException('Please sign in again.');
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const ComplaintException('Please sign in again.');
    }
    try {
      return await _apiClient.post(path, idToken: idToken, body: body);
    } on ApiException catch (error) {
      throw ComplaintException(error.message);
    }
  }

  Future<Map<String, dynamic>> _authenticatedPatch(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const ComplaintException('Please sign in again.');
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const ComplaintException('Please sign in again.');
    }
    try {
      return await _apiClient.patch(path, idToken: idToken, body: body);
    } on ApiException catch (error) {
      throw ComplaintException(error.message);
    }
  }

  static int _int(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;
}

class ComplaintPage {
  const ComplaintPage({
    required this.complaints,
    required this.page,
    required this.pages,
    required this.total,
    required this.hasNext,
    required this.hasPrevious,
  });

  final List<Complaint> complaints;
  final int page;
  final int pages;
  final int total;
  final bool hasNext;
  final bool hasPrevious;
}

class ComplaintException implements Exception {
  const ComplaintException(this.message);

  final String message;
}
