import 'admin_session_stub.dart'
    if (dart.library.html) 'admin_session_web.dart' as impl;

/// Persists a verified admin login in the browser's localStorage for 1 day so
/// a refresh or short browser close does not force a re-login. Logout clears
/// it immediately. No password is ever stored — only the server-verified
/// user_id/name.
class AdminSession {
  static void save({required String userId, required String name}) =>
      impl.save(userId: userId, name: name);

  static Map<String, String>? read() => impl.read();

  static void clear() => impl.clear();
}