import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/admin_user_model.dart';
import '../models/role_request_model.dart';
import '../models/reported_content_model.dart';

class AdminSupabaseService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  /// Verified server-side by the verify-admin edge function during login.
  /// Attached to admin-only edge function calls so the server can re-check
  /// the admin role on every sensitive operation.
  String adminUserId = '';

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<AdminUserModel> _allUsers = [];
  List<AdminUserModel> get allUsers => _allUsers;

  List<AdminUserModel> _admins = [];
  List<AdminUserModel> get admins => _admins;

  List<AdminUserModel> _onlineUsers = [];
  List<AdminUserModel> get onlineUsers => _onlineUsers;

  List<RoleRequestModel> _roleRequests = [];
  List<RoleRequestModel> get roleRequests => _roleRequests;

  List<ReportedContentModel> _reportedPosts = [];
  List<ReportedContentModel> get reportedPosts => _reportedPosts;

  // Persistent set of deleted user IDs to prevent re-appearance
  final Set<String> _deletedUserIds = {};

  RealtimeChannel? _presenceChannel;

  AdminSupabaseService() {
    _initPresenceTracker();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Posts to an admin-only edge function with the shared secret. Sensitive
  /// operations verify the caller's admin role server-side (adminUserId).
  Future<http.Response> _callAdminFunction(
    String url,
    Map<String, dynamic> body,
  ) async {
    return http
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'apikey': SupabaseConfig.anonKey,
            'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
            if (SupabaseConfig.pushSecret.isNotEmpty)
              'X-Push-Secret': SupabaseConfig.pushSecret,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
  }

  // --- 1. Realtime Online Presence Tracker ---
  void _initPresenceTracker() {
    try {
      _presenceChannel = _client.channel('online-students');
      _presenceChannel?.onPresenceSync((_) {
        refreshOnlinePresence();
      }).subscribe();
    } catch (e) {
      debugPrint('Presence tracking init warning: $e');
    }
  }

  void refreshOnlinePresence() {
    if (_presenceChannel == null) return;
    try {
      final state = _presenceChannel!.presenceState();
      final List<AdminUserModel> active = [];

      // Each entry is one connected socket; its presences carry the payload
      // the mobile app tracked (the user profile).
      for (final entry in state) {
        for (final presence in entry.presences) {
          final payload = presence.payload;
          if (payload.containsKey('id') || payload.containsKey('user_id')) {
            final u = AdminUserModel.fromMap(Map<String, dynamic>.from(payload));
            if (!_deletedUserIds.contains(u.id) && !u.isDeleted) {
              active.add(u);
            }
          }
        }
      }

      _onlineUsers = active;
      notifyListeners();
    } catch (e) {
      debugPrint('Sync presence error: $e');
    }
  }

  // --- 2. User & Student Lookup Management ---
  Future<void> fetchUsers({String? searchQuery}) async {
    _setLoading(true);
    try {
      var query = _client.from('profiles').select();
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('name.ilike.%$searchQuery%,email.ilike.%$searchQuery%,student_or_employee_id.ilike.%$searchQuery%');
      }

      dynamic response;
      try {
        response = await query
            .order('updated_at', ascending: false)
            .timeout(const Duration(seconds: 12));
      } catch (_) {
        response = await query
            .timeout(const Duration(seconds: 12));
      }

      final List<dynamic> data = response as List<dynamic>;

      _allUsers = data
          .map((json) => AdminUserModel.fromMap(json))
          .where((u) =>
              !_deletedUserIds.contains(u.id) &&
              !u.isDeleted &&
              u.role != 'deleted' &&
              !u.roles.contains('admin'))
          .toList();
    } catch (e) {
      debugPrint('Fetch users error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Admin accounts (profiles carrying the `admin` role) — shown in the
  /// dedicated Admins tab instead of the user directory.
  Future<void> fetchAdmins() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .contains('roles', ['admin'])
          .order('updated_at', ascending: false)
          .timeout(const Duration(seconds: 12));

      final List<dynamic> data = response as List<dynamic>;
      _admins = data
          .map((json) => AdminUserModel.fromMap(json))
          .where((u) => !_deletedUserIds.contains(u.id) && !u.isDeleted)
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Fetch admins error: $e');
      _admins = [];
      notifyListeners();
    }
  }

  Future<bool> toggleVerifyStudent(String userId, bool currentStatus) async {
    try {
      // Server-side with admin verification; anon clients cannot flip
      // verification flags directly anymore.
      final res = await _callAdminFunction(
        SupabaseConfig.adminActionsFunctionUrl,
        {
          'admin_user_id': adminUserId,
          'action': 'verify_student',
          'user_id': userId,
        },
      );
      if (res.statusCode != 200) {
        debugPrint('Toggle verify rejected: ${res.statusCode} ${res.body}');
        return false;
      }

      await fetchUsers();
      return true;
    } catch (e) {
      debugPrint('Toggle verify student error: $e');
      return false;
    }
  }

  Future<bool> updateUserRole(String userId, String newRole) async {
    try {
      final roleKey = newRole.toLowerCase();
      List<String> targetRoles = ['student'];
      if (roleKey == 'host' || roleKey == 'eventhost' || roleKey == 'event_host') {
        targetRoles = ['student', 'host'];
      } else if (roleKey == 'faculty') {
        targetRoles = ['faculty'];
      }

      // Server-side: the function re-verifies the caller's admin role before
      // granting anything. Anon clients can no longer mutate roles at all
      // (see guard_profiles_roles trigger).
      final res = await _callAdminFunction(
        SupabaseConfig.adminActionsFunctionUrl,
        {
          'admin_user_id': adminUserId,
          'action': 'set_roles',
          'user_id': userId,
          'roles': targetRoles,
        },
      );
      if (res.statusCode != 200) {
        debugPrint('Update user role rejected: ${res.statusCode} ${res.body}');
        return false;
      }

      await fetchUsers();
      return true;
    } catch (e) {
      debugPrint('Update user role error: $e');
      return false;
    }
  }

  Future<bool> removeUserRoleWithNotice(String userId, String userName) async {
    try {
      // 1. Revert user role to student — server-side with admin verification.
      final res = await _callAdminFunction(
        SupabaseConfig.adminActionsFunctionUrl,
        {
          'admin_user_id': adminUserId,
          'action': 'set_roles',
          'user_id': userId,
          'roles': ['student'],
        },
      );
      if (res.statusCode != 200) {
        debugPrint('Remove user role rejected: ${res.statusCode} ${res.body}');
        return false;
      }

      // 2. Dispatch push notification to user
      try {
        final push = await http.post(
          Uri.parse(SupabaseConfig.pushFunctionUrl),
          headers: {
            'Content-Type': 'application/json',
            'apikey': SupabaseConfig.anonKey,
            'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
            if (SupabaseConfig.pushSecret.isNotEmpty)
              'X-Push-Secret': SupabaseConfig.pushSecret,
          },
          body: jsonEncode({
            'post_id': 'role_removal_${DateTime.now().millisecondsSinceEpoch}',
            'title': 'Role Status Updated',
            'body': 'Your role has been removed, you can contact if you have any query.',
            'recipient_user_id': userId,
            'category': 'personal',
            'type': 'role_removal',
          }),
        );
        if (push.statusCode < 200 || push.statusCode >= 300) {
          debugPrint('Role removal push failed: ${push.statusCode} ${push.body}');
        }
      } catch (e) {
        debugPrint('Push role removal notice error: $e');
      }

      await fetchUsers();
      return true;
    } catch (e) {
      debugPrint('Remove user role error: $e');
      return false;
    }
  }

  Future<bool> toggleBanUser(String userId, bool targetBannedState) async {
    try {
      // Server-side ban/unban: the function re-verifies the caller's admin
      // role before touching roles (guard_profiles_roles trigger blocks anon
      // writes entirely).
      final res = await _callAdminFunction(
        SupabaseConfig.adminActionsFunctionUrl,
        {
          'admin_user_id': adminUserId,
          'action': targetBannedState ? 'ban' : 'unban',
          'user_id': userId,
        },
      );
      if (res.statusCode != 200) {
        debugPrint('Toggle ban rejected: ${res.statusCode} ${res.body}');
        return false;
      }

      if (targetBannedState) {
        // Dispatch Ban push notification
        try {
          final push = await http.post(
            Uri.parse(SupabaseConfig.pushFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              if (SupabaseConfig.pushSecret.isNotEmpty)
                'X-Push-Secret': SupabaseConfig.pushSecret,
            },
            body: jsonEncode({
              'post_id': 'ban_${DateTime.now().millisecondsSinceEpoch}',
              'title': 'Account Suspended 🚫',
              'body': 'Your account has been suspended by Administrator. You cannot access features until resolved.',
              'recipient_user_id': userId,
              'category': 'personal',
              'type': 'account_ban',
            }),
          );
          if (push.statusCode < 200 || push.statusCode >= 300) {
            debugPrint('Ban push failed: ${push.statusCode} ${push.body}');
          }
        } catch (e) {
          debugPrint('Push ban notice error: $e');
        }
      } else {
        // Dispatch Unban push notification
        try {
          final push = await http.post(
            Uri.parse(SupabaseConfig.pushFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              if (SupabaseConfig.pushSecret.isNotEmpty)
                'X-Push-Secret': SupabaseConfig.pushSecret,
            },
            body: jsonEncode({
              'post_id': 'unban_${DateTime.now().millisecondsSinceEpoch}',
              'title': 'Account Restored! 🎉',
              'body': 'Your account has been unbanned by Administrator. You now have full access to StudentHub.',
              'recipient_user_id': userId,
              'category': 'personal',
              'type': 'account_unban',
            }),
          );
          if (push.statusCode < 200 || push.statusCode >= 300) {
            debugPrint('Unban push failed: ${push.statusCode} ${push.body}');
          }
        } catch (e) {
          debugPrint('Push unban notice error: $e');
        }
      }

      // Update local state immediately
      final index = _allUsers.indexWhere((u) => u.id == userId);
      if (index != -1) {
        final old = _allUsers[index];
        _allUsers[index] = AdminUserModel(
          id: old.id,
          email: old.email,
          fullName: old.fullName,
          avatarUrl: old.avatarUrl,
          role: targetBannedState ? 'banned' : 'student',
          studentId: old.studentId,
          branch: old.branch,
          year: old.year,
          mobileNumber: old.mobileNumber,
          isVerifiedStudent: old.isVerifiedStudent,
          isBanned: targetBannedState,
          isDeleted: old.isDeleted,
          lastSeen: old.lastSeen,
          createdAt: old.createdAt,
        );
        notifyListeners();
      }

      await fetchUsers();
      return true;
    } catch (e) {
      debugPrint('Toggle ban user error: $e');
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    // Permanent server-side deletion runs through the delete-user Edge
    // Function (service role): it removes device tokens, form submissions,
    // role requests, the user's posts, push log entries, reports and finally
    // the profile row (cascading password credentials). The function now also
    // verifies the caller's admin role before deleting. The local UI list is
    // only updated AFTER the server confirms.
    try {
      final res = await _callAdminFunction(
        SupabaseConfig.deleteUserFunctionUrl,
        {
          'user_id': userId,
          'admin_user_id': adminUserId,
        },
      );

      if (res.statusCode != 200) {
        debugPrint('Delete user rejected: ${res.statusCode} ${res.body}');
        return false;
      }

      _deletedUserIds.add(userId);
      _allUsers.removeWhere((u) => u.id == userId);
      _onlineUsers.removeWhere((u) => u.id == userId);
      notifyListeners();
      await fetchUsers();
      return true;
    } catch (e) {
      debugPrint('Delete user error: $e');
      return false;
    }
  }

  // --- 3. Role Approval Requests Queue ---
  Future<void> fetchRoleRequests() async {
    _setLoading(true);
    try {
      final response = await _client
          .from('role_requests')
          .select()
          .order('submitted_at', ascending: false)
          .timeout(const Duration(seconds: 12));

      final List<dynamic> data = response as List<dynamic>;
      _roleRequests = data
          .map((json) => RoleRequestModel.fromMap(json))
          .where((r) => !_deletedUserIds.contains(r.userId))
          .toList();
    } catch (e) {
      debugPrint('Fetch role requests error: $e');
      _roleRequests = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> reviewRoleRequest({
    required String requestId,
    required String userId,
    required String targetRole,
    required bool approve,
    String? note,
  }) async {
    try {
      // Server-side review: the function verifies the caller's admin role,
      // updates the request status, and seeds the granted role into the
      // applicant's profiles row (creating it if the applicant has none).
      final res = await _callAdminFunction(
        SupabaseConfig.reviewRoleFunctionUrl,
        {
          'request_id': requestId,
          'admin_user_id': adminUserId,
          'status': approve ? 'approved' : 'rejected',
          'notes': note,
        },
      );
      if (res.statusCode != 200) {
        debugPrint('Review role request rejected: ${res.statusCode} ${res.body}');
        return false;
      }

      await fetchRoleRequests();
      await fetchUsers();
      return true;
    } catch (e) {
      debugPrint('Review role request error: $e');
      return false;
    }
  }

  // --- 4. Content Moderation & Announcements ---
  Future<void> fetchReportedContent() async {
    _setLoading(true);
    try {
      final response = await _client
          .from('reported_posts')
          .select()
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 12));

      final List<dynamic> data = response as List<dynamic>;
      _reportedPosts = data.map((json) => ReportedContentModel.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Fetch reported content error: $e');
      _reportedPosts = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deletePost(String postId, String reportId) async {
    try {
      // Server-side moderation delete: the function verifies the caller's
      // admin role before deleting (anon clients cannot delete posts directly
      // via the client anymore).
      final res = await _callAdminFunction(
        SupabaseConfig.deleteFunctionUrl,
        {
          'post_id': postId,
          'admin_user_id': adminUserId,
        },
      );
      if (res.statusCode != 200) {
        debugPrint('Moderation delete rejected: ${res.statusCode} ${res.body}');
        return false;
      }

      await _client.from('reported_posts').update({'status': 'resolved'}).eq('id', reportId);
      await fetchReportedContent();
      return true;
    } catch (e) {
      debugPrint('Delete post error: $e');
      return false;
    }
  }

  Future<bool> dismissReport(String reportId) async {
    try {
      await _client.from('reported_posts').update({'status': 'dismissed'}).eq('id', reportId);
      await fetchReportedContent();
      return true;
    } catch (e) {
      debugPrint('Dismiss report error: $e');
      return false;
    }
  }

  // --- 5. Broadcast Push Announcements (Push Notification Only - No Feed Post) ---
  Future<bool> sendBroadcastAnnouncement({
    required String title,
    required String body,
    String? targetBranch,
    String? targetYear,
  }) async {
    try {
      final notifId = 'announcement_${DateTime.now().millisecondsSinceEpoch}';

      // Send push notification via Supabase Edge Function without posting to feed
      final res = await http.post(
        Uri.parse(SupabaseConfig.pushFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          if (SupabaseConfig.pushSecret.isNotEmpty)
            'X-Push-Secret': SupabaseConfig.pushSecret,
        },
        body: jsonEncode({
          'post_id': notifId,
          'title': title,
          'body': body,
          'category': 'announcement',
          'author_id': 'admin_official',
          'device_id': 'admin_panel',
          'type': 'announcement',
          'skip_sender_device': false,
          'target_branch': targetBranch ?? 'ALL',
          'target_year': targetYear ?? 'ALL',
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('Push Edge Function status: ${res.statusCode} ${res.body}');
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Broadcast notification error: $e');
      return false;
    }
  }

  // --- 6. Admin Password Reset / Wipe ---
  Future<({bool success, String message})> adminResetUserPassword({
    required String email,
    String? newPassword,
    bool clearPassword = false,
  }) async {
    try {
      final action = clearPassword ? 'admin_clear_password' : 'admin_reset_password';
      final res = await _callAdminFunction(
        SupabaseConfig.accountCredentialsFunctionUrl,
        {
          'action': action,
          'email': email,
          'password': newPassword ?? '123456',
          'device_id': 'admin_panel',
        },
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        return (
          success: true,
          message: data['message']?.toString() ?? 'Password updated successfully.',
        );
      } else {
        return (
          success: false,
          message: 'Server responded with code ${res.statusCode}: ${res.body}',
        );
      }
    } catch (e) {
      debugPrint('adminResetUserPassword error: $e');
      return (success: false, message: e.toString());
    }
  }

  @override
  void dispose() {
    _presenceChannel?.unsubscribe();
    super.dispose();
  }
}
