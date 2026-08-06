import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/role_request_model.dart';
import '../models/notification_model.dart';

class MockDataService extends ChangeNotifier {
  late AppConfig config;
  late UserModel currentUser;
  late UserRole activeRole;

  List<PostModel> _posts = [];
  List<RoleRequestModel> _roleRequests = [];
  List<NotificationModel> _notifications = [];

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Timer? _expiryTimer;

  List<PostModel> get posts => List.unmodifiable(_posts);
  List<RoleRequestModel> get roleRequests => List.unmodifiable(_roleRequests);
  List<NotificationModel> get notifications => List.unmodifiable(_notifications);

  MockDataService() {
    _initData();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    config = await AppConfig.loadFromAssets();

    // Default Current User (Student with Event Host capability or standard student)
    currentUser = UserModel(
      id: 'usr_101',
      name: 'Aarav Sharma',
      email: 'aarav.sharma@studenthub.edu',
      studentOrEmployeeId: 'MIT/CS/2023/042',
      department: 'Computer Science & Engineering',
      year: 'Third Year',
      mobileNumber: '+91 98765 12345',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=256',
      roles: [UserRole.student, UserRole.eventHost],
      savedPostIds: ['pst_002', 'pst_004'],
      registeredEventIds: ['pst_002'],
      isVerified: true,
    );

    activeRole = currentUser.roles.first;

    _generateMockPosts();
    _generateMockRoleRequests();
    _generateMockNotifications();

    checkForExpiredRoles();

    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) => checkForExpiredRoles());

    _isLoading = false;
    notifyListeners();
  }

  void updateConfig(AppConfig newConfig) {
    config = newConfig;
    notifyListeners();
  }

  void switchActiveRole(UserRole newRole) {
    if (currentUser.roles.contains(newRole) || activeRole != newRole) {
      activeRole = newRole;
      notifyListeners();
    }
  }

  // --- Feed & Priority Logic ---
  List<PostModel> getPersonalizedFeed({
    String? categoryFilter,
    String? searchQuery,
    bool savedOnly = false,
  }) {
    List<PostModel> list = List.from(_posts);

    if (savedOnly) {
      list = list.where((p) => currentUser.savedPostIds.contains(p.id)).toList();
    }

    if (categoryFilter != null && categoryFilter != 'All') {
      list = list.where((p) => p.category.displayName.toLowerCase() == categoryFilter.toLowerCase()).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((p) =>
        p.title.toLowerCase().contains(q) ||
        p.description.toLowerCase().contains(q) ||
        p.department.toLowerCase().contains(q) ||
        p.authorName.toLowerCase().contains(q)
      ).toList();
    }

    // Sort by priority logic (PRD Section 10):
    // 1. Urgent posts
    // 2. Target department match
    // 3. Target year match
    // 4. Pinned
    // 5. Timestamp
    list.sort((a, b) {
      if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      
      final aDeptMatch = a.department == currentUser.department;
      final bDeptMatch = b.department == currentUser.department;
      if (aDeptMatch != bDeptMatch) return aDeptMatch ? -1 : 1;

      final aYearMatch = a.targetYear == null || a.targetYear == currentUser.year;
      final bYearMatch = b.targetYear == null || b.targetYear == currentUser.year;
      if (aYearMatch != bYearMatch) return aYearMatch ? -1 : 1;

      return b.timestamp.compareTo(a.timestamp);
    });

    return list;
  }

  // --- Post Actions ---
  void toggleSavePost(String postId) {
    List<String> updatedSaved = List.from(currentUser.savedPostIds);
    int postIndex = _posts.indexWhere((p) => p.id == postId);

    if (updatedSaved.contains(postId)) {
      updatedSaved.remove(postId);
      if (postIndex != -1) {
        final currentCount = _posts[postIndex].saveCount;
        _posts[postIndex] = _posts[postIndex].copyWith(saveCount: (currentCount > 0 ? currentCount - 1 : 0));
      }
    } else {
      updatedSaved.add(postId);
      if (postIndex != -1) {
        _posts[postIndex] = _posts[postIndex].copyWith(saveCount: _posts[postIndex].saveCount + 1);
      }
    }

    currentUser = currentUser.copyWith(savedPostIds: updatedSaved);
    notifyListeners();
  }

  void toggleEventRegistration(String postId) {
    int index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    PostModel post = _posts[index];
    List<String> regUsers = List.from(post.registeredUserIds);
    List<String> userRegEvents = List.from(currentUser.registeredEventIds);

    if (regUsers.contains(currentUser.id)) {
      regUsers.remove(currentUser.id);
      userRegEvents.remove(postId);
    } else {
      if (post.maxParticipants != null && regUsers.length >= post.maxParticipants!) {
        return; // Full
      }
      regUsers.add(currentUser.id);
      userRegEvents.add(postId);

      // Add event registration notification
      _notifications.insert(0, NotificationModel(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Registration Confirmed! 🎉',
        body: 'You have registered for ${post.title}. Keep an eye on updates.',
        category: NotificationCategory.events,
        timestamp: DateTime.now(),
        relatedPostId: post.id,
      ));
    }

    _posts[index] = post.copyWith(registeredUserIds: regUsers);
    currentUser = currentUser.copyWith(registeredEventIds: userRegEvents);
    notifyListeners();
  }

  void addPost(PostModel newPost) {
    _posts.insert(0, newPost);
    notifyListeners();
  }

  void deletePost(String postId) {
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  // --- Role Request Actions ---
  void submitRoleRequest({
    required UserRole requestedRole,
    required String reason,
    required String phoneNumber,
    bool isLimitedAccess = false,
    int? durationDays,
  }) {
    final newReq = RoleRequestModel(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      userId: currentUser.id,
      userName: currentUser.name,
      userEmail: currentUser.email,
      department: currentUser.department,
      studentId: currentUser.studentOrEmployeeId,
      requestedRole: requestedRole,
      reason: reason,
      phoneNumber: phoneNumber,
      submittedAt: DateTime.now(),
      isLimitedAccess: isLimitedAccess,
      durationDays: durationDays,
    );

    _roleRequests.insert(0, newReq);
    
    // Add notification for user
    _notifications.insert(0, NotificationModel(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Role Application Submitted',
      body: isLimitedAccess
          ? 'Your request for ${requestedRole.displayName} status (temporary, until ${_formatDate(newReq.expiresAt!)}) has been sent to Admin for review.'
          : 'Your request for ${requestedRole.displayName} status has been sent to Admin for review.',
      category: NotificationCategory.personal,
      timestamp: DateTime.now(),
    ));

    notifyListeners();
  }

  void updateRoleRequestStatus(String requestId, RoleRequestStatus status, String? notes) {
    int idx = _roleRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;

    RoleRequestModel req = _roleRequests[idx];
    _roleRequests[idx] = req.copyWith(status: status, adminNotes: notes);

    if (status == RoleRequestStatus.approved) {
      if (req.userId == currentUser.id) {
        List<UserRole> updatedRoles = List.from(currentUser.roles);
        Map<UserRole, DateTime> updatedExpirations = Map.from(currentUser.roleExpirations);
        if (!updatedRoles.contains(req.requestedRole)) {
          updatedRoles.add(req.requestedRole);
          if (req.isLimitedAccess && req.expiresAt != null) {
            updatedExpirations[req.requestedRole] = req.expiresAt!;
          }
          currentUser = currentUser.copyWith(
            roles: updatedRoles,
            roleExpirations: updatedExpirations,
          );
        }
      }
      _notifications.insert(0, NotificationModel(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Role Approved! 🎖️',
        body: req.isLimitedAccess && req.expiresAt != null
            ? 'Congratulations! Your temporary ${req.requestedRole.displayName} access is approved until ${_formatDate(req.expiresAt!)}.'
            : 'Congratulations! Your application for ${req.requestedRole.displayName} was approved.',
        category: NotificationCategory.personal,
        timestamp: DateTime.now(),
      ));
    } else if (status == RoleRequestStatus.rejected) {
      _notifications.insert(0, NotificationModel(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Role Application Update',
        body: 'Your application for ${req.requestedRole.displayName} was reviewed.',
        category: NotificationCategory.personal,
        timestamp: DateTime.now(),
      ));
    }

    notifyListeners();
  }

  void markNotificationRead(String notifId) {
    int idx = _notifications.indexWhere((n) => n.id == notifId);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllNotificationsRead() {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  void checkForExpiredRoles() {
    final expirations = currentUser.roleExpirations;
    if (expirations.isEmpty) return;

    final now = DateTime.now();
    final expiredRoles = expirations.entries
        .where((e) => e.value.isBefore(now))
        .map((e) => e.key)
        .toList();

    if (expiredRoles.isEmpty) return;

    List<UserRole> updatedRoles = List.from(currentUser.roles)..removeWhere(expiredRoles.contains);
    Map<UserRole, DateTime> updatedExpirations = Map.from(expirations)..removeWhere((role, _) => expiredRoles.contains(role));

    currentUser = currentUser.copyWith(
      roles: updatedRoles,
      roleExpirations: updatedExpirations,
    );

    if (expiredRoles.contains(activeRole)) {
      activeRole = currentUser.roles.isNotEmpty ? currentUser.roles.first : UserRole.student;
    }

    for (final role in expiredRoles) {
      _notifications.insert(0, NotificationModel(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        title: '${role.displayName} Access Expired ⏳',
        body: 'Your temporary ${role.displayName} access period has ended. You are now back to Student view. Your hosted events remain on the campus feed.',
        category: NotificationCategory.personal,
        timestamp: now,
      ));
    }

    notifyListeners();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  // --- Initial Mock Data Generators ---
  void _generateMockPosts() {
    final now = DateTime.now();
    _posts = [
      PostModel(
        id: 'pst_001',
        title: '🔥 Urgent: Mid-Semester Exam Schedule Revision (Autumn 2026)',
        description: 'All 3rd and 4th year CSE & IT students must review the revised examination timetable. Exams start on Monday at 09:00 AM in Block C.',
        category: PostCategory.urgent,
        department: 'Computer Science & Engineering',
        targetYear: 'Third Year',
        authorName: 'Dr. Ramesh K. Verma (Dean Academics)',
        authorRole: UserRole.faculty,
        authorId: 'fac_101',
        timestamp: now.subtract(const Duration(hours: 2)),
        isUrgent: true,
        isPinned: true,
        attachments: [
          PostAttachment(
            title: 'Mid_Sem_Exam_Schedule_Autumn2026.pdf',
            fileType: 'pdf',
            url: 'mock_pdf_exam.pdf',
            fileSize: '1.4 MB',
          ),
        ],
        saveCount: 142,
      ),
      PostModel(
        id: 'pst_002',
        title: '🚀 HackCampus 2026: 24-Hour Flagship Hackathon',
        description: 'Join over 500+ student developers, designers, and innovators! Build groundbreaking AI & Campus IoT solutions with prize pools up to \$5,000.',
        category: PostCategory.event,
        department: 'Computer Science & Engineering',
        authorName: 'Dev Society (Host: Aarav S.)',
        authorRole: UserRole.eventHost,
        authorId: 'usr_101',
        timestamp: now.subtract(const Duration(hours: 5)),
        imageUrl: 'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?auto=format&fit=crop&q=80&w=800',
        venue: 'Main Auditorium & Innovation Lab',
        eventDate: now.add(const Duration(days: 4)),
        registrationDeadline: now.add(const Duration(days: 2)),
        maxParticipants: 300,
        registeredUserIds: ['usr_101', 'usr_102', 'usr_103'],
        saveCount: 88,
      ),
      PostModel(
        id: 'pst_003',
        title: '📚 Academic Notice: Elective Selection Guidelines for Final Year',
        description: 'Please submit your preferences for Open Elective Course III before Friday 5:00 PM. Access the student portal to review syllabus descriptions.',
        category: PostCategory.academic,
        department: 'Information Technology',
        targetYear: 'Final Year',
        authorName: 'Prof. Ananya Sen',
        authorRole: UserRole.faculty,
        authorId: 'fac_102',
        timestamp: now.subtract(const Duration(days: 1)),
        attachments: [
          PostAttachment(
            title: 'Open_Elective_Syllabus_2026.pdf',
            fileType: 'pdf',
            url: 'mock_pdf_elective.pdf',
            fileSize: '2.8 MB',
          ),
        ],
        saveCount: 45,
      ),
      PostModel(
        id: 'pst_004',
        title: '🤖 Hands-on Workshop: Flutter & Mobile AI Apps',
        description: 'Learn to build modern cross-platform mobile apps with Flutter, Supabase backend, and local AI model integration. Prerequisites: Basic OOP concepts.',
        category: PostCategory.workshop,
        department: 'Computer Science & Engineering',
        authorName: 'Mobile Dev Club',
        authorRole: UserRole.eventHost,
        authorId: 'host_202',
        timestamp: now.subtract(const Duration(days: 1, hours: 4)),
        imageUrl: 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&q=80&w=800',
        venue: 'CS Lab 302',
        eventDate: now.add(const Duration(days: 6)),
        registrationDeadline: now.add(const Duration(days: 3)),
        maxParticipants: 60,
        registeredUserIds: ['usr_105'],
        saveCount: 94,
      ),
      PostModel(
        id: 'pst_005',
        title: '🏆 Campus Sports Squad Wins Inter-College Basketball Trophy!',
        description: 'Hearty congratulations to the MIT Eagles Basketball team for taking 1st place in the State Inter-University Championship 2026!',
        category: PostCategory.achievement,
        department: 'Management Studies',
        authorName: 'Sports Directorate',
        authorRole: UserRole.admin,
        authorId: 'adm_001',
        timestamp: now.subtract(const Duration(days: 2)),
        imageUrl: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&q=80&w=800',
        saveCount: 156,
      ),
      PostModel(
        id: 'pst_006',
        title: '💼 Campus Placement Drive: Google Cloud & Microsoft Tech Roles',
        description: 'Eligible 4th year CSE, IT, and ECE students can register for upcoming technical interviews. Minimum CGPA required: 7.5.',
        category: PostCategory.placement,
        department: 'Electronics & Communication',
        targetYear: 'Final Year',
        authorName: 'Placement Cell',
        authorRole: UserRole.faculty,
        authorId: 'fac_103',
        timestamp: now.subtract(const Duration(days: 2, hours: 8)),
        attachments: [
          PostAttachment(
            title: 'Placement_Drive_Eligibility_Details.pdf',
            fileType: 'pdf',
            url: 'placement_details.pdf',
            fileSize: '890 KB',
          ),
        ],
        saveCount: 210,
      )
    ];
  }

  void _generateMockRoleRequests() {
    _roleRequests = [
      RoleRequestModel(
        id: 'req_101',
        userId: 'usr_104',
        userName: 'Rohan Gupta',
        userEmail: 'rohan.gupta@studenthub.edu',
        department: 'Electronics & Communication',
        studentId: 'MIT/EC/2024/019',
        requestedRole: UserRole.eventHost,
        reason: 'I am the president of Robotics Club and need permissions to post robotics competitions and workshops for students.',
        phoneNumber: '+91 99887 76655',
        submittedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      RoleRequestModel(
        id: 'req_102',
        userId: 'usr_108',
        userName: 'Prof. Meera Malhotra',
        userEmail: 'meera.m@studenthub.edu',
        department: 'Management Studies',
        studentId: 'EMP/FAC/704',
        requestedRole: UserRole.faculty,
        reason: 'Need faculty access to publish official departmental seminar notices and guest speaker updates.',
        phoneNumber: '+91 91234 56789',
        submittedAt: DateTime.now().subtract(const Duration(hours: 8)),
      )
    ];
  }

  void _generateMockNotifications() {
    final now = DateTime.now();
    _notifications = [
      NotificationModel(
        id: 'notif_001',
        title: '🔥 Urgent Notice Published',
        body: 'Mid-Semester Exam Schedule Revision posted for your department.',
        category: NotificationCategory.academic,
        timestamp: now.subtract(const Duration(hours: 2)),
        relatedPostId: 'pst_001',
      ),
      NotificationModel(
        id: 'notif_002',
        title: '🚀 HackCampus 2026 Event Tomorrow',
        body: 'Don\'t forget your registration deadline is in 2 days.',
        category: NotificationCategory.events,
        timestamp: now.subtract(const Duration(hours: 5)),
        relatedPostId: 'pst_002',
      ),
      NotificationModel(
        id: 'notif_003',
        title: 'Welcome to StudentHub!',
        body: 'Personalized updates for CS Third Year loaded.',
        category: NotificationCategory.general,
        timestamp: now.subtract(const Duration(days: 3)),
      )
    ];
  }
}
