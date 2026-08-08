import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../config/supabase_config.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/role_request_model.dart';
import '../models/notification_model.dart';
import '../models/active_announcement_model.dart';
import 'local_store_service.dart';

class MockDataService extends ChangeNotifier {
  late AppConfig config;
  late UserModel currentUser;
  late UserRole activeRole;

  List<PostModel> _posts = [];
  List<RoleRequestModel> _roleRequests = [];
  List<NotificationModel> _notifications = [];
  List<ActiveAnnouncement> _announcements = [];

  /// Post ids this device has confirmed exist on the server. The server is
  /// authoritative for them: they are never re-uploaded from a stale local
  /// copy (which resurrects deleted posts), and when the server stops
  /// returning one it is removed from the local feed.
  final Set<String> _serverKnownIds = {};

  /// Posts created while the backend was unreachable. They stay on-device
  /// ONLY: they are never uploaded on a later sync, so an offline draft can
  /// never resurface on the server (and on other devices' feeds).
  /// Persisted with the snapshot so the guarantee survives restarts.
  final Set<String> _deviceOnlyPostIds = {};

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Timer? _expiryTimer;
  Timer? _syncTimer;
  bool _syncInFlight = false;

  // --- Rebuild caches -------------------------------------------------------
  //
  // The data lists are mutated in place, so widget-level `context.select`
  // subscriptions need a stable *instance* whose identity changes exactly when
  // the underlying data changes. These caches provide that, and also memoize
  // the personalized feed so builds don't re-copy/re-sort unless inputs change.
  int _dataVersion = 0;
  List<PostModel> _cachePosts = const [];
  List<RoleRequestModel> _cacheRoleRequests = const [];
  List<NotificationModel> _cacheNotifications = const [];
  List<ActiveAnnouncement> _cacheAnnouncements = const [];
  String? _feedCacheKey;
  List<PostModel>? _feedCacheValue;

  void _invalidateDataCaches() {
    _dataVersion++;
    _feedCacheKey = null;
    _feedCacheValue = null;
    _cachePosts = List.unmodifiable(_posts);
    _cacheRoleRequests = List.unmodifiable(_roleRequests);
    _cacheNotifications = List.unmodifiable(_notifications);
    _cacheAnnouncements = List.unmodifiable(
      _announcements.where((a) => !a.isExpired),
    );
  }

  List<PostModel> get posts => _cachePosts;
  List<RoleRequestModel> get roleRequests => _cacheRoleRequests;
  List<NotificationModel> get notifications => _cacheNotifications;
  List<ActiveAnnouncement> get activeAnnouncements => _cacheAnnouncements;

  MockDataService({AppConfig? initialConfig}) {
    config = initialConfig ?? AppConfig.defaultConfig();
    _seedDefaults();
    _invalidateDataCaches();
    _initData(initialConfig);
  }
  @override
  void dispose() {
    _expiryTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _initData(AppConfig? initialConfig) async {
    if (initialConfig == null) {
      AppConfig.loadFromAssets().then((c) {
        config = c;
        _invalidateDataCaches();
        notifyListeners();
      });
    }

    final restored = await _loadLocalState();

    if (restored != null) {
      currentUser = restored.currentUser;
      activeRole =
          restored.activeRole ??
          (currentUser.roles.isNotEmpty
              ? currentUser.roles.first
              : UserRole.student);
      _posts = restored.posts;
      _notifications = restored.notifications;
      _roleRequests = restored.roleRequests;
      _announcements = restored.announcements;
      _serverKnownIds
        ..clear()
        ..addAll(restored.serverKnownIds);
      _deviceOnlyPostIds
        ..clear()
        ..addAll(restored.deviceOnlyPostIds);
      checkForExpiredRoles();
      _invalidateDataCaches();
      notifyListeners();
    }

    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      checkForExpiredRoles();
      _clearExpiredAnnouncements();
    });

    // Lightweight polling: keeps the in-app notification bell fresh with posts
    // published by other devices without the user pulling to refresh.
    _syncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_periodicSync());
    });

    _isLoading = false;
    _invalidateDataCaches();
    notifyListeners();
  }

  Future<void> _periodicSync() async {
    if (_syncInFlight) return;
    _syncInFlight = true;
    try {
      await syncNow();
    } finally {
      _syncInFlight = false;
    }
  }

  /// Merges the Supabase mirror into the device state (background; safe to
  /// call repeatedly). Only notifies listeners when something actually
  /// changed, so the periodic poll is silent when the feed is unchanged.
  Future<void> syncNow() async {
    final result = await _syncFromBackend();
    if (result.changed) {
      _invalidateDataCaches();
      notifyListeners();
    }
  }

  Future<void> _seedDefaults() async {
    // Default Current User (Student with Event Host capability or standard student)
    currentUser = UserModel(
      id: 'usr_101',
      name: 'Aarav Sharma',
      email: 'aarav.sharma@studenthub.edu',
      studentOrEmployeeId: 'MIT/CS/2023/042',
      department: 'Computer Science & Engineering',
      year: 'Third Year',
      mobileNumber: '+91 98765 12345',
      avatarUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=256',
      roles: [UserRole.student, UserRole.eventHost],
      savedPostIds: ['pst_002', 'pst_004'],
      registeredEventIds: ['pst_002'],
      congratulatedPostIds: ['pst_005'],
      isVerified: true,
    );

    activeRole = currentUser.roles.first;

    _generateMockPosts();
    _generateMockRoleRequests();
    _generateMockNotifications();
    _seedDefaultAnnouncement();
  }

  // --- On-device persistence ---

  LocalStoreService get _localStore => LocalStoreService.instance;

  final bool _localPersistEnabled = true;

  Timer? _saveDebounce;
  bool _saving = false;
  bool _saveDirty = false;

  /// Schedules the on-device snapshot. Debounced so rapid mutations (role
  /// switches, save toggles, typing) collapse into a single disk write, and
  /// serialized so overlapping saves can't pile up on the event loop.
  void _scheduleLocalSave() {
    if (!_localPersistEnabled) return;
    _saveDirty = true;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _flushLocalSave);
  }

  /// Cancels any pending debounce and persists immediately. Exposed so tests
  /// (and lifecycle teardown) can deterministically flush state without
  /// leaving a dangling timer behind.
  Future<void> flushLocalSave() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    await _flushLocalSave();
  }

  Future<void> _flushLocalSave() async {
    if (_saving) return;
    _saveDebounce = null;
    _saving = true;
    _saveDirty = false;
    try {
      await _saveLocalState();
    } finally {
      _saving = false;
      if (_saveDirty) {
        _saveDebounce?.cancel();
        _saveDebounce = Timer(
          const Duration(milliseconds: 200),
          _flushLocalSave,
        );
      }
    }
  }

  /// Persists everything that must survive a restart (profile incl. avatar,
  /// assigned + active role, and all posts/notifications/requests) as a JSON
  /// snapshot plus local blob files for any uploaded PDF/image. Blobs already
  /// stored as `local://` refs are left untouched, so repeated saves are cheap.
  Future<void> _saveLocalState() async {
    if (!_localPersistEnabled) return;
    try {
      final imageUrl = await _localStore.persistDataUri(
        currentUser.avatarUrl,
        currentUser.id,
        'avatar',
        _extFromDataUri(currentUser.avatarUrl),
      );
      if (imageUrl != currentUser.avatarUrl) {
        currentUser = currentUser.copyWith(avatarUrl: imageUrl);
      }

      final postsJson = <Map<String, dynamic>>[];
      for (final post in _posts) {
        postsJson.add(await _localRowFromPost(post));
      }

      final payload = {
        'version': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'activeRole': activeRole.name,
        'currentUser': {
          'id': currentUser.id,
          'name': currentUser.name,
          'email': currentUser.email,
          'studentOrEmployeeId': currentUser.studentOrEmployeeId,
          'department': currentUser.department,
          'year': currentUser.year,
          'mobileNumber': currentUser.mobileNumber,
          'avatarUrl': imageUrl,
          'roles': currentUser.roles.map((r) => r.name).toList(),
          'savedPostIds': currentUser.savedPostIds,
          'registeredEventIds': currentUser.registeredEventIds,
          'congratulatedPostIds': currentUser.congratulatedPostIds,
          'isVerified': currentUser.isVerified,
          'hasChangedUniqueId': currentUser.hasChangedUniqueId,
          'roleExpirations': currentUser.roleExpirations.map(
            (role, expiry) => MapEntry(role.name, expiry.toIso8601String()),
          ),
        },
        'posts': postsJson,
        'notifications': _notifications.map(_notificationToJson).toList(),
        'roleRequests': _roleRequests.map(_roleRequestToJson).toList(),
        'announcements': _announcements.map(_announcementToJson).toList(),
        'serverKnownIds': _serverKnownIds.toList(),
        'deviceOnlyPostIds': _deviceOnlyPostIds.toList(),
      };

      await _localStore.saveSnapshot(jsonEncode(payload));
    } catch (_) {
      // Best-effort: ignore persistence failures.
    }
  }

  Future<_LocalState?> _loadLocalState() async {
    final raw = await _localStore.loadSnapshot();
    if (raw == null || raw.isEmpty) return null;
    try {
      final payload = await compute(_parseJsonHelper, raw);
      if (payload == null) return null;
      final user = _userFromJson(
        payload['currentUser'] as Map<String, dynamic>,
      );
      final active = payload['activeRole'] == null
          ? null
          : _roleFromName(payload['activeRole'].toString());

      final posts = ((payload['posts'] as List?) ?? const [])
          .whereType<Map>()
          .map((r) => _postFromRow(r.cast<String, dynamic>()))
          .whereType<PostModel>()
          .toList();
      final notifications = ((payload['notifications'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => _notificationFromJson(m.cast<String, dynamic>()))
          .toList();
      final roleRequests = ((payload['roleRequests'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => _roleRequestFromJson(m.cast<String, dynamic>()))
          .toList();
      final announcements = ((payload['announcements'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => _announcementFromJson(m.cast<String, dynamic>()))
          .toList();
      final serverKnownIds = ((payload['serverKnownIds'] as List?) ?? const [])
          .whereType<String>()
          .toSet();
      final deviceOnlyPostIds =
          ((payload['deviceOnlyPostIds'] as List?) ?? const [])
              .whereType<String>()
              .toSet();

      return _LocalState(
        currentUser: user,
        activeRole: active,
        posts: posts,
        notifications: notifications,
        roleRequests: roleRequests,
        announcements: announcements,
        serverKnownIds: serverKnownIds,
        deviceOnlyPostIds: deviceOnlyPostIds,
      );
    } catch (_) {
      return null;
    }
  }

  UserRole _roleFromName(String name) => UserRole.values.firstWhere(
    (r) => r.name == name,
    orElse: () => UserRole.student,
  );

  String _extFromDataUri(String? url) {
    if (url == null || !url.startsWith('data:')) return 'jpg';
    final mimeMatch = RegExp(r'data:([^;,]+)').firstMatch(url);
    final mime = mimeMatch?.group(1)?.toLowerCase() ?? '';
    if (mime.contains('/pdf')) return 'pdf';
    final ext = mime.split('/').last;
    return ext.replaceAll(RegExp(r'[^a-z0-9.]'), '');
  }

  Future<Map<String, dynamic>> _localRowFromPost(PostModel p) async {
    final row = _rowFromPost(p);
    final localImage = await _localStore.persistDataUri(
      p.imageUrl,
      p.id,
      'cover',
      _extFromDataUri(p.imageUrl),
    );
    var changed = false;
    if (localImage != p.imageUrl) {
      changed = true;
      row['image_url'] = localImage;
    }
    final attachments = <Map<String, dynamic>>[];
    final localAttachments = <PostAttachment>[];
    var i = 0;
    for (final att in p.attachments) {
      final url = await _localStore.persistDataUri(
        att.url,
        p.id,
        'att$i',
        att.fileType == 'pdf' ? 'pdf' : _extFromDataUri(att.url),
      );
      if (url != att.url) changed = true;
      localAttachments.add(
        PostAttachment(
          title: att.title,
          fileType: att.fileType,
          url: url,
          fileSize: att.fileSize,
        ),
      );
      attachments.add({
        'title': att.title,
        'fileType': att.fileType,
        'url': url,
        'fileSize': att.fileSize,
      });
      i++;
    }
    row['attachments'] = attachments;
    // Swap the in-memory post to `local://` refs so later saves skip the
    // expensive base64 decode + disk write entirely.
    if (changed) {
      final idx = _posts.indexWhere((x) => x.id == p.id);
      if (idx != -1) {
        _posts[idx] = _posts[idx].copyWith(
          imageUrl: localImage,
          attachments: localAttachments,
        );
      }
    }
    return row;
  }

  UserModel _userFromJson(Map<String, dynamic> m) {
    final expirationsJson = (m['roleExpirations'] as Map?) ?? const {};
    final expirations = <UserRole, DateTime>{};
    expirationsJson.forEach((role, expiry) {
      final parsed = DateTime.tryParse(expiry?.toString() ?? '');
      if (parsed != null) expirations[_roleFromName(role.toString())] = parsed;
    });

    return UserModel(
      id: m['id']?.toString() ?? 'usr_local',
      name: m['name']?.toString() ?? '',
      email: m['email']?.toString() ?? '',
      studentOrEmployeeId: m['studentOrEmployeeId']?.toString() ?? '',
      department: m['department']?.toString() ?? '',
      year: m['year']?.toString() ?? '',
      mobileNumber: m['mobileNumber']?.toString() ?? '',
      avatarUrl: m['avatarUrl']?.toString() ?? '',
      roles: ((m['roles'] as List?) ?? const [])
          .whereType<String>()
          .map(_roleFromName)
          .toList(),
      savedPostIds: ((m['savedPostIds'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      registeredEventIds: ((m['registeredEventIds'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      congratulatedPostIds: ((m['congratulatedPostIds'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      isVerified: m['isVerified'] as bool? ?? true,
      roleExpirations: expirations,
      hasChangedUniqueId: m['hasChangedUniqueId'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _notificationToJson(NotificationModel n) => {
    'id': n.id,
    'title': n.title,
    'body': n.body,
    'category': n.category.name,
    'timestamp': n.timestamp.toIso8601String(),
    'isRead': n.isRead,
    'relatedPostId': n.relatedPostId,
  };

  NotificationModel _notificationFromJson(Map<String, dynamic> m) =>
      NotificationModel(
        id: m['id']?.toString() ?? 'notif_local',
        title: m['title']?.toString() ?? '',
        body: m['body']?.toString() ?? '',
        category: NotificationCategory.values.firstWhere(
          (c) => c.name == m['category'],
          orElse: () => NotificationCategory.general,
        ),
        timestamp:
            DateTime.tryParse(m['timestamp']?.toString() ?? '') ??
            DateTime.now(),
        isRead: m['isRead'] as bool? ?? false,
        relatedPostId: m['relatedPostId'] as String?,
      );

  Map<String, dynamic> _roleRequestToJson(RoleRequestModel r) => {
    'id': r.id,
    'userId': r.userId,
    'userName': r.userName,
    'userEmail': r.userEmail,
    'department': r.department,
    'studentId': r.studentId,
    'requestedRole': r.requestedRole.name,
    'reason': r.reason,
    'phoneNumber': r.phoneNumber,
    'status': r.status.name,
    'submittedAt': r.submittedAt.toIso8601String(),
    'adminNotes': r.adminNotes,
    'isLimitedAccess': r.isLimitedAccess,
    'durationDays': r.durationDays,
  };

  RoleRequestModel _roleRequestFromJson(Map<String, dynamic> m) =>
      RoleRequestModel(
        id: m['id']?.toString() ?? '',
        userId: m['userId']?.toString() ?? '',
        userName: m['userName']?.toString() ?? '',
        userEmail: m['userEmail']?.toString() ?? '',
        department: m['department']?.toString() ?? '',
        studentId: m['studentId']?.toString() ?? '',
        requestedRole: _roleFromName(m['requestedRole']?.toString() ?? ''),
        reason: m['reason']?.toString() ?? '',
        phoneNumber: m['phoneNumber']?.toString() ?? '',
        status: RoleRequestStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => RoleRequestStatus.pending,
        ),
        submittedAt:
            DateTime.tryParse(m['submittedAt']?.toString() ?? '') ??
            DateTime.now(),
        adminNotes: m['adminNotes'] as String?,
        isLimitedAccess: m['isLimitedAccess'] as bool? ?? false,
        durationDays: m['durationDays'] as int?,
      );

  Map<String, dynamic> _announcementToJson(ActiveAnnouncement a) => {
    'id': a.id,
    'title': a.title,
    'description': a.description,
    'authorName': a.authorName,
    'authorRole': a.authorRole.name,
    'department': a.department,
    'postedAt': a.postedAt.toIso8601String(),
    'expiresAt': a.expiresAt.toIso8601String(),
  };

  ActiveAnnouncement _announcementFromJson(
    Map<String, dynamic> m,
  ) => ActiveAnnouncement(
    id: m['id']?.toString() ?? 'ann_local',
    title: m['title']?.toString() ?? '',
    description: m['description']?.toString() ?? '',
    authorName: m['authorName']?.toString() ?? '',
    authorRole: _roleFromName(m['authorRole']?.toString() ?? ''),
    department: m['department']?.toString() ?? '',
    postedAt:
        DateTime.tryParse(m['postedAt']?.toString() ?? '') ?? DateTime.now(),
    expiresAt:
        DateTime.tryParse(m['expiresAt']?.toString() ?? '') ?? DateTime.now(),
  );

  void updateConfig(AppConfig newConfig) {
    config = newConfig;
    _invalidateDataCaches();
    notifyListeners();
  }

  /// Used by the sign-up flow: swaps in a brand-new student account and resets
  /// the active perspective, persisted on-device for future sessions.
  void initializeNewUser({
    required String id,
    required String name,
    required String email,
    required String studentOrEmployeeId,
    required String department,
    required String year,
    required String mobileNumber,
    String avatarUrl = '',
    List<String> savedPostIds = const [],
    List<String> registeredEventIds = const [],
    List<String> congratulatedPostIds = const [],
  }) {
    currentUser = UserModel(
      id: id,
      name: name,
      email: email,
      studentOrEmployeeId: studentOrEmployeeId,
      department: department,
      year: year,
      mobileNumber: mobileNumber,
      avatarUrl: avatarUrl,
      roles: const [UserRole.student],
      savedPostIds: savedPostIds,
      registeredEventIds: registeredEventIds,
      congratulatedPostIds: congratulatedPostIds,
      isVerified: true,
    );
    activeRole = UserRole.student;
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
  }

  void switchActiveRole(UserRole newRole) {
    if (currentUser.roles.contains(newRole) || activeRole != newRole) {
      activeRole = newRole;
      notifyListeners();
      _scheduleLocalSave();
    }
  }

  // --- Supabase persistence ---
  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Cached backend reachability verdict (see [checkBackendReachable]) so
  /// publish flows fail instantly while offline instead of waiting out the
  /// probe timeout, which can be several seconds when the network is dead.
  static const _reachabilityOnlineWindow = Duration(seconds: 15);
  static const _reachabilityOfflineWindow = Duration(seconds: 45);
  DateTime? _lastReachabilityCheck;
  bool _backendReachable = false;

  void _recordReachability(bool reachable) {
    _backendReachable = reachable;
    _lastReachabilityCheck = DateTime.now();
  }

  /// Loads posts, the device user's profile and every role request from
  /// Supabase when available; merges them with device-local state so nothing
  /// saved on this device is ever dropped. Bounded by a timeout so a dead/slow
  /// network can never block the UI. Returns whether the backend was actually
  /// reached and whether the merge changed anything (so periodic polls stay
  /// silent when nothing changed).
  Future<({bool success, bool changed})> _syncFromBackend() async {
    final client = _client;
    if (client == null) {
      _recordReachability(false);
      return (success: false, changed: false);
    }
    var changed = false;
    try {
      final rows = await client
          .from('posts')
          .select()
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(const Duration(seconds: 5));
      final fetched = rows.map(_postFromRow).whereType<PostModel>().toList();
      if (fetched.isEmpty) {
        await _pushSeedPostsToBackend(client);
      } else {
        final remoteIds = fetched.map((p) => p.id).toSet();
        _serverKnownIds.addAll(remoteIds);

        // Posts this device once confirmed on the server but the server no
        // longer returns were deleted elsewhere — drop them from the local feed.
        final disappeared = _posts
            .where(
              (p) =>
                  _serverKnownIds.contains(p.id) && !remoteIds.contains(p.id),
            )
            .map((p) => p.id)
            .toSet();

        // Only posts never confirmed by the server (created offline / failed
        // write) count as "local only"; server-known posts must never be
        // re-uploaded from a stale copy, or deleted posts come back to life.
        final localOnly = _posts
            .where(
              (p) => !remoteIds.contains(p.id) && !_serverKnownIds.contains(p.id),
            )
            .toList();
        final newRemote = fetched
            .where((p) => !_posts.any((local) => local.id == p.id))
            .toList();
        // In-app notification for every post published by another device.
        for (final post in newRemote) {
          if (_notifications.any((n) => n.relatedPostId == post.id)) continue;
          _notifications.insert(0, _postNotification(post));
        }
        _posts = [...localOnly, ...fetched];
        for (final post in localOnly) {
          _persistPost(post);
        }
        changed =
            disappeared.isNotEmpty ||
            localOnly.isNotEmpty ||
            newRemote.isNotEmpty;
      }
    } catch (e) {
      // Table missing / offline: keep the in-memory seeds.
      debugPrint('StudentHub: backend sync failed: $e');
      _recordReachability(false);
      return (success: false, changed: false);
    }

    // Profile (server-granted roles) and role requests are best-effort
    // extras: a failure here never blocks the posts sync above.
    try {
      if (await _syncOwnProfile(client)) changed = true;
    } catch (e) {
      debugPrint('StudentHub: profile sync failed: $e');
    }
    try {
      if (await _syncRoleRequests(client)) changed = true;
    } catch (e) {
      debugPrint('StudentHub: role request sync failed: $e');
    }
    _recordReachability(true);
    return (success: true, changed: changed);
  }

  Future<void> _pushSeedPostsToBackend(SupabaseClient client) async {
    // Device-only posts must never be seeded to a fresh backend either.
    await client
        .from('posts')
        .upsert(
          _posts
              .where((p) => !_deviceOnlyPostIds.contains(p.id))
              .map(_rowFromPost)
              .toList(),
          onConflict: 'id',
        );
  }

  /// Quick reachability probe so publish flows can refuse to upload while
  /// offline instead of silently queueing a post that may never sync.
  ///
  /// An earlier verdict (any sync or probe) is believed for a short window —
  /// longer after a failure, since being offline tends to persist — so
  /// offline publishes fail instantly instead of waiting out the probe
  /// timeout (3s+) with no network.
  Future<bool> checkBackendReachable() async {
    final client = _client;
    if (client == null) return false;
    final last = _lastReachabilityCheck;
    if (last != null) {
      final age = DateTime.now().difference(last);
      final window =
          _backendReachable ? _reachabilityOnlineWindow : _reachabilityOfflineWindow;
      if (age < window) return _backendReachable;
    }
    var reachable = false;
    try {
      await client
          .from('posts')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 3));
      reachable = true;
    } catch (_) {
      reachable = false;
    }
    _recordReachability(reachable);
    return reachable;
  }

  /// Pulls the device user's `profiles` row and unions in any roles the server
  /// granted (e.g. a role request approved on another device). Never clobbers
  /// locally edited display fields, and never removes locally-held roles.
  Future<bool> _syncOwnProfile(SupabaseClient client) async {
    final rows = await client
        .from('profiles')
        .select('user_id, roles, is_verified')
        .eq('user_id', currentUser.id)
        .limit(1)
        .timeout(const Duration(seconds: 5));
    if (rows.isEmpty) {
      // Fresh DB: mirror the local profile once (including roles), matching
      // the seed-posts behavior for a brand-new project.
      await _pushSeedProfileToBackend(client);
      return false;
    }
    final serverRoles = ((rows.first['roles'] as List?) ?? const [])
        .whereType<String>()
        .map(_roleFromName)
        .toList();
    final granted = serverRoles
        .where((r) => !currentUser.roles.contains(r))
        .toList();
    if (granted.isEmpty) return false;
    currentUser = currentUser.copyWith(
      roles: [...currentUser.roles, ...granted],
      isVerified: rows.first['is_verified'] as bool? ?? currentUser.isVerified,
    );
    _scheduleLocalSave();
    return true;
  }

  /// One-time seed of the demo profile (first sync on a fresh backend).
  Future<void> _pushSeedProfileToBackend(SupabaseClient client) async {
    final avatar = await _uploadAvatarIfNeeded(client, currentUser.avatarUrl);
    if (avatar != currentUser.avatarUrl) {
      currentUser = currentUser.copyWith(avatarUrl: avatar);
    }
    await client.from('profiles').upsert({
      'user_id': currentUser.id,
      'name': currentUser.name,
      'email': currentUser.email,
      'student_or_employee_id': currentUser.studentOrEmployeeId,
      'department': currentUser.department,
      'year': currentUser.year,
      'mobile_number': currentUser.mobileNumber,
      'avatar_url': avatar,
      'roles': currentUser.roles.map((r) => r.name).toList(),
      'saved_post_ids': currentUser.savedPostIds,
      'registered_event_ids': currentUser.registeredEventIds,
      'congratulated_post_ids': currentUser.congratulatedPostIds,
      'is_verified': currentUser.isVerified,
    }, onConflict: 'user_id');
  }

  /// Upserts the current user's profile after an edit. Display fields only:
  /// `roles` are seeded server-side by `review-role-request` and must never be
  /// overwritten from a possibly stale local snapshot.
  Future<void> _persistProfile() async {
    final client = _client;
    if (client == null) return;
    try {
      final avatar = await _uploadAvatarIfNeeded(client, currentUser.avatarUrl);
      if (avatar != currentUser.avatarUrl) {
        currentUser = currentUser.copyWith(avatarUrl: avatar);
      }
      await client.from('profiles').upsert({
        'user_id': currentUser.id,
        'name': currentUser.name,
        'email': currentUser.email,
        'student_or_employee_id': currentUser.studentOrEmployeeId,
        'department': currentUser.department,
        'year': currentUser.year,
        'mobile_number': currentUser.mobileNumber,
        'avatar_url': avatar,
        'saved_post_ids': currentUser.savedPostIds,
        'registered_event_ids': currentUser.registeredEventIds,
        'congratulated_post_ids': currentUser.congratulatedPostIds,
        'is_verified': currentUser.isVerified,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      // Keep local state; retried on the next sync.
      debugPrint('StudentHub: profile not persisted: $e');
    }
  }

  /// Uploads the avatar (data URI or `local://` blob) to Storage and returns
  /// the public URL. Remote URLs are left untouched.
  Future<String> _uploadAvatarIfNeeded(
    SupabaseClient client,
    String url,
  ) async {
    if (url.isEmpty || (!url.startsWith('data:') && !_localStore.isLocalRef(url))) {
      return url;
    }
    try {
      final bytes = url.startsWith('data:')
          ? await compute(
              _decodeBase64Helper,
              url.substring(url.indexOf(',') + 1),
            )
          : await _localStore.readLocalBlob(url);
      if (bytes == null || bytes.isEmpty) return url;
      final ext = _extFromDataUri(url);
      final path = 'avatars/${currentUser.id}.$ext';
      await client.storage
          .from('documents')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
              upsert: true,
            ),
          );
      return client.storage.from('documents').getPublicUrl(path);
    } catch (_) {
      return url;
    }
  }

  Map<String, dynamic> _roleRequestRow(RoleRequestModel r) => {
        'id': r.id,
        'user_id': r.userId,
        'user_name': r.userName,
        'user_email': r.userEmail,
        'department': r.department,
        'student_id': r.studentId,
        'requested_role': r.requestedRole.name,
        'reason': r.reason,
        'phone_number': r.phoneNumber,
        'status': r.status.name,
        'admin_notes': r.adminNotes,
        'is_limited_access': r.isLimitedAccess,
        'duration_days': r.durationDays,
        'submitted_at': r.submittedAt.toIso8601String(),
      };

  RoleRequestModel _roleRequestFromRow(Map<String, dynamic> m) =>
      RoleRequestModel(
        id: m['id']?.toString() ?? '',
        userId: m['user_id']?.toString() ?? '',
        userName: m['user_name']?.toString() ?? '',
        userEmail: m['user_email']?.toString() ?? '',
        department: m['department']?.toString() ?? '',
        studentId: m['student_id']?.toString() ?? '',
        requestedRole: _roleFromName(m['requested_role']?.toString() ?? ''),
        reason: m['reason']?.toString() ?? '',
        phoneNumber: m['phone_number']?.toString() ?? '',
        status: RoleRequestStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => RoleRequestStatus.pending,
        ),
        submittedAt:
            DateTime.tryParse(m['submitted_at']?.toString() ?? '') ??
            DateTime.now(),
        adminNotes: m['admin_notes'] as String?,
        isLimitedAccess: m['is_limited_access'] as bool? ?? false,
        durationDays: m['duration_days'] as int?,
      );

  /// Merges every `role_requests` row into the device list. The server status
  /// is authoritative: local-only requests (created offline) are pushed up,
  /// and when one of MY requests flips to approved/rejected the role is granted
  /// (or a rejection notice shown) locally with an in-app bell notification.
  /// Returns whether anything changed.
  Future<bool> _syncRoleRequests(SupabaseClient client) async {
    final rows = await client
        .from('role_requests')
        .select()
        .order('submitted_at', ascending: false)
        .limit(200)
        .timeout(const Duration(seconds: 5));
    final fetched = rows.map(_roleRequestFromRow).toList();
    if (fetched.isEmpty) {
      // Fresh backend: mirror the seeded requests once.
      for (final r in _roleRequests) {
        await _persistRoleRequest(r);
      }
      return false;
    }

    final remoteById = {for (final r in fetched) r.id: r};
    var changed = false;

    // Local-only requests (submitted offline) get pushed upstream.
    final localOnly = _roleRequests
        .where((r) => !remoteById.containsKey(r.id))
        .toList();
    for (final r in localOnly) {
      await _persistRoleRequest(r);
      changed = true;
    }

    final merged = <RoleRequestModel>[...localOnly];
    for (final remote in fetched) {
      RoleRequestModel? local;
      for (final l in _roleRequests) {
        if (l.id == remote.id) {
          local = l;
          break;
        }
      }
      // Adopt the server state as the source of truth.
      final effective = local == null
          ? remote
          : local.copyWith(
              status: remote.status,
              adminNotes: remote.adminNotes,
              isLimitedAccess: remote.isLimitedAccess,
              durationDays: remote.durationDays,
            );
      merged.add(effective);

      // A decision reached on another device for MY request: grant/reject
      // locally so the bell + roles update instantly.
      if (remote.userId == currentUser.id &&
          (local == null || local.status != remote.status)) {
        if (remote.status == RoleRequestStatus.approved) {
          if (_grantRoleFromRemote(remote)) changed = true;
        } else if (remote.status == RoleRequestStatus.rejected &&
            !_notifications.any(
              (n) =>
                  n.title == 'Role Application Update' &&
                  n.body ==
                      'Your application for ${remote.requestedRole.displayName} was reviewed.',
            )) {
          _notifications.insert(
            0,
            NotificationModel(
              id: 'notif_${DateTime.now().microsecondsSinceEpoch}_${remote.id}_rev',
              title: 'Role Application Update',
              body:
                  'Your application for ${remote.requestedRole.displayName} was reviewed.',
              category: NotificationCategory.personal,
              timestamp: DateTime.now(),
              relatedPostId: remote.id,
            ),
          );
          changed = true;
        }
      }
    }

    _roleRequests
      ..clear()
      ..addAll(merged);
    return changed;
  }

  /// Grants a server-approved role to the device user and emits the in-app
  /// "Role Approved" notification. Returns whether anything changed.
  bool _grantRoleFromRemote(RoleRequestModel req) {
    if (!currentUser.roles.contains(req.requestedRole)) {
      final updatedRoles = List<UserRole>.from(currentUser.roles)
        ..add(req.requestedRole);
      final updatedExpirations = Map<UserRole, DateTime>.from(
        currentUser.roleExpirations,
      );
      if (req.requestedRole == UserRole.faculty) {
        updatedRoles.remove(UserRole.student);
      }
      if (req.isLimitedAccess && req.expiresAt != null) {
        updatedExpirations[req.requestedRole] = req.expiresAt!;
      }
      currentUser = currentUser.copyWith(
        roles: updatedRoles,
        roleExpirations: updatedExpirations,
      );
    }
    if (_notifications.any((n) => n.relatedPostId == req.id)) return false;
    _notifications.insert(
      0,
      NotificationModel(
        id: 'notif_${DateTime.now().microsecondsSinceEpoch}_${req.id}_appr',
        title: 'Role Approved! 🎖️',
        body: req.isLimitedAccess && req.expiresAt != null
            ? 'Congratulations! Your temporary ${req.requestedRole.displayName} access is approved until ${_formatDate(req.expiresAt!)}.'
            : 'Congratulations! Your application for ${req.requestedRole.displayName} was approved.',
        category: NotificationCategory.personal,
        timestamp: DateTime.now(),
        relatedPostId: req.id,
      ),
    );
    _scheduleLocalSave();
    return true;
  }

  /// Upserts a role application to `role_requests` (offline-safe; retried via
  /// the next sync).
  Future<void> _persistRoleRequest(RoleRequestModel req) async {
    final client = _client;
    if (client == null) return;
    try {
      await client
          .from('role_requests')
          .upsert(_roleRequestRow(req), onConflict: 'id');
    } catch (e) {
      debugPrint('StudentHub: role request ${req.id} not persisted: $e');
    }
  }

  /// Server-side review of a role application via the `review-role-request`
  /// edge function (the caller must hold admin in `profiles`). Best-effort:
  /// a failure keeps the local decision and is retried on the next review.
  Future<void> _reviewRoleOnServer({
    required String requestId,
    required RoleRequestStatus status,
    String? notes,
  }) async {
    if (status == RoleRequestStatus.pending) return;
    final client = _client;
    if (client == null) return;
    try {
      final res = await http
          .post(
            Uri.parse(SupabaseConfig.reviewRoleFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Push-Secret': SupabaseConfig.pushSecret,
            },
            body: jsonEncode({
              'request_id': requestId,
              'admin_user_id': currentUser.id,
              'status': status.name,
              'notes': notes,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        // The applicant (and every device) picks up the decision via sync.
        unawaited(syncNow());
        final req = _roleRequests.where((r) => r.id == requestId).toList();
        if (req.isNotEmpty) {
          _pushRoleDecision(
            request: req.first,
            status: status,
          );
        }
      } else {
        debugPrint(
          'StudentHub: role review rejected: ${res.statusCode} ${res.body}',
        );
      }
    } catch (e) {
      debugPrint('StudentHub: role review failed: $e');
    }
  }

  /// OS push to the applicant's device ("Role Approved / Reviewed") via the
  /// send-push function, targeted by user id. Best-effort.
  Future<void> _pushRoleDecision({
    required RoleRequestModel request,
    required RoleRequestStatus status,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      final deviceId = await LocalStoreService.instance.getDeviceId();
      final approved = status == RoleRequestStatus.approved;
      final res = await http
          .post(
            Uri.parse(SupabaseConfig.pushFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Push-Secret': SupabaseConfig.pushSecret,
            },
            body: jsonEncode({
              'type': 'role_update',
              'recipient_user_id': request.userId,
              'device_id': deviceId,
              'title': approved ? '🎖️ Role Approved!' : 'Role Request Update',
              'body': approved
                  ? 'Congratulations! You are now '
                        '${request.requestedRole.displayName}.'
                  : 'Your application for '
                        '${request.requestedRole.displayName} was reviewed.',
              'category': 'announcement',
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint(
          'StudentHub: role push rejected: ${res.statusCode} ${res.body}',
        );
      }
    } catch (e) {
      debugPrint('StudentHub: role push failed: $e');
    }
  }

  PostModel? _postFromRow(Map<String, dynamic> row) {
    if (row['id'] == null) return null;
    final attachments = (row['attachments'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (a) => PostAttachment(
            title: a['title']?.toString() ?? '',
            fileType: a['fileType']?.toString() ?? 'pdf',
            url: a['url']?.toString() ?? '',
            fileSize: a['fileSize']?.toString() ?? '',
          ),
        )
        .toList();
    return PostModel(
      id: row['id']!.toString(),
      title: row['title']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      category: PostCategory.values.firstWhere(
        (c) => c.name == row['category'],
        orElse: () => PostCategory.announcement,
      ),
      department: row['department']?.toString() ?? '',
      targetYear: row['target_year'] as String?,
      authorName: row['author_name']?.toString() ?? '',
      authorRole: UserRole.values.firstWhere(
        (r) => r.name == row['author_role'],
        orElse: () => UserRole.student,
      ),
      authorId: row['author_id']?.toString() ?? '',
      timestamp: _parseDate(row['created_at']) ?? DateTime.now(),
      imageUrl: row['image_url'] as String?,
      attachments: attachments,
      isUrgent: row['is_urgent'] as bool? ?? false,
      isPinned: row['is_pinned'] as bool? ?? false,
      saveCount: row['save_count'] as int? ?? 0,
      congratulateCount: row['congratulate_count'] as int? ?? 0,
      congratulatedUserIds: ((row['congratulated_user_ids'] as List?) ??
              const [])
          .cast<String>(),
      venue: row['venue'] as String?,
      eventDate: _parseDate(row['event_date']),
      registrationDeadline: _parseDate(row['registration_deadline']),
      maxParticipants: row['max_participants'] as int?,
      registeredUserIds: ((row['registered_user_ids'] as List?) ?? const [])
          .cast<String>(),
    );
  }

  Map<String, dynamic> _rowFromPost(PostModel p) => {
    'id': p.id,
    'title': p.title,
    'description': p.description,
    'category': p.category.name,
    'department': p.department,
    'target_year': p.targetYear,
    'author_name': p.authorName,
    'author_role': p.authorRole.name,
    'author_id': p.authorId,
    'image_url': p.imageUrl,
    'is_urgent': p.isUrgent,
    'is_pinned': p.isPinned,
    'save_count': p.saveCount,
    'congratulate_count': p.congratulateCount,
    'congratulated_user_ids': p.congratulatedUserIds,
    'venue': p.venue,
    'event_date': p.eventDate?.toIso8601String(),
    'registration_deadline': p.registrationDeadline?.toIso8601String(),
    'max_participants': p.maxParticipants,
    'registered_user_ids': p.registeredUserIds,
    'attachments': p.attachments
        .map(
          (a) => {
            'title': a.title,
            'fileType': a.fileType,
            'url': a.url,
            'fileSize': a.fileSize,
          },
        )
        .toList(),
    'created_at': p.timestamp.toIso8601String(),
  };

  DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    if (value is DateTime) return value;
    return null;
  }

/// Pushes a post to Postgres in the background, uploading any base64 PDF
  /// attachments (and post images) to Supabase Storage first. Device-only posts
  /// (created offline) are permanently exempt: they never reach the server.
  Future<void> _persistPost(PostModel post) async {
    if (_deviceOnlyPostIds.contains(post.id)) {
      _scheduleLocalSave();
      return;
    }
    final client = _client;
    if (client == null) {
      _scheduleLocalSave();
      return;
    }
    try {
      var stored = post;
      var changed = false;
      final uploaded = <PostAttachment>[];
      for (final att in post.attachments) {
        final resolved = await _uploadAttachmentIfNeeded(att);
        uploaded.add(resolved);
        if (resolved.url != att.url) changed = true;
      }
      if (changed) {
        stored = post.copyWith(attachments: uploaded);
      }
      stored = await _uploadPostImageIfNeeded(stored);
      await client.from('posts').upsert(_rowFromPost(stored), onConflict: 'id');
      final idx = _posts.indexWhere((p) => p.id == post.id);
      if (idx != -1) _posts[idx] = stored;
    } catch (e) {
      // Never sent to the server: keep the post local and permanently
      // device-only so a later sync cannot silently publish it.
      if (!_serverKnownIds.contains(post.id)) {
        _deviceOnlyPostIds.add(post.id);
      }
      debugPrint('StudentHub: post ${post.id} not persisted: $e');
    }
  }

  /// Uploads a post's cover image (data URI or local file ref) to Supabase
  /// Storage and returns the post with the public URL. Remote/empty images are
  /// left untouched.
  Future<PostModel> _uploadPostImageIfNeeded(PostModel post) async {
    final client = _client;
    final url = post.imageUrl;
    if (client == null || url == null || url.isEmpty) return post;
    if (!url.startsWith('data:') && !_localStore.isLocalRef(url)) return post;

    try {
      final bytes = url.startsWith('data:')
          ? await compute(
              _decodeBase64Helper,
              url.substring(url.indexOf(',') + 1),
            )
          : await _localStore.readLocalBlob(url);
      if (bytes == null || bytes.isEmpty) return post;

      final ext = _extFromDataUri(url);
      final path = 'posts/${post.id}_cover.$ext';
      await client.storage
          .from('documents')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
              upsert: true,
            ),
          );
      final publicUrl = client.storage.from('documents').getPublicUrl(path);
      return post.copyWith(imageUrl: publicUrl);
    } catch (_) {
      return post;
    }
  }

  Future<PostAttachment> _uploadAttachmentIfNeeded(PostAttachment att) async {
    final client = _client;
    final url = att.url;
    if (client == null) return att;
    if (!url.startsWith('data:') && !_localStore.isLocalRef(url)) return att;
    try {
      final bytes = url.startsWith('data:')
          ? await compute(
              _decodeBase64Helper,
              url.substring(url.indexOf(',') + 1),
            )
          : await _localStore.readLocalBlob(url);
      if (bytes == null || bytes.isEmpty) return att;
      final safeName = att.title.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = 'docs/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await client.storage
          .from('documents')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );
      final publicUrl = client.storage.from('documents').getPublicUrl(path);
      return PostAttachment(
        title: att.title,
        fileType: att.fileType,
        url: publicUrl,
        fileSize: att.fileSize,
      );
    } catch (_) {
      return att;
    }
  }

  // --- Feed & Priority Logic ---
  List<PostModel> getPersonalizedFeed({
    String? categoryFilter,
    String? searchQuery,
    bool savedOnly = false,
    bool excludeEvents = false,
  }) {
    // Memoized: identical filter inputs at the same data version return the
    // cached result, so rebuilds triggered by unrelated changes (or typing in
    // search bars) don't re-copy/re-sort the feed.
    final key =
        '$savedOnly|$categoryFilter|$searchQuery|$excludeEvents|$_dataVersion';
    final cached = _feedCacheValue;
    if (key == _feedCacheKey && cached != null) return cached;

    List<PostModel> list = List.from(_posts);

    if (excludeEvents) {
      list = list.where((p) => !p.isEvent).toList();
    }

    if (savedOnly) {
      list = list
          .where((p) => currentUser.savedPostIds.contains(p.id))
          .toList();
    }

    if (categoryFilter != null && categoryFilter != 'All') {
      list = list
          .where(
            (p) =>
                p.category.displayName.toLowerCase() ==
                categoryFilter.toLowerCase(),
          )
          .toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list
          .where(
            (p) =>
                p.title.toLowerCase().contains(q) ||
                p.description.toLowerCase().contains(q) ||
                p.department.toLowerCase().contains(q) ||
                p.authorName.toLowerCase().contains(q),
          )
          .toList();
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

      final aYearMatch =
          a.targetYear == null || a.targetYear == currentUser.year;
      final bYearMatch =
          b.targetYear == null || b.targetYear == currentUser.year;
      if (aYearMatch != bYearMatch) return aYearMatch ? -1 : 1;

      return b.timestamp.compareTo(a.timestamp);
    });

    _feedCacheKey = key;
    _feedCacheValue = list;
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
        _posts[postIndex] = _posts[postIndex].copyWith(
          saveCount: (currentCount > 0 ? currentCount - 1 : 0),
        );
      }
    } else {
      updatedSaved.add(postId);
      if (postIndex != -1) {
        _posts[postIndex] = _posts[postIndex].copyWith(
          saveCount: _posts[postIndex].saveCount + 1,
        );
      }
    }

    currentUser = currentUser.copyWith(savedPostIds: updatedSaved);
    if (postIndex != -1) _persistPost(_posts[postIndex]);
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
  }

  void toggleCongratulate(String postId) {
    int index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    PostModel post = _posts[index];
    List<String> congratulated = List.from(post.congratulatedUserIds);
    List<String> userCongratulated = List.from(
      currentUser.congratulatedPostIds,
    );

    if (congratulated.contains(currentUser.id)) {
      congratulated.remove(currentUser.id);
      userCongratulated.remove(postId);
    } else {
      congratulated.add(currentUser.id);
      userCongratulated.add(postId);
    }

    _posts[index] = post.copyWith(
      congratulatedUserIds: congratulated,
      congratulateCount: congratulated.length,
    );
    currentUser = currentUser.copyWith(
      congratulatedPostIds: userCongratulated,
    );
    _persistPost(_posts[index]);
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
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
      if (post.maxParticipants != null &&
          regUsers.length >= post.maxParticipants!) {
        return; // Full
      }
      regUsers.add(currentUser.id);
      userRegEvents.add(postId);

      // Add event registration notification
      _notifications.insert(
        0,
        NotificationModel(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Registration Confirmed! 🎉',
          body:
              'You have registered for ${post.title}. Keep an eye on updates.',
          category: NotificationCategory.events,
          timestamp: DateTime.now(),
          relatedPostId: post.id,
        ),
      );

      // Let every other device know via push ("X registered for Event").
      _pushBroadcast(
        post,
        type: 'event_registration',
        title: '🎟️ New event registration',
        body: '${currentUser.name} registered for "${post.title}"',
        registrantName: currentUser.name,
      );

      // When the last seat gets taken, tell everyone registration closed.
      if (post.isRegistrationFull) {
        _pushBroadcast(
          post,
          type: 'registrations_closed',
          title: '⛔ Registrations closed',
          body: 'The event "${post.title}" is now full.',
        );
      }
    }

    _posts[index] = post.copyWith(registeredUserIds: regUsers);
    currentUser = currentUser.copyWith(registeredEventIds: userRegEvents);
    _persistPost(_posts[index]);
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
  }

  void addPost(PostModel newPost) {
    _posts.insert(0, newPost);
    _notifications.insert(0, _postNotification(newPost, publishedByMe: true));
    _invalidateDataCaches();
    notifyListeners();
    if (_client == null) {
      // No backend reachable at publish time: the post stays on this device
      // only and is never uploaded on a later sync.
      _deviceOnlyPostIds.add(newPost.id);
    } else {
      _persistPost(newPost);
      _pushBroadcast(
        newPost,
        title:
            newPost.isEvent ? '🎉 New event posted' : '📢 New announcement posted',
        body: newPost.title,
      );
    }
    _scheduleLocalSave();
  }

  /// Builds the in-app bell notification for a post. Used for posts this
  /// device published (publishedByMe) and for posts synced from other devices.
  NotificationModel _postNotification(
    PostModel post, {
    bool publishedByMe = false,
  }) {
    final isEvent = post.isEvent;
    final category = isEvent
        ? NotificationCategory.events
        : post.category == PostCategory.urgent ||
              post.category == PostCategory.urgentAnnouncement
        ? NotificationCategory.academic
        : NotificationCategory.general;
    return NotificationModel(
      id: 'notif_${DateTime.now().microsecondsSinceEpoch}_${post.id}',
      title: publishedByMe
          ? (isEvent ? '🎉 Your event is live!' : '📢 Your post is live!')
          : (isEvent ? '🎉 New event posted' : '📢 New post: ${post.title}'),
      body: publishedByMe
          ? '"${post.title}" is now on the campus feed.'
          : (post.description.isEmpty ? post.title : post.description),
      category: category,
      timestamp: post.timestamp,
      relatedPostId: post.id,
    );
  }

  void updatePost(PostModel updatedPost) {
    final idx = _posts.indexWhere((p) => p.id == updatedPost.id);
    if (idx != -1) {
      _posts[idx] = updatedPost;
      _invalidateDataCaches();
      notifyListeners();
      _persistPost(updatedPost);
      _scheduleLocalSave();
    }
  }

  /// Deletes a post from this device AND the server. The server refuses unless
  /// the caller is the post's author, so a user can never delete a post they
  /// did not publish. Returns false when the server delete failed (local state
  /// is rolled back so the feed stays truthful).
  Future<bool> deletePost(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return true;
    final removed = _posts[index];

    var serverDeleted = true;
    final client = _client;
    if (client != null) {
      try {
        final res = await http
            .post(
              Uri.parse(SupabaseConfig.deleteFunctionUrl),
              headers: {
                'Content-Type': 'application/json',
                'X-Push-Secret': SupabaseConfig.pushSecret,
              },
              body: jsonEncode({
                'post_id': postId,
                'author_id': currentUser.id,
                // Admins may moderate any post; the edge function verifies the
                // admin role before falling back to the author-only check.
                if (currentUser.hasRole(UserRole.admin))
                  'admin_user_id': currentUser.id,
              }),
            )
            .timeout(const Duration(seconds: 8));
        serverDeleted = res.statusCode >= 200 && res.statusCode < 300;
        if (!serverDeleted) {
          debugPrint(
            'StudentHub: server delete rejected: ${res.statusCode} ${res.body}',
          );
        }
      } catch (e) {
        debugPrint('StudentHub: server delete failed: $e');
        serverDeleted = false;
      }
    }

    if (!serverDeleted) {
      // Keep the post locally; the next refresh would resurrect it anyway.
      return false;
    }

    _posts.removeWhere((p) => p.id == postId);
    // Remember the deletion: even if this app is killed before the snapshot
    // write, the id can never be re-pushed or resurrected by this device.
    _serverKnownIds.add(postId);
    _client?.from('posts').delete().eq('id', postId);
    _localStore.deleteLocalBlob(removed.imageUrl);
    for (final att in removed.attachments) {
      _localStore.deleteLocalBlob(att.url);
    }
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
    await flushLocalSave();
    return true;
  }

  /// Pulls the latest data from the backend. Network is mandatory: when the
  /// backend cannot be reached this returns false so the caller can prompt the
  /// user instead of showing stale content.
  Future<bool> refreshFeed() async {
    final result = await _syncFromBackend();
    if (result.success && result.changed) {
      _invalidateDataCaches();
      notifyListeners();
      _scheduleLocalSave();
    }
    return result.success;
  }

  /// Registers this device's FCM token so the backend can broadcast pushes to
  /// it. Best-effort: the token is simply retried on the next launch when the
  /// backend is unreachable.
  Future<void> registerDeviceToken(String token) async {
    final client = _client;
    if (client == null) return;
    try {
      final deviceId = await LocalStoreService.instance.getDeviceId();
      await client.from('device_tokens').upsert({
        'token': token,
        'user_id': currentUser.id,
        'device_id': deviceId,
        'platform': 'android',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');
    } catch (_) {
      // Backend offline: retried implicitly on next launch/token refresh.
    }
  }

  /// Broadcasts a push to every registered device (except this one) via the
  /// send-push Edge Function. Used for new posts, event registrations and
  /// registration-closed updates.
  Future<void> _pushBroadcast(
    PostModel post, {
    String type = 'new_post',
    String? title,
    String? body,
    String? registrantName,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      final deviceId = await LocalStoreService.instance.getDeviceId();
      final res = await http
          .post(
            Uri.parse(SupabaseConfig.pushFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Push-Secret': SupabaseConfig.pushSecret,
            },
            body: jsonEncode({
              'post_id': post.id,
              'title': title ?? post.title,
              'body': body ?? post.description,
              'category': post.category.name,
              'author_id': post.authorId,
              'device_id': deviceId,
              'type': type,
              'registrant_name': ?registrantName,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint(
          'StudentHub: push broadcast rejected: ${res.statusCode} ${res.body}',
        );
      }
    } catch (e) {
      // Push is best-effort; a failed broadcast never blocks publishing.
      debugPrint('StudentHub: push broadcast failed: $e');
    }
  }

  /// In-app bell entry for the event host when someone registers for their
  /// event. Called from the push handler so it appears the moment the
  /// registration happens, without waiting for a poll.
  void addHostRegistrationNotification({
    required String postId,
    required String registrantName,
  }) {
    final post = _posts.where((p) => p.id == postId).toList();
    if (post.isEmpty || post.first.authorId != currentUser.id) return;
    final title = '🎟️ New registration';
    final body = '$registrantName registered for "${post.first.title}"';
    if (_notifications.any(
      (n) =>
          n.relatedPostId == postId &&
          n.title == title &&
          n.body == body,
    )) {
      return;
    }
    _notifications.insert(
      0,
      NotificationModel(
        id: 'notif_${DateTime.now().microsecondsSinceEpoch}_${postId}_reg',
        title: title,
        body: body,
        category: NotificationCategory.events,
        timestamp: DateTime.now(),
        relatedPostId: postId,
      ),
    );
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
  }

  void updateUserProfile({
    required String name,
    required String department,
    required String year,
    String? studentOrEmployeeId,
    String? avatarUrl,
  }) {
    bool hasChanged = currentUser.hasChangedUniqueId;
    String finalId = currentUser.studentOrEmployeeId;

    if (studentOrEmployeeId != null &&
        studentOrEmployeeId.trim().isNotEmpty &&
        studentOrEmployeeId.trim() != currentUser.studentOrEmployeeId &&
        !hasChanged) {
      finalId = studentOrEmployeeId.trim();
      hasChanged = true;
    }

    currentUser = currentUser.copyWith(
      name: name.trim(),
      department: department,
      year: year,
      studentOrEmployeeId: finalId,
      hasChangedUniqueId: hasChanged,
      avatarUrl: (avatarUrl != null && avatarUrl.trim().isNotEmpty)
          ? avatarUrl.trim()
          : currentUser.avatarUrl,
    );

    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
    unawaited(_persistProfile());
  }

  // --- Header Announcement (Time-limited, one per department) ---
  ActiveAnnouncement? activeAnnouncementFor(String userDepartment) {
    final active = activeAnnouncements;
    if (active.isEmpty) return null;

    // Prefer an announcement targeting the user's own department.
    final deptMatches = active
        .where((a) => a.department == userDepartment)
        .toList();
    if (deptMatches.isNotEmpty) {
      deptMatches.sort((a, b) => b.expiresAt.compareTo(a.expiresAt));
      return deptMatches.first;
    }

    // Fall back to a campus-wide (global) announcement.
    final global = active.where((a) => a.department.isEmpty).toList();
    if (global.isNotEmpty) {
      global.sort((a, b) => b.expiresAt.compareTo(a.expiresAt));
      return global.first;
    }

    return null;
  }

  Duration? canPostAnnouncement(String department) {
    // Blocking is per-department only; the campus-wide seed does not lock slots.
    final matches = activeAnnouncements
        .where((a) => a.department == department)
        .toList();
    if (matches.isEmpty) return null;
    return matches.first.remaining;
  }

  bool postAnnouncement({
    required String title,
    required String description,
    required String department,
    required Duration duration,
    required String authorName,
    required UserRole authorRole,
  }) {
    if (canPostAnnouncement(department) != null) return false;

    _announcements.removeWhere((a) => a.department == department);
    _announcements.insert(
      0,
      ActiveAnnouncement(
        id: 'ann_${DateTime.now().millisecondsSinceEpoch}',
        title: title.trim(),
        description: description.trim(),
        authorName: authorName,
        authorRole: authorRole,
        department: department,
        postedAt: DateTime.now(),
        expiresAt: DateTime.now().add(duration),
      ),
    );

    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
    return true;
  }

  void _clearExpiredAnnouncements() {
    final before = _announcements.length;
    _announcements.removeWhere((a) => a.isExpired);
    if (_announcements.length != before) {
      _invalidateDataCaches();
      notifyListeners();
    }
  }

  void _seedDefaultAnnouncement() {
    final text = config.announcementBannerText.trim();
    if (text.isEmpty) return;
    _announcements = [
      ActiveAnnouncement(
        id: 'ann_default',
        title: text,
        description: '',
        authorName: 'StudentHub Admin',
        authorRole: UserRole.admin,
        department: '',
        postedAt: DateTime.now().subtract(const Duration(hours: 1)),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      ),
    ];
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
    _notifications.insert(
      0,
      NotificationModel(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Role Application Submitted',
        body: isLimitedAccess
            ? 'Your request for ${requestedRole.displayName} status (temporary, until ${_formatDate(newReq.expiresAt!)}) has been sent to Admin for review.'
            : 'Your request for ${requestedRole.displayName} status has been sent to Admin for review.',
        category: NotificationCategory.personal,
        timestamp: DateTime.now(),
      ),
    );

    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
    unawaited(_persistRoleRequest(newReq));
  }

  void updateRoleRequestStatus(
    String requestId,
    RoleRequestStatus status,
    String? notes,
  ) {
    int idx = _roleRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;

    RoleRequestModel req = _roleRequests[idx];
    _roleRequests[idx] = req.copyWith(status: status, adminNotes: notes);

    if (status == RoleRequestStatus.approved) {
      if (req.userId == currentUser.id) {
        List<UserRole> updatedRoles = List.from(currentUser.roles);
        Map<UserRole, DateTime> updatedExpirations = Map.from(
          currentUser.roleExpirations,
        );
        if (!updatedRoles.contains(req.requestedRole)) {
          updatedRoles.add(req.requestedRole);
          if (req.requestedRole == UserRole.faculty) {
            updatedRoles.remove(UserRole.student);
          }
          if (req.isLimitedAccess && req.expiresAt != null) {
            updatedExpirations[req.requestedRole] = req.expiresAt!;
          }
          currentUser = currentUser.copyWith(
            roles: updatedRoles,
            roleExpirations: updatedExpirations,
          );
        }
      }
      _notifications.insert(
        0,
        NotificationModel(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Role Approved! 🎖️',
          body: req.isLimitedAccess && req.expiresAt != null
              ? 'Congratulations! Your temporary ${req.requestedRole.displayName} access is approved until ${_formatDate(req.expiresAt!)}.'
              : 'Congratulations! Your application for ${req.requestedRole.displayName} was approved.',
          category: NotificationCategory.personal,
          timestamp: DateTime.now(),
        ),
      );
    } else if (status == RoleRequestStatus.rejected) {
      _notifications.insert(
        0,
        NotificationModel(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Role Application Update',
          body:
              'Your application for ${req.requestedRole.displayName} was reviewed.',
          category: NotificationCategory.personal,
          timestamp: DateTime.now(),
        ),
      );
    }

    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
    unawaited(
      _reviewRoleOnServer(
        requestId: requestId,
        status: status,
        notes: notes,
      ),
    );
  }

  void markNotificationRead(String notifId) {
    int idx = _notifications.indexWhere((n) => n.id == notifId);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      _invalidateDataCaches();
      notifyListeners();
      _scheduleLocalSave();
    }
  }

  void markAllNotificationsRead() {
    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
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

    List<UserRole> updatedRoles = List.from(currentUser.roles)
      ..removeWhere(expiredRoles.contains);
    Map<UserRole, DateTime> updatedExpirations = Map.from(expirations)
      ..removeWhere((role, _) => expiredRoles.contains(role));

    currentUser = currentUser.copyWith(
      roles: updatedRoles,
      roleExpirations: updatedExpirations,
    );

    if (expiredRoles.contains(activeRole)) {
      activeRole = currentUser.roles.isNotEmpty
          ? currentUser.roles.first
          : UserRole.student;
    }

    for (final role in expiredRoles) {
      _notifications.insert(
        0,
        NotificationModel(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          title: '${role.displayName} Access Expired ⏳',
          body:
              'Your temporary ${role.displayName} access period has ended. You are now back to Student view. Your hosted events remain on the campus feed.',
          category: NotificationCategory.personal,
          timestamp: now,
        ),
      );
    }

    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
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
        description:
            'All 3rd and 4th year CSE & IT students must review the revised examination timetable. Exams start on Monday at 09:00 AM in Block C.',
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
            url: 'assets/pdfs/mid_sem_exam_schedule.pdf',
            fileSize: '1.4 MB',
          ),
        ],
        saveCount: 142,
      ),
      PostModel(
        id: 'pst_002',
        title: '🚀 HackCampus 2026: 24-Hour Flagship Hackathon',
        description:
            'Join over 500+ student developers, designers, and innovators! Build groundbreaking AI & Campus IoT solutions with prize pools up to \$5,000.',
        category: PostCategory.event,
        department: 'Computer Science & Engineering',
        authorName: 'Dev Society (Host: Aarav S.)',
        authorRole: UserRole.eventHost,
        authorId: 'usr_101',
        timestamp: now.subtract(const Duration(hours: 5)),
        imageUrl:
            'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?auto=format&fit=crop&q=80&w=800',
        venue: 'Main Auditorium & Innovation Lab',
        eventDate: now.add(const Duration(days: 4)),
        registrationDeadline: now.add(const Duration(days: 2)),
        maxParticipants: 300,
        registeredUserIds: ['usr_101', 'usr_102', 'usr_103'],
        saveCount: 88,
      ),
      PostModel(
        id: 'pst_003',
        title:
            '📚 Academic Notice: Elective Selection Guidelines for Final Year',
        description:
            'Please submit your preferences for Open Elective Course III before Friday 5:00 PM. Access the student portal to review syllabus descriptions.',
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
            url: 'assets/pdfs/open_elective_syllabus.pdf',
            fileSize: '2.8 MB',
          ),
        ],
        saveCount: 45,
      ),
      PostModel(
        id: 'pst_004',
        title: '🤖 Hands-on Workshop: Flutter & Mobile AI Apps',
        description:
            'Learn to build modern cross-platform mobile apps with Flutter, Supabase backend, and local AI model integration. Prerequisites: Basic OOP concepts.',
        category: PostCategory.workshop,
        department: 'Computer Science & Engineering',
        authorName: 'Mobile Dev Club',
        authorRole: UserRole.eventHost,
        authorId: 'host_202',
        timestamp: now.subtract(const Duration(days: 1, hours: 4)),
        imageUrl:
            'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&q=80&w=800',
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
        description:
            'Hearty congratulations to the MIT Eagles Basketball team for taking 1st place in the State Inter-University Championship 2026!',
        category: PostCategory.achievement,
        department: 'Management Studies',
        authorName: 'Sports Directorate',
        authorRole: UserRole.admin,
        authorId: 'adm_001',
        timestamp: now.subtract(const Duration(days: 2)),
        imageUrl:
            'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&q=80&w=800',
        saveCount: 156,
      ),
      PostModel(
        id: 'pst_006',
        title: '💼 Campus Placement Drive: Google Cloud & Microsoft Tech Roles',
        description:
            'Eligible 4th year CSE, IT, and ECE students can register for upcoming technical interviews. Minimum CGPA required: 7.5.',
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
            url: 'assets/pdfs/placement_eligibility.pdf',
            fileSize: '890 KB',
          ),
        ],
        saveCount: 210,
      ),
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
        reason:
            'I am the president of Robotics Club and need permissions to post robotics competitions and workshops for students.',
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
        reason:
            'Need faculty access to publish official departmental seminar notices and guest speaker updates.',
        phoneNumber: '+91 91234 56789',
        submittedAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
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
      ),
    ];
  }
}

/// Snapshot of everything that must be restored from the device between app
/// sessions.
class _LocalState {
  _LocalState({
    required this.currentUser,
    required this.activeRole,
    required this.posts,
    required this.notifications,
    required this.roleRequests,
    required this.announcements,
    required this.serverKnownIds,
    required this.deviceOnlyPostIds,
  });

  final UserModel currentUser;
  final UserRole? activeRole;
  final List<PostModel> posts;
  final List<NotificationModel> notifications;
  final List<RoleRequestModel> roleRequests;
  final List<ActiveAnnouncement> announcements;
  final Set<String> serverKnownIds;
  final Set<String> deviceOnlyPostIds;
}

Uint8List _decodeBase64Helper(String base64) => base64Decode(base64);

Map<String, dynamic>? _parseJsonHelper(String raw) {
  try {
    return jsonDecode(raw) as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}
