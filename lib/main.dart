import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'models/post_model.dart';
import 'models/user_model.dart';
import 'services/mock_data_service.dart';
import 'services/local_store_service.dart';
import 'services/push_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/home_feed_screen.dart';
import 'screens/events_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'widgets/create_post_modal.dart';
import 'widgets/create_event_modal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fast unawaited local warm-up so runApp() starts on frame 1 immediately.
  unawaited(LocalStoreService.instance.warmUp());
  final dataService = MockDataService();
  runApp(
    ChangeNotifierProvider.value(
      value: dataService,
      child: const StudentHubApp(),
    ),
  );
  // Background backend init delayed post-frame so app startup renders instantly
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.delayed(const Duration(seconds: 2), () {
      _initBackend(dataService);
    });
  });
}

Future<void> _initBackend(MockDataService dataService) async {
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    // Backend unavailable: continue with local/mock dataset.
    debugPrint('StudentHub: Supabase init skipped: $e');
    return;
  }
  await dataService.syncNow();
  // OS-level push: registers the device token and listens for new-post pushes.
  // Safe to run even when Firebase config is present but the backend is down.
  try {
    await PushService.instance.init(dataService: dataService);
  } catch (e) {
    debugPrint('StudentHub: push init failed: $e');
  }
}

class StudentHubApp extends StatelessWidget {
  const StudentHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final cfg = context.select((MockDataService s) => s.config);
    return MaterialApp(
      title: cfg.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(cfg),
      darkTheme: AppTheme.darkTheme(cfg),
      themeMode: ThemeMode.light,
      home: const MainNavigationContainer(),
    );
  }
}

class MainNavigationContainer extends StatefulWidget {
  const MainNavigationContainer({super.key});

  @override
  State<MainNavigationContainer> createState() =>
      _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  int currentIndex = 0;
  bool isAuthenticated = true;

  final List<Widget> screens = const [
    HomeFeedScreen(),
    EventsScreen(),
    DiscoverScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    PushService.instance.openCategory.addListener(_handlePushTap);
  }

  @override
  void dispose() {
    PushService.instance.openCategory.removeListener(_handlePushTap);
    super.dispose();
  }

  void _handlePushTap() {
    final category = PushService.instance.openCategory.value;
    final targetIndex = category == PostCategory.event ? 1 : 0;
    if (currentIndex != targetIndex) {
      setState(() => currentIndex = targetIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isAuthenticated) {
      return AuthScreen(
        onLoginComplete: () => setState(() => isAuthenticated = true),
      );
    }

    final cfg = context.select((MockDataService s) => s.config);
    final unreadNotifs = context.select(
      (MockDataService s) => s.notifications.where((n) => !n.isRead).length,
    );
    final user = context.select((MockDataService s) => s.currentUser);
    final canCreate =
        user.hasRole(UserRole.eventHost) ||
        user.hasRole(UserRole.admin) ||
        user.hasRole(UserRole.faculty);

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
              child: const Icon(
                Icons.school_rounded,
                size: 20,
                color: Colors.white,
              ),
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
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
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
                    MaterialPageRoute(
                      builder: (c) => const NotificationsScreen(),
                    ),
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
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
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
      body: IndexedStack(index: currentIndex, children: screens),

      // Global create FAB (Event Host / Faculty / Admin) — one entry point
      // for every publish action. Shown only on the Home and Events tabs.
      floatingActionButton: canCreate && (currentIndex == 0 || currentIndex == 1)
          ? FloatingActionButton.extended(
              backgroundColor: cfg.primaryColor,
              foregroundColor: Colors.white,
              onPressed: () => _showCreateOptionsSheet(context, dataService: context.read<MockDataService>()),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Create',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,

      // Bottom Navigation with active-tab pill (Google Photos / Spotify style)
      bottomNavigationBar: _PillNavigationBar(
        currentIndex: currentIndex,
        activeColor: cfg.primaryColor,
        onTap: (idx) => setState(() => currentIndex = idx),
      ),
    );
  }

  void _showCreateOptionsSheet(
    BuildContext context, {
    required MockDataService dataService,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'What would you like to publish?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: const Icon(Icons.event, color: Colors.orange),
                  ),
                  title: const Text('Create Event'),
                  subtitle: const Text(
                    'Hackathons, workshops, competitions with registration',
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    showDialog(
                      context: context,
                      builder: (c) => const CreateEventModal(),
                    );
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.announcement, color: Colors.blue),
                  ),
                  title: const Text('Create Announcement'),
                  subtitle: const Text(
                    'Post academic updates, notices, or achievements',
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    showDialog(
                      context: context,
                      builder: (c) => const CreatePostModal(),
                    );
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.green,
                    ),
                  ),
                  title: const Text('Upload Gallery'),
                  subtitle: const Text(
                    'Publish campus event photos and highlights',
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    showDialog(
                      context: context,
                      builder: (c) => const CreatePostModal(
                        initialCategory: PostCategory.gallery,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Bottom navigation where the active tab sits inside an animated pill,
/// instead of a thin indicator line.
class _PillNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Color activeColor;
  final ValueChanged<int> onTap;

  const _PillNavigationBar({
    required this.currentIndex,
    required this.activeColor,
    required this.onTap,
  });

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.feed_outlined, activeIcon: Icons.feed, label: 'Home'),
    _NavItem(
      icon: Icons.event_outlined,
      activeIcon: Icons.event,
      label: 'Events',
    ),
    _NavItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: 'Discover',
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final selected = index == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? activeColor.withValues(alpha: 0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            selected ? item.activeIcon : item.icon,
                            key: ValueKey(selected),
                            size: 22,
                            color: selected
                                ? activeColor
                                : Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: selected
                                ? activeColor
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}