class RoleRequestModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String? studentId;
  final String requestedRole; // cr, club_lead, moderator, faculty
  final String reason;
  final String? proofDocumentUrl;
  final String status; // pending, approved, rejected
  final DateTime createdAt;
  final String? reviewerId;
  final String? reviewNotes;

  RoleRequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.studentId,
    required this.requestedRole,
    required this.reason,
    this.proofDocumentUrl,
    required this.status,
    required this.createdAt,
    this.reviewerId,
    this.reviewNotes,
  });

  factory RoleRequestModel.fromMap(Map<String, dynamic> map) {
    return RoleRequestModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      userName: map['user_name']?.toString() ?? map['applicant_name']?.toString() ?? 'Student',
      userEmail: map['user_email']?.toString() ?? '',
      studentId: map['student_id']?.toString() ?? map['mit_id']?.toString(),
      requestedRole: map['requested_role']?.toString() ?? map['role']?.toString() ?? 'cr',
      reason: map['reason']?.toString() ?? map['notes']?.toString() ?? 'Role application submitted.',
      proofDocumentUrl: map['proof_url']?.toString() ?? map['document_url']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'].toString()) 
          : DateTime.now(),
      reviewerId: map['reviewer_id']?.toString(),
      reviewNotes: map['review_notes']?.toString(),
    );
  }
}
