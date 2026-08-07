import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/mock_data_service.dart';
import 'services/local_store_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_feed_screen.dart';
import 'screens/events_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStoreService.instance.warmUp();
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  } catch (_) {
    // Backend unavailable (offline / not set up): the app continues with
    // the in-memory mock dataset.
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => MockDataService(),
      child: const StudentHubApp(),
    ),
  );
}

class StudentHubApp extends StatelessWidget {
  const StudentHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MockDataService>(
      builder: (context, dataService, child) {
        if (dataService.isLoading) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MaterialApp(
          title: dataService.config.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(dataService.config),
          darkTheme: AppTheme.darkTheme(dataService.config),
          themeMode: ThemeMode.light,
          home: const MainNavigationContainer(),
        );
      },
    );
  }
}

class MainNavigationContainer extends StatefulWidget {
  const MainNavigationContainer({super.key});

  @override
  State<MainNavigationContainer> createState() => _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  int currentIndex = 0;
  bool isAuthenticated = true;
  bool showSplash = true;

  final List<Widget> screens = const [
    HomeFeedScreen(),
    EventsScreen(),
    ExploreScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    if (showSplash) {
      return SplashScreen(
        onGetStarted: () => setState(() => showSplash = false),
      );
    }

    if (!isAuthenticated) {
      return AuthScreen(
        onLoginComplete: () => setState(() => isAuthenticated = true),
      );
    }

    final dataService = Provider.of<MockDataService>(context);
    final cfg = dataService.config;
    final unreadNotifs = dataService.notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cfg.primaryColor, cfg.primaryColor.withBlue(220)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cfg.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.school_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cfg.appName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: cfg.primaryColor,
                  ),
                ),
                Text(
                  cfg.collegeShortCode,
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Notification Bell with Badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const NotificationsScreen()),
                  );
                },
              ),
              if (unreadNotifs > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$unreadNotifs',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),

      // Body Navigation Screen
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),

      // Bottom Navigation Bar (Home, Events, Explore, Profile)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (idx) => setState(() => currentIndex = idx),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.feed_outlined),
            activeIcon: Icon(Icons.feed),
            label: 'Home Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
