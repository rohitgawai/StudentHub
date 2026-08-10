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

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<AdminUserModel> _allUsers = [];
  List<AdminUserModel> get allUsers => _allUsers;

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

  // --- 1. Realtime Online Presence Tracker ---
  void _initPresenceTracker() {
    try {
      _presenceChannel = _client.channel('online-students');
      _presenceChannel?.onPresenceSync((_) {
        _syncOnlinePresence();
      }).subscribe();
    } catch (e) {
      debugPrint('Presence tracking init warning: $e');
    }
  }

  void _syncOnlinePresence() {
    if (_presenceChannel == null) return;
    try {
      final state = _presenceChannel!.presenceState();
      final List<AdminUserModel> active = [];

      for (dynamic presenceObj in state) {
        if (presenceObj is Map) {
          if (presenceObj.containsKey('id') || presenceObj.containsKey('user_id')) {
            final u = AdminUserModel.fromMap(Map<String, dynamic>.from(presenceObj));
            if (!_deletedUserIds.contains(u.id) && !u.isDeleted) {
              active.add(u);
            }
          }
        } else {
          try {
            final payload = (presenceObj as dynamic).payload;
            if (payload != null && payload is Map && (payload.containsKey('id') || payload.containsKey('user_id'))) {
              final u = AdminUserModel.fromMap(Map<String, dynamic>.from(payload));
              if (!_deletedUserIds.contains(u.id) && !u.isDeleted) {
                active.add(u);
              }
            }
          } catch (_) {}
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
        response = await query.order('updated_at', ascending: false);
      } catch (_) {
        response = await query;
      }

      final List<dynamic> data = response as List<dynamic>;

      _allUsers = data
          .map((json) => AdminUserModel.fromMap(json))
          .where((u) => !_deletedUserIds.contains(u.id) && !u.isDeleted && u.role != 'deleted')
          .toList();

      // Only include online presence users
      if (_presenceChannel == null || _onlineUsers.isEmpty) {
        _onlineUsers = _allUsers.where((u) => u.isOnline).toList();
      }
    } catch (e) {
      debugPrint('Fetch users error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> toggleVerifyStudent(String userId, bool currentStatus) async {
    try {
      await _client.from('profiles').update({
        'is_verified': !currentStatus,
      }).eq('user_id', userId);

      await fetchUsers();
      return true;
    } catch (e) {
      debugPrint('Toggle verify student error: $e');
      return false;
    }
  }

  Future<bool> updateUserRole(String userId, String newRole) async {
    try {
      await _client.from('profiles').update({
        'roles': [newRole],
      }).eq('user_id', userId);

      await fetchUsers();
      return true;
    } catch (e) {
      debugPrint('Update user role error: $e');
      return false;
    }
  }

  Future<bool> removeUserRoleWithNotice(String userId, String userName) async {
    try {
      // 1. Revert user role to student
      await _client.from('profiles').update({
        'roles': ['student'],
      }).eq('user_id', userId);

      // 2. Dispatch push notification to user
      try {
        await http.post(
          Uri.parse(SupabaseConfig.pushFunctionUrl),
          headers: {
            'Content-Type': 'application/json',
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
      final newRoles = targetBannedState ? ['banned'] : ['student'];

      try {
        await _client.from('profiles').update({
          'roles': newRoles,
        }).eq('user_id', userId);
      } catch (_) {}

      try {
        await _client.from('profiles').update({
          'is_banned': targetBannedState,
        }).eq('user_id', userId);
      } catch (_) {}

      if (targetBannedState) {
        // Dispatch Ban notification
        try {
          await http.post(
            Uri.parse(SupabaseConfig.pushFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Push-Secret': SupabaseConfig.pushSecret,
            },
            body: jsonEncode({
              'post_id': 'ban_${DateTime.now().millisecondsSinceEpoch}',
              'title': 'Account Suspended',
              'body': 'You are banned, so you cant use any features.',
              'recipient_user_id': userId,
              'category': 'personal',
              'type': 'account_ban',
            }),
          );
        } catch (e) {
          debugPrint('Push ban notice error: $e');
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
    // Mark as deleted in local set & remove immediately from active UI lists
    _deletedUserIds.add(userId);
    _allUsers.removeWhere((u) => u.id == userId);
    _onlineUsers.removeWhere((u) => u.id == userId);
    notifyListeners();

    try {
      // 1. Delete user role requests
      try {
        await _client.from('role_requests').delete().eq('user_id', userId);
      } catch (_) {}

      // 2. Mark profile roles as deleted to prevent re-upsert from mobile app sync
      try {
        await _client.from('profiles').update({
          'roles': ['deleted'],
          'name': '[DELETED USER]',
        }).eq('user_id', userId);
      } catch (_) {}

      // 3. Delete user profile from profiles table
      try {
        await _client.from('profiles').delete().eq('user_id', userId);
      } catch (e) {
        debugPrint('DB delete notice: $e');
      }

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
          .order('created_at', ascending: false);

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
      final status = approve ? 'approved' : 'rejected';
      
      await _client.from('role_requests').update({
        'status': status,
        'review_notes': note ?? (approve ? 'Approved by Admin' : 'Rejected by Admin'),
      }).eq('id', requestId);

      if (approve) {
        await _client.from('profiles').update({
          'roles': [targetRole],
        }).eq('user_id', userId);
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
          .order('created_at', ascending: false);

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
      await _client.from('posts').delete().eq('id', postId);
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
      return true;
    } catch (e) {
      debugPrint('Broadcast notification error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _presenceChannel?.unsubscribe();
    super.dispose();
  }
}
