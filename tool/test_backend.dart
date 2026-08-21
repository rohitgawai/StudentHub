import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:student_hub/config/supabase_config.dart';

void main() async {
  print('═══════════════════════════════════════════════════════');
  print('       STUDENTHUB BACKEND & SERVER HEALTH CHECK        ');
  print('═══════════════════════════════════════════════════════\n');

  final headers = {
    'apikey': SupabaseConfig.anonKey,
    'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
  };

  // 1. Check REST API on core tables
  final tables = ['posts', 'profiles', 'broadcasts', 'app_updates', 'role_requests', 'device_tokens'];
  for (final t in tables) {
    try {
      final res = await http.get(
        Uri.parse('${SupabaseConfig.url}/rest/v1/$t?select=count',),
        headers: {...headers, 'Range-Unit': 'items', 'Prefer': 'count=exact'},
      ).timeout(const Duration(seconds: 5));
      final count = res.headers['content-range'] ?? 'ok';
      print('✅ Table [$t]: Status ${res.statusCode} (Range: $count)');
    } catch (e) {
      print('❌ Table [$t]: Error $e');
    }
  }

  // 2. Check Edge Functions preflight (OPTIONS) & Auth
  final functions = [
    'account-credentials',
    'admin-actions',
    'delete-post',
    'delete-user',
    'review-role-request',
    'send-push',
    'verify-admin',
  ];

  print('\n--- Edge Functions Health Check ---');
  for (final fn in functions) {
    try {
      final fnUrl = '${SupabaseConfig.url}/functions/v1/$fn';
      final client = http.Client();
      final req = http.Request('OPTIONS', Uri.parse(fnUrl))
        ..headers.addAll({
          'Origin': 'https://studenthub-admin-panel.vercel.app',
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Headers': 'content-type,x-push-secret',
        });
      final streamed = await client.send(req).timeout(const Duration(seconds: 5));
      final res = await http.Response.fromStream(streamed);
      
      final allowOrigin = res.headers['access-control-allow-origin'] ?? 'none';
      if (res.statusCode >= 200 && res.statusCode < 300) {
        print('✅ Function [$fn]: Status ${res.statusCode} (CORS Origin: $allowOrigin)');
      } else {
        print('⚠️ Function [$fn]: Status ${res.statusCode}');
      }
    } catch (e) {
      print('❌ Function [$fn]: Error $e');
    }
  }

  print('\n═══════════════════════════════════════════════════════');
  print('           ALL SYSTEMS HEALTH CHECK COMPLETE           ');
  print('═══════════════════════════════════════════════════════');
}
