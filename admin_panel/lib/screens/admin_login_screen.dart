import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../theme/admin_theme.dart';
import '../layouts/responsive_admin_shell.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _adminIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _adminIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Verifies the admin email + password against the server (bcrypt hash in
  /// `profile_credentials` + admin role check). No credentials exist in this
  /// codebase; the panel only receives an ok/user_id from the server.
  Future<void> _login() async {
    final email = _adminIdController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both Admin Email and Password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await http
          .post(
            Uri.parse(SupabaseConfig.verifyAdminFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              'apikey': SupabaseConfig.anonKey,
              'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
              if (SupabaseConfig.pushSecret.isNotEmpty)
                'X-Push-Secret': SupabaseConfig.pushSecret,
            },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ResponsiveAdminShell(
                adminUserId: decoded['user_id']?.toString() ?? '',
                adminName: decoded['name']?.toString() ?? 'Admin',
              ),
            ),
          );
        }
        return;
      }

      String message = 'Invalid Admin Email or Password. Please check credentials.';
      if (res.statusCode == 401) {
        message = 'Wrong password. Please try again.';
      } else if (res.statusCode == 403) {
        message = 'This account does not have admin access.';
      } else if (res.statusCode == 404) {
        message = 'Account not found. Please check the email.';
      } else if (res.statusCode == 401 || res.statusCode == 500) {
        message = 'Admin service unavailable (${res.statusCode}). Try again later.';
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = message;
        });
      }
    } catch (e) {
      debugPrint('Admin login error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Cannot reach the admin service. Check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.bgDark,
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AdminTheme.surfaceDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AdminTheme.borderDark),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0030B0).withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  children: const [
                    TextSpan(
                      text: 'Student',
                      style: TextStyle(fontWeight: FontWeight.w400),
                    ),
                    TextSpan(
                      text: 'Hub',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    TextSpan(
                      text: ' Admin',
                      style: TextStyle(fontWeight: FontWeight.w300, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Control Center Login',
                style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 28),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminTheme.statusDanger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminTheme.statusDanger.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(color: AdminTheme.statusDanger, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _adminIdController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Admin Email',
                  hintText: 'admin@example.com',
                  labelStyle: GoogleFonts.inter(color: AdminTheme.textMuted),
                  hintStyle: GoogleFonts.inter(color: AdminTheme.textMuted.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.badge_outlined, color: AdminTheme.textMuted),
                  filled: true,
                  fillColor: AdminTheme.surfaceCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: GoogleFonts.inter(color: AdminTheme.textMuted),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AdminTheme.textMuted),
                  filled: true,
                  fillColor: AdminTheme.surfaceCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text(
                          'Sign In to Dashboard',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}