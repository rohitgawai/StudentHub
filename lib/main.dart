import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/user_model.dart';

import 'services/mock_data_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/home_feed_screen.dart';
import 'screens/events_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'widgets/non_coder_config_editor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

  final List<Widget> screens = const [
    HomeFeedScreen(),
    EventsScreen(),
    ExploreScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cfg.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cfg.appName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  cfg.collegeShortCode,
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Interactive Role Simulator Pill (Allows user to test all 4 roles instantly)
          PopupMenuButton<UserRole>(
            tooltip: 'Switch Active View Role',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: cfg.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cfg.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getRoleIcon(dataService.activeRole),
                    size: 14,
                    color: cfg.primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dataService.activeRole.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: cfg.primaryColor,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
            ),
            onSelected: (UserRole role) {
              dataService.switchActiveRole(role);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Switched view perspective to ${role.displayName}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: UserRole.student,
                child: Row(
                  children: [
                    Icon(Icons.school, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('View as Student'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: UserRole.eventHost,
                child: Row(
                  children: [
                    Icon(Icons.event, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('View as Event Host'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: UserRole.faculty,
                child: Row(
                  children: [
                    Icon(Icons.menu_book, size: 18, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('View as Faculty'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: UserRole.admin,
                child: Row(
                  children: [
                    Icon(Icons.verified_user, size: 18, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('View as Admin'),
                  ],
                ),
              ),
            ],
          ),

          // Non-Coder Config Manager Button
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Non-Coder Config Manager',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const NonCoderConfigEditor()),
              );
            },
          ),

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
          const SizedBox(width: 4),
        ],
      ),

      // Body Navigation Screen
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),

      // Bottom Navigation Bar (PRD Section 8: Home, Events, Explore, Profile)
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

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Icons.school;
      case UserRole.eventHost:
        return Icons.event;
      case UserRole.faculty:
        return Icons.menu_book;
      case UserRole.admin:
        return Icons.verified_user;
    }
  }
}
