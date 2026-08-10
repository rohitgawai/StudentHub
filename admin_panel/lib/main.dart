import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'theme/admin_theme.dart';
import 'services/admin_supabase_service.dart';
import 'screens/admin_login_screen.dart';
import 'layouts/responsive_admin_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    final session = Supabase.instance.client.auth.currentSession;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminSupabaseService()),
      ],
      child: MaterialApp(
        title: 'StudentHub Admin Control Center',
        debugShowCheckedModeBanner: false,
        theme: AdminTheme.darkTheme,
        home: session != null ? const ResponsiveAdminShell() : const AdminLoginScreen(),
      ),
    );
  }
}
