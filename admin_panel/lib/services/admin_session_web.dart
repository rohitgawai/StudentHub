// Web-only session storage backed by localStorage. dart:html is deprecated in
// favor of package:web, but it is still the most compact reliable API here.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html';

const String _key = 'studenthub_admin_session';
const int _sessionDurationMs = 86400000; // 1 day

void save({required String userId, required String name}) {
  final payload = {
    'userId': userId,
    'name': name,
    'expiresAt': DateTime.now().millisecondsSinceEpoch + _sessionDurationMs,
  };
  try {
    window.localStorage[_key] = jsonEncode(payload);
  } catch (_) {}
}

Map<String, String>? read() {
  try {
    final raw = window.localStorage[_key];
    if (raw == null || raw.isEmpty) return null;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final expiresAt = data['expiresAt'] as int? ?? 0;
    if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
      clear();
      return null;
    }
    return {
      'userId': data['userId']?.toString() ?? '',
      'name': data['name']?.toString() ?? 'Admin',
    };
  } catch (_) {
    return null;
  }
}

void clear() {
  try {
    window.localStorage.remove(_key);
  } catch (_) {}
}