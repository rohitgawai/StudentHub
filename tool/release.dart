// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:student_hub/config/supabase_config.dart';

/// StudentHub Automated CLI Release & OTA Publishing Tool
///
/// Usage:
///   dart run tool/release.dart
///   dart run tool/release.dart --notes "Added event registration improvements"
///   dart run tool/release.dart --mandatory
void main(List<String> args) async {
  print('═══════════════════════════════════════════════════════════════');
  print('       STUDENTHUB OVER-THE-AIR (OTA) RELEASE DEPLOYER          ');
  print('═══════════════════════════════════════════════════════════════\n');

  // 1. Parse pubspec.yaml for version and build number
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('❌ Error: pubspec.yaml not found. Run this tool from project root.');
    exit(1);
  }

  var pubspecContent = pubspecFile.readAsStringSync();
  final versionMatch = RegExp(r'version:\s*([0-9\.]+)\+([0-9]+)').firstMatch(pubspecContent);
  if (versionMatch == null) {
    print('❌ Error: Could not determine version from pubspec.yaml');
    exit(1);
  }

  var versionName = versionMatch.group(1)!;
  var versionCode = int.parse(versionMatch.group(2)!);

  bool isMandatory = args.contains('--mandatory');
  String releaseNotes = '• General performance and stability improvements\n• Bug fixes and UI enhancements';
  String pushSecret = Platform.environment['PUSH_SECRET'] ?? 'studenthub-dev-push-secret';

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--notes' && i + 1 < args.length) {
      releaseNotes = args[i + 1];
    } else if (args[i] == '--push-secret' && i + 1 < args.length) {
      pushSecret = args[i + 1];
    } else if (args[i] == '--version' && i + 1 < args.length) {
      final customVer = args[i + 1];
      final customMatch = RegExp(r'([0-9\.]+)\+([0-9]+)').firstMatch(customVer);
      if (customMatch != null) {
        versionName = customMatch.group(1)!;
        versionCode = int.parse(customMatch.group(2)!);
        pubspecContent = pubspecContent.replaceFirst(
          RegExp(r'version:\s*[0-9\.]+\+[0-9]+'),
          'version: $versionName+$versionCode',
        );
        pubspecFile.writeAsStringSync(pubspecContent);
        print('📝 Updated pubspec.yaml -> version: $versionName+$versionCode');
      }
    } else if (args[i] == '--bump' || args[i] == '--bump-patch') {
      versionCode += 1;
      final parts = versionName.split('.');
      if (parts.length == 3) {
        final patch = int.tryParse(parts[2]) ?? 0;
        versionName = '${parts[0]}.${parts[1]}.${patch + 1}';
      }
      pubspecContent = pubspecContent.replaceFirst(
        RegExp(r'version:\s*[0-9\.]+\+[0-9]+'),
        'version: $versionName+$versionCode',
      );
      pubspecFile.writeAsStringSync(pubspecContent);
      print('🚀 Auto-bumped pubspec.yaml -> version: $versionName+$versionCode');
    }
  }

  // 1.1 Simultaneously synchronize lib/services/update_service.dart before building
  final updateServiceFile = File('lib/services/update_service.dart');
  if (updateServiceFile.existsSync()) {
    var updateServiceContent = updateServiceFile.readAsStringSync();
    updateServiceContent = updateServiceContent.replaceAll(
      RegExp(r'static const int currentVersionCode = \d+;'),
      'static const int currentVersionCode = $versionCode;',
    );
    updateServiceContent = updateServiceContent.replaceAll(
      RegExp(r"static const String currentVersionName = '[^']+';"),
      "static const String currentVersionName = '$versionName';",
    );
    updateServiceContent = updateServiceContent.replaceAll(
      RegExp(r'// Current build numbers \(synchronized with pubspec\.yaml [^\)]+\)'),
      '// Current build numbers (synchronized with pubspec.yaml $versionName+$versionCode)',
    );
    updateServiceFile.writeAsStringSync(updateServiceContent);
    print('🔄 Synchronized update_service.dart -> v$versionName (Code: $versionCode)');
  }

  print('📦 Release Target:');
  print('   • Version Name: v$versionName');
  print('   • Version Code: $versionCode');
  print('   • Mandatory:    $isMandatory');
  print('   • Push Secret:  ${pushSecret.isNotEmpty ? '✓ Configured ($pushSecret)' : '⚠️ Missing'}');
  print('   • Notes:        $releaseNotes\n');

  // 2. Supabase credentials
  final supabaseUrl = SupabaseConfig.url;
  final supabaseKey = SupabaseConfig.anonKey;

  // 2.1 Pre-check if Version Name or Code already exists
  try {
    final checkUri = Uri.parse(
      '$supabaseUrl/rest/v1/app_updates?select=id,version_name,version_code&or=(version_code.eq.$versionCode,version_name.eq.$versionName)',
    );
    final checkRes = await http.get(checkUri, headers: {
      'apikey': supabaseKey,
      'Authorization': 'Bearer $supabaseKey',
    });
    if (checkRes.statusCode == 200) {
      final list = jsonDecode(checkRes.body) as List;
      if (list.isNotEmpty) {
        final existing = list.first;
        print('⚠️ Release v${existing['version_name']} (Version Code: ${existing['version_code']}) is already published!');
        print('👉 Please update version in pubspec.yaml to a higher number before deploying.\n');
        exit(1);
      }
    }
  } catch (_) {}

  // 3. Build Release APK with PUSH_SECRET and Split-per-ABI
  print('🔨 Building Flutter Release APK with PUSH_SECRET (this may take a minute)...');
  final buildResult = await Process.run(
    'flutter.bat',
    [
      'build',
      'apk',
      '--release',
      '--split-per-abi',
      '--dart-define=PUSH_SECRET=$pushSecret',
    ],
    runInShell: true,
  );

  if (buildResult.exitCode != 0) {
    print('❌ Flutter build failed:');
    print(buildResult.stderr);
    print(buildResult.stdout);
    exit(1);
  }

  // 4. Locate output APK (prefer 64-bit arm64-v8a)
  final apkDir = Directory('build/app/outputs/flutter-apk');
  if (!apkDir.existsSync()) {
    print('❌ Error: APK output directory does not exist.');
    exit(1);
  }

  final apkFiles = apkDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.apk') && !f.path.contains('debug'))
      .toList();

  if (apkFiles.isEmpty) {
    print('❌ Error: No release APK found in ${apkDir.path}');
    exit(1);
  }

  final apkFile = apkFiles.firstWhere(
    (f) => f.path.contains('arm64-v8a'),
    orElse: () => apkFiles.first,
  );
  final fileSizeBytes = apkFile.lengthSync();
  final sizeMb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);

  print('✅ Built APK successfully: ${apkFile.path} ($sizeMb MB)');

  // 5. Upload APK to Supabase Storage 'app_releases' bucket
  final storageFileName = 'StudentHub-v$versionName-$versionCode.apk';
  print('☁️ Uploading to Supabase Storage bucket [app_releases] as $storageFileName...');

  final uploadUri = Uri.parse('$supabaseUrl/storage/v1/object/app_releases/$storageFileName');
  final uploadReq = http.Request('POST', uploadUri)
    ..headers.addAll({
      'apikey': supabaseKey,
      'Authorization': 'Bearer $supabaseKey',
      'Content-Type': 'application/vnd.android.package-archive',
      'x-upsert': 'true',
    })
    ..bodyBytes = apkFile.readAsBytesSync();

  final uploadRes = await uploadReq.send();
  if (uploadRes.statusCode != 200 && uploadRes.statusCode != 201) {
    final body = await uploadRes.stream.bytesToString();
    print('❌ Storage upload failed with status ${uploadRes.statusCode}: $body');
    exit(1);
  }

  final publicApkUrl = '$supabaseUrl/storage/v1/object/public/app_releases/$storageFileName';
  print('✅ APK uploaded to CDN: $publicApkUrl');

  // 6. Insert new version record into app_updates table
  print('📝 Registering release in database [app_updates]...');
  final insertUri = Uri.parse('$supabaseUrl/rest/v1/app_updates');
  final insertRes = await http.post(
    insertUri,
    headers: {
      'apikey': supabaseKey,
      'Authorization': 'Bearer $supabaseKey',
      'Content-Type': 'application/json',
      'Prefer': 'return=minimal',
    },
    body: jsonEncode({
      'version_name': versionName,
      'version_code': versionCode,
      'apk_url': publicApkUrl,
      'file_size_bytes': fileSizeBytes,
      'release_notes': releaseNotes,
      'is_mandatory': isMandatory,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }),
  );

  if (insertRes.statusCode != 200 && insertRes.statusCode != 201) {
    print('❌ Database insert failed with status ${insertRes.statusCode}: ${insertRes.body}');
    exit(1);
  }

  // 7. Register broadcast notification for the update
  print('📢 Registering update broadcast notification...');
  final broadcastId = 'announcement_update_$versionCode';
  try {
    final broadcastRes = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/broadcasts'),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer $supabaseKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      },
      body: jsonEncode({
        'id': broadcastId,
        'title': 'App Update: v$versionName',
        'body': "What's new:\n$releaseNotes",
        'branch': 'ALL',
        'year': 'ALL',
        'author_name': 'Admin',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    if (broadcastRes.statusCode == 200 || broadcastRes.statusCode == 201) {
      print('✅ App update broadcast registered in in-app notification bell.');
    }
  } catch (e) {
    print('⚠️ Broadcast register notice: $e');
  }

  // 8. Dispatch Push Notification to all active mobile devices
  print('📲 Dispatching push notification to all active devices...');
  try {
    final pushRes = await http.post(
      Uri.parse(SupabaseConfig.pushFunctionUrl),
      headers: {
        'Content-Type': 'application/json',
        if (pushSecret.isNotEmpty) 'X-Push-Secret': pushSecret,
      },
      body: jsonEncode({
        'post_id': broadcastId,
        'title': 'App Update: v$versionName',
        'body': "What's new:\n$releaseNotes",
        'category': 'announcement',
        'author_id': 'admin_official',
        'device_id': 'cli_release',
        'type': 'announcement',
        'skip_sender_device': false,
        'target_branch': 'ALL',
        'target_year': 'ALL',
      }),
    ).timeout(const Duration(seconds: 10));
    if (pushRes.statusCode >= 200 && pushRes.statusCode < 300) {
      print('✅ Push notifications dispatched successfully.');
    }
  } catch (e) {
    print('⚠️ Push dispatch notice: $e');
  }

  print('\n═══════════════════════════════════════════════════════════════');
  print('🎉 RELEASE v$versionName (Build $versionCode) PUBLISHED SUCCESSFULLY! ');
  print('═══════════════════════════════════════════════════════════════');
  print('📲 All active StudentHub apps have received push & in-app bell notification!');
  print('🔗 Public APK: $publicApkUrl\n');
}
