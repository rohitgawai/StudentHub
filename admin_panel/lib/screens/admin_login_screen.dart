import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  Future<void> _login() async {
    final adminId = _adminIdController.text.trim();
    final password = _passwordController.text.trim();

    if (adminId.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both Admin ID and Password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Dedicated Credentials Check
    if (adminId == 'rohitgawai' && password == 'mit@34') {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ResponsiveAdminShell()),
        );
      }
      return;
    }

    // Supabase Auth Fallback
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: adminId,
        password: password,
      );

      if (response.user != null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ResponsiveAdminShell()),
          );
        }
        return;
      }
    } catch (_) {}

    setState(() {
      _isLoading = false;
      _errorMessage = 'Invalid Admin ID or Password. Please check credentials.';
    });
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AdminTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, size: 36, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'StudentHub Admin',
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
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
                  labelText: 'Admin ID',
                  hintText: 'e.g. rohitgawai',
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
