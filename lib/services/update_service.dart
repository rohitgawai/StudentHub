import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/update_modal.dart';

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

  // Current build numbers (synchronized with pubspec.yaml 1.4.2+35)
  static const int currentVersionCode = 35;
  static const String currentVersionName = '1.4.2';

  static const MethodChannel _installerChannel =
      MethodChannel('student_hub/installer');

  RealtimeChannel? _realtimeChannel;
  bool _isChecking = false;
  bool _modalVisible = false;

  /// Initializes realtime listener for incoming OTA release broadcasts
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
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                final update = AppUpdateInfo.fromMap(newRecord);
                if (update.versionCode > currentVersionCode) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final ctx = getContext();
                    if (ctx.mounted) showUpdateDialog(ctx, update);
                  });
                }
              }
            },
          )
          .onBroadcast(
            event: 'new_app_release',
            callback: (payload) {
              final update = AppUpdateInfo.fromMap(payload);
              if (update.versionCode > currentVersionCode) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final ctx = getContext();
                  if (ctx.mounted) showUpdateDialog(ctx, update);
                });
              }
            },
          )
          .subscribe();
    } catch (_) {
      // Backend not yet migrated or offline
    }
  }

  /// Checks Supabase for the latest version and presents the update modal if newer
  Future<AppUpdateInfo?> checkForUpdate(
    BuildContext context, {
    bool silent = false,
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
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ StudentHub is up to date (v$currentVersionName)'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return null;
      }

      final latest = AppUpdateInfo.fromMap(res);
      if (latest.versionCode > currentVersionCode) {
        if (context.mounted) {
          showUpdateDialog(context, latest);
        }
        return latest;
      } else {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ You are using the latest version of StudentHub (v$currentVersionName)',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return null;
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

  /// Shows the rich in-app update bottom sheet
  void showUpdateDialog(BuildContext context, AppUpdateInfo update) {
    if (_modalVisible) return;
    _modalVisible = true;

    showModalBottomSheet(
      context: context,
      isDismissible: !update.isMandatory,
      enableDrag: !update.isMandatory,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UpdateModal(update: update),
    ).whenComplete(() {
      _modalVisible = false;
    });
  }

  /// Downloads the APK from CDN and invokes Android PackageInstaller
  Future<void> downloadAndInstall({
    required AppUpdateInfo update,
    required void Function(double progress, int downloaded, int total) onProgress,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(update.apkUrl));
      final response = await client.send(request);

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

      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          final progress =
              totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
          onProgress(progress, downloadedBytes, totalBytes);
        },
        cancelOnError: true,
      ).asFuture();

      await sink.flush();
      await sink.close();

      // Launch native PackageInstaller
      await _installerChannel.invokeMethod('installApk', {
        'filePath': apkFile.path,
      });
    } finally {
      client.close();
    }
  }

  void dispose() {
    _realtimeChannel?.unsubscribe();
  }
}
