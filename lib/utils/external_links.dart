import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an external URL (Google Form, Meet, website…) in the browser/app.
/// Shows a snackbar when the URL is invalid or nothing can open it.
Future<void> openExternalLink(BuildContext context, String url) async {
  final trimmed = url.trim();
  final uri = Uri.tryParse(trimmed);
  final valid =
      uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
  if (!valid) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ That link does not look valid.'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return;
  }
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Could not open this link on your device.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Could not open this link on your device.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
