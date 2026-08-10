class AdminUserModel {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String role; // student, host, faculty, admin, banned, deleted
  final String? studentId; // student_or_employee_id (MIT ID)
  final String? branch; // department
  final String? year;
  final String? mobileNumber;
  final bool isVerifiedStudent;
  final bool isBanned;
  final bool isDeleted;
  final DateTime? lastSeen;
  final DateTime? createdAt;

  AdminUserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    required this.role,
    this.studentId,
    this.branch,
    this.year,
    this.mobileNumber,
    this.isVerifiedStudent = false,
    this.isBanned = false,
    this.isDeleted = false,
    this.lastSeen,
    this.createdAt,
  });

  factory AdminUserModel.fromMap(Map<String, dynamic> map) {
    String userRole = 'student';
    List<String> rolesList = [];

    if (map['roles'] is List) {
      rolesList = (map['roles'] as List).map((e) => e.toString()).toList();
      if (rolesList.isNotEmpty) {
        userRole = rolesList.first;
      }
    } else if (map['role'] != null) {
      userRole = map['role'].toString();
      rolesList = [userRole];
    }

    final bool banned = rolesList.contains('banned') || userRole == 'banned' || map['is_banned'] == true;
    final bool deleted = rolesList.contains('deleted') || userRole == 'deleted' || map['is_deleted'] == true;

    final updatedAt = map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null;
    final createdAt = map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : updatedAt;

    return AdminUserModel(
      id: map['user_id']?.toString() ?? map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? 'No Email',
      fullName: map['name']?.toString() ?? map['full_name']?.toString() ?? 'Student',
      avatarUrl: map['avatar_url']?.toString(),
      role: userRole,
      studentId: map['student_or_employee_id']?.toString() ?? map['student_id']?.toString() ?? map['mit_id']?.toString(),
      branch: map['department']?.toString() ?? map['branch']?.toString(),
      year: map['year']?.toString(),
      mobileNumber: map['mobile_number']?.toString() ?? map['phone']?.toString() ?? map['mobile']?.toString(),
      isVerifiedStudent: map['is_verified'] == true || map['is_verified_student'] == true,
      isBanned: banned,
      isDeleted: deleted,
      lastSeen: updatedAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': id,
      'email': email,
      'name': fullName,
      'avatar_url': avatarUrl,
      'roles': isBanned ? ['banned'] : isDeleted ? ['deleted'] : [role],
      'student_or_employee_id': studentId,
      'department': branch,
      'year': year,
      'mobile_number': mobileNumber,
      'is_verified': isVerifiedStudent,
      'is_banned': isBanned,
      'is_deleted': isDeleted,
      'updated_at': lastSeen?.toIso8601String(),
    };
  }

  bool get isOnline {
    if (lastSeen == null) return false;
    // Strict active presence check (60 seconds)
    return DateTime.now().difference(lastSeen!).inSeconds < 60;
  }
}
