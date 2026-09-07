import 'dart:async';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/post_model.dart';
import 'mock_data_service.dart';

/// Handles OS-level (FCM) push notifications so new posts, events and
/// announcements appear in the system tray even while the app is closed.
///
/// - Background / terminated: FCM renders the notification natively.
/// - Foreground: shown through [FlutterLocalNotificationsPlugin].
/// - Tapping any notification emits [openCategory] so the navigation layer can
///   open the relevant tab.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Set when the user taps a notification; the app navigates to the tab
  /// matching the post category (Events tab for events/workshops, Home
  /// otherwise).
  final ValueNotifier<PostCategory?> openCategory =
      ValueNotifier<PostCategory?>(null);

  /// Set when the user taps a notification targeting a specific post
  final ValueNotifier<String?> targetPostId = ValueNotifier<String?>(null);

  /// Set when user opens an account ban/unban notification
  final ValueNotifier<String?> accountNotice = ValueNotifier<String?>(null);

  /// Set when user taps an announcement notification to open notification bell
  final ValueNotifier<bool> openNotifications = ValueNotifier<bool>(false);

  /// Set when user taps an app update push notification to directly open update dialog
  final ValueNotifier<bool> triggerAppUpdate = ValueNotifier<bool>(false);

  MockDataService? _dataService;
  bool _initialized = false;

  void _onMessageOpenedApp(RemoteMessage message) {
    final category = message.data['category'];
    final type = message.data['type'];
    final postId = message.data['post_id']?.toString();
    final title = message.notification?.title ?? message.data['title']?.toString() ?? '';
    final body = message.notification?.body ?? message.data['body']?.toString();

    if (type == 'account_ban' || (postId != null && postId.startsWith('ban_'))) {
      accountNotice.value = body ?? 'Your account has been suspended by Administrator.';
      return;
    }
    if (type == 'account_unban') {
      accountNotice.value = body ?? 'Your account has been unbanned. Welcome back!';
      return;
    }

    // Direct app update trigger when user taps app update push notification
    final isAppUpdate = (postId != null &&
            (postId.startsWith('announcement_update_') ||
                postId.toLowerCase().contains('update'))) ||
        (type == 'app_update') ||
        title.toLowerCase().contains('update') ||
        (body != null &&
            (body.toLowerCase().contains('update') ||
                body.toLowerCase().contains('what\'s new')));

    if (isAppUpdate) {
      triggerAppUpdate.value = true;
      _maybeSyncAfterPush(message.data);
      return;
    }

    if (type == 'announcement' || (postId != null && postId.startsWith('announcement_'))) {
      openNotifications.value = true;
      _maybeSyncAfterPush(message.data);
      return;
    }

    openCategory.value = 'event' == category || 'workshop' == category
        ? PostCategory.event
        : PostCategory.announcement;
    if (postId != null &&
        postId.isNotEmpty &&
        !postId.startsWith('ban_') &&
        !postId.startsWith('role_removal_') &&
        !postId.startsWith('announcement_')) {
      targetPostId.value = postId;
    }
    _maybeSyncAfterPush(message.data);
  }

  Future<void> init({required MockDataService dataService}) async {
    if (_initialized) return;
    _dataService = dataService;

    await Firebase.initializeApp();
    _configureAndroidNotifications();
    await _ensureChannelsCreated();

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _onMessageOpenedApp(initial);

    _initialized = true;
    await _registerToken();
  }

  void _configureAndroidNotifications() {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          if (payload.startsWith('announcement_update_') ||
              payload.toLowerCase().contains('update')) {
            triggerAppUpdate.value = true;
            return;
          }
          if (payload.startsWith('ban_') || payload.startsWith('role_removal_')) {
            return;
          }
          if (payload.startsWith('announcement_')) {
            openNotifications.value = true;
            return;
          }
          targetPostId.value = payload;
        }
      },
    );
  }

  /// Pre-creates every channel the app uses so that native FCM rendering
  /// (background / terminated pushes) finds a real channel on Android 8+.
  /// Without this, the manifest default channel (`high_importance` /
  /// `campus_updates`) does not exist yet and older Android versions silently
  /// suppress the system notification while newer ones happen to show it.
  Future<void> _ensureChannelsCreated() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final impl = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) return;
    const channels = [
      AndroidNotificationChannel(
        'campus_updates',
        'Campus Updates & Announcements',
        description: 'Official updates, notifications and campus events',
        importance: Importance.max,
        showBadge: true,
      ),
      AndroidNotificationChannel(
        'social_activity',
        'Likes & Appreciations',
        description: 'Social interactions from students and faculty',
        importance: Importance.max,
        showBadge: true,
      ),
      AndroidNotificationChannel(
        'account_security',
        'Account & Role Alerts',
        description: 'Security alerts and official role status updates',
        importance: Importance.max,
        showBadge: true,
      ),
      AndroidNotificationChannel(
        'events_workshops',
        'Events & Workshops',
        description: 'Live campus events, workshops and registrations',
        importance: Importance.max,
        showBadge: true,
      ),
    ];
    for (final channel in channels) {
      try {
        await impl.createNotificationChannel(channel);
      } catch (e) {
        debugPrint('StudentHub: channel create failed: $e');
      }
    }
  }

  Future<void> _registerToken() async {
    final dataService = _dataService;
    if (dataService == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await dataService.registerDeviceToken(token);
    FirebaseMessaging.instance.onTokenRefresh.listen((refreshed) {
      dataService.registerDeviceToken(refreshed);
    });
  }

  /// Re-binds the FCM token to the CURRENTLY logged-in user. Must be called
  /// after every login: the token is keyed by token string in device_tokens,
  /// so registering again with a different user_id moves the device to the
  /// right account (otherwise the previous user keeps getting this device's
  /// pushes, and the new user receives none).
  Future<void> rebindToken() async {
    final dataService = _dataService;
    if (dataService == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await dataService.registerDeviceToken(token);
      }
    } catch (e) {
      debugPrint('StudentHub: push token rebind failed: $e');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final title = message.notification?.title ?? data['title']?.toString();
    final body = message.notification?.body ?? data['body']?.toString();
    final postId = data['post_id']?.toString();
    final category = data['category']?.toString().toLowerCase() ?? '';
    final type = data['type']?.toString().toLowerCase() ?? '';

    if (title != null && title.isNotEmpty) {
      String channelId = 'campus_updates';
      String channelName = 'Campus Updates & Announcements';
      String channelDesc = 'Official updates, notifications and campus events';
      Color notifColor = const Color(0xFF1E3A8A); // StudentHub Deep Blue

      if (type.contains('like') || type.contains('appreciat')) {
        channelId = 'social_activity';
        channelName = 'Likes & Appreciations';
        channelDesc = 'Social interactions from students and faculty';
        notifColor = const Color(0xFFE11D48);
      } else if (type.contains('ban') || type.contains('role') || type.contains('security')) {
        channelId = 'account_security';
        channelName = 'Account & Role Alerts';
        channelDesc = 'Security alerts and official role status updates';
        notifColor = const Color(0xFFD97706);
      } else if (category == 'event' || category == 'workshop') {
        channelId = 'events_workshops';
        channelName = 'Events & Workshops';
        channelDesc = 'Live campus events, workshops and registrations';
        notifColor = const Color(0xFF4F46E5);
      }

      final bigTextStyle = BigTextStyleInformation(
        body ?? '',
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: 'StudentHub MIT',
        htmlFormatSummaryText: false,
      );

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          color: notifColor,
          styleInformation: bigTextStyle,
          enableVibration: true,
          channelShowBadge: true,
          icon: '@mipmap/ic_launcher',
        ),
      );

      final isUpdate = type == 'app_update' ||
          (postId != null && (postId.startsWith('announcement_update_') || postId.toLowerCase().contains('update'))) ||
          title.toLowerCase().contains('update');
      final notifPayload = isUpdate
          ? ((postId != null && postId.isNotEmpty) ? postId : 'announcement_update_latest')
          : postId;

      await _localNotifications.show(
        id: DateTime.now().microsecondsSinceEpoch.remainder(1 << 31),
        title: title,
        body: body ?? '',
        notificationDetails: details,
        payload: notifPayload,
      );
    }

    // The push proves a new backend row exists; refresh immediately so the
    // in-app bell notification ("New post: ...") appears right away instead of
    // waiting for the next 45s poll.
    _maybeSyncAfterPush(data);
  }

  /// Refreshes the feed right after a push-related event so the in-app bell is
  /// never more than a second behind the system notification.
  void _maybeSyncAfterPush(Map<String, dynamic> data) {
    final type = data['type'];
    final service = _dataService;
    if (service == null) return;
    // The event host gets an in-app bell entry the moment someone registers.
    if (type == 'event_registration') {
      final postId = data['post_id'];
      final registrant = data['registrant_name'];
      if (postId != null && registrant != null && registrant.isNotEmpty) {
        service.addHostRegistrationNotification(
          postId: postId,
          registrantName: registrant,
        );
      }
    }
    if (type != 'new_post' &&
        type != 'post_live' &&
        type != 'event_registration' &&
        type != 'registration_confirmed' &&
        type != 'registrations_closed' &&
        type != 'role_update' &&
        type != 'announcement' &&
        type != 'app_update') {
      return;
    }
    unawaited(service.syncNow());
  }
}

/// Runs in a background isolate when a push arrives while the app is
/// backgrounded or terminated. The system tray is rendered natively by FCM, so
/// this only needs to keep the engine ready.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('StudentHub: push received in background: ${message.messageId}');
}
