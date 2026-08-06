import 'user_model.dart';

enum RoleRequestStatus {
  pending,
  approved,
  rejected,
}

class RoleRequestModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String department;
  final String studentId;
  final UserRole requestedRole;
  final String reason;
  final String phoneNumber;
  final RoleRequestStatus status;
  final DateTime submittedAt;
  final String? adminNotes;

  RoleRequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.department,
    required this.studentId,
    required this.requestedRole,
    required this.reason,
    required this.phoneNumber,
    this.status = RoleRequestStatus.pending,
    required this.submittedAt,
    this.adminNotes,
  });

  RoleRequestModel copyWith({
    RoleRequestStatus? status,
    String? adminNotes,
  }) {
    return RoleRequestModel(
      id: id,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      department: department,
      studentId: studentId,
      requestedRole: requestedRole,
      reason: reason,
      phoneNumber: phoneNumber,
      status: status ?? this.status,
      submittedAt: submittedAt,
      adminNotes: adminNotes ?? this.adminNotes,
    );
  }
}
