import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local on-device persistence.
///
/// A lightweight JSON snapshot of the app state (current user, roles, last
/// active role, posts, notifications, role requests, announcements) is kept in
/// `shared_preferences`, while any uploaded files (PDFs, images) are written to
/// the app's private documents directory. Stored file refs use the `local://`
/// prefix so the in-memory models and remote mirror (Supabase) can tell apart
/// device-only blobs from `data:` URIs, HTTP URLs, or bundled assets.
class LocalStoreService {
  LocalStoreService._();

  static final LocalStoreService instance = LocalStoreService._();

  static const String _snapshotKey = 'studenthub.local_state.v1';
  static const String _splashKey = 'studenthub.has_seen_splash.v1';
  static const String localPrefix = 'local://';

  Directory? _cachedDir;

  // --- First-run flags --------------------------------------------------------

  Future<bool> hasSeenSplash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_splashKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markSplashSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_splashKey, true);
    } catch (_) {
      // Best-effort.
    }
  }

  /// Warms the in-memory cache of the attachments directory so that image
  /// providers can resolve `local://` refs synchronously. Call once at startup
  /// on platforms that support file I/O (throws are swallowed).
  Future<void> warmUp() async {
    try {
      await _attachmentsDir();
    } catch (_) {
      // Not a platform with a real filesystem (e.g. web): local refs are never
      // produced there, so caching is best-effort.
    }
  }

  /// Resolves a `local://` ref to an absolute path synchronously when the
  /// directory cache is ready; otherwise null.
  String? resolvePathSync(String url) {
    if (!isLocalRef(url)) return null;
    final dir = _cachedDir;
    if (dir == null) return null;
    final name = _basenameOf(url);
    return '${dir.path}${Platform.pathSeparator}$name';
  }

  Future<Directory> _attachmentsDir() async {
    final cached = _cachedDir;
    if (cached != null) return cached;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}${Platform.pathSeparator}attachments');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cachedDir = dir;
      return dir;
    } catch (_) {
      final fallback = Directory.systemTemp;
      _cachedDir = fallback;
      return fallback;
    }
  }

  // --- Snapshot -----------------------------------------------------------------

  Future<String?> loadSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_snapshotKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSnapshot(String jsonString) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snapshotKey, jsonString);
    } catch (_) {
      // Persistence is best-effort; in-memory state always remains usable.
    }
  }

  Future<void> clearSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_snapshotKey);
    } catch (_) {
      // ignore
    }
  }

  // --- Blob storage ------------------------------------------------------------

  String referenceTo(String basename) => '$localPrefix$basename';

  bool isLocalRef(String? url) => url != null && url.startsWith(localPrefix);

  String _basenameOf(String ref) => ref.substring(localPrefix.length);

  /// Writes [source] bytes to the app documents directory and returns a
  /// `local://` reference. Returns the input unchanged when it is not a `data:`
  /// URI or when the write fails.
  Future<String> persistDataUri(
    String? source,
    String baseId,
    String suffix,
    String extension,
  ) async {
    if (source == null || source.isEmpty) return source ?? '';
    if (isLocalRef(source)) return source;
    if (!source.startsWith('data:')) return source;

    try {
      final commaIndex = source.indexOf(',');
      if (commaIndex == -1) return source;
      // Decode on a background isolate: PDFs and camera photos are multi-MB and
      // base64 decoding them on the UI isolate blocks frames.
      final bytes = await compute(
        _decodeBase64,
        source.substring(commaIndex + 1),
      );
      final safeName = baseId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final fileName = '${safeName}_$suffix.$extension';
      final dir = await _attachmentsDir();
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return referenceTo(fileName);
    } catch (_) {
      return source;
    }
  }

  /// Returns the file name of a `local://` reference (may be null for other
  /// sources).
  String? localFileNameFor(String? url) {
    if (!isLocalRef(url)) return null;
    return _basenameOf(url!);
  }

  Future<File?> fileFor(String? url) async {
    final name = localFileNameFor(url);
    if (name == null) return null;
    final dir = await _attachmentsDir();
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    if (!await file.exists()) return null;
    return file;
  }

  Future<Uint8List?> readLocalBlob(String? url) async {
    final file = await fileFor(url);
    if (file == null) return null;
    return file.readAsBytes();
  }

  /// Deletes the blob file backing a `local://` reference (no-op otherwise).
  Future<void> deleteLocalBlob(String? url) async {
    final file = await fileFor(url);
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}

Uint8List _decodeBase64(String base64) => base64Decode(base64);
