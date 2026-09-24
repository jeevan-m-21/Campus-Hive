import 'package:firebase_auth/firebase_auth.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/complaint.dart';

class ComplaintService {
  ComplaintService({ApiClient? apiClient, FirebaseAuth? firebaseAuth})
    : _apiClient = apiClient ?? ApiClient(),
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final ApiClient _apiClient;
  final FirebaseAuth _firebaseAuth;

  Future<List<Complaint>> fetchComplaints() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const ComplaintException('Please sign in again.');

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const ComplaintException('Please sign in again.');
    }

    final response = await _apiClient.get(
      ApiEndpoints.complaints,
      idToken: idToken,
      queryParameters: const {'page': '1', 'per_page': '50'},
    );
    final data = response['data'];
    final items = data is Map<String, dynamic> ? data['data'] : null;
    if (items is! List) {
      throw const ComplaintException('The server returned invalid complaints.');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(Complaint.fromJson)
        .toList();
  }
}

class ComplaintException implements Exception {
  const ComplaintException(this.message);

  final String message;
}
