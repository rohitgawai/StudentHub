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

  final pubspecContent = pubspecFile.readAsStringSync();
  final versionMatch = RegExp(r'version:\s*([0-9\.]+)\+([0-9]+)').firstMatch(pubspecContent);
  if (versionMatch == null) {
    print('❌ Error: Could not determine version from pubspec.yaml');
    exit(1);
  }

  final versionName = versionMatch.group(1)!;
  final versionCode = int.parse(versionMatch.group(2)!);

  bool isMandatory = args.contains('--mandatory');
  String releaseNotes = '• General performance and stability improvements\n• Bug fixes and UI enhancements';

  String pushSecret = Platform.environment['PUSH_SECRET'] ?? 'studenthub-dev-push-secret';

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--notes' && i + 1 < args.length) {
      releaseNotes = args[i + 1];
    } else if (args[i] == '--push-secret' && i + 1 < args.length) {
      pushSecret = args[i + 1];
    }
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

  print('\n═══════════════════════════════════════════════════════════════');
  print('🎉 RELEASE v$versionName (Build $versionCode) PUBLISHED SUCCESSFULLY! ');
  print('═══════════════════════════════════════════════════════════════');
  print('📲 All installed StudentHub apps will automatically receive the update prompt!');
  print('🔗 Public APK: $publicApkUrl\n');
}
