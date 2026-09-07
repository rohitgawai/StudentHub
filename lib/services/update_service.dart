import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/update_modal.dart';

class UpdateDownloadException implements Exception {
  final String message;
  final bool isOffline;

  UpdateDownloadException(this.message, {this.isOffline = false});

  @override
  String toString() => message;
}

class AppUpdateInfo {
  final String id;
  final String versionName;
  final int versionCode;
  final String apkUrl;
  final int fileSizeBytes;
  final String releaseNotes;
  final bool isMandatory;
  final DateTime createdAt;

  AppUpdateInfo({
    required this.id,
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.fileSizeBytes,
    required this.releaseNotes,
    this.isMandatory = false,
    required this.createdAt,
  });

  factory AppUpdateInfo.fromMap(Map<String, dynamic> map) {
    return AppUpdateInfo(
      id: map['id']?.toString() ?? '',
      versionName: map['version_name']?.toString() ?? '1.0.0',
      versionCode: (map['version_code'] as num?)?.toInt() ?? 1,
      apkUrl: map['apk_url']?.toString() ?? '',
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
      releaseNotes: map['release_notes']?.toString() ??
          'Bug fixes and performance improvements.',
      isMandatory: map['is_mandatory'] == true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  // Current build numbers (synchronized with pubspec.yaml 1.4.13+46)
  static const int currentVersionCode = 46;
  static const String currentVersionName = '1.4.13';

  /// Compares semantic versions e.g. "1.4.10" vs "1.4.9".
  /// Returns > 0 if v1 > v2, < 0 if v1 < v2, 0 if equal.
  static int compareVersions(String v1, String v2) {
    try {
      final clean1 = v1.replaceAll(RegExp(r'[^0-9.]'), '');
      final clean2 = v2.replaceAll(RegExp(r'[^0-9.]'), '');
      final parts1 = clean1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final parts2 = clean2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;
      for (int i = 0; i < maxLen; i++) {
        final p1 = i < parts1.length ? parts1[i] : 0;
        final p2 = i < parts2.length ? parts2[i] : 0;
        if (p1 != p2) return p1.compareTo(p2);
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Returns true if a given versionCode or versionName is already installed on the client.
  static bool isVersionInstalled({int? versionCode, String? versionName}) {
    if (versionCode != null && versionCode > 0) {
      return currentVersionCode >= versionCode;
    }
    if (versionName != null && versionName.isNotEmpty) {
      return compareVersions(currentVersionName, versionName) >= 0;
    }
    return true;
  }

  static const MethodChannel _installerChannel =
      MethodChannel('student_hub/installer');

  RealtimeChannel? _realtimeChannel;
  bool _isChecking = false;
  bool _modalVisible = false;

  /// Initializes realtime listener for incoming OTA release broadcasts.
  /// Update notifications are delivered as push & in-app bell notification text.
  void initialize(BuildContext Function() getContext) {
    try {
      final client = Supabase.instance.client;
      _realtimeChannel = client.channel('app_updates_realtime');

      _realtimeChannel
          ?.onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_updates',
            callback: (payload) {
              // Realtime OTA updates notify via push & in-app bell notification text
            },
          )
          .onBroadcast(
            event: 'new_app_release',
            callback: (payload) {
              // Realtime OTA updates notify via push & in-app bell notification text
            },
          )
          .subscribe();
    } catch (_) {
      // Backend not yet migrated or offline
    }
  }

  /// Checks Supabase for the latest version and presents the update modal if newer,
  /// or presents the update modal in the 'Already Up to Date' state if already updated.
  Future<AppUpdateInfo?> checkForUpdate(
    BuildContext context, {
    bool silent = false,
    bool forceShow = false,
  }) async {
    if (_isChecking) return null;
    _isChecking = true;

    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('app_updates')
          .select()
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      _isChecking = false;
      if (res == null) {
        if ((!silent || forceShow) && context.mounted) {
          // Construct fallback update info representing current build so dialog can open
          final fallback = AppUpdateInfo(
            id: 'current_build',
            versionName: currentVersionName,
            versionCode: currentVersionCode,
            apkUrl: '',
            fileSizeBytes: 0,
            releaseNotes: 'You are on the latest version of StudentHub (v$currentVersionName).\n\n• Performance optimizations and smooth animations\n• Enhanced AI assistant experience\n• Latest campus security updates and real-time synchronization',
            isMandatory: false,
            createdAt: DateTime.now(),
          );
          showUpdateDialog(context, fallback);
          return fallback;
        }
        return null;
      }

      final latest = AppUpdateInfo.fromMap(res);
      if (latest.versionCode > currentVersionCode || forceShow) {
        if (context.mounted) {
          showUpdateDialog(context, latest);
        }
        return latest;
      } else {
        // App is already up to date!
        if (!silent && context.mounted) {
          showUpdateDialog(context, latest);
        }
        return latest;
      }
    } catch (e) {
      _isChecking = false;
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Unable to check for updates: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }

  /// Shows the rich in-app update presentation
  void showUpdateDialog(BuildContext context, AppUpdateInfo update) {
    if (_modalVisible) return;
    _modalVisible = true;

    showGeneralDialog(
      context: context,
      barrierDismissible: !update.isMandatory,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => UpdateModal(update: update),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ).whenComplete(() {
      _modalVisible = false;
    });
  }

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int _downloadNotifId = 9898;
  static const String _downloadChannelId = 'app_downloads';
  int _lastReportedPercent = -1;

  /// Launches native PackageInstaller with the downloaded APK file
  Future<void> launchInstaller(String filePath) async {
    try {
      await _installerChannel.invokeMethod('installApk', {
        'filePath': filePath,
      });
    } catch (e) {
      debugPrint('StudentHub: Error launching native installer: $e');
    }
  }

  /// Posts an ongoing progress notification in the Android system drawer
  Future<void> _showDownloadProgressNotification({
    required String versionName,
    required double progress,
    required int downloaded,
    required int total,
  }) async {
    try {
      final percent = (progress * 100).toInt().clamp(0, 100);
      if (percent == _lastReportedPercent && percent != 0 && percent != 100) {
        return;
      }
      _lastReportedPercent = percent;

      final downloadedMb = (downloaded / (1024 * 1024)).toStringAsFixed(1);
      final totalMb = (total > 0 ? total / (1024 * 1024) : 0.0).toStringAsFixed(1);

      final androidDetails = AndroidNotificationDetails(
        _downloadChannelId,
        'App Updates & Downloads',
        channelDescription: 'Download progress for StudentHub in-app updates',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: 100,
        progress: percent,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        icon: '@mipmap/ic_launcher',
      );

      await _notificationsPlugin.show(
        id: _downloadNotifId,
        title: 'Downloading StudentHub v$versionName',
        body: '$percent% • $downloadedMb MB / $totalMb MB',
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: 'announcement_update',
      );
    } catch (_) {
      // Notification failed silently without interrupting download
    }
  }

  /// Posts completion alert in the notification drawer with one-tap installation
  Future<void> _showDownloadCompleteNotification({
    required String versionName,
    required String filePath,
  }) async {
    try {
      _lastReportedPercent = -1;
      final androidDetails = const AndroidNotificationDetails(
        _downloadChannelId,
        'App Updates & Downloads',
        channelDescription: 'Download progress for StudentHub in-app updates',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: false,
        autoCancel: true,
        icon: '@mipmap/ic_launcher',
      );

      await _notificationsPlugin.show(
        id: _downloadNotifId,
        title: '✅ StudentHub v$versionName Ready',
        body: 'Download complete. Tap to install the update.',
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: 'install_apk_$filePath',
      );
    } catch (_) {}
  }

  /// Clears active download progress notification
  Future<void> _cancelDownloadNotification() async {
    _lastReportedPercent = -1;
    try {
      await _notificationsPlugin.cancel(id: _downloadNotifId);
    } catch (_) {}
  }

  /// Downloads the APK from CDN, publishes live progress to the UI & system notification drawer,
  /// and automatically invokes the Android PackageInstaller once complete.
  Future<void> downloadAndInstall({
    required AppUpdateInfo update,
    required void Function(double progress, int downloaded, int total) onProgress,
  }) async {
    final client = http.Client();
    try {
      _lastReportedPercent = -1;
      final request = http.Request('GET', Uri.parse(update.apkUrl));
      final response = await client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw UpdateDownloadException(
          'Server returned status code ${response.statusCode} while downloading update.',
          isOffline: false,
        );
      }

      final totalBytes = response.contentLength ?? update.fileSizeBytes;
      int downloadedBytes = 0;

      final tempDir = await getTemporaryDirectory();
      final apkFile = File(
        '${tempDir.path}/StudentHub-v${update.versionName}.apk',
      );

      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final sink = apkFile.openWrite();

      // Show initial notification
      await _showDownloadProgressNotification(
        versionName: update.versionName,
        progress: 0.0,
        downloaded: 0,
        total: totalBytes,
      );

      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          final progress =
              totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
          onProgress(progress, downloadedBytes, totalBytes);
          _showDownloadProgressNotification(
            versionName: update.versionName,
            progress: progress,
            downloaded: downloadedBytes,
            total: totalBytes,
          );
        },
        cancelOnError: true,
      ).asFuture();

      await sink.flush();
      await sink.close();

      // Post completion notification
      await _showDownloadCompleteNotification(
        versionName: update.versionName,
        filePath: apkFile.path,
      );

      // Launch native Android PackageInstaller
      await launchInstaller(apkFile.path);
    } on SocketException catch (_) {
      await _cancelDownloadNotification();
      throw UpdateDownloadException(
        'Internet connection lost. Please check your network and try again.',
        isOffline: true,
      );
    } on http.ClientException catch (_) {
      await _cancelDownloadNotification();
      throw UpdateDownloadException(
        'Connection interrupted during download. Please check your internet connection.',
        isOffline: true,
      );
    } on TimeoutException catch (_) {
      await _cancelDownloadNotification();
      throw UpdateDownloadException(
        'Download request timed out. Please check your connection and retry.',
        isOffline: true,
      );
    } catch (e) {
      await _cancelDownloadNotification();
      final errStr = e.toString().toLowerCase();
      final isOffline = errStr.contains('socket') ||
          errStr.contains('network') ||
          errStr.contains('connection') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('offline') ||
          errStr.contains('timeout');
      if (isOffline) {
        throw UpdateDownloadException(
          'Internet connection lost. Please check your network and try again.',
          isOffline: true,
        );
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  void dispose() {
    _realtimeChannel?.unsubscribe();
  }
}
