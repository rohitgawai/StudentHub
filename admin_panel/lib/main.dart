import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'theme/admin_theme.dart';
import 'services/admin_supabase_service.dart';
import 'screens/admin_login_screen.dart';
import 'layouts/responsive_admin_shell.dart';

/// Persists the hardcoded-credential admin login across refreshes/relaunches.
/// Supabase-auth logins are covered by the SDK's own session storage.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final savedAdminAuth = prefs.getBool('admin_authenticated') ?? false;

  // initialize() is idempotent; Supabase.instance must NOT be touched first
  // (it asserts when uninitialized).
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    debugPrint('Supabase init note: $e');
  }

  runApp(StudentHubAdminApp(startAuthenticated: savedAdminAuth));
}

class StudentHubAdminApp extends StatelessWidget {
  const StudentHubAdminApp({super.key, this.startAuthenticated = false});

  final bool startAuthenticated;

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminSupabaseService()),
      ],
      child: MaterialApp(
        title: 'StudentHub Admin Control Center',
        debugShowCheckedModeBanner: false,
        theme: AdminTheme.darkTheme,
        home: startAuthenticated || session != null
            ? const ResponsiveAdminShell()
            : const AdminLoginScreen(),
      ),
    );
  }
}