import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../widgets/app_image.dart' show clearCachedImage;
import '../config/supabase_config.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/role_request_model.dart';
import '../models/notification_model.dart';
import '../models/form_models.dart';
import 'local_store_service.dart';

/// Which password interaction the login form must show next.
enum PasswordMode {
  /// User must choose a first password (new or legacy account).
  set,

  /// User must enter the existing password (new device login).
  enter,
}

/// Thrown by [MockDataService.loginUser] when the account is password
/// protected and this login attempt cannot continue without one. The auth
/// screen switches to the matching password UI using [mode].
class PasswordRequiredException implements Exception {
  final PasswordMode mode;
  final String email;
  final String userId;
  final String accountName;

  /// True when the account row already exists on the server but never set a
  /// password (legacy user forced into the set-password flow).
  final bool isExistingAccount;

  const PasswordRequiredException({
    required this.mode,
    required this.email,
    this.userId = '',
    this.accountName = '',
    this.isExistingAccount = false,
  });

  @override
  String toString() =>
      mode == PasswordMode.set ? 'set_password' : 'enter_password';
}

/// Neutral placeholder written into a server row when an image could not be
/// uploaded (still device-only). Other devices see a generic image instead of
/// a broken frame; a background backfill replaces it with the real URL later.
const String _fallbackImageUrl =
    'https://images.unsplash.com/photo-1523240795612-9a054b0db644?auto=format&fit=crop&w=600';

class MockDataService extends ChangeNotifier with WidgetsBindingObserver {
  late AppConfig config;
  late UserModel currentUser;
  late UserRole activeRole;

  List<PostModel> _posts = [];
  List<RoleRequestModel> _roleRequests = [];
  List<NotificationModel> _notifications = [];
  List<FormSubmission> _formSubmissions = [];
  final Map<String, int> _profileLikes = {};
  final Set<String> _likedProfileAuthorIds = {};
  final Map<String, String> _authorAvatarCache = {};
  bool _notificationsCleared = false;
  DateTime? _notificationsClearedAt;
  final Set<String> _dismissedNotificationIds = {};
  bool get notificationsCleared => _notificationsCleared;
  DateTime? get notificationsClearedAt => _notificationsClearedAt;
  Set<String> get dismissedNotificationIds => Set.unmodifiable(_dismissedNotificationIds);

