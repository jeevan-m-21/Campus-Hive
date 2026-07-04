/// Complaint model for issue management

class Complaint {
  final String id;
  final String studentId;
  final String? supervisorId;
  final String category;
  final String title;
  final String description;
  final String? location;
  final String priority;
  final double priorityScore;
  final String? mlPriority;
  final double? mlPriorityScore;
  final String status;
  final int escalationLevel;
  final DateTime? escalatedAt;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? deadline;
  final DateTime? resolvedAt;
  final String? resolutionNotes;
  final int imageCount;
  final List<String> imageUrls;

  Complaint({
    required this.id,
    required this.studentId,
    this.supervisorId,
    required this.category,
    required this.title,
    required this.description,
    this.location,
    required this.priority,
    required this.priorityScore,
    this.mlPriority,
    this.mlPriorityScore,
    required this.status,
    required this.escalationLevel,
    this.escalatedAt,
    required this.createdAt,
    this.assignedAt,
    this.deadline,
    this.resolvedAt,
    this.resolutionNotes,
    required this.imageCount,
    this.imageUrls = const [],
  });

  bool get isResolved => status == 'resolved' || status == 'closed';
  bool get isOverdue => deadline != null && DateTime.now().isAfter(deadline!);

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'supervisor_id': supervisorId,
      'category': category,
      'title': title,
      'description': description,
      'location': location,
      'priority': priority,
      'priority_score': priorityScore,
      'ml_priority': mlPriority,
      'ml_priority_score': mlPriorityScore,
      'status': status,
      'escalation_level': escalationLevel,
      'escalated_at': escalatedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'assigned_at': assignedAt?.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolution_notes': resolutionNotes,
      'image_count': imageCount,
    };
  }

  /// Create from JSON
  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] ?? '',
      studentId: json['student_id'] ?? '',
      supervisorId: json['supervisor_id'],
      category: json['category'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      location: json['location'],
      priority: json['priority'] ?? 'medium',
      priorityScore: (json['priority_score'] ?? 0.5).toDouble(),
      mlPriority: json['ml_priority'],
      mlPriorityScore: json['ml_priority_score'] != null
          ? (json['ml_priority_score']).toDouble()
          : null,
      status: json['status'] ?? 'pending',
      escalationLevel: json['escalation_level'] ?? 1,
      escalatedAt: json['escalated_at'] != null
          ? DateTime.parse(json['escalated_at'])
          : null,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'])
          : null,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'])
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
      resolutionNotes: json['resolution_notes'],
      imageCount: json['image_count'] ?? 0,
      imageUrls: List<String>.from(json['image_urls'] ?? []),
    );
  }

  /// Copy with modifications
  Complaint copyWith({
    String? id,
    String? studentId,
    String? supervisorId,
    String? category,
    String? title,
    String? description,
    String? location,
    String? priority,
    double? priorityScore,
    String? mlPriority,
    double? mlPriorityScore,
    String? status,
    int? escalationLevel,
    DateTime? escalatedAt,
    DateTime? createdAt,
    DateTime? assignedAt,
    DateTime? deadline,
    DateTime? resolvedAt,
    String? resolutionNotes,
    int? imageCount,
    List<String>? imageUrls,
  }) {
    return Complaint(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      supervisorId: supervisorId ?? this.supervisorId,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      priority: priority ?? this.priority,
      priorityScore: priorityScore ?? this.priorityScore,
      mlPriority: mlPriority ?? this.mlPriority,
      mlPriorityScore: mlPriorityScore ?? this.mlPriorityScore,
      status: status ?? this.status,
      escalationLevel: escalationLevel ?? this.escalationLevel,
      escalatedAt: escalatedAt ?? this.escalatedAt,
      createdAt: createdAt ?? this.createdAt,
      assignedAt: assignedAt ?? this.assignedAt,
      deadline: deadline ?? this.deadline,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      imageCount: imageCount ?? this.imageCount,
      imageUrls: imageUrls ?? this.imageUrls,
    );
  }

  @override
  String toString() => 'Complaint(id: $id, title: $title, status: $status)';
}
