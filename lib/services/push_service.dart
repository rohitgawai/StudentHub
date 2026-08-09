import 'dart:async';

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

  MockDataService? _dataService;
  bool _initialized = false;

  Future<void> init({required MockDataService dataService}) async {
    if (_initialized) return;
    _dataService = dataService;

    await Firebase.initializeApp();
    _configureAndroidNotifications();

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
    _localNotifications.initialize(settings: settings);
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

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final title = message.notification?.title ?? data['title'];
    final body = message.notification?.body ?? data['body'];
    if (title != null) {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance',
          'High Importance',
          channelDescription: 'New campus posts, events and announcements',
          importance: Importance.max,
          priority: Priority.high,
        ),
      );
      await _localNotifications.show(
        id: DateTime.now().microsecondsSinceEpoch.remainder(1 << 31),
        title: title,
        body: body ?? '',
        notificationDetails: details,
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
        type != 'event_registration' &&
        type != 'registration_confirmed' &&
        type != 'registrations_closed' &&
        type != 'role_update') {
      return;
    }
    unawaited(service.syncNow());
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    final category = message.data['category'];
    openCategory.value = 'event' == category || 'workshop' == category
        ? PostCategory.event
        : PostCategory.announcement;
    _maybeSyncAfterPush(message.data);
  }
}

/// Runs in a background isolate when a push arrives while the app is
/// backgrounded or terminated. The system tray is rendered natively by FCM, so
/// this only needs to keep the engine ready.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('StudentHub: push received in background: ${message.messageId}');
}