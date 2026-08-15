import 'package:flutter/services.dart';

/// Service to enforce OS-level screenshot and screen recording protection
/// (FLAG_SECURE on Android, like WhatsApp, banking apps, and Telegram).
class SecurityService {
  static const MethodChannel _channel = MethodChannel('student_hub/security');

  /// Enables OS-level security (blocks screenshots and screen recordings).
  static Future<void> enableSecureScreen() async {
    try {
      await _channel.invokeMethod('enableSecure');
    } catch (_) {
      // Graceful fallback on unsupported platforms
    }
  }

  /// Disables OS-level security when navigating away from protected screens.
  static Future<void> disableSecureScreen() async {
    try {
      await _channel.invokeMethod('disableSecure');
    } catch (_) {
      // Graceful fallback on unsupported platforms
    }
  }
}
