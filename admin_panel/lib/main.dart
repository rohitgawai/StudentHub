import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'theme/admin_theme.dart';
import 'services/admin_supabase_service.dart';
import 'screens/admin_login_screen.dart';

/// Admin access is verified server-side on every login (see verify-admin edge
/// function). No credentials or auth flags are stored on the device — every
/// launch requires a fresh login.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const StudentHubAdminApp());
}

class StudentHubAdminApp extends StatelessWidget {
  const StudentHubAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminSupabaseService()),
      ],
      child: MaterialApp(
        title: 'StudentHub Admin Control Center',
        debugShowCheckedModeBanner: false,
        theme: AdminTheme.darkTheme,
        home: const AdminLoginScreen(),
      ),
    );
  }
}