import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
import '../models/form_models.dart';
import 'local_store_service.dart';

class MockDataService extends ChangeNotifier {
  late AppConfig config;
  late UserModel currentUser;
  late UserRole activeRole;

  List<PostModel> _posts = [];
  List<RoleRequestModel> _roleRequests = [];
  List<NotificationModel> _notifications = [];
  List<ActiveAnnouncement> _announcements = [];
  List<FormSubmission> _formSubmissions = [];
  bool _notificationsCleared = false;
  DateTime? _notificationsClearedAt;

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
  List<FormSubmission> _cacheSubmissions = const [];
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
    _cacheSubmissions = List.unmodifiable(_formSubmissions);
  }

  List<PostModel> get posts => _cachePosts;
  List<RoleRequestModel> get roleRequests => _cacheRoleRequests;
  List<NotificationModel> get notifications => _cacheNotifications;
  List<ActiveAnnouncement> get activeAnnouncements => _cacheAnnouncements;
  List<FormSubmission> get formSubmissions => _cacheSubmissions;

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
      final isDemoAccount = restored.currentUser.id == 'usr_101' ||
          restored.currentUser.name.toLowerCase().contains('aarav') ||
          restored.currentUser.email.contains('aarav.sharma');

      if (isDemoAccount) {
        _isLoggedOut = true;
        logoutReason = 'Demo account deleted.';
        lastKnownUser = null;
        await _localStore.clearSnapshot();
      } else {
        currentUser = restored.currentUser;
        activeRole = restored.activeRole ??
            (currentUser.roles.isNotEmpty
                ? currentUser.roles.first
                : UserRole.student);
      }

      _posts = restored.posts
          .where(
            (p) =>
                p.authorId != 'usr_101' &&
                !p.authorName.toLowerCase().contains('aarav'),
          )
          .toList();
      _notifications = restored.notifications;
      _roleRequests = restored.roleRequests;
      _announcements = restored.announcements;
      _formSubmissions = restored.formSubmissions;
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
    await _syncFromBackend();
    _invalidateDataCaches();
    notifyListeners();
  }

  Future<void> _seedDefaults() async {
    // Unauthenticated initial user state (requires login or signup)
    currentUser = UserModel(
      id: '',
      name: '',
      email: '',
      studentOrEmployeeId: '',
      department: config.departments.first,
      year: config.academicYears.first,
      mobileNumber: '',
      avatarUrl: '',
      roles: const [UserRole.student],
      savedPostIds: const [],
      registeredEventIds: const [],
      congratulatedPostIds: const [],
      isVerified: true,
    );

    activeRole = UserRole.student;

    _generateMockPosts();
    _generateMockRoleRequests();
    _generateMockNotifications();
    _generateMockSubmissions();
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
          'likedPostIds': currentUser.likedPostIds,
          'isVerified': currentUser.isVerified,
          'hasChangedUniqueId': currentUser.hasChangedUniqueId,
          'hasCompletedProgressiveForm': currentUser.hasCompletedProgressiveForm,
          'activeDeviceId': currentUser.activeDeviceId,
          'roleExpirations': currentUser.roleExpirations.map(
            (role, expiry) => MapEntry(role.name, expiry.toIso8601String()),
          ),
        },
        'posts': postsJson,
        'notifications': _notifications.map(_notificationToJson).toList(),
        'roleRequests': _roleRequests.map(_roleRequestToJson).toList(),
        'announcements': _announcements.map(_announcementToJson).toList(),
        'formSubmissions': _formSubmissions.map(_submissionToJson).toList(),
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
      final formSubmissions =
          ((payload['formSubmissions'] as List?) ?? const [])
              .whereType<Map>()
              .map(
                (m) => FormSubmission.fromJson(m.cast<String, dynamic>()),
              )
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
        formSubmissions: formSubmissions,
        serverKnownIds: serverKnownIds,
        deviceOnlyPostIds: deviceOnlyPostIds,
      );
    } catch (_) {
      return null;
    }
  }

  UserRole _roleFromName(String name) {
    final clean = name.trim().toLowerCase();
    if (clean == 'host' || clean == 'eventhost' || clean == 'event_host') {
      return UserRole.eventHost;
    }
    if (clean == 'faculty') return UserRole.faculty;
    if (clean == 'admin') return UserRole.admin;
    return UserRole.values.firstWhere(
      (r) => r.name.toLowerCase() == clean,
      orElse: () => UserRole.student,
    );
  }

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
    // Persist gallery images to local refs too, so offline snapshots keep
    // the full multi-image set instead of the raw base64 blobs.
    final localGallery = <String>[];
    var j = 0;
    for (final url in p.imageUrls) {
      final localUrl = await _localStore.persistDataUri(
        url,
        p.id,
        'g$j',
        _extFromDataUri(url),
      );
      if (localUrl != url) changed = true;
      localGallery.add(localUrl);
      j++;
    }
    if (localGallery.isNotEmpty) {
      row['image_urls'] = localGallery;
    }
    // Swap the in-memory post to `local://` refs so later saves skip the
    // expensive base64 decode + disk write entirely.
    if (changed) {
      final idx = _posts.indexWhere((x) => x.id == p.id);
      if (idx != -1) {
        _posts[idx] = _posts[idx].copyWith(
          imageUrl: localImage,
          imageUrls: localGallery,
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
      likedPostIds: ((m['likedPostIds'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      isVerified: m['isVerified'] as bool? ?? true,
      roleExpirations: expirations,
      hasChangedUniqueId: m['hasChangedUniqueId'] as bool? ?? false,
      hasCompletedProgressiveForm:
          m['hasCompletedProgressiveForm'] as bool? ?? true,
      activeDeviceId: m['activeDeviceId']?.toString(),
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

  Map<String, dynamic> _submissionToJson(FormSubmission s) => s.toJson();

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
    List<String> likedPostIds = const [],
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
      likedPostIds: likedPostIds,
      isVerified: true,
    );
    activeRole = UserRole.student;
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
  }

  bool _isLoggedOut = false;
  bool get isLoggedOut => _isLoggedOut;
  String? logoutReason;

  /// Device id this install was already security-logged-out for.
  String? _kickedForDeviceId;
  String? _syncedDeviceId;

  Future<void> loginUser({
    required String name,
    required String email,
    required String mobileNumber,
  }) async {
    _isLoggedOut = false;
    logoutReason = null;
    _kickedForDeviceId = null;
    _syncedDeviceId = null;
    final deviceId = await LocalStoreService.instance.getDeviceId();
    final client = _client;

    if (client != null) {
      try {
        final rows = await client
            .from('profiles')
            .select()
            .eq('email', email.trim().toLowerCase())
            .limit(1)
            .timeout(const Duration(seconds: 6));

        if (rows.isNotEmpty) {
          final r = rows.first;
          final serverRoles = ((r['roles'] as List?) ?? const ['student'])
              .whereType<String>()
              .map(_roleFromName)
              .toList();

          currentUser = UserModel(
            id: r['user_id']?.toString() ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
            name: (r['name']?.toString() ?? '').isNotEmpty ? r['name'].toString() : name.trim(),
            email: email.trim().toLowerCase(),
            studentOrEmployeeId: r['student_or_employee_id']?.toString() ?? '',
            department: (r['department']?.toString() ?? '').isNotEmpty ? r['department'].toString() : config.departments.first,
            year: (r['year']?.toString() ?? '').isNotEmpty ? r['year'].toString() : config.academicYears.first,
            mobileNumber: (r['mobile_number']?.toString() ?? '').isNotEmpty ? r['mobile_number'].toString() : mobileNumber.trim(),
            avatarUrl: r['avatar_url']?.toString() ?? '',
            roles: serverRoles.isEmpty ? [UserRole.student] : serverRoles,
            savedPostIds: ((r['saved_post_ids'] as List?) ?? const []).whereType<String>().toList(),
            registeredEventIds: ((r['registered_event_ids'] as List?) ?? const []).whereType<String>().toList(),
            congratulatedPostIds: ((r['congratulated_post_ids'] as List?) ?? const []).whereType<String>().toList(),
            likedPostIds: ((r['liked_post_ids'] as List?) ?? const []).whereType<String>().toList(),
            isVerified: r['is_verified'] as bool? ?? true,
            hasCompletedProgressiveForm: r['has_completed_progressive_form'] as bool? ?? false,
            activeDeviceId: deviceId,
          );

          activeRole = currentUser.roles.first;

          await client.from('profiles').update({
            'active_device_id': deviceId,
            'mobile_number': currentUser.mobileNumber,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('user_id', currentUser.id);

          _syncedDeviceId = deviceId;
          _invalidateDataCaches();
          notifyListeners();
          _scheduleLocalSave();
          // Pull latest posts and registrations right after login so counts are fresh
          await syncNow();
          return;
        }
      } catch (e) {
        debugPrint('StudentHub: login profile query failed: $e');
      }
    }

    // New User or offline login: initialize account requiring progressive onboarding
    currentUser = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      email: email.trim().toLowerCase(),
      studentOrEmployeeId: '',
      department: config.departments.first,
      year: config.academicYears.first,
      mobileNumber: mobileNumber.trim(),
      avatarUrl: '',
      roles: const [UserRole.student],
      savedPostIds: const [],
      registeredEventIds: const [],
      hasCompletedProgressiveForm: false,
      activeDeviceId: deviceId,
    );
    activeRole = UserRole.student;

    _syncedDeviceId = deviceId;
    _invalidateDataCaches();
    notifyListeners();
    await _persistProfile();
    _scheduleLocalSave();
    await syncNow();
  }

  /// Checks whether an MIT ID (student/employee ID) is available or already
  /// registered to another user account on the server.
  Future<bool> isMitIdAvailable(
    String mitId, {
    String? excludeUserId,
  }) async {
    final trimmed = mitId.trim();
    if (trimmed.isEmpty) return true;
    final client = _client;
    if (client != null) {
      try {
        final rows = await client
            .from('profiles')
            .select('user_id, student_or_employee_id')
            .eq('student_or_employee_id', trimmed)
            .timeout(const Duration(seconds: 5));
        final targetExclude = excludeUserId ?? currentUser.id;
        final existingOther = rows.where(
          (r) =>
              r['user_id']?.toString() != null &&
              r['user_id']?.toString() != targetExclude &&
              r['user_id']?.toString() != '',
        );
        if (existingOther.isNotEmpty) return false;
      } catch (e) {
        debugPrint('StudentHub: error checking MIT ID availability: $e');
      }
    }
    return true;
  }

  Future<void> completeProgressiveForm({
    required String avatarUrl,
    required String department,
    required String year,
    required String studentOrEmployeeId,
  }) async {
    final trimmedId = studentOrEmployeeId.trim();
    if (trimmedId.isNotEmpty) {
      final available = await isMitIdAvailable(
        trimmedId,
        excludeUserId: currentUser.id,
      );
      if (!available) {
        throw Exception(
          'MIT ID "$trimmedId" is already registered to another account. Please use your unique MIT ID.',
        );
      }
    }

    currentUser = currentUser.copyWith(
      avatarUrl: avatarUrl,
      department: department,
      year: year,
      studentOrEmployeeId: trimmedId,
      hasCompletedProgressiveForm: true,
    );
    _invalidateDataCaches();
    notifyListeners();
    await _persistProfile();
    _scheduleLocalSave();
  }

  UserModel? lastKnownUser;

  Future<void> logout({String? reason}) async {
    _isLoggedOut = true;
    logoutReason = reason;
    _syncedDeviceId = null;
    if (currentUser.name.isNotEmpty && currentUser.email.isNotEmpty) {
      lastKnownUser = currentUser;
    }
    await LocalStoreService.instance.clearSnapshot();
    currentUser = UserModel(
      id: '',
      name: '',
      email: '',
      studentOrEmployeeId: '',
      department: config.departments.first,
      year: config.academicYears.first,
      mobileNumber: '',
      avatarUrl: '',
      roles: const [UserRole.student],
      savedPostIds: const [],
      registeredEventIds: const [],
      hasCompletedProgressiveForm: false,
    );
    _invalidateDataCaches();
    notifyListeners();
  }

  /// Pulls form submissions (form fills + quick registrations) from the
  /// backend and merges them with device-local rows. This is what lets a host
  /// on another device see real attendee profile data (name, MIT ID,
  /// department, year, mobile) instead of synthetic placeholders.
  Future<bool> _syncFormSubmissions(SupabaseClient client) async {
    final rows = await client
        .from('form_submissions')
        .select()
        .order('submitted_at', ascending: false)
        .limit(500)
        .timeout(const Duration(seconds: 5));
    var changed = false;
    final localById = <String, FormSubmission>{
      for (final s in _formSubmissions) s.id: s,
    };
    final merged = List<FormSubmission>.from(_formSubmissions);
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      final postId = row['post_id']?.toString() ?? '';
      if (id.isEmpty || postId.isEmpty) continue;
      final remote = FormSubmission(
        id: id,
        postId: postId,
        formId: row['form_id']?.toString().isEmpty == true
            ? null
            : row['form_id']?.toString(),
        userId: row['user_id']?.toString() ?? '',
        name: row['name']?.toString() ?? '',
        studentOrEmployeeId: row['student_or_employee_id']?.toString() ?? '',
        department: row['department']?.toString() ?? '',
        year: row['year']?.toString() ?? '',
        mobileNumber: row['mobile_number']?.toString() ?? '',
        answers:
            ((row['answers'] as Map?) ?? const {}).cast<String, dynamic>(),
        submittedAt: _parseDate(row['submitted_at']) ?? DateTime.now(),
      );
      final local = localById[id];
      if (local == null) {
        final missing = <String, FormSubmission>{
          for (final s in merged) '${s.postId}|${s.userId}': s,
        };
        final key = '${remote.postId}|${remote.userId}';
        final existing = missing[key];
        if (existing != null) {
          final idx = merged.indexOf(existing);
          merged[idx] = existing.copyWith(
            name: existing.name.isNotEmpty ? existing.name : remote.name,
            studentOrEmployeeId: existing.studentOrEmployeeId.isNotEmpty
                ? existing.studentOrEmployeeId
                : remote.studentOrEmployeeId,
            department: existing.department.isNotEmpty
                ? existing.department
                : remote.department,
            year: existing.year.isNotEmpty ? existing.year : remote.year,
            mobileNumber: existing.mobileNumber.isNotEmpty
                ? existing.mobileNumber
                : remote.mobileNumber,
          );
        } else {
          merged.add(remote);
        }
        changed = true;
      } else {
        final enriched = local.copyWith(
          name: local.name.isNotEmpty ? local.name : remote.name,
          studentOrEmployeeId: local.studentOrEmployeeId.isNotEmpty
              ? local.studentOrEmployeeId
              : remote.studentOrEmployeeId,
          department: local.department.isNotEmpty
              ? local.department
              : remote.department,
          year: local.year.isNotEmpty ? local.year : remote.year,
          mobileNumber: local.mobileNumber.isNotEmpty
              ? local.mobileNumber
              : remote.mobileNumber,
        );
        final idx = merged.indexOf(local);
        if (idx != -1 && !_sameSubmission(local, enriched)) {
          merged[idx] = enriched;
          changed = true;
        }
      }
    }
    if (changed) {
      _formSubmissions = merged;
    }
    return changed;
  }

  static bool _sameSubmission(FormSubmission a, FormSubmission b) =>
      a.name == b.name &&
      a.studentOrEmployeeId == b.studentOrEmployeeId &&
      a.department == b.department &&
      a.year == b.year &&
      a.mobileNumber == b.mobileNumber;

  final Map<String, UserModel> _knownProfiles = {};

  /// Syncs profiles for all registrants and submission authors from Supabase
  /// `profiles` table into [_knownProfiles]. This ensures hosts see the real
  /// student name, MIT ID, department, year, and mobile number even for
  /// historical registrations or when form_submissions table row is missing.
  Future<bool> _syncProfilesForRegistrants(SupabaseClient client) async {
    final uids = <String>{
      for (final p in _posts) ...p.registeredUserIds,
      for (final s in _formSubmissions) s.userId,
    }.where((id) => id.isNotEmpty && id != currentUser.id).toList();

    if (uids.isEmpty) return false;

    try {
      final filterList = uids.take(100).map((id) => 'user_id.eq.$id').join(',');
      final rows = await client
          .from('profiles')
          .select()
          .or(filterList)
          .timeout(const Duration(seconds: 5));

      var changed = false;
      for (final row in rows) {
        final uid = row['user_id']?.toString() ?? '';
        if (uid.isEmpty) continue;
        final user = UserModel(
          id: uid,
          name: row['name']?.toString() ?? '',
          email: row['email']?.toString() ?? '',
          studentOrEmployeeId: row['student_or_employee_id']?.toString() ?? '',
          department: row['department']?.toString() ?? '',
          year: row['year']?.toString() ?? '',
          mobileNumber: row['mobile_number']?.toString() ?? '',
          avatarUrl: row['avatar_url']?.toString() ?? '',
          roles: const [UserRole.student],
          savedPostIds: const [],
          registeredEventIds: const [],
        );
        if (_knownProfiles[uid] == null ||
            _knownProfiles[uid]!.name != user.name ||
            _knownProfiles[uid]!.mobileNumber != user.mobileNumber) {
          _knownProfiles[uid] = user;
          changed = true;
        }
      }
      return changed;
    } catch (e) {
      debugPrint('StudentHub: profiles lookup failed: $e');
      return false;
    }
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
  RealtimeChannel? _postsRealtimeChannel;

  void _subscribeRealtimePosts() {
    final client = _client;
    if (client == null || _postsRealtimeChannel != null) return;
    try {
      _postsRealtimeChannel = client
          .channel('public:posts')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'posts',
            callback: (payload) {
              _handleRealtimePostPayload(payload);
            },
          )
          .subscribe();
      debugPrint('StudentHub: Realtime posts channel subscribed.');
    } catch (e) {
      debugPrint('StudentHub: Realtime posts subscription error: $e');
    }
  }

  void _handleRealtimePostPayload(dynamic payload) {
    try {
      final eventType = payload.eventType;
      if (eventType == PostgresChangeEvent.insert ||
          eventType == PostgresChangeEvent.update) {
        final record = payload.newRecord;
        if (record.isEmpty) return;
        final post = _postFromRow(record);
        if (post == null) return;

        _serverKnownIds.add(post.id);
        final idx = _posts.indexWhere((p) => p.id == post.id);
        if (idx != -1) {
          _posts[idx] = post;
        } else {
          _posts.insert(0, post);
        }

        if (!_notifications.any((n) => n.relatedPostId == post.id)) {
          _notifications.insert(
            0,
            _postNotification(
              post,
              publishedByMe: post.authorId == currentUser.id,
            ),
          );
        }

        _invalidateDataCaches();
        notifyListeners();
        _scheduleLocalSave();
      } else if (eventType == PostgresChangeEvent.delete) {
        final oldRecord = payload.oldRecord;
        final deletedId = oldRecord['id']?.toString();
        if (deletedId != null && deletedId.isNotEmpty) {
          _posts.removeWhere((p) => p.id == deletedId);
          _serverKnownIds.remove(deletedId);
          _invalidateDataCaches();
          notifyListeners();
          _scheduleLocalSave();
        }
      }
    } catch (e) {
      debugPrint('StudentHub: error handling realtime payload: $e');
    }
  }

  Future<({bool success, bool changed})> _syncFromBackend() async {
    final client = _client;
    if (client == null) {
      _recordReachability(false);
      return (success: false, changed: false);
    }
    _subscribeRealtimePosts();

    // Clean up demo account & demo posts from server database
    try {
      await client
          .from('posts')
          .delete()
          .or('author_id.eq.usr_101,author_name.eq.Aarav Sharma,author_name.ilike.%aarav%');
      await client
          .from('profiles')
          .delete()
          .or('user_id.eq.usr_101,email.eq.aarav.sharma@studenthub.edu');
    } catch (e) {
      debugPrint('StudentHub: demo server cleanup error: $e');
    }

    var changed = false;
    try {
      final rows = await client
          .from('posts')
          .select()
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(const Duration(seconds: 5));
      final fetched = rows
          .map(_postFromRow)
          .whereType<PostModel>()
          .where(
            (p) =>
                p.authorId != 'usr_101' &&
                !p.authorName.toLowerCase().contains('aarav'),
          )
          .toList();
      if (fetched.isEmpty) {
        // No seed push for demo posts
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

        // In-app notification for every post synced from server if not already present or cleared.
        for (final post in fetched) {
          if (_notificationsCleared &&
              _notificationsClearedAt != null &&
              post.timestamp.isBefore(_notificationsClearedAt!)) {
            continue;
          }
          if (!_notifications.any((n) => n.relatedPostId == post.id)) {
            _notifications.insert(
              0,
              _postNotification(
                post,
                publishedByMe: post.authorId == currentUser.id,
              ),
            );
            changed = true;
          }
        }
        _posts = [...localOnly, ...fetched];
        for (final post in localOnly) {
          _persistPost(post);
        }
        changed =
            changed ||
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
      if (await _syncFormSubmissions(client)) changed = true;
    } catch (e) {
      debugPrint('StudentHub: form submissions sync failed: $e');
    }
    try {
      if (await _syncProfilesForRegistrants(client)) changed = true;
    } catch (e) {
      debugPrint('StudentHub: registrant profiles sync failed: $e');
    }
    try {
      if (await _syncRoleRequests(client)) changed = true;
    } catch (e) {
      debugPrint('StudentHub: role request sync failed: $e');
    }
    try {
      if (await _syncAdminBroadcasts(client)) changed = true;
    } catch (e) {
      debugPrint('StudentHub: broadcast sync failed: $e');
    }
    _recordReachability(true);
    return (success: true, changed: changed);
  }

  /// Pulls ADMIN broadcasts (sent from the admin panel) into the in-app
  /// notification bell only — they never appear in the campus feed. Each
  /// broadcast becomes an unread notification carrying the "By Admin" marker.
  Future<bool> _syncAdminBroadcasts(SupabaseClient client) async {
    final rows = await client
        .from('broadcasts')
        .select()
        .order('created_at', ascending: false)
        .limit(50)
        .timeout(const Duration(seconds: 5));
    var changed = false;
    for (final row in rows) {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final title = row['title']?.toString() ?? '';
      if (title.isEmpty) continue;
      final createdAt = _parseDate(row['created_at']) ?? DateTime.now();
      if (_notificationsCleared &&
          _notificationsClearedAt != null &&
          createdAt.isBefore(_notificationsClearedAt!)) {
        continue;
      }
      final broadcastNotifId = 'notif_admin_broadcast_$id';
      if (_notifications.any((n) => n.id == broadcastNotifId)) continue;
      _notifications.insert(
        0,
        NotificationModel(
          id: broadcastNotifId,
          title: '📢 $title',
          body: '${row['body']?.toString() ?? ''}\n\nBy Admin',
          category: NotificationCategory.academic,
          timestamp: createdAt,
          relatedPostId: id,
        ),
      );
      changed = true;
    }
    if (changed) {
      _invalidateDataCaches();
      _scheduleLocalSave();
    }
    return changed;
  }



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

  Future<bool> _syncOwnProfile(SupabaseClient client) async {
    if (isLoggedOut || currentUser.id.isEmpty) return false;
    final currentDeviceId = await LocalStoreService.instance.getDeviceId();
    final rows = await client
        .from('profiles')
        .select('user_id, roles, is_verified, active_device_id, has_completed_progressive_form')
        .eq('user_id', currentUser.id)
        .limit(1)
        .timeout(const Duration(seconds: 5));
    if (rows.isEmpty) {
      await _pushSeedProfileToBackend(client);
      _syncedDeviceId = currentDeviceId;
      return false;
    }

    final row = rows.first;
    final serverActiveDeviceId = row['active_device_id']?.toString() ?? '';

    if (serverActiveDeviceId.isNotEmpty && serverActiveDeviceId != currentDeviceId) {
      if (_syncedDeviceId != null &&
          _syncedDeviceId == currentDeviceId &&
          _kickedForDeviceId != serverActiveDeviceId) {
        _kickedForDeviceId = serverActiveDeviceId;
        debugPrint('StudentHub: Active device changed on server. Triggering auto-logout & security notification.');
        _notifications.insert(
          0,
          NotificationModel(
            id: 'notif_sec_${DateTime.now().microsecondsSinceEpoch}',
            title: '🚨 Security Alert: New Device Login',
            body: 'Someone logged into your account from another device. For safety, this previous session was automatically terminated.',
            category: NotificationCategory.personal,
            timestamp: DateTime.now(),
          ),
        );
        unawaited(logout(reason: '🚨 Security Alert: Someone logged into your account from another device. Session terminated for safety.'));
        return true;
      } else {
        try {
          await client.from('profiles').update({
            'active_device_id': currentDeviceId,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('user_id', currentUser.id);
          _syncedDeviceId = currentDeviceId;
          currentUser = currentUser.copyWith(activeDeviceId: currentDeviceId);
        } catch (e) {
          debugPrint('StudentHub: active_device_id update failed: $e');
        }
      }
    } else if (serverActiveDeviceId == currentDeviceId) {
      _syncedDeviceId = currentDeviceId;
    }

    final serverRoles = ((row['roles'] as List?) ?? const [])
        .whereType<String>()
        .map(_roleFromName)
        .toList();
    final serverHasCompleted = row['has_completed_progressive_form'] as bool? ?? currentUser.hasCompletedProgressiveForm;

    final localSet = currentUser.roles.toSet();
    final serverSet = serverRoles.toSet();
    final rolesChanged =
        localSet.length != serverSet.length || !localSet.containsAll(serverSet);

    if (!rolesChanged && serverHasCompleted == currentUser.hasCompletedProgressiveForm) {
      return false;
    }

    // The server is the source of truth for granted roles: adopt it wholesale
    // (additions AND removals) so admin grants/revocations land on every
    // device without a re-login. An empty server list means "nothing granted
    // yet", so the local default (Student) survives for fresh profiles.
    final effectiveRoles = serverRoles.isEmpty ? currentUser.roles : serverRoles;
    currentUser = currentUser.copyWith(
      roles: effectiveRoles,
      isVerified: row['is_verified'] as bool? ?? currentUser.isVerified,
      hasCompletedProgressiveForm: serverHasCompleted,
    );
    if (!effectiveRoles.contains(activeRole)) {
      activeRole = effectiveRoles.isNotEmpty
          ? effectiveRoles.first
          : UserRole.student;
    }
    _scheduleLocalSave();
    return true;
  }

  Future<void> _pushSeedProfileToBackend(SupabaseClient client) async {
    final avatar = await _uploadAvatarIfNeeded(client, currentUser.avatarUrl);
    if (avatar != currentUser.avatarUrl) {
      currentUser = currentUser.copyWith(avatarUrl: avatar);
    }
    final deviceId = await LocalStoreService.instance.getDeviceId();
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
      'active_device_id': deviceId,
      'has_completed_progressive_form': currentUser.hasCompletedProgressiveForm,
      'saved_post_ids': currentUser.savedPostIds,
      'registered_event_ids': currentUser.registeredEventIds,
      'congratulated_post_ids': currentUser.congratulatedPostIds,
      'liked_post_ids': currentUser.likedPostIds,
      'is_verified': currentUser.isVerified,
    }, onConflict: 'user_id');
    _syncedDeviceId = deviceId;
  }

  Future<void> _persistProfile() async {
    final client = _client;
    if (client == null) return;
    try {
      final avatar = await _uploadAvatarIfNeeded(client, currentUser.avatarUrl);
      if (avatar != currentUser.avatarUrl) {
        currentUser = currentUser.copyWith(avatarUrl: avatar);
      }
      final deviceId = await LocalStoreService.instance.getDeviceId();
      await client.from('profiles').upsert({
        'user_id': currentUser.id,
        'name': currentUser.name,
        'email': currentUser.email,
        'student_or_employee_id': currentUser.studentOrEmployeeId,
        'department': currentUser.department,
        'year': currentUser.year,
        'mobile_number': currentUser.mobileNumber,
        'avatar_url': avatar,
        'active_device_id': deviceId,
        'has_completed_progressive_form': currentUser.hasCompletedProgressiveForm,
        'saved_post_ids': currentUser.savedPostIds,
        'registered_event_ids': currentUser.registeredEventIds,
        'congratulated_post_ids': currentUser.congratulatedPostIds,
        'liked_post_ids': currentUser.likedPostIds,
        'roles': currentUser.roles.map((r) => r == UserRole.eventHost ? 'host' : r.name).toList(),
        'is_verified': currentUser.isVerified,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
      _syncedDeviceId = deviceId;
    } catch (e) {
      debugPrint('StudentHub: profile not persisted: $e');
    }
  }

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
          if (_grantRoleFromRemote(remote)) {
            changed = true;
            unawaited(
              _pushRoleDecision(
                request: remote,
                status: RoleRequestStatus.approved,
                notes: remote.adminNotes,
              ),
            );
          }
        } else if (remote.status == RoleRequestStatus.rejected &&
            !_notifications.any((n) => n.relatedPostId == remote.id)) {
          final hasNote =
              remote.adminNotes != null && remote.adminNotes!.trim().isNotEmpty;
          _notifications.insert(
            0,
            NotificationModel(
              id: 'notif_${DateTime.now().microsecondsSinceEpoch}_${remote.id}_rev',
              title: 'Role Application Rejected',
              body: hasNote
                  ? 'Your application for ${remote.requestedRole.displayName} was rejected. Reason: ${remote.adminNotes}'
                  : 'Your application for ${remote.requestedRole.displayName} was rejected.',
              category: NotificationCategory.personal,
              timestamp: DateTime.now(),
              relatedPostId: remote.id,
            ),
          );
          changed = true;
          unawaited(
            _pushRoleDecision(
              request: remote,
              status: RoleRequestStatus.rejected,
              notes: remote.adminNotes,
            ),
          );
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
    final hasNote =
        req.adminNotes != null && req.adminNotes!.trim().isNotEmpty;
    _notifications.insert(
      0,
      NotificationModel(
        id: 'notif_${DateTime.now().microsecondsSinceEpoch}_${req.id}_appr',
        title: 'Role Approved! 🎖️',
        body: hasNote
            ? 'Congratulations! Your application for ${req.requestedRole.displayName} was approved. Message: ${req.adminNotes}'
            : req.isLimitedAccess && req.expiresAt != null
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
            notes: notes,
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

  /// OS push to the applicant's device ("Role Approved / Rejected") via the
  /// send-push function, targeted by user id. Best-effort.
  Future<void> _pushRoleDecision({
    required RoleRequestModel request,
    required RoleRequestStatus status,
    String? notes,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      final deviceId = await LocalStoreService.instance.getDeviceId();
      final approved = status == RoleRequestStatus.approved;
      final roleName = request.requestedRole.displayName;
      final hasNote = notes != null && notes.trim().isNotEmpty;
      final body = approved
          ? hasNote
              ? 'Congratulations! You are now $roleName.\nMessage: $notes'
              : 'Congratulations! You are now $roleName.'
          : hasNote
              ? 'Your application for $roleName was rejected.\nReason: $notes'
              : 'Your application for $roleName was rejected.';
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
              'title': approved
                  ? '🎖️ Role Approved!'
                  : '⛔ Role Request Rejected',
              'body': body,
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
    // `links` and `form` are text columns holding JSON documents, so rows can
    // arrive as raw String (PostgREST) or already-decoded List/Map (local
    // cache) depending on the source.
    List<PostLink> links;
    final linksRaw = row['links'];
    if (linksRaw is List) {
      links = linksRaw
          .whereType<Map>()
          .map((l) => PostLink.fromJson(l.cast<String, dynamic>()))
          .toList();
    } else if (linksRaw is String && linksRaw.trim().isNotEmpty) {
      try {
        links = (jsonDecode(linksRaw) as List? ?? const [])
            .whereType<Map>()
            .map((l) => PostLink.fromJson(l.cast<String, dynamic>()))
            .toList();
      } catch (_) {
        links = const [];
      }
    } else {
      links = const [];
    }
    FormDefinition? form;
    final formRaw = row['form'];
    if (formRaw is Map) {
      final f = FormDefinition.fromJson(formRaw.cast<String, dynamic>());
      if (f != null && f.title.trim().isNotEmpty && f.fields.isNotEmpty) form = f;
    } else if (formRaw is String && formRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(formRaw);
        if (decoded is Map) {
          final f = FormDefinition.fromJson(decoded.cast<String, dynamic>());
          if (f != null && f.title.trim().isNotEmpty && f.fields.isNotEmpty) form = f;
        }
      } catch (_) {
        form = null;
      }
    }
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
      imageUrls: ((row['image_urls'] as List?) ?? const []).cast<String>(),
      attachments: attachments,
      links: links,
      form: form,
      isUrgent: row['is_urgent'] as bool? ?? false,
      isPinned: row['is_pinned'] as bool? ?? false,
      saveCount: row['save_count'] as int? ?? 0,
      congratulateCount: row['congratulate_count'] as int? ?? 0,
      likeCount: row['like_count'] as int? ?? 0,
      congratulatedUserIds: ((row['congratulated_user_ids'] as List?) ??
              const [])
          .cast<String>(),
      likedUserIds: ((row['liked_user_ids'] as List?) ?? const []).cast<
          String>(),
      venue: row['venue'] as String?,
      eventDate: _parseDate(row['event_date']),
      registrationDeadline: _parseDate(row['registration_deadline']),
      maxParticipants: row['max_participants'] as int?,
      registeredUserIds: ((row['registered_user_ids'] as List?) ?? const [])
          .cast<String>(),
    );
  }

  Map<String, dynamic> _rowFromPost(PostModel p) {
    String? cleanUrl(String? url) {
      if (url == null || url.isEmpty) return null;
      if (url.startsWith('data:')) {
        return 'https://images.unsplash.com/photo-1523240795612-9a054b0db644?auto=format&fit=crop&w=600';
      }
      return url;
    }

    final cleanGallery = p.imageUrls
        .map(
          (u) => u.startsWith('data:')
              ? 'https://images.unsplash.com/photo-1523240795612-9a054b0db644?auto=format&fit=crop&w=600'
              : u,
        )
        .toList();

    return {
      'id': p.id,
      'title': p.title,
      'description': p.description,
      'category': p.category.name,
      'department': p.department,
      'target_year': p.targetYear ?? 'ALL',
      'author_name': p.authorName,
      'author_role': p.authorRole.name,
      'author_id': p.authorId,
      'image_url': cleanUrl(p.imageUrl),
      'image_urls': cleanGallery,
      'is_urgent': p.isUrgent,
      'is_pinned': p.isPinned,
      'save_count': p.saveCount,
      'congratulate_count': p.congratulateCount,
      'like_count': p.likeCount,
      'congratulated_user_ids': p.congratulatedUserIds,
      'liked_user_ids': p.likedUserIds,
      'venue': p.venue,
      'event_date': p.eventDate?.toIso8601String(),
      'registration_deadline': p.registrationDeadline?.toIso8601String(),
      'max_participants': p.maxParticipants,
      'registered_user_ids': p.registeredUserIds,
      'links': jsonEncode(p.links.map((l) => l.toJson()).toList()),
      'form': jsonEncode(p.form?.toJson() ?? {}),
      'attachments': p.attachments
          .map(
            (a) => {
              'title': a.title,
              'fileType': a.fileType,
              'url': cleanUrl(a.url) ?? a.url,
              'fileSize': a.fileSize,
            },
          )
          .toList(),
      'created_at': p.timestamp.toIso8601String(),
    };
  }

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
      stored = await _uploadGalleryImagesIfNeeded(stored);
      await client.from('posts').upsert(_rowFromPost(stored), onConflict: 'id');
      final idx = _posts.indexWhere((p) => p.id == post.id);
      if (idx != -1) _posts[idx] = stored;
      _serverKnownIds.add(post.id);
    } catch (e) {
      debugPrint('StudentHub: post ${post.id} persistence failed: $e');
      _scheduleLocalSave();
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

  /// Uploads every gallery image (data URI or local file ref) to Supabase
  /// Storage as `posts/<id>_gallery_<index>.<ext>` and returns the post with
  /// all public URLs. Remote/empty images are left untouched.
  Future<PostModel> _uploadGalleryImagesIfNeeded(PostModel post) async {
    final client = _client;
    if (client == null || post.imageUrls.isEmpty) return post;

    final uploaded = <String>[];
    var changed = false;
    for (var i = 0; i < post.imageUrls.length; i++) {
      final url = post.imageUrls[i];
      if (url.isEmpty) {
        uploaded.add(url);
        continue;
      }
      if (!url.startsWith('data:') && !_localStore.isLocalRef(url)) {
        uploaded.add(url);
        continue;
      }
      try {
        final bytes = url.startsWith('data:')
            ? await compute(
                _decodeBase64Helper,
                url.substring(url.indexOf(',') + 1),
              )
            : await _localStore.readLocalBlob(url);
        if (bytes == null || bytes.isEmpty) {
          uploaded.add(url);
          continue;
        }
        final ext = _extFromDataUri(url);
        final path = 'posts/${post.id}_gallery_$i.$ext';
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
        uploaded.add(client.storage.from('documents').getPublicUrl(path));
        changed = true;
      } catch (_) {
        uploaded.add(url);
      }
    }
    if (!changed) return post;
    return post.copyWith(imageUrls: uploaded);
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

      final aDeptMatch = a.department.isEmpty ||
          a.department == 'All' ||
          a.department == 'General' ||
          a.department == 'Campus' ||
          a.department == currentUser.department;
      final bDeptMatch = b.department.isEmpty ||
          b.department == 'All' ||
          b.department == 'General' ||
          b.department == 'Campus' ||
          b.department == currentUser.department;
      if (aDeptMatch != bDeptMatch) return aDeptMatch ? -1 : 1;

      final aYearMatch = a.targetYear == null ||
          a.targetYear == 'All' ||
          a.targetYear == currentUser.year;
      final bYearMatch = b.targetYear == null ||
          b.targetYear == 'All' ||
          b.targetYear == currentUser.year;
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
    List<String> postCongratulated = List.from(post.congratulatedUserIds);
    List<String> userCongratulated = List.from(
      currentUser.congratulatedPostIds,
    );
    final wasCongratulated = userCongratulated.contains(postId);

    if (wasCongratulated) {
      postCongratulated.remove(currentUser.id);
      userCongratulated.remove(postId);
    } else {
      if (!postCongratulated.contains(currentUser.id)) {
        postCongratulated.add(currentUser.id);
      }
      userCongratulated.add(postId);
    }

    _posts[index] = post.copyWith(
      congratulatedUserIds: postCongratulated,
      congratulateCount: postCongratulated.length,
    );
    currentUser = currentUser.copyWith(
      congratulatedPostIds: userCongratulated,
    );
    _persistPost(_posts[index]);
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
  }

  void toggleLikePost(String postId) {
    int index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    PostModel post = _posts[index];
    List<String> liked = List.from(post.likedUserIds);
    List<String> userLiked = List.from(currentUser.likedPostIds);

    if (liked.contains(currentUser.id)) {
      liked.remove(currentUser.id);
      userLiked.remove(postId);
    } else {
      liked.add(currentUser.id);
      userLiked.add(postId);
    }

    _posts[index] = post.copyWith(
      likedUserIds: liked,
      likeCount: liked.length,
    );
    currentUser = currentUser.copyWith(likedPostIds: userLiked);
    _persistPost(_posts[index]);
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
  }

  void toggleEventRegistration(String postId) {
    int index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    PostModel post = _posts[index];

    // Events with an attached registration form are handled by the form
    // flow (submitForm), never by the raw one-tap toggle.
    if (post.form != null) return;

    // Check if user previously cancelled and is permanently blocked
    if (currentUser.cancelledEventIds.contains(postId)) return;

    List<String> regUsers = List.from(post.registeredUserIds);
    List<String> userRegEvents = List.from(currentUser.registeredEventIds);

    if (regUsers.contains(currentUser.id)) {
      regUsers.removeWhere((id) => id == currentUser.id);
      userRegEvents.removeWhere((id) => id == postId);
      _formSubmissions.removeWhere(
        (s) => s.postId == postId && s.userId == currentUser.id,
      );
      unawaited(_deleteFormSubmission(postId, currentUser.id));
    } else {
      if (!_canRegister(post)) return;
      if (!regUsers.contains(currentUser.id)) {
        regUsers.add(currentUser.id);
      }
      if (!userRegEvents.contains(postId)) {
        userRegEvents.add(postId);
      }

      // Quick (no-form) registration records a submission entry with a
      // profile snapshot, so hosts see attendee data in Registration Stats.
      _formSubmissions.removeWhere(
        (s) => s.postId == postId && s.userId == currentUser.id,
      );
      final quickSubmission = FormSubmission(
        id: 'sub_${postId}_${currentUser.id}',
        postId: postId,
        formId: '',
        userId: currentUser.id,
        name: currentUser.name,
        studentOrEmployeeId: currentUser.studentOrEmployeeId,
        department: currentUser.department,
        year: currentUser.year,
        mobileNumber: currentUser.mobileNumber,
        submittedAt: DateTime.now(),
      );
      _formSubmissions.add(quickSubmission);
      unawaited(_persistFormSubmission(quickSubmission));

      // Add event registration notification
      _notifications.insert(
        0,
        NotificationModel(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Registration Confirmed! 🎉',
          body:
              'You have registered for "${post.title}". Keep an eye on updates.',
          category: NotificationCategory.events,
          timestamp: DateTime.now(),
          relatedPostId: post.id,
        ),
      );

      // Confirmation to the registrant's own devices.
      _pushBroadcast(
        post,
        type: 'registration_confirmed',
        title: '🎉 Registration Confirmed!',
        body: 'You have registered for "${post.title}". Keep an eye on updates.',
        recipientUserId: currentUser.id,
        skipSenderDevice: false,
      );

      // Let only the event host know via push ("X registered for Event").
      _pushBroadcast(
        post,
        type: 'event_registration',
        title: '🎟️ New event registration',
        body: '${currentUser.name} registered for "${post.title}"',
        registrantName: currentUser.name,
        recipientUserId: post.authorId,
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

    _posts[index] = post.copyWith(registeredUserIds: regUsers.toSet().toList());
    currentUser = currentUser.copyWith(registeredEventIds: userRegEvents.toSet().toList());
    _persistPost(_posts[index]);
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
  }

  /// Cancels registration permanently for an event and blocks future re-registration.
  void cancelRegistrationPermanently(String postId) {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final post = _posts[idx];

    final regUsers = List<String>.from(post.registeredUserIds)..removeWhere((id) => id == currentUser.id);
    final userRegEvents = List<String>.from(currentUser.registeredEventIds)..removeWhere((id) => id == postId);
    final cancelledEvents = Set<String>.from(currentUser.cancelledEventIds)..add(postId);

    _formSubmissions.removeWhere(
      (s) => s.postId == postId && s.userId == currentUser.id,
    );
    unawaited(_deleteFormSubmission(postId, currentUser.id));

    _posts[idx] = post.copyWith(registeredUserIds: regUsers.toSet().toList());
    currentUser = currentUser.copyWith(
      registeredEventIds: userRegEvents.toSet().toList(),
      cancelledEventIds: cancelledEvents.toList(),
    );
    _persistPost(_posts[idx]);
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
  }

  /// Whether the event/workshop still accepts registrations: not past the
  /// deadline and not full.
  bool _canRegister(PostModel post) {
    final deadline = post.registrationDeadline;
    if (deadline != null && DateTime.now().isAfter(deadline)) return false;
    if (post.maxParticipants != null &&
        post.registeredUserIds.length >= post.maxParticipants!) {
      return false;
    }
    return true;
  }

  /// Human-readable reason a student can no longer register (button helper).
  /// Returns null when registration is still open.
  String? registrationBlockReason(PostModel post) {
    if (post.maxParticipants != null &&
        post.registeredUserIds.length >= post.maxParticipants!) {
      return 'Registrations closed (seats full)';
    }
    final deadline = post.registrationDeadline;
    if (deadline != null && DateTime.now().isAfter(deadline)) {
      return 'Registration closed (deadline passed)';
    }
    return null;
  }

  /// Submits a filled form. For events this *is* the registration: the user is
  /// added to [registeredUserIds] with the same confirmations + host pushes as
  /// the quick toggle. For posts it just records the submission and alerts the
  /// author. Returns false when submission is rejected (duplicate, full,
  /// closed, or offline-host rules).
  Future<bool> submitForm({
    required PostModel post,
    required Map<String, dynamic> answers,
  }) async {
    final isEvent = post.isEvent;
    if (isEvent && !_canRegister(post)) return false;
    if (!isEvent && post.form?.allowResubmit == false) {
      final existing = _formSubmissions.any(
        (s) =>
            s.postId == post.id &&
            s.userId == currentUser.id &&
            s.formId == post.form?.id,
      );
      if (existing) return false;
    }

    final submission = FormSubmission(
      id: 'sub_${DateTime.now().microsecondsSinceEpoch}',
      postId: post.id,
      formId: post.form?.id,
      userId: currentUser.id,
      name: currentUser.name,
      studentOrEmployeeId: currentUser.studentOrEmployeeId,
      department: currentUser.department,
      year: currentUser.year,
      mobileNumber: currentUser.mobileNumber,
      answers: answers,
      submittedAt: DateTime.now(),
    );
    _formSubmissions.add(submission);

    if (isEvent) {
      final regUsers = List<String>.from(post.registeredUserIds);
      final userRegEvents = List<String>.from(currentUser.registeredEventIds);
      regUsers.add(currentUser.id);
      userRegEvents.add(post.id);

      _notifications.insert(
        0,
        NotificationModel(
          id: 'notif_${DateTime.now().microsecondsSinceEpoch}',
          title: 'Registration Confirmed! 🎉',
          body:
              'You have registered for ${post.title}. Keep an eye on updates.',
          category: NotificationCategory.events,
          timestamp: DateTime.now(),
          relatedPostId: post.id,
        ),
      );
      _pushBroadcast(
        post,
        type: 'registration_confirmed',
        title: '🎉 Registration Confirmed!',
        body: 'You have registered for "${post.title}". Keep an eye on updates.',
        recipientUserId: currentUser.id,
        skipSenderDevice: false,
      );
      _pushBroadcast(
        post,
        type: 'event_registration',
        title: '🎟️ New event registration',
        body: '${currentUser.name} registered for "${post.title}"',
        registrantName: currentUser.name,
        recipientUserId: post.authorId,
      );
      if (regUsers.length >= (post.maxParticipants ?? regUsers.length + 1)) {
        _pushBroadcast(
          post,
          type: 'registrations_closed',
          title: '⛔ Registrations closed',
          body: 'The event "${post.title}" is now full.',
        );
      }

      final idx = _posts.indexWhere((p) => p.id == post.id);
      if (idx != -1) {
        _posts[idx] = _posts[idx].copyWith(registeredUserIds: regUsers);
        _persistPost(_posts[idx]);
      }
      currentUser = currentUser.copyWith(registeredEventIds: userRegEvents);
    } else {
      _pushBroadcast(
        post,
        type: 'form_submission',
        title: '📝 New form response',
        body: '${currentUser.name} filled "${post.form?.title ?? 'your form'}"',
        registrantName: currentUser.name,
        recipientUserId: post.authorId,
      );
    }

    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
    unawaited(_persistFormSubmission(submission));
    return true;
  }

  /// Rewrites this user's submission for a post (used when a form allows
  /// resubmission/editing).
  void updateMySubmission({
    required String postId,
    required Map<String, dynamic> answers,
  }) {
    final idx = _formSubmissions.indexWhere(
      (s) => s.postId == postId && s.userId == currentUser.id,
    );
    if (idx == -1) return;
    _formSubmissions[idx] = _formSubmissions[idx].copyWith(answers: answers);
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
    unawaited(_persistFormSubmission(_formSubmissions[idx]));
  }

  /// Withdraws the current user's registration + form submission for an event.
  void withdrawRegistration(String postId) {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final post = _posts[idx];
    final regUsers = List<String>.from(post.registeredUserIds)
      ..remove(currentUser.id);
    final userRegEvents = List<String>.from(currentUser.registeredEventIds)
      ..remove(postId);
    _formSubmissions.removeWhere(
      (s) => s.postId == postId && s.userId == currentUser.id,
    );
    unawaited(_deleteFormSubmission(postId, currentUser.id));
    _posts[idx] = post.copyWith(registeredUserIds: regUsers);
    currentUser = currentUser.copyWith(registeredEventIds: userRegEvents);
    _persistPost(_posts[idx]);
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
  }

  /// All submissions for a post, newest first, deduplicated by user ID. For events,
  /// guarantees every user in [registeredUserIds] is included so stats and registrant
  /// lists always display complete attendee data.
  List<FormSubmission> submissionsForPost(String postId) {
    final postList = _posts.where((p) => p.id == postId).toList();
    final post = postList.isNotEmpty ? postList.first : null;

    final list = _formSubmissions
        .where((s) => s.postId == postId)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    final seen = <String>{};
    final deduplicated = <FormSubmission>[];
    for (final sub in list) {
      if (seen.add(sub.userId)) {
        final known = _knownProfiles[sub.userId];
        final enriched = (known != null && (sub.mobileNumber.isEmpty || sub.mobileNumber == 'N/A' || sub.name.startsWith('Registered Student')))
            ? sub.copyWith(
                name: known.name.isNotEmpty ? known.name : sub.name,
                studentOrEmployeeId: known.studentOrEmployeeId.isNotEmpty ? known.studentOrEmployeeId : sub.studentOrEmployeeId,
                department: known.department.isNotEmpty ? known.department : sub.department,
                year: known.year.isNotEmpty ? known.year : sub.year,
                mobileNumber: known.mobileNumber.isNotEmpty ? known.mobileNumber : sub.mobileNumber,
              )
            : sub;
        deduplicated.add(enriched);
      }
    }

    if (post != null && post.isEvent) {
      for (final uid in post.registeredUserIds) {
        if (seen.add(uid)) {
          final isMe = uid == currentUser.id;
          final known = _knownProfiles[uid];
          final name = isMe
              ? currentUser.name
              : (known != null && known.name.isNotEmpty
                  ? known.name
                  : 'Registered Student ($uid)');
          final sid = isMe
              ? currentUser.studentOrEmployeeId
              : (known != null && known.studentOrEmployeeId.isNotEmpty
                  ? known.studentOrEmployeeId
                  : uid);
          final dept = isMe
              ? currentUser.department
              : (known != null && known.department.isNotEmpty
                  ? known.department
                  : post.department);
          final yr = isMe
              ? currentUser.year
              : (known != null && known.year.isNotEmpty
                  ? known.year
                  : 'Student');
          final phone = isMe
              ? currentUser.mobileNumber
              : (known != null && known.mobileNumber.isNotEmpty
                  ? known.mobileNumber
                  : 'N/A');

          deduplicated.add(
            FormSubmission(
              id: 'sub_synced_${postId}_$uid',
              postId: postId,
              userId: uid,
              name: name,
              studentOrEmployeeId: sid,
              department: dept,
              year: yr,
              mobileNumber: phone,
              submittedAt: post.timestamp,
            ),
          );
        }
      }
    }

    return deduplicated;
  }

  /// One-click broadcast (OS push + in-app bell) to everyone registered /
  /// who filled a form for this post. Includes sender and event details.
  Future<void> sendMessageToRegistrants({
    required PostModel post,
    required String title,
    required String body,
  }) async {
    final userIds = <String>{
      ...post.registeredUserIds,
      ..._formSubmissions
          .where((s) => s.postId == post.id)
          .map((s) => s.userId),
    }.where((id) => id.isNotEmpty).toList();

    final authorRole = currentUser.roles.isNotEmpty ? currentUser.roles.first.displayName : 'Host';
    final notifTitle = title.trim().isEmpty
        ? '📢 Update for ${post.title}'
        : '📢 ${title.trim()} - ${post.title}';
    final notifBody = body.trim().isEmpty
        ? 'A new update was sent for "${post.title}".\n(Sent by ${currentUser.name} [$authorRole])'
        : '${body.trim()}\n\n(Sent by ${currentUser.name} [$authorRole] for "${post.title}")';

    for (final uid in userIds) {
      // In-app bell notification entry for every target user
      _notifications.insert(
        0,
        NotificationModel(
          id: 'notif_${DateTime.now().microsecondsSinceEpoch}_${uid.substring(0, math.min(4, uid.length))}',
          title: notifTitle,
          body: notifBody,
          category: post.isEvent
              ? NotificationCategory.events
              : NotificationCategory.general,
          timestamp: DateTime.now(),
          relatedPostId: post.id,
        ),
      );

      // Push notification broadcast if not current user
      if (uid != currentUser.id) {
        _pushBroadcast(
          post,
          type: 'registrant_message',
          title: notifTitle,
          body: notifBody,
          recipientUserId: uid,
        );
      }
    }
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
  }

  /// Best-effort mirror of a form submission row to the backend. Offline or
  /// missing-table failures are ignored; the local record is authoritative.
  Future<void> _persistFormSubmission(FormSubmission s) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('form_submissions').upsert({
        'id': s.id.isEmpty ? 'sub_${s.postId}_${s.userId}' : s.id,
        'post_id': s.postId,
        'form_id': s.formId ?? '',
        'user_id': s.userId,
        'name': s.name,
        'student_or_employee_id': s.studentOrEmployeeId,
        'department': s.department,
        'year': s.year,
        'mobile_number': s.mobileNumber,
        'answers': s.answers,
        'submitted_at': s.submittedAt.toIso8601String(),
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('StudentHub: submission ${s.id} not persisted: $e');
    }
  }

  /// Removes a form submission row from backend (e.g., when a student unregisters).
  Future<void> _deleteFormSubmission(String postId, String userId) async {
    final client = _client;
    if (client == null) return;
    try {
      await client
          .from('form_submissions')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('StudentHub: submission deletion failed: $e');
    }
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
      final isEvent = newPost.isEvent;
      final isGallery = newPost.category == PostCategory.gallery;

      // Everyone else (never the publisher device) sees the "new post" push.
      _pushBroadcast(
        newPost,
        title: isEvent
            ? '🎉 New event posted'
            : isGallery
                ? '📸 New gallery posted'
                : '📢 New announcement posted',
        body: newPost.title,
        skipSenderDevice: true,
      );

      // The publisher's own devices get a live confirmation instead.
      _pushBroadcast(
        newPost,
        type: 'post_live',
        title: isEvent
            ? '✅ Your event is live!'
            : isGallery
                ? '✅ Your gallery is live on Campus Feed!'
                : '✅ Your post is live on Campus Feed!',
        body: newPost.title,
        recipientUserId: currentUser.id,
        skipSenderDevice: false,
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
    // Posts that failed to persist are device-only: the server never had them,
    // so there is nothing to delete remotely — skip the (rejected) server call.
    final neverOnServer = _deviceOnlyPostIds.contains(postId);
    if (client != null && !neverOnServer) {
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
    _deviceOnlyPostIds.remove(postId);
    if (client != null && !neverOnServer) {
      await _client?.from('posts').delete().eq('id', postId);
    }
    _localStore.deleteLocalBlob(removed.imageUrl);
    for (final img in removed.imageUrls) {
      _localStore.deleteLocalBlob(img);
    }
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
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
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

  /// Sends a push via the send-push Edge Function. By default it broadcasts
  /// to every registered device except this one (used for new posts, event
  /// registrations and registration-closed updates). Pass [recipientUserId]
  /// to target only one user's devices (e.g. the event host, or the
  /// registrant's own confirmation), [recipientUserIds] to target a batch of
  /// users (e.g. every registrant of an event), [excludeUserId] to exclude an
  /// entire user's devices (e.g. the publisher), and [skipSenderDevice] =
  /// false to also deliver to this device.
  Future<void> _pushBroadcast(
    PostModel post, {
    String type = 'new_post',
    String? title,
    String? body,
    String? registrantName,
    String? recipientUserId,
    List<String>? recipientUserIds,
    String? excludeUserId,
    bool skipSenderDevice = true,
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
              'recipient_user_id': recipientUserId,
              'recipient_user_ids': recipientUserIds,
              'exclude_user_id': excludeUserId,
              'skip_sender_device': skipSenderDevice,
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

  Future<void> updateUserProfile({
    required String name,
    required String department,
    required String year,
    String? studentOrEmployeeId,
    String? avatarUrl,
    String? mobileNumber,
  }) async {
    bool hasChanged = currentUser.hasChangedUniqueId;
    String finalId = currentUser.studentOrEmployeeId;

    if (studentOrEmployeeId != null &&
        studentOrEmployeeId.trim().isNotEmpty &&
        studentOrEmployeeId.trim() != currentUser.studentOrEmployeeId) {
      final trimmedId = studentOrEmployeeId.trim();
      final available = await isMitIdAvailable(
        trimmedId,
        excludeUserId: currentUser.id,
      );
      if (!available) {
        throw Exception(
          'MIT ID "$trimmedId" is already registered to another account on the server. Please enter your unique MIT ID.',
        );
      }
      if (!hasChanged) {
        finalId = trimmedId;
        hasChanged = true;
      }
    }

    currentUser = currentUser.copyWith(
      name: name.trim(),
      department: department,
      year: year,
      studentOrEmployeeId: finalId,
      hasChangedUniqueId: hasChanged,
      mobileNumber: (mobileNumber != null && mobileNumber.trim().isNotEmpty)
          ? mobileNumber.trim()
          : currentUser.mobileNumber,
      avatarUrl: (avatarUrl != null && avatarUrl.trim().isNotEmpty)
          ? avatarUrl.trim()
          : currentUser.avatarUrl,
    );

    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
    await _persistProfile();
  }

  Future<bool> refreshUserProfile() async {
    final client = _client;
    if (client == null) return false;
    try {
      final rows = await client
          .from('profiles')
          .select()
          .eq('user_id', currentUser.id)
          .limit(1);

      if (rows.isNotEmpty) {
        final r = rows.first;
        final serverRoles = ((r['roles'] as List?) ?? const ['student'])
            .whereType<String>()
            .map(_roleFromName)
            .toList();

        currentUser = currentUser.copyWith(
          name: (r['name']?.toString() ?? '').isNotEmpty ? r['name'].toString() : currentUser.name,
          roles: serverRoles.isEmpty ? [UserRole.student] : serverRoles,
          isVerified: r['is_verified'] as bool? ?? currentUser.isVerified,
        );

        if (!currentUser.roles.contains(activeRole)) {
          activeRole = currentUser.roles.first;
        }

        _invalidateDataCaches();
        notifyListeners();
        _scheduleLocalSave();
        return true;
      }
    } catch (e) {
      debugPrint('StudentHub: refresh profile error: $e');
    }
    return false;
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
          body: notes != null && notes.trim().isNotEmpty
              ? 'Congratulations! Your application for ${req.requestedRole.displayName} was approved. Message: $notes'
              : req.isLimitedAccess && req.expiresAt != null
                  ? 'Congratulations! Your temporary ${req.requestedRole.displayName} access is approved until ${_formatDate(req.expiresAt!)}.'
                  : 'Congratulations! Your application for ${req.requestedRole.displayName} was approved.',
          category: NotificationCategory.personal,
          timestamp: DateTime.now(),
          relatedPostId: req.id,
        ),
      );
    } else if (status == RoleRequestStatus.rejected) {
      _notifications.insert(
        0,
        NotificationModel(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Role Application Rejected',
          body: notes != null && notes.trim().isNotEmpty
              ? 'Your application for ${req.requestedRole.displayName} was rejected. Reason: $notes'
              : 'Your application for ${req.requestedRole.displayName} was rejected.',
          category: NotificationCategory.personal,
          timestamp: DateTime.now(),
          relatedPostId: req.id,
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

  void clearAllNotifications() {
    _notificationsCleared = true;
    _notificationsClearedAt = DateTime.now();
    _notifications.clear();
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
        congratulatedUserIds: ['usr_101'],
        congratulateCount: 1,
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

  /// Seeds registration/submission entries for the mock registered users so
  /// the host-side Registration Stats screen has data out of the box.
  void _generateMockSubmissions() {
    final now = DateTime.now();
    _formSubmissions = [
      FormSubmission(
        id: 'sub_101',
        postId: 'pst_002',
        userId: 'usr_102',
        name: 'Rohan Gupta',
        studentOrEmployeeId: 'MIT/CS/2023/118',
        department: 'Computer Science & Engineering',
        year: 'Third Year',
        mobileNumber: '+91 99887 76655',
        answers: {'teamSize': '3 members', 'mode': 'Offline'},
        submittedAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      FormSubmission(
        id: 'sub_102',
        postId: 'pst_002',
        userId: 'usr_103',
        name: 'Sneha Kulkarni',
        studentOrEmployeeId: 'MIT/CS/2023/071',
        department: 'Computer Science & Engineering',
        year: 'Third Year',
        mobileNumber: '+91 97788 12340',
        answers: {'teamSize': 'Solo (1)', 'mode': 'Online'},
        submittedAt: now.subtract(const Duration(hours: 6)),
      ),
      FormSubmission(
        id: 'sub_103',
        postId: 'pst_004',
        userId: 'usr_105',
        name: 'Arjun Nair',
        studentOrEmployeeId: 'MIT/CS/2024/056',
        department: 'Computer Science & Engineering',
        year: 'Second Year',
        mobileNumber: '+91 96655 43210',
        answers: {'teamSize': '2 members', 'mode': 'Offline'},
        submittedAt: now.subtract(const Duration(days: 2, hours: 1)),
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
    required this.formSubmissions,
    required this.serverKnownIds,
    required this.deviceOnlyPostIds,
  });

  final UserModel currentUser;
  final UserRole? activeRole;
  final List<PostModel> posts;
  final List<NotificationModel> notifications;
  final List<RoleRequestModel> roleRequests;
  final List<ActiveAnnouncement> announcements;
  final List<FormSubmission> formSubmissions;
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
