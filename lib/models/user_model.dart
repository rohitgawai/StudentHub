enum UserRole {
  student,
  eventHost,
  faculty,
  admin,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.eventHost:
        return 'Event Host';
      case UserRole.faculty:
        return 'Faculty';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String studentOrEmployeeId;
  final String department;
  final String year;
  final String mobileNumber;
  final String avatarUrl;
  final List<UserRole> roles;
  final List<String> savedPostIds;
  final List<String> registeredEventIds;
  final List<String> congratulatedPostIds;
  final List<String> likedPostIds;
  final bool isVerified;
  final Map<UserRole, DateTime> roleExpirations;
  final bool hasChangedUniqueId;
  final bool hasCompletedProgressiveForm;
  final String? activeDeviceId;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.studentOrEmployeeId,
    required this.department,
    required this.year,
    required this.mobileNumber,
    required this.avatarUrl,
    required this.roles,
    required this.savedPostIds,
    required this.registeredEventIds,
    this.congratulatedPostIds = const [],
    this.likedPostIds = const [],
    this.isVerified = true,
    this.roleExpirations = const {},
    this.hasChangedUniqueId = false,
    this.hasCompletedProgressiveForm = true,
    this.activeDeviceId,
  });

  bool hasRole(UserRole role) => roles.contains(role);

  bool isRoleExpiring(UserRole role) => roleExpirations[role] != null;

  DateTime? getRoleExpiry(UserRole role) => roleExpirations[role];

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? studentOrEmployeeId,
    String? department,
    String? year,
    String? mobileNumber,
    String? avatarUrl,
    List<UserRole>? roles,
    List<String>? savedPostIds,
    List<String>? registeredEventIds,
    List<String>? congratulatedPostIds,
    List<String>? likedPostIds,
    bool? isVerified,
    Map<UserRole, DateTime>? roleExpirations,
    bool? hasChangedUniqueId,
    bool? hasCompletedProgressiveForm,
    String? activeDeviceId,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      studentOrEmployeeId: studentOrEmployeeId ?? this.studentOrEmployeeId,
      department: department ?? this.department,
      year: year ?? this.year,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      roles: roles ?? this.roles,
      savedPostIds: savedPostIds ?? this.savedPostIds,
      registeredEventIds: registeredEventIds ?? this.registeredEventIds,
      congratulatedPostIds:
          congratulatedPostIds ?? this.congratulatedPostIds,
      likedPostIds: likedPostIds ?? this.likedPostIds,
      isVerified: isVerified ?? this.isVerified,
      roleExpirations: roleExpirations ?? this.roleExpirations,
      hasChangedUniqueId: hasChangedUniqueId ?? this.hasChangedUniqueId,
      hasCompletedProgressiveForm:
          hasCompletedProgressiveForm ?? this.hasCompletedProgressiveForm,
      activeDeviceId: activeDeviceId ?? this.activeDeviceId,
    );
  }
}
