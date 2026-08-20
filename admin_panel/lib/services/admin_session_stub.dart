// Non-web fallback: no persistent session storage available (this project
// targets web only, so this file is never used at runtime).

void save({required String userId, required String name}) {}

Map<String, String>? read() => null;

void clear() {}