  static String? _sanitizeAvatarUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (trimmed.contains('unsplash.com') || trimmed == _fallbackImageUrl) {
      return null;
    }
    return trimmed;
  }

  String? getAuthorAvatar(String? authorId, String? authorName) {
    return _resolveAuthorAvatar(authorId, authorName);
  }

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

  /// True when a locally-restored session completed onboarding. Lets the app
  /// open straight to the feed for real users while stubs (seed/demo or
  /// phantom accounts) always land on the login screen.
  bool _restoredCompletedSession = false;
  bool get restoredCompletedSession => _restoredCompletedSession;

  /// True once this identity has (or had) a real row on the server. Lets the
  /// sync distinguish "never had a server profile" (seed/phantom stubs, which
  /// are silently ignored) from "had one and it disappeared" (account deleted
  /// by an admin — force logout + wipe the device).
  bool _hadServerProfile = false;
  bool get hadServerProfile => _hadServerProfile;

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
    _cacheSubmissions = List.unmodifiable(_formSubmissions);
  }

  List<PostModel> get posts => _cachePosts;
  List<RoleRequestModel> get roleRequests => _cacheRoleRequests;
  List<NotificationModel> get notifications => _cacheNotifications;
  List<FormSubmission> get formSubmissions => _cacheSubmissions;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final modeStr = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await LocalStoreService.instance.setThemeMode(modeStr);
    notifyListeners();
  }

  MockDataService({AppConfig? initialConfig}) {
    config = initialConfig ?? AppConfig.defaultConfig();
    _seedDefaults();
    _invalidateDataCaches();
    _attachLifecycleObserver();
    _initData(initialConfig);
  }
  bool _isDisposed = false;

  /// Registers for app lifecycle events so a pending debounced snapshot is
  /// flushed before the process is suspended or killed. Without this, read /
  /// clear marks made right before closing the app (within the 400ms debounce
  /// window) never reach disk and the notifications come back on the next
  /// launch. Guarded because unit tests may run without a widget binding.
  void _attachLifecycleObserver() {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // No binding (pure Dart tests): lifecycle flush simply won't fire.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(flushLocalSave());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _expiryTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _initData(AppConfig? initialConfig) async {
    if (initialConfig == null) {
      AppConfig.loadFromAssets().then((c) {
        if (_isDisposed) return;
        config = c;
        _invalidateDataCaches();
        notifyListeners();
      });
    }

    final restored = await _loadLocalState();
    if (_isDisposed) return;

    if (restored != null) {
      final cleanUserAvatar = _sanitizeAvatarUrl(restored.currentUser.avatarUrl) ?? '';
      currentUser = restored.currentUser.copyWith(avatarUrl: cleanUserAvatar);
      activeRole = restored.activeRole ??
          (currentUser.roles.isNotEmpty
              ? currentUser.roles.first
              : UserRole.student);

      // A restored profile that completed onboarding is a genuine session and
      // may skip the login screen on restart. Stubs (seed/demo users and
      // phantom accounts created by older builds) never are.
      _restoredCompletedSession =
          currentUser.id.isNotEmpty && currentUser.hasCompletedProgressiveForm;
      _hadServerProfile = restored.hadServerProfile;

      _posts = restored.posts.map((p) {
        final clean = _sanitizeAvatarUrl(p.authorAvatarUrl);
        return clean != p.authorAvatarUrl ? p.copyWith(authorAvatarUrl: clean) : p;
      }).toList();
      _notifications = restored.notifications
          .where((n) => !n.id.startsWith('notif_save_'))
          .toList();
      _notificationsCleared = restored.notificationsCleared;
      _notificationsClearedAt = restored.notificationsClearedAt;
      _dismissedNotificationIds
        ..clear()
        ..addAll(restored.dismissedNotificationIds);
      if (_notificationsCleared && _notificationsClearedAt != null) {
        final cutoff = _notificationsClearedAt!.toUtc();
        _notifications.removeWhere((n) {
          if (_dismissedNotificationIds.contains(n.id)) return true;
          if (n.relatedPostId != null && _dismissedNotificationIds.contains(n.relatedPostId)) return true;
          return !n.timestamp.toUtc().isAfter(cutoff);
        });
      }
      _roleRequests = restored.roleRequests;
      _formSubmissions = restored.formSubmissions;
      _showAllYearsFeed = restored.showAllYearsFeed;
      _serverKnownIds
        ..clear()
        ..addAll(restored.serverKnownIds);
      _deviceOnlyPostIds
        ..clear()
        ..addAll(restored.deviceOnlyPostIds);
      _profileLikes
        ..clear()
        ..addAll(restored.profileLikes);
      _likedProfileAuthorIds
        ..clear()
        ..addAll(restored.likedProfileAuthorIds);
      checkForExpiredRoles();
      _invalidateDataCaches();
      notifyListeners();
    }

    if (_isDisposed) return;

    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      checkForExpiredRoles();
    });

    // Lightweight polling: keeps the in-app notification bell fresh with posts
    // published by other devices without the user pulling to refresh.
    _syncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_periodicSync());
    });

    final savedTheme = await LocalStoreService.instance.getThemeMode();
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

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
  ///
  /// Concurrent calls coalesce into a single run: many flows trigger a sync
  /// back-to-back (post publish, push arrival, login), and overlapping merges
  /// could double-apply rows or interleave updates.
  Future<void> syncNow() async {
    if (_syncInFlight) return;
    _syncInFlight = true;
    try {
      await _syncFromBackend();
      _invalidateDataCaches();
      notifyListeners();
    } finally {
      _syncInFlight = false;
    }
  }

  Future<void> _seedDefaults() async {
    currentUser = UserModel(
      id: 'usr_101',
      name: 'Aarav Sharma',
      email: 'aarav.sharma@studenthub.edu',
      studentOrEmployeeId: 'MIT/CS/2023/042',
      department: 'Computer Science & Engineering',
      year: 'Third Year',
      mobileNumber: '+91 98765 43210',
      avatarUrl: '',
      roles: const [UserRole.student, UserRole.eventHost],
      savedPostIds: const ['pst_001'],
      registeredEventIds: const ['pst_004'],
      congratulatedPostIds: const ['pst_005'],
      likedPostIds: const ['pst_001'],
      isVerified: true,
    );

    activeRole = UserRole.student;

    _generateMockPosts();
    _generateMockRoleRequests();
    _generateMockNotifications();
    _generateMockSubmissions();

    _profileLikes.addAll({
      'fac_101': 48,
      'fac_102': 32,
      'fac_103': 64,
      'host_202': 115,
      'adm_001': 89,
      'usr_101': 24,
    });
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
          'interests': currentUser.interests,
          'activeDeviceId': currentUser.activeDeviceId,
          'roleExpirations': currentUser.roleExpirations.map(
            (role, expiry) => MapEntry(role.name, expiry.toIso8601String()),
          ),
        },
        'posts': postsJson,
        'notifications': _notifications.map(_notificationToJson).toList(),
        'roleRequests': _roleRequests.map(_roleRequestToJson).toList(),
        'formSubmissions': _formSubmissions.map(_submissionToJson).toList(),
        'serverKnownIds': _serverKnownIds.toList(),
        'deviceOnlyPostIds': _deviceOnlyPostIds.toList(),
        'showAllYearsFeed': _showAllYearsFeed,
        'profileLikes': _profileLikes,
        'likedProfileAuthorIds': _likedProfileAuthorIds.toList(),
        'hadServerProfile': _hadServerProfile,
        'notificationsCleared': _notificationsCleared,
        'notificationsClearedAt':
            _notificationsClearedAt?.toUtc().toIso8601String(),
        'dismissedNotificationIds': _dismissedNotificationIds.toList(),
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
      final showAllYearsFeed = payload['showAllYearsFeed'] as bool? ?? false;
      final rawLikes = (payload['profileLikes'] as Map?) ?? const {};
      final profileLikes = <String, int>{};
      rawLikes.forEach((k, v) {
        if (v is int) profileLikes[k.toString()] = v;
      });
      final likedProfileAuthorIds =
          ((payload['likedProfileAuthorIds'] as List?) ?? const [])
              .whereType<String>()
              .toSet();
      final hadServerProfile =
          payload['hadServerProfile'] as bool? ?? false;
      final notificationsCleared =
          payload['notificationsCleared'] as bool? ?? false;
      final parsedClearedAt = DateTime.tryParse(
        payload['notificationsClearedAt']?.toString() ?? '',
      )?.toUtc();
      final notificationsClearedAt = (parsedClearedAt != null &&
              parsedClearedAt.isAfter(DateTime.now().toUtc()))
          ? DateTime.now().toUtc()
          : parsedClearedAt;
      final dismissedNotificationIds =
          ((payload['dismissedNotificationIds'] as List?) ?? const [])
              .whereType<String>()
              .toSet();

      return _LocalState(
        currentUser: user,
        activeRole: active,
        posts: posts,
        notifications: notifications,
        roleRequests: roleRequests,
        formSubmissions: formSubmissions,
        serverKnownIds: serverKnownIds,
        deviceOnlyPostIds: deviceOnlyPostIds,
        showAllYearsFeed: showAllYearsFeed,
        profileLikes: profileLikes,
        likedProfileAuthorIds: likedProfileAuthorIds,
        hadServerProfile: hadServerProfile,
        notificationsCleared: notificationsCleared,
        notificationsClearedAt: notificationsClearedAt,
        dismissedNotificationIds: dismissedNotificationIds,
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
      interests: ((m['interests'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
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

  /// Required before an account can be used: either a password must be chosen
  /// (new/legacy account) or the correct one entered (password-protected
  /// account on a different device). The auth screen uses [mode] to pick the
  /// "Set Password" vs "Enter Password" UI.
  ///
  /// When [continueAs] is true (the "Continue as..." card) the account MUST
  /// already exist on the server: the lookup is never allowed to fabricate a
  /// fresh identity, so a failed/empty lookup surfaces a clear error instead
  /// of trapping the user in the onboarding form.
  Future<void> loginUser({
    required String name,
    required String email,
    required String mobileNumber,
    bool continueAs = false,
  }) async {
    _isLoggedOut = false;
    logoutReason = null;
    _kickedForDeviceId = null;
    _syncedDeviceId = null;
    final deviceId = await LocalStoreService.instance.getDeviceId();
    final client = _client;

    // Continue-as is a quick re-entry on THIS device for the account that was
    // just signed out of it. Restore it instantly from the local snapshot —
    // the server lookup happens in the background (syncNow), so a slow or
    // flaky network can never block the redirect or make the app look stuck.
    final snap = lastKnownUser;
    if (continueAs &&
        snap != null &&
        snap.email == email.trim().toLowerCase()) {
      currentUser = snap.copyWith(activeDeviceId: deviceId);
      activeRole = currentUser.roles.first;
      _syncedDeviceId = deviceId;
      _hadServerProfile = true;
      _invalidateDataCaches();
      notifyListeners();
      _scheduleLocalSave();
      _subscribeRealtimeOwnProfile();
      _subscribePresence();
      unawaited(syncNow());
      return;
    }

    if (client != null) {
      try {
        final r = await _bestProfileByEmail(email, client);

        if (r != null) {
          final hasPassword = r['has_password'] as bool? ?? false;
          final serverActiveDeviceId = r['active_device_id']?.toString() ?? '';

          if (hasPassword &&
              serverActiveDeviceId.isNotEmpty &&
              serverActiveDeviceId != deviceId) {
            // A password was set from another device: verify it here.
            throw PasswordRequiredException(
              mode: PasswordMode.enter,
              email: email.trim().toLowerCase(),
              userId: r['user_id']?.toString() ?? '',
              accountName: r['name']?.toString() ?? name.trim(),
            );
          }
          if (hasPassword) {
            // Same device that set the password: log in as before, no prompt.
            await _adoptServerProfile(
              client,
              r,
              name: name,
              email: email,
              mobileNumber: mobileNumber,
              deviceId: deviceId,
            );
            return;
          }
          // Legacy account that never set a password: force it now so every
          // account ends up protected.
          throw PasswordRequiredException(
            mode: PasswordMode.set,
            email: email.trim().toLowerCase(),
            userId: r['user_id']?.toString() ?? '',
            accountName: r['name']?.toString() ?? name.trim(),
            isExistingAccount: true,
          );
        }

        if (continueAs) {
          // Never invent an account when "continuing as": the server row must
          // exist for this device to pick it back up.
          throw Exception(
            'Your account was not found on the server. Log in with your details instead.',
          );
        }
        // Email not registered yet: a password must be chosen to create it.
        throw PasswordRequiredException(
          mode: PasswordMode.set,
          email: email.trim().toLowerCase(),
          accountName: name.trim(),
          isExistingAccount: false,
        );
      } on PasswordRequiredException {
        rethrow;
      } catch (e) {
        // Lookup failed (offline/timeout): never fabricate a fresh identity —
        // a phantom local account is what traps users in the onboarding form.
        debugPrint('StudentHub: login profile query failed: $e');
        throw Exception(
          continueAs
              ? "Couldn't verify your account on the server. Check your internet connection and try again."
              : 'Could not connect to the server. Check your internet and try again.',
        );
      }
    }

    // Truly offline (no backend configured at all): keep the legacy local
    // account creation so the app stays usable without connectivity. The
    // password is enforced once the server becomes reachable.
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

  /// Completes login after the user picked a first password (new account or
  /// legacy account that never had one). The server rejects the call if a
  /// password was already set elsewhere, in which case the caller switches to
  /// "Enter Password" mode.
  Future<void> setPasswordForLogin({
    required String name,
    required String email,
    required String mobileNumber,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('You are offline. Connect to the internet to set a password.');
    }
    final deviceId = await LocalStoreService.instance.getDeviceId();
    final serverRow = await _bestProfileByEmail(email, client);

    if (serverRow != null) {
      if (serverRow['has_password'] as bool? ?? false) {
        // Another device already protected the account: fall back to verifying.
        throw PasswordRequiredException(
          mode: PasswordMode.enter,
          email: email.trim().toLowerCase(),
          userId: serverRow['user_id']?.toString() ?? '',
          accountName: serverRow['name']?.toString() ?? name.trim(),
        );
      }
      await _callCredentialsFunction(
        action: 'set_password',
        email: email,
        password: password,
        deviceId: deviceId,
      );
      await _adoptServerProfile(
        client,
        serverRow,
        name: name,
        email: email,
        mobileNumber: mobileNumber,
        deviceId: deviceId,
      );
      return;
    }

    // Brand-new account: create the profile row first so the function can find
    // it by email, then store the password.
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
    _hadServerProfile = true;
    _subscribePresence();
    await _callCredentialsFunction(
      action: 'set_password',
      email: email,
      password: password,
      deviceId: deviceId,
    );
    _scheduleLocalSave();
    unawaited(syncNow());
  }

  /// Verifies the account password (used when logging in from a device that is
  /// not the one that set the password). On success the account is adopted,
  /// the active device rotates server-side (kicking the previous session), and
  /// the owner's other devices are alerted about the new-device login.
  Future<void> loginWithPassword({
    required String name,
    required String email,
    required String mobileNumber,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('You are offline. Connect to the internet to log in.');
    }
    final deviceId = await LocalStoreService.instance.getDeviceId();
    final serverRow = await _bestProfileByEmail(email, client);
    if (serverRow == null) {
      throw Exception('Account not found on server. Please check the email.');
    }
    await _callCredentialsFunction(
      action: 'verify_login',
      email: email,
      password: password,
      deviceId: deviceId,
    );
    await _adoptServerProfile(
      client,
      serverRow,
      name: name,
      email: email,
      mobileNumber: mobileNumber,
      deviceId: deviceId,
    );
    await _pushLoginAlert(
      userId: serverRow['user_id']?.toString() ?? currentUser.id,
      deviceId: deviceId,
    );
  }

  /// Resets an existing account password. Only succeeds when called from the
  /// device that originally set the password (server-enforced via
  /// `created_device_id`).
  Future<void> resetPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('You are offline. Connect to the internet to reset your password.');
    }
    final deviceId = await LocalStoreService.instance.getDeviceId();
    await _callCredentialsFunction(
      action: 'reset_password',
      email: email,
      password: password,
      deviceId: deviceId,
    );
  }

  /// Looks up the account for [email], preferring the most complete profile
  /// when duplicate rows exist (e.g. a phantom row created by an older build
  /// that fabricated local accounts). Completeness: a claimed MIT ID beats a
  /// completed onboarding flag beats a verified flag, so the real account
  /// always wins over an empty stub.
  Future<Map<String, dynamic>?> _bestProfileByEmail(
    String email,
    SupabaseClient client,
  ) async {
    final rows = await client
        .from('profiles')
        .select()
        .eq('email', email.trim().toLowerCase())
        .timeout(const Duration(seconds: 15));
    if (rows.isEmpty) return null;
    Map<String, dynamic>? best;
    var bestScore = -1;
    for (final r in rows) {
      // Deleted accounts (admin panel soft-delete residue) are never
      // loggable — even if the row still exists with the deleted marker.
      final deletedRoles = (r['roles'] as List?) ?? const [];
      if (deletedRoles.any((x) => x.toString() == 'deleted') ||
          (r['name']?.toString() ?? '') == '[DELETED USER]') {
        continue;
      }
      var score = 0;
      if ((r['student_or_employee_id']?.toString() ?? '').isNotEmpty) score += 4;
      if (r['has_completed_progressive_form'] as bool? ?? false) score += 2;
      if (r['is_verified'] as bool? ?? false) score += 1;
      if (score > bestScore) {
        bestScore = score;
        best = r;
      }
    }
    return best;
  }

  /// Shared tail of every successful login path: adopts the server profile as
  /// the current user and refreshes device-local caches.
  Future<void> _adoptServerProfile(
    SupabaseClient client,
    Map<String, dynamic> r, {
    required String name,
    required String email,
    required String mobileNumber,
    required String deviceId,
  }) async {
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
      interests: ((r['interests'] as List?) ?? const []).whereType<String>().toList(),
      activeDeviceId: deviceId,
    );

    activeRole = currentUser.roles.first;

    await client.from('profiles').update({
      'active_device_id': deviceId,
      'mobile_number': currentUser.mobileNumber,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', currentUser.id);

    _syncedDeviceId = deviceId;
    _hadServerProfile = true;
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
    _subscribeRealtimeOwnProfile();
    _subscribePresence();
    // Pull latest posts and registrations right after login so counts are fresh
    unawaited(syncNow());
  }

  /// Calls the `account-credentials` edge function and maps server errors to
  /// human-readable messages.
  Future<Map<String, dynamic>> _callCredentialsFunction({
    required String action,
    required String email,
    required String password,
    required String deviceId,
  }) async {
    if (SupabaseConfig.pushSecret.isEmpty) {
      // Misconfigured build: the edge function rejects anonymous calls, so
      // fail with an explicit message instead of a confusing 401.
      throw Exception(
        'This build is missing the PUSH_SECRET. Rebuild with --dart-define=PUSH_SECRET=...',
      );
    }
    final res = await http
        .post(
          Uri.parse(SupabaseConfig.credentialsFunctionUrl),
          headers: {
            'Content-Type': 'application/json',
            'X-Push-Secret': SupabaseConfig.pushSecret,
          },
          body: jsonEncode({
            'action': action,
            'email': email.trim().toLowerCase(),
            'password': password,
            'device_id': deviceId,
          }),
        )
        .timeout(const Duration(seconds: 15));
    Map<String, dynamic> decoded = const {};
    if (res.body.isNotEmpty) {
      try {
        decoded = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        // Non-JSON error body: fall through to the generic message.
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
    switch (decoded['error']?.toString()) {
      case 'wrong_password':
        throw Exception('Incorrect password. Please try again.');
      case 'device_mismatch':
        throw Exception(
          'Password reset is only allowed from the device where the password was originally set.',
        );
      case 'password_already_set':
        throw PasswordRequiredException(
          mode: PasswordMode.enter,
          email: email.trim().toLowerCase(),
        );
      case 'account_not_found':
        throw Exception('Account not found on server. Please check the email.');
      case 'credentials_missing':
        throw Exception(
          'No password is set for this account yet. Log in without a password first to set one.',
        );
      default:
        throw Exception('Login failed (${res.statusCode}). Please try again.');
    }
  }

  /// Push alert to the account owner's other devices when a new device logs
  /// in with the correct password. Uses the existing send-push function; the
  /// logging-in device is excluded via skip_sender_device.
  Future<void> _pushLoginAlert({
    required String userId,
    required String deviceId,
  }) async {
    final client = _client;
    if (client == null) return;
    if (SupabaseConfig.pushSecret.isEmpty) return;
    try {
      final res = await http
          .post(
            Uri.parse(SupabaseConfig.pushFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Push-Secret': SupabaseConfig.pushSecret,
            },
            body: jsonEncode({
              'type': 'login_alert',
              'recipient_user_id': userId,
              'device_id': deviceId,
              'skip_sender_device': true,
              'title': '🔐 New Device Login',
              'body':
                  'Someone logged into your account from a new device. If this was not you, reset your password from Profile → ⋮ → Reset Password.',
              'category': 'announcement',
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint(
          'StudentHub: login alert push rejected: ${res.statusCode} ${res.body}',
        );
      }
    } catch (e) {
      debugPrint('StudentHub: login alert push failed: $e');
    }
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
            .timeout(const Duration(seconds: 12));
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
    List<String> interests = const [],
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
      interests: interests,
      hasCompletedProgressiveForm: true,
    );
    _invalidateDataCaches();
    notifyListeners();
    await _persistProfile();
    _scheduleLocalSave();
  }

  UserModel? lastKnownUser;

  Future<void> logout({String? reason, bool keepAsLastKnown = true}) async {
    _isLoggedOut = true;
    logoutReason = reason;
    _syncedDeviceId = null;
    if (keepAsLastKnown &&
        currentUser.name.isNotEmpty &&
        currentUser.email.isNotEmpty) {
      lastKnownUser = currentUser;
    } else if (!keepAsLastKnown &&
        lastKnownUser?.id.isNotEmpty == true &&
        lastKnownUser?.id == currentUser.id) {
      lastKnownUser = null;
    }
    _hadServerProfile = false;
    _profilesRealtimeChannel?.unsubscribe();
    _profilesRealtimeChannel = null;
    _postsRealtimeChannel?.unsubscribe();
    _postsRealtimeChannel = null;
    _untrackPresence();
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
        .timeout(const Duration(seconds: 15));
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
      for (final p in _posts) p.authorId,
      for (final s in _formSubmissions) s.userId,
    }.where((id) => id.isNotEmpty && id != currentUser.id).toList();

    if (uids.isEmpty) return false;

    var changed = false;
    try {
      final chunks = <List<String>>[];
      for (var i = 0; i < uids.length; i += 50) {
        chunks.add(uids.sublist(i, math.min(i + 50, uids.length)));
      }
      for (final chunk in chunks) {
        final rows = await client
            .from('profiles')
            .select()
            .inFilter('user_id', chunk)
            .timeout(const Duration(seconds: 8));

        for (final row in rows) {
          final uid = row['user_id']?.toString() ?? '';
          if (uid.isEmpty) continue;
          final avatar = _sanitizeAvatarUrl(row['avatar_url']?.toString()) ?? '';
          final user = UserModel(
            id: uid,
            name: row['name']?.toString() ?? '',
            email: row['email']?.toString() ?? '',
            studentOrEmployeeId: row['student_or_employee_id']?.toString() ?? '',
            department: row['department']?.toString() ?? '',
            year: row['year']?.toString() ?? '',
            mobileNumber: row['mobile_number']?.toString() ?? '',
            avatarUrl: avatar,
            roles: const [UserRole.student],
            savedPostIds: const [],
            registeredEventIds: const [],
          );
          if (_knownProfiles[uid] == null ||
              _knownProfiles[uid]!.name != user.name ||
              _knownProfiles[uid]!.mobileNumber != user.mobileNumber ||
              _knownProfiles[uid]!.avatarUrl != user.avatarUrl) {
            _knownProfiles[uid] = user;
            changed = true;
          }
          if (avatar.isNotEmpty) {
            _authorAvatarCache[uid] = avatar;
            for (var i = 0; i < _posts.length; i++) {
              if (_posts[i].authorId == uid &&
                  (_posts[i].authorAvatarUrl == null ||
                      _posts[i].authorAvatarUrl!.isEmpty ||
                      _posts[i].authorAvatarUrl != avatar)) {
                _posts[i] = _posts[i].copyWith(authorAvatarUrl: avatar);
                changed = true;
              }
            }
          }
          final appreciatedBy =
              ((row['appreciated_by_user_ids'] as List?) ?? const [])
                  .whereType<String>()
                  .toList();
          if (_profileLikes[uid] != appreciatedBy.length) {
            _profileLikes[uid] = appreciatedBy.length;
            changed = true;
          }
          final meInList = appreciatedBy.contains(currentUser.id);
          if (meInList && !_likedProfileAuthorIds.contains(uid)) {
            _likedProfileAuthorIds.add(uid);
            changed = true;
          } else if (!meInList && _likedProfileAuthorIds.contains(uid)) {
            _likedProfileAuthorIds.remove(uid);
            changed = true;
          }
        }
      }
      if (changed) {
        _invalidateDataCaches();
        notifyListeners();
        _scheduleLocalSave();
      }
      return changed;
    } catch (e) {
      debugPrint('StudentHub: profiles lookup failed: $e');
      return false;
    }
  }

  void switchActiveRole(UserRole newRole) {
    // Both conditions required: the role must actually be granted, and it must
    // differ from the current one (an OR here would let a user "switch" into a
    // role they were never granted).
    if (currentUser.roles.contains(newRole) && activeRole != newRole) {
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
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'broadcasts',
            callback: (payload) {
              _syncAdminBroadcasts(client);
            },
          )
          .onBroadcast(
            event: 'admin_broadcast',
            callback: (payload) {
              try {
                final id = payload['id']?.toString() ?? '';
                final title = payload['title']?.toString() ?? '';
                final body = payload['body']?.toString() ?? '';
                if (id.isNotEmpty && title.isNotEmpty) {
                  final broadcastNotifId = 'notif_admin_broadcast_$id';
                  final isUpdate = id.startsWith('announcement_update_') ||
                      title.toLowerCase().contains('update');
                  final displayTitle = title.startsWith('📢') || title.startsWith('🚀')
                      ? title
                      : (isUpdate ? '🚀 $title' : '📢 $title');
                  if (!_notifications.any((n) => n.id == broadcastNotifId) &&
                      !_dismissedNotificationIds.contains(id) &&
                      !_dismissedNotificationIds.contains(broadcastNotifId)) {
                    _notifications.insert(
                      0,
                      NotificationModel(
                        id: broadcastNotifId,
                        title: displayTitle,
                        body: '$body\n\nBy Admin',
                        category: NotificationCategory.general,
                        timestamp: DateTime.now(),
                        relatedPostId: isUpdate ? 'app_update' : null,
                      ),
                    );
                    _invalidateDataCaches();
                    notifyListeners();
                    _scheduleLocalSave();
                  }
                }
              } catch (_) {}
              _syncAdminBroadcasts(client);
            },
          )
          .onBroadcast(
            event: 'post_sync',
            callback: (payload) {
              try {
                final record = payload['record'] as Map<String, dynamic>?;
                if (record != null && record.isNotEmpty) {
                  final post = _postFromRow(record);
                  if (post != null) {
                    _serverKnownIds.add(post.id);
                    final idx = _posts.indexWhere((p) => p.id == post.id);
                    if (idx != -1) {
                      final existing = _posts[idx];
                      // Same guard as the postgres realtime handler: the
                      // broadcast echo carries the author's own post row as it
                      // was written to the server — sanitized, with any still
                      //-uploading device-only images stripped. Never let the
                      // echo downgrade the better in-memory version.
                      final downgrade =
                          !_hasUsableRemoteSource(post) &&
                          (_hasUsableRemoteSource(existing) ||
                              _hasDeviceOnlySources(existing));
                      if (!downgrade) _posts[idx] = post;
                    } else {
                      _posts.insert(0, post);
                    }
                    _invalidateDataCaches();
                    notifyListeners();
                    _scheduleLocalSave();
                  }
                }
              } catch (_) {}
            },
          )
          .onBroadcast(
            event: 'post_liked',
            callback: (payload) {
              try {
                final targetAuthorId = payload['target_author_id']?.toString() ?? '';
                final targetAuthorName = payload['target_author_name']?.toString() ?? '';
                final likerId = payload['liker_id']?.toString() ?? '';
                final likerName = payload['liker_name']?.toString() ?? 'Someone';
                final postId = payload['post_id']?.toString() ?? '';
                final postTitle = payload['post_title']?.toString() ?? 'your post';

                // ONLY notify the creator on their own device, never the liker
                final isMyPost = (targetAuthorId.isNotEmpty && targetAuthorId == currentUser.id) ||
                    (targetAuthorName.isNotEmpty &&
                        targetAuthorName.trim().toLowerCase() == currentUser.name.trim().toLowerCase());
                if (isMyPost && likerId != currentUser.id) {
                  _notifications.insert(
                    0,
                    NotificationModel(
                      id: 'notif_like_${DateTime.now().millisecondsSinceEpoch}',
                      title: '❤️ New Like',
                      body: '$likerName liked your post "$postTitle"',
                      category: NotificationCategory.personal,
                      timestamp: DateTime.now().toUtc(),
                      relatedPostId: postId,
                    ),
                  );
                  _invalidateDataCaches();
                  notifyListeners();
                  _scheduleLocalSave();
                }
              } catch (_) {}
            },
          )
          .onBroadcast(
            event: 'post_congratulated',
            callback: (payload) {
              try {
                final targetAuthorId = payload['target_author_id']?.toString() ?? '';
                final targetAuthorName = payload['target_author_name']?.toString() ?? '';
                final likerId = payload['liker_id']?.toString() ?? '';
                final likerName = payload['liker_name']?.toString() ?? 'Someone';
                final postId = payload['post_id']?.toString() ?? '';
                final postTitle = payload['post_title']?.toString() ?? 'your post';

                // ONLY notify the creator on their own device, never the sender
                final isMyPost = (targetAuthorId.isNotEmpty && targetAuthorId == currentUser.id) ||
                    (targetAuthorName.isNotEmpty &&
                        targetAuthorName.trim().toLowerCase() == currentUser.name.trim().toLowerCase());
                if (isMyPost && likerId != currentUser.id) {
                  _notifications.insert(
                    0,
                    NotificationModel(
                      id: 'notif_congrat_${DateTime.now().millisecondsSinceEpoch}',
                      title: '👏 New Congratulation!',
                      body: '$likerName congratulated you on "$postTitle"',
                      category: NotificationCategory.personal,
                      timestamp: DateTime.now().toUtc(),
                      relatedPostId: postId,
                    ),
                  );
                  _invalidateDataCaches();
                  notifyListeners();
                  _scheduleLocalSave();
                }
              } catch (_) {}
            },
          )
          .onBroadcast(
            event: 'profile_appreciated',
            callback: (payload) {
              try {
                final targetAuthorId = payload['target_author_id']?.toString() ?? '';
                final likerId = payload['liker_id']?.toString() ?? '';
                final likerName = payload['liker_name']?.toString() ?? 'Someone';
                if (targetAuthorId.isNotEmpty) {
                  // If this is the creator's device and not the liker, show notification
                  if (targetAuthorId == currentUser.id && likerId != currentUser.id) {
                    _notifications.insert(
                      0,
                      NotificationModel(
                        id: 'notif_prof_like_${DateTime.now().millisecondsSinceEpoch}',
                        title: '⭐ Profile Appreciated!',
                        body: '$likerName appreciated your creator profile.',
                        category: NotificationCategory.personal,
                        timestamp: DateTime.now().toUtc(),
                      ),
                    );
                    _invalidateDataCaches();
                    notifyListeners();
                    _scheduleLocalSave();
                  }
                  // Reconcile the authoritative count from the server instead of
                  // blind-incrementing (counts are server-persisted now).
                  unawaited(refreshProfileLikesFor(targetAuthorId));
                }
              } catch (_) {}
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
          final existing = _posts[idx];
          // A row with no real, resolvable URLs (device-only refs or the
          // neutral fallback) is a stale write from a failed upload. Never
          // downgrade the better in-memory version, which may hold URLs that
          // are newer than the row — otherwise the author's own device would
          // lose its local images to an echo of its own sanitized row.
          final downgrade =
              !_hasUsableRemoteSource(post) &&
              (_hasUsableRemoteSource(existing) ||
                  _hasDeviceOnlySources(existing));
          if (!downgrade) _posts[idx] = post;
        } else {
          _posts.insert(0, post);
        }

        // Respect the "notifications cleared" marker exactly like the sync
        // path: a late-arriving row for an old post must not re-populate the
        // bell after the user cleared it.
        final cleared =
            _notificationsCleared &&
            _notificationsClearedAt != null &&
            post.timestamp.isBefore(_notificationsClearedAt!);
        if (!cleared && !_notifications.any((n) => n.relatedPostId == post.id)) {
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

  RealtimeChannel? _profilesRealtimeChannel;

  /// Subscribes to DELETE events on the caller's own profile row so an admin
  /// panel deletion force-logs-out and wipes this device within seconds
  /// instead of waiting for the next periodic sync.
  void _subscribeRealtimeOwnProfile() {
    final client = _client;
    if (client == null || _profilesRealtimeChannel != null) return;
    if (currentUser.id.isEmpty) return;
    final userId = currentUser.id;
    try {
      _profilesRealtimeChannel = client
          .channel('public:profiles')
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              if (payload.oldRecord['user_id']?.toString() == userId) {
                debugPrint(
                    'StudentHub: own profile deleted on server — wiping device.');
                unawaited(_wipeAccountForDeletion());
              }
            },
          )
          .subscribe();
      debugPrint('StudentHub: Realtime own-profile channel subscribed.');
    } catch (e) {
      debugPrint('StudentHub: Realtime own-profile subscription error: $e');
    }
  }

  /// Account permanently deleted on the server (admin panel). Force-log-out,
  /// clear the local snapshot and never offer the deleted account as a
  /// continue-as option again.
  Future<void> _wipeAccountForDeletion() async {
    if (isLoggedOut) return;
    await logout(
      reason: 'Your account was deleted by an administrator.',
      keepAsLastKnown: false,
    );
  }

  RealtimeChannel? _presenceChannel;
  Timer? _presenceKeepaliveTimer;

  /// Real live presence: joins the shared `online-students` channel so the
  /// admin panel shows exactly who has the app open and logged in right now.
  /// Presence entries are tied to this socket and disappear automatically
  /// when it disconnects (app closed / network lost), so no false "online"
  /// states can accumulate.
  void _subscribePresence() {
    final client = _client;
    if (client == null || _presenceChannel != null) return;
    if (isLoggedOut || currentUser.id.isEmpty) return;
    final channel = client.channel('online-students');
    try {
      channel.onPresenceSync((_) {}).subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await _trackPresence();
          _presenceKeepaliveTimer?.cancel();
          _presenceKeepaliveTimer = Timer.periodic(
            const Duration(seconds: 30),
            (_) => unawaited(_trackPresence()),
          );
        }
      });
      _presenceChannel = channel;
      debugPrint('StudentHub: Realtime presence subscribed.');
    } catch (e) {
      debugPrint('StudentHub: Realtime presence subscription error: $e');
    }
  }

  /// Publishes the current profile as this socket's presence payload, so the
  /// admin panel sees a live user with real profile data.
  Future<void> _trackPresence() async {
    final channel = _presenceChannel;
    if (channel == null || isLoggedOut || currentUser.id.isEmpty) return;
    try {
      await channel.track({
        'user_id': currentUser.id,
        'name': currentUser.name,
        'email': currentUser.email,
        'roles': currentUser.roles.map((r) => r.name).toList(),
        'student_or_employee_id': currentUser.studentOrEmployeeId,
        'department': currentUser.department,
        'year': currentUser.year,
        'mobile_number': currentUser.mobileNumber,
        'avatar_url': currentUser.avatarUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('StudentHub: presence track failed: $e');
    }
  }

  void _untrackPresence() {
    _presenceKeepaliveTimer?.cancel();
    _presenceKeepaliveTimer = null;
    try {
      _presenceChannel?.untrack();
    } catch (_) {}
    _presenceChannel?.unsubscribe();
    _presenceChannel = null;
  }

  Future<({bool success, bool changed})> _syncFromBackend() async {
    final client = _client;
    if (client == null) {
      _recordReachability(false);
      return (success: false, changed: false);
    }
    _subscribeRealtimePosts();
    _subscribeRealtimeOwnProfile();
    _subscribePresence();

    var changed = false;
    try {
      final rows = await client
          .from('posts')
          .select()
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(const Duration(seconds: 15));
      final fetched = rows
          .map(_postFromRow)
          .whereType<PostModel>()
          .toList();
      if (fetched.isEmpty) {
        // No remote posts
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
              !post.timestamp.toUtc().isAfter(_notificationsClearedAt!.toUtc())) {
            continue;
          }
          if (_dismissedNotificationIds.contains(post.id)) {
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
        // Rows written by older builds (or after failed uploads) may still
        // carry `local://` device refs that other devices cannot resolve.
        // Only the author's device has the files, so re-persist those posts
        // to backfill the server row with real URLs.
        for (final post in _posts) {
          if (post.authorId == currentUser.id && _hasDeviceOnlySources(post)) {
            _persistPost(post);
          }
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

    // Profile (server-granted roles), forms, registrants, role requests and
    // broadcasts are best-effort extras: failures never block the posts sync.
    // They run concurrently so a full sync completes in ~1s instead of a
    // chain of sequential round-trips.
    final extras = await Future.wait<bool>([
      _syncOwnProfile(client).catchError((e) {
        debugPrint('StudentHub: profile sync failed: $e');
        return false;
      }),
      _syncFormSubmissions(client).catchError((e) {
        debugPrint('StudentHub: form submissions sync failed: $e');
        return false;
      }),
      _syncProfilesForRegistrants(client).catchError((e) {
        debugPrint('StudentHub: registrant profiles sync failed: $e');
        return false;
      }),
      _syncRoleRequests(client).catchError((e) {
        debugPrint('StudentHub: role request sync failed: $e');
        return false;
      }),
      _syncAdminBroadcasts(client).catchError((e) {
        debugPrint('StudentHub: broadcast sync failed: $e');
        return false;
      }),
    ]);
    if (extras.any((changedExtra) => changedExtra)) changed = true;
    if (changed) {
      _invalidateDataCaches();
      notifyListeners();
      _scheduleLocalSave();
    }
    _recordReachability(true);
    return (success: true, changed: changed);
  }

  /// Pulls ADMIN broadcasts (sent from the admin panel) into the in-app
  /// notification bell only — they never appear in the campus feed. Each
  /// broadcast becomes an unread notification carrying the "By Admin" marker.
  Future<bool> _syncAdminBroadcasts(SupabaseClient client) async {
    try {
      final rows = await client
          .from('broadcasts')
          .select()
          .order('created_at', ascending: false)
          .limit(30)
          .timeout(const Duration(seconds: 15));
      var changed = false;
      final nowUtc = DateTime.now().toUtc();
      // For fresh installs or unrecorded clear timestamps, show broadcasts
      // from the last 72 hours so students don't miss recent announcements.
      final defaultCutoff = nowUtc.subtract(const Duration(hours: 72));

      for (final row in rows) {
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final title = row['title']?.toString() ?? '';
        if (title.isEmpty) continue;
        final broadcastNotifId = 'notif_admin_broadcast_$id';
        if (_dismissedNotificationIds.contains(id) ||
            _dismissedNotificationIds.contains(broadcastNotifId)) {
          continue;
        }

        final createdAt = _parseDate(row['created_at'])?.toUtc() ?? nowUtc;
        final isUpdate = id.startsWith('announcement_update_') ||
            title.toLowerCase().contains('update');

        if (_notificationsCleared && _notificationsClearedAt != null) {
          if (!createdAt.isAfter(_notificationsClearedAt!.toUtc())) {
            continue;
          }
        } else if (createdAt.isBefore(defaultCutoff)) {
          continue;
        }

        final existingIndex = _notifications.indexWhere((n) => n.id == broadcastNotifId);
        if (existingIndex != -1) {
          // Retroactively update category & relatedPostId if stored from older builds
          if (isUpdate &&
              (_notifications[existingIndex].category != NotificationCategory.general ||
                  _notifications[existingIndex].relatedPostId != 'app_update')) {
            _notifications[existingIndex] = _notifications[existingIndex].copyWith(
              category: NotificationCategory.general,
              relatedPostId: 'app_update',
            );
            changed = true;
          }
          continue;
        }

        final displayTitle = title.startsWith('📢') || title.startsWith('🚀')
            ? title
            : (isUpdate ? '🚀 $title' : '📢 $title');
        _notifications.insert(
          0,
          NotificationModel(
            id: broadcastNotifId,
            title: displayTitle,
            body: '${row['body']?.toString() ?? ''}\n\nBy Admin',
            category: NotificationCategory.general,
            timestamp: createdAt.toLocal(),
            relatedPostId: isUpdate ? 'app_update' : null,
          ),
        );
        changed = true;
      }
      if (changed) {
        _invalidateDataCaches();
        notifyListeners();
        _scheduleLocalSave();
      }
      return changed;
    } catch (e) {
      debugPrint('StudentHub: _syncAdminBroadcasts failed: $e');
      return false;
    }
  }

  /// Manually pulls recent admin broadcasts into the notification bell
  Future<void> syncBroadcasts() async {
    final client = _client;
    if (client == null) return;
    await _syncAdminBroadcasts(client);
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
        .select('user_id, roles, is_verified, active_device_id, has_password, has_completed_progressive_form, appreciated_by_user_ids, notifications_cleared_at')
        .eq('user_id', currentUser.id)
        .limit(1)
        .timeout(const Duration(seconds: 12));
    if (rows.isEmpty) {
      // The server has no row for this identity: either a stale seed/phantom
      // stub (never had a server profile — ignore silently, never fabricate),
      // or a real account that was permanently deleted by an admin. Only the
      // latter wipes the device and force-logs-out.
      _syncedDeviceId = currentDeviceId;
      if (_hadServerProfile || _restoredCompletedSession) {
        debugPrint('StudentHub: own profile missing on server — account deleted.');
        await _wipeAccountForDeletion();
      }
      return false;
    }

    final row = rows.first;
    final serverActiveDeviceId = row['active_device_id']?.toString() ?? '';

    // Reconcile server notifications_cleared_at so clean installs don't reload cleared notifs
    if (row['notifications_cleared_at'] != null) {
      final serverCleared = _parseDate(row['notifications_cleared_at'])?.toUtc();
      if (serverCleared != null) {
        final nowUtc = DateTime.now().toUtc();
        final sanitizedCleared = serverCleared.isAfter(nowUtc) ? nowUtc : serverCleared;
        if (_notificationsClearedAt == null || sanitizedCleared.isAfter(_notificationsClearedAt!.toUtc())) {
          _notificationsClearedAt = sanitizedCleared;
          _notificationsCleared = true;
        }
      }
    }

    if (_notificationsCleared && _notificationsClearedAt != null) {
      final cutoff = _notificationsClearedAt!.toUtc();
      final beforeLen = _notifications.length;
      _notifications.removeWhere((n) {
        if (_dismissedNotificationIds.contains(n.id)) return true;
        if (n.relatedPostId != null && _dismissedNotificationIds.contains(n.relatedPostId)) return true;
        return !n.timestamp.toUtc().isAfter(cutoff);
      });
      if (_notifications.length != beforeLen) {
        _invalidateDataCaches();
        notifyListeners();
        _scheduleLocalSave();
      }
    }

    // Password protection rollout: an existing account that never set a
    // password is forced back to the login screen where a password must be
    // chosen before entering. Skips the freshly-created seed rows below by
    // checking the server's own flag.
    if (!(row['has_password'] as bool? ?? true)) {
      debugPrint('StudentHub: account has no password. Forcing set-password login.');
      unawaited(
        logout(
          reason:
              'Set a password to secure your account. It will be asked when you log in from a new device.',
        ),
      );
      return true;
    }

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

    // Reconcile the authoritative appreciation count from the server (the
    // device-local count can drift when live broadcasts are missed).
    final ownAppreciatedBy =
        ((row['appreciated_by_user_ids'] as List?) ?? const [])
            .whereType<String>()
            .toList();
    final appreciationChanged =
        _profileLikes[currentUser.id] != ownAppreciatedBy.length;
    if (appreciationChanged) {
      _profileLikes[currentUser.id] = ownAppreciatedBy.length;
    }

    if (!rolesChanged &&
        serverHasCompleted == currentUser.hasCompletedProgressiveForm &&
        !appreciationChanged) {
      return false;
    }

    // The server is the source of truth for granted roles: adopt it wholesale
    // (additions AND removals) so admin grants/revocations land on every
    // device without a re-login. An empty server list means "nothing granted
    // yet", so the local default (Student) survives for fresh profiles.
    final effectiveRoles = serverRoles.isEmpty ? currentUser.roles : serverRoles;
    final serverAvatar = _sanitizeAvatarUrl(row['avatar_url']?.toString()) ?? '';
    final avatarToSet = (serverAvatar.isNotEmpty && (currentUser.avatarUrl.isEmpty || !currentUser.avatarUrl.startsWith('http')))
        ? serverAvatar
        : currentUser.avatarUrl;

    currentUser = currentUser.copyWith(
      roles: effectiveRoles,
      avatarUrl: avatarToSet,
      isVerified: row['is_verified'] as bool? ?? currentUser.isVerified,
      hasCompletedProgressiveForm: serverHasCompleted,
      interests: ((row['interests'] as List?) ?? currentUser.interests)
          .whereType<String>()
          .toList(),
    );
    if (avatarToSet.isNotEmpty) {
      _authorAvatarCache[currentUser.id] = avatarToSet;
    }
    if (currentUser.avatarUrl.isNotEmpty &&
        (currentUser.avatarUrl.startsWith('data:') || _localStore.isLocalRef(currentUser.avatarUrl))) {
      unawaited(_persistProfile());
    }
    if (!effectiveRoles.contains(activeRole)) {
      activeRole = effectiveRoles.isNotEmpty
          ? effectiveRoles.first
          : UserRole.student;
    }
    _scheduleLocalSave();
    return true;
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
        'interests': currentUser.interests,
        'saved_post_ids': currentUser.savedPostIds,
        'registered_event_ids': currentUser.registeredEventIds,
        'congratulated_post_ids': currentUser.congratulatedPostIds,
        'liked_post_ids': currentUser.likedPostIds,
        'is_verified': currentUser.isVerified,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
      _syncedDeviceId = deviceId;

      // Update authorAvatarUrl on all posts authored by this user locally
      if (avatar.isNotEmpty) {
        _authorAvatarCache[currentUser.id] = avatar;
        var postsUpdated = false;
        for (var i = 0; i < _posts.length; i++) {
          if (_posts[i].authorId == currentUser.id && _posts[i].authorAvatarUrl != avatar) {
            _posts[i] = _posts[i].copyWith(authorAvatarUrl: avatar);
            postsUpdated = true;
          }
        }
        if (postsUpdated) {
          _invalidateDataCaches();
          notifyListeners();
          _scheduleLocalSave();
        }
      }
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
      final ok = await _uploadBinaryWithRetry(
        client,
        path,
        bytes,
        ext == 'png' ? 'image/png' : 'image/jpeg',
      );
      if (!ok) return url;
      final publicUrl = client.storage.from('documents').getPublicUrl(path);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final stamped = '$publicUrl?v=$stamp';
      clearCachedImage(url);
      clearCachedImage(publicUrl);
      return stamped;
    } catch (_) {
      return url;
    }
  }

  Future<String?> _uploadAuthorAvatarIfNeeded(String? url, String authorId) async {
    final client = _client;
    if (client == null || url == null || url.isEmpty) return url;
    if (!url.startsWith('data:') && !_localStore.isLocalRef(url)) return url;

    try {
      final bytes = url.startsWith('data:')
          ? await compute(
              _decodeBase64Helper,
              url.substring(url.indexOf(',') + 1),
            )
          : await _localStore.readLocalBlob(url);
      if (bytes == null || bytes.isEmpty) return url;
      final ext = _extFromDataUri(url);
      final path = 'avatars/$authorId.$ext';
      final ok = await _uploadBinaryWithRetry(
        client,
        path,
        bytes,
        ext == 'png' ? 'image/png' : 'image/jpeg',
      );
      if (!ok) return null;
      final publicUrl = client.storage.from('documents').getPublicUrl(path);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final stamped = '$publicUrl?v=$stamp';
      clearCachedImage(url);
      clearCachedImage(publicUrl);
      return stamped;
    } catch (_) {
      return null;
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
        .timeout(const Duration(seconds: 10));
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
            !_notifications.any((n) => n.relatedPostId == remote.id) &&
            !(_notificationsCleared &&
                _notificationsClearedAt != null &&
                remote.submittedAt.isBefore(_notificationsClearedAt!))) {
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
    final wasGranted = !currentUser.roles.contains(req.requestedRole);
    if (wasGranted) {
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
    final alreadyShown = _notifications.any((n) => n.relatedPostId == req.id);
    final clearedBefore =
        _notificationsCleared &&
        _notificationsClearedAt != null &&
        req.submittedAt.isBefore(_notificationsClearedAt!);
    if (alreadyShown || clearedBefore) return wasGranted;
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
    if (SupabaseConfig.pushSecret.isEmpty) {
      // Server review unavailable without the secret: keep the local decision
      // (it is retried on the next review).
      debugPrint('StudentHub: review-role skipped (no PUSH_SECRET in build).');
      return;
    }
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
    if (SupabaseConfig.pushSecret.isEmpty) return;
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
      targetYear: (row['target_year'] == 'ALL') ? 'All' : row['target_year'] as String?,
      authorName: row['author_name']?.toString() ?? '',
      authorRole: UserRole.values.firstWhere(
        (r) => r.name == row['author_role'],
        orElse: () => UserRole.student,
      ),
      authorId: row['author_id']?.toString() ?? '',
      authorAvatarUrl: _sanitizeAvatarUrl(
        (row['author_avatar_url'] as String?) ??
            _resolveAuthorAvatar(
              row['author_id']?.toString(),
              row['author_name']?.toString(),
            ),
      ),
      timestamp: _parseDate(row['created_at']) ?? DateTime.now(),
      imageUrl: (row['image_url'] is String && (row['image_url'] as String).trim().isNotEmpty)
          ? (row['image_url'] as String).trim()
          : null,
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

  String? _resolveAuthorAvatar(String? authorId, String? authorName) {
    if (authorId == null && authorName == null) return null;
    if (authorId == currentUser.id ||
        (authorName != null &&
            authorName.trim().isNotEmpty &&
            authorName.trim().toLowerCase() == currentUser.name.trim().toLowerCase())) {
      return _sanitizeAvatarUrl(currentUser.avatarUrl);
    }
    if (authorId != null && _authorAvatarCache.containsKey(authorId)) {
      final cached = _sanitizeAvatarUrl(_authorAvatarCache[authorId]);
      if (cached != null && cached.isNotEmpty) return cached;
    }
    if (authorId != null && _knownProfiles.containsKey(authorId)) {
      final profileAvatar = _sanitizeAvatarUrl(_knownProfiles[authorId]?.avatarUrl);
      if (profileAvatar != null && profileAvatar.isNotEmpty) return profileAvatar;
    }
    for (final p in _posts) {
      if ((authorId != null && p.authorId == authorId) ||
          (authorName != null && p.authorName.toLowerCase() == authorName.toLowerCase())) {
        final sanitized = _sanitizeAvatarUrl(p.authorAvatarUrl);
        if (sanitized != null && sanitized.isNotEmpty) {
          return sanitized;
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _rowFromPost(PostModel p) {
    // Device-only sources (picked photos, `data:` URIs, `local://` file refs)
    // must NEVER reach the server row: other devices cannot resolve them and
    // would render grey boxes. If an upload failed and the source is still
    // device-only, the row stores a neutral placeholder instead.
    const placeholder = _fallbackImageUrl;

    String? cleanUrl(String? url) {
      if (url == null || url.isEmpty) return null;
      if (url.startsWith('data:') ||
          url.startsWith(LocalStoreService.localPrefix)) {
        return null;
      }
      return url.trim();
    }

    String cleanAttachmentUrl(String url) {
      if (url.startsWith('data:') ||
          url.startsWith(LocalStoreService.localPrefix)) {
        return '';
      }
      return url;
    }

    final cleanGallery = p.imageUrls
        .map(
          (u) => u.startsWith('data:') ||
                  u.startsWith(LocalStoreService.localPrefix)
              ? placeholder
              : u,
        )
        .toList();

    return {
      'id': p.id,
      'title': p.title,
      'description': p.description,
      'category': p.category.name,
      'department': p.department,
      'target_year': p.targetYear ?? 'All',
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
              'url': cleanAttachmentUrl(a.url),
              'fileSize': a.fileSize,
            },
          )
          .toList(),
      'created_at': p.timestamp.toUtc().toIso8601String(),
    };
  }

  DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      return parsed?.toUtc();
    }
    if (value is DateTime) return value.toUtc();
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

      // Upload attachments, cover, gallery, and author avatar images in parallel
      final attachmentFuture = Future.wait(
        post.attachments.map(_uploadAttachmentIfNeeded),
      );
      final coverFuture = _uploadPostImageIfNeeded(post);
      final galleryFuture = _uploadGalleryImagesIfNeeded(post);
      final avatarFuture = _uploadAuthorAvatarIfNeeded(post.authorAvatarUrl, post.authorId);
      final results = await Future.wait<Object?>(
        [attachmentFuture, coverFuture, galleryFuture, avatarFuture],
      );
      final attachments = List<PostAttachment>.from(
        results[0] as List<PostAttachment>,
      );
      final resolvedCover = results[1] as PostModel;
      final resolvedGallery = results[2] as PostModel;
      final resolvedAvatar = results[3] as String?;
      for (var i = 0; i < attachments.length; i++) {
        if (attachments[i].url != post.attachments[i].url) changed = true;
      }
      if (resolvedCover.imageUrl != post.imageUrl) changed = true;
      if (resolvedGallery.imageUrls != post.imageUrls) changed = true;
      if (resolvedAvatar != null && resolvedAvatar != post.authorAvatarUrl) {
        changed = true;
      }
      if (changed) {
        stored = post.copyWith(
          attachments: attachments,
          imageUrl: resolvedCover.imageUrl,
          imageUrls: resolvedGallery.imageUrls,
          authorAvatarUrl: resolvedAvatar ?? post.authorAvatarUrl,
        );
      }
      final row = _rowFromPost(stored);
      await client.from('posts').upsert(row, onConflict: 'id');
      try {
        client.channel('public:posts').sendBroadcastMessage(
          event: 'post_sync',
          payload: {'record': row},
        );
      } catch (_) {}
      final idx = _posts.indexWhere((p) => p.id == post.id);
      if (idx != -1) _posts[idx] = stored;
      _serverKnownIds.add(post.id);
      if (_hasDeviceOnlySources(stored)) _scheduleRepersist(stored);
    } catch (e) {
      debugPrint('StudentHub: post ${post.id} persistence failed: $e');
      _scheduleLocalSave();
    }
  }
  /// left untouched. Transient upload failures are retried; a persistent
  /// failure keeps the in-memory source untouched (the row write sanitizes it,
  /// and [_scheduleRepersist] backfills it once the network recovers).
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
      if (!await _uploadBinaryWithRetry(
        client,
        path,
        bytes,
        ext == 'png' ? 'image/png' : 'image/jpeg',
      )) {
        return post.copyWith(imageUrl: null);
      }

      // Cache-busting query: re-uploading an edited cover keeps the same
      // storage path, so a `?v=` stamp forces every device to reload the new
      // bytes instead of the stale cached frame.
      final publicUrl = client.storage.from('documents').getPublicUrl(path);
      final stamped = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      clearCachedImage(url);
      clearCachedImage(publicUrl);
      return post.copyWith(imageUrl: stamped);
    } catch (_) {
      return post.copyWith(imageUrl: null);
    }
  }

  /// Uploads every gallery image (data URI or local file ref) to Supabase
  /// Storage as `posts/<id>_gallery_<index>.<ext>` and returns the post with
  /// all public URLs. Remote/empty images are left untouched. Uploads run in
  /// parallel waves (with per-image retries) so a full gallery reaches the
  /// server in ~1s like any other social app, instead of one sequential
  /// round-trip per photo. An image that still fails is dropped so unsynced
  /// local device blobs are never displayed on the feed.
  Future<PostModel> _uploadGalleryImagesIfNeeded(PostModel post) async {
    final client = _client;
    if (client == null || post.imageUrls.isEmpty) return post;

    final uploaded = List<String>.from(post.imageUrls);
    final stamp = DateTime.now().millisecondsSinceEpoch;

    // (index, bytes, ext) triples for every image that needs a real upload.
    final pending = <(int, Uint8List, String)>[];
    for (var i = 0; i < post.imageUrls.length; i++) {
      final url = post.imageUrls[i];
      if (url.isEmpty) continue;
      if (!url.startsWith('data:') && !_localStore.isLocalRef(url)) continue;
      try {
        final bytes = url.startsWith('data:')
            ? await compute(
                _decodeBase64Helper,
                url.substring(url.indexOf(',') + 1),
              )
            : await _localStore.readLocalBlob(url);
        if (bytes == null || bytes.isEmpty) continue;
        pending.add((i, bytes, _extFromDataUri(url)));
      } catch (_) {
        // Drop failed local blob
      }
    }
    if (pending.isEmpty) {
      final validRemoteOnly = post.imageUrls
          .where((u) => !u.startsWith('data:') && !_localStore.isLocalRef(u))
          .toList();
      return post.copyWith(imageUrls: validRemoteOnly);
    }

    // Upload up to 3 images concurrently; Supabase handles parallel uploads
    // well and this keeps memory spikes bounded on lower-end devices.
    const waveSize = 3;
    for (var start = 0; start < pending.length; start += waveSize) {
      final wave = pending.skip(start).take(waveSize).toList();
      final results = await Future.wait(
        wave.map((item) async {
          final (i, bytes, ext) = item;
          final path = 'posts/${post.id}_gallery_$i.$ext';
          final ok = await _uploadBinaryWithRetry(
            client,
            path,
            bytes,
            ext == 'png' ? 'image/png' : 'image/jpeg',
          );
          return (i, path, ok);
        }),
      );
      for (final (i, path, ok) in results) {
        if (!ok) continue;
        final publicUrl =
            client.storage.from('documents').getPublicUrl(path);
        clearCachedImage(uploaded[i]);
        uploaded[i] = '$publicUrl?v=$stamp';
      }
    }
    final validSyncedGallery = uploaded
        .where((u) => !u.startsWith('data:') && !_localStore.isLocalRef(u))
        .toList();
    return post.copyWith(imageUrls: validSyncedGallery);
  }

  /// Uploads [bytes] to Supabase Storage at [path], retrying transient
  /// failures with a short backoff. Returns whether the upload succeeded.
  Future<bool> _uploadBinaryWithRetry(
    SupabaseClient client,
    String path,
    Uint8List bytes,
    String contentType, {
    int attempts = 3,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        await client.storage.from('documents').uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: contentType,
                upsert: true,
              ),
            );
        return true;
      } catch (e) {
        lastError = e;
        final errStr = e.toString().toLowerCase();
        // If the server rejects due to storage RLS policies (403 Unauthorized), fail fast
        if (errStr.contains('403') ||
            errStr.contains('row-level security') ||
            errStr.contains('unauthorized')) {
          break;
        }
        if (attempt < attempts - 1) {
          await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        }
      }
    }
    debugPrint('StudentHub: storage upload skipped/unauthorized for $path: $lastError');
    return false;
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
      final ok = await _uploadBinaryWithRetry(
        client,
        path,
        bytes,
        'application/pdf',
        attempts: 3,
      );
      if (!ok) return att;
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

  /// True when [p] still carries device-only image/attachment sources (data
  /// URIs or `local://` refs) after an upload attempt — i.e. the row needs a
  /// backfill upload later.
  bool _hasDeviceOnlySources(PostModel p) {
    final imageUrl = p.imageUrl;
    if (imageUrl != null &&
        imageUrl.isNotEmpty &&
        (imageUrl.startsWith('data:') ||
            _localStore.isLocalRef(imageUrl))) {
      return true;
    }
    for (final u in p.imageUrls) {
      if (u.startsWith('data:') || _localStore.isLocalRef(u)) return true;
    }
    for (final a in p.attachments) {
      if (a.url.startsWith('data:') || _localStore.isLocalRef(a.url)) {
        return true;
      }
    }
    return false;
  }

  /// True when [p] carries at least one real, other-device-resolvable image or
  /// attachment URL (not a device-only source and not the neutral fallback).
  bool _hasUsableRemoteSource(PostModel p) {
    bool usable(String url) {
      if (url.isEmpty) return false;
      if (url.startsWith('data:') || _localStore.isLocalRef(url)) return false;
      if (url == _fallbackImageUrl) return false;
      return true;
    }

    final cover = p.imageUrl;
    if (cover != null && cover.isNotEmpty && usable(cover)) return true;
    for (final u in p.imageUrls) {
      if (usable(u)) return true;
    }
    for (final a in p.attachments) {
      if (usable(a.url)) return true;
    }
    return false;
  }

  final Set<String> _pendingRepersistIds = {};
  Timer? _repersistTimer;

  /// Re-runs [_persistPost] for posts whose images failed to upload earlier,
  /// so the server row gets backfilled with real URLs once the network is
  /// back. Only the author's own device has the local files, so only their
  /// posts are ever re-persisted.
  void _scheduleRepersist(PostModel post) {
    if (post.authorId != currentUser.id) return;
    _pendingRepersistIds.add(post.id);
    _repersistTimer ??= Timer(const Duration(seconds: 25), () {
      _repersistTimer = null;
      final ids = List<String>.from(_pendingRepersistIds);
      _pendingRepersistIds.clear();
      for (final id in ids) {
        final idx = _posts.indexWhere((p) => p.id == id);
        if (idx != -1) _persistPost(_posts[idx]);
      }
    });
  }

  // --- Feed & Priority Logic ---

  bool _showAllYearsFeed = false;

  /// When true, creators/managers (Event Host, Faculty, Admin) see posts from
  /// all academic years. When false (default), feed filters to their selected year.
  bool get showAllYearsFeed => _showAllYearsFeed;

  void setShowAllYearsFeed(bool value) {
    if (_showAllYearsFeed == value) return;
    _showAllYearsFeed = value;
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();
  }

  /// Determines whether a post is targeted to the given user year (or the current
  /// user's year by default). Returns true for null, empty, 'All', 'ALL', exact year matches,
  /// or when the current user is the author or has enabled showAllYearsFeed.
  bool matchesYear(PostModel p, [String? userYear]) {
    // 1. Authors can always see their own posts on their own devices. Matched
    // strictly by user id — name comparison can't be used here (a substring
    // collision like "Aarav" matching "Aarav Gupta" would leak posts).
    if (p.authorId.isNotEmpty && p.authorId == currentUser.id) {
      return true;
    }

    // 2. Creator perspectives (Event Host, Faculty, Admin) see all years if chosen
    final bool isCreator = activeRole == UserRole.eventHost ||
        activeRole == UserRole.faculty ||
        activeRole == UserRole.admin;
    if (isCreator && _showAllYearsFeed) {
      return true;
    }

    final target = p.targetYear;
    if (target == null ||
        target.isEmpty ||
        target == 'All' ||
        target == 'ALL' ||
        target == 'All Academic Years') {
      return true;
    }
    final uYear = userYear ?? currentUser.year;
    if (uYear.isEmpty ||
        uYear.toLowerCase() == 'all' ||
        uYear.toLowerCase() == 'faculty' ||
        uYear.toLowerCase() == 'n/a') {
      return true;
    }
    return target.trim().toLowerCase() == uYear.trim().toLowerCase();
  }

  bool _matchesInterests(PostModel p, List<String> interests) {
    if (interests.isEmpty) return false;
    final text = '${p.title} ${p.description} ${p.category.displayName}'.toLowerCase();
    for (final interest in interests) {
      final query = interest.toLowerCase().replaceAll('&', ' ').replaceAll('/', ' ');
      final words = query.split(' ').where((w) => w.trim().length > 2);
      for (final w in words) {
        if (text.contains(w)) return true;
      }
    }
    return false;
  }

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
        '$savedOnly|$categoryFilter|$searchQuery|$excludeEvents|${currentUser.year}|${currentUser.interests.join(',')}|$_showAllYearsFeed|$_dataVersion';
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

    // Hard year filter step: exclude non-matching posts
    list = list.where((p) => matchesYear(p)).toList();

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
    // 2. Pinned
    // 3. Department match
    // 4. User interest match boost
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

      if (currentUser.interests.isNotEmpty) {
        final aInterestsMatch = _matchesInterests(a, currentUser.interests);
        final bInterestsMatch = _matchesInterests(b, currentUser.interests);
        if (aInterestsMatch != bInterestsMatch) {
          return aInterestsMatch ? -1 : 1;
        }
      }

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
        final targetPost = _posts[postIndex];
        _posts[postIndex] = targetPost.copyWith(
          saveCount: targetPost.saveCount + 1,
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

      // Broadcast congratulation to the creator's device only (never self-notify)
      if (post.authorId != currentUser.id &&
          post.authorName.trim().toLowerCase() !=
              currentUser.name.trim().toLowerCase()) {
        final client = _client;
        if (client != null) {
          try {
            client.channel('public:posts').sendBroadcastMessage(
              event: 'post_congratulated',
              payload: {
                'target_author_id': post.authorId,
                'target_author_name': post.authorName,
                'liker_id': currentUser.id,
                'liker_name': currentUser.name,
                'post_id': post.id,
                'post_title': post.title,
              },
            );
          } catch (_) {}
        }
      }
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

      // Broadcast like to the creator's device only (never self-notify)
      if (post.authorId != currentUser.id &&
          post.authorName.trim().toLowerCase() !=
              currentUser.name.trim().toLowerCase()) {
        final client = _client;
        if (client != null) {
          try {
            client.channel('public:posts').sendBroadcastMessage(
              event: 'post_liked',
              payload: {
                'target_author_id': post.authorId,
                'target_author_name': post.authorName,
                'liker_id': currentUser.id,
                'liker_name': currentUser.name,
                'post_id': post.id,
                'post_title': post.title,
              },
            );
          } catch (_) {}
        }
      }
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

  // --- Profile Likes (Creator Appreciations) ---
  int getProfileLikes(String authorId) {
    if (authorId.isEmpty) return 0;
    return _profileLikes[authorId] ?? 0;
  }

  bool isProfileLiked(String authorId) {
    if (authorId.isEmpty) return false;
    return _likedProfileAuthorIds.contains(authorId);
  }

  Future<void> toggleLikeProfile(String authorId, String authorName) async {
    if (authorId.isEmpty) return;
    if (authorId == currentUser.id ||
        (authorName.trim().isNotEmpty &&
            authorName.trim().toLowerCase() ==
                currentUser.name.trim().toLowerCase())) {
      return;
    }
    final isLiked = _likedProfileAuthorIds.contains(authorId);

    // Optimistic local toggle so the UI responds instantly.
    if (isLiked) {
      _likedProfileAuthorIds.remove(authorId);
      _profileLikes[authorId] = math.max(0, (_profileLikes[authorId] ?? 0) - 1);
    } else {
      _likedProfileAuthorIds.add(authorId);
      _profileLikes[authorId] = (_profileLikes[authorId] ?? 0) + 1;
    }
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();

    final client = _client;
    if (client == null) return;

    try {
      // Persist on the target profile server-side so every device (including
      // the creator's) converges on the same authoritative count.
      final count = await client.rpc(
        'toggle_profile_appreciation',
        params: {
          'p_target_user_id': authorId,
          'p_liker_user_id': currentUser.id,
        },
      );
      final serverCount = count is num
          ? count.toInt()
          : int.tryParse(count?.toString() ?? '') ?? 0;
      _profileLikes[authorId] = math.max(0, serverCount);

      // Broadcast appreciation to the creator's device for a live notification
      // (best-effort; counts are now reconciled from the server on next sync).
      if (!isLiked && authorId != currentUser.id) {
        try {
          client.channel('public:posts').sendBroadcastMessage(
            event: 'profile_appreciated',
            payload: {
              'target_author_id': authorId,
              'liker_id': currentUser.id,
              'liker_name': currentUser.name,
            },
          );
        } catch (_) {}
      }
      _invalidateDataCaches();
      notifyListeners();
      _scheduleLocalSave();
    } catch (_) {
      // Server unreachable: the optimistic local toggle already applied and
      // the next sync/poll reconciles the count from the server.
    }
  }

  /// Fetches one profile's authoritative appreciation data from the server and
  /// hydrates the local count + "did I appreciate this?" state. Used when a
  /// creator profile is opened so the count is correct even if the live
  /// broadcast was missed (creator offline / app closed at that moment).
  Future<void> refreshProfileLikesFor(String authorId) async {
    final client = _client;
    if (client == null || authorId.isEmpty) return;
    try {
      final rows = await client
          .from('profiles')
          .select('user_id, appreciated_by_user_ids')
          .eq('user_id', authorId)
          .limit(1)
          .timeout(const Duration(seconds: 8));
      if (rows.isEmpty) return;
      final appreciatedBy = ((rows.first['appreciated_by_user_ids'] as List?) ??
              const [])
          .whereType<String>()
          .toList();
      var changed = false;
      if (_profileLikes[authorId] != appreciatedBy.length) {
        _profileLikes[authorId] = appreciatedBy.length;
        changed = true;
      }
      final meInList = appreciatedBy.contains(currentUser.id);
      if (meInList && !_likedProfileAuthorIds.contains(authorId)) {
        _likedProfileAuthorIds.add(authorId);
        changed = true;
      } else if (!meInList && _likedProfileAuthorIds.contains(authorId)) {
        _likedProfileAuthorIds.remove(authorId);
        changed = true;
      }
      if (changed) {
        _invalidateDataCaches();
        notifyListeners();
        _scheduleLocalSave();
      }
    } catch (_) {
      // Best-effort: the local state remains and the periodic sync retries.
    }
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
    if (isEvent && currentUser.cancelledEventIds.contains(post.id)) return false;
    if (isEvent && !_canRegister(post)) return false;
    if (isEvent &&
        (post.registeredUserIds.contains(currentUser.id) ||
            currentUser.registeredEventIds.contains(post.id))) {
      // Already registered (quick toggle or a previous form submit): treat the
      // repeat submission as an idempotent success instead of adding the user
      // a second time to registeredUserIds / registeredEventIds.
      return true;
    }
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
      if (!userRegEvents.contains(post.id)) {
        userRegEvents.add(post.id);
      }
      // One submission row per event+user (same rule as the quick toggle):
      // drop any previous rows for this event+user, keep the fresh one.
      _formSubmissions.removeWhere(
        (s) =>
            s.postId == post.id &&
            s.userId == currentUser.id &&
            s.id != submission.id,
      );

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
    if (newPost.authorAvatarUrl == null || newPost.authorAvatarUrl!.isEmpty) {
      newPost = newPost.copyWith(authorAvatarUrl: currentUser.avatarUrl);
    }
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
        : post.category == PostCategory.urgent
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
    if (SupabaseConfig.pushSecret.isEmpty) return;
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
            ? (newReq.expiresAt != null
                ? 'Your request for ${requestedRole.displayName} status (temporary, until ${_formatDate(newReq.expiresAt!)}) has been sent to Admin for review.'
                : 'Your request for ${requestedRole.displayName} status (temporary) has been sent to Admin for review.')
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

  void deleteNotification(String notifId) {
    final idx = _notifications.indexWhere((n) => n.id == notifId);
    if (idx != -1) {
      final notif = _notifications[idx];
      _dismissedNotificationIds.add(notif.id);
      if (notif.relatedPostId != null && notif.relatedPostId!.isNotEmpty) {
        _dismissedNotificationIds.add(notif.relatedPostId!);
      }
      _notifications.removeAt(idx);
      _invalidateDataCaches();
      notifyListeners();
      _scheduleLocalSave();
    }
  }

  void clearAllNotifications() {
    _notificationsCleared = true;
    final nowUtc = DateTime.now().toUtc();
    _notificationsClearedAt = nowUtc;
    for (final n in _notifications) {
      _dismissedNotificationIds.add(n.id);
      if (n.relatedPostId != null && n.relatedPostId!.isNotEmpty) {
        _dismissedNotificationIds.add(n.relatedPostId!);
      }
    }
    _notifications.clear();
    _invalidateDataCaches();
    notifyListeners();
    _scheduleLocalSave();

    // Persist clear-all state to Supabase profile so clean installs don't reload cleared notifs
    final client = _client;
    if (client != null && currentUser.id.isNotEmpty) {
      unawaited(
        client
            .from('profiles')
            .update({'notifications_cleared_at': nowUtc.toIso8601String()})
            .eq('user_id', currentUser.id)
            .catchError((_) {}),
      );
    }
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
      if (_notificationsCleared &&
          _notificationsClearedAt != null &&
          !expirations[role]!.toUtc().isAfter(_notificationsClearedAt!.toUtc())) {
        continue;
      }
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
        title: '🤖 Flutter & Mobile AI Workshop Tomorrow',
        body: 'Don\'t forget your registration deadline is in 3 days.',
        category: NotificationCategory.events,
        timestamp: now.subtract(const Duration(hours: 5)),
        relatedPostId: 'pst_004',
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
        postId: 'pst_004',
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
        postId: 'pst_004',
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
    required this.formSubmissions,
    required this.serverKnownIds,
    required this.deviceOnlyPostIds,
    this.showAllYearsFeed = false,
    this.profileLikes = const {},
    this.likedProfileAuthorIds = const {},
    this.hadServerProfile = false,
    this.notificationsCleared = false,
    this.notificationsClearedAt,
    this.dismissedNotificationIds = const {},
  });

  final UserModel currentUser;
  final UserRole? activeRole;
  final List<PostModel> posts;
  final List<NotificationModel> notifications;
  final List<RoleRequestModel> roleRequests;
  final List<FormSubmission> formSubmissions;
  final Set<String> serverKnownIds;
  final Set<String> deviceOnlyPostIds;
  final bool showAllYearsFeed;
  final Map<String, int> profileLikes;
  final Set<String> likedProfileAuthorIds;
  final bool hadServerProfile;
  final bool notificationsCleared;
  final DateTime? notificationsClearedAt;
  final Set<String> dismissedNotificationIds;
}

Uint8List _decodeBase64Helper(String base64) => base64Decode(base64);

Map<String, dynamic>? _parseJsonHelper(String raw) {
  try {
    return jsonDecode(raw) as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}
