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
  final bool isLimitedAccess;
  final int? durationDays;

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
    this.isLimitedAccess = false,
    this.durationDays,
  });

  DateTime? get expiresAt {
    if (!isLimitedAccess || durationDays == null) return null;
    return submittedAt.add(Duration(days: durationDays!));
  }

  String get termLabel {
    if (!isLimitedAccess) return 'Permanent';
    return 'Temporary • ${durationDays! >= 7 && durationDays! % 7 == 0 ? '${durationDays! ~/ 7} week${durationDays! ~/ 7 > 1 ? 's' : ''}' : '$durationDays days'}';
  }

  RoleRequestModel copyWith({
    RoleRequestStatus? status,
    String? adminNotes,
    bool? isLimitedAccess,
    int? durationDays,
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
      isLimitedAccess: isLimitedAccess ?? this.isLimitedAccess,
      durationDays: durationDays ?? this.durationDays,
    );
  }
}
