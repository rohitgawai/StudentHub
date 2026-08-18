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
import 'screens/progressive_form_screen.dart';
import 'screens/home_feed_screen.dart';
import 'screens/events_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'widgets/create_post_modal.dart';
import 'widgets/create_event_modal.dart';
import 'widgets/create_gallery_modal.dart';
import 'widgets/post_detail_modal.dart';

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
      builder: (context, child) {
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.95,
          maxScaleFactor: 1.0,
          child: child ?? const SizedBox.shrink(),
        );
      },
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
  // Starts false: anonymous/seed auto-login is not allowed. The app opens
  // straight to the feed only after a real login or a restored session that
  // completed onboarding (see restoredCompletedSession below).
  bool isAuthenticated = false;

  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _eventsKey = GlobalKey();

  late final List<Widget> screens = [
    HomeFeedScreen(key: _homeKey),
    EventsScreen(key: _eventsKey),
    const DiscoverScreen(),
    const ProfileScreen(),
  ];

  void _handleBottomNavTap(int idx) {
    if (currentIndex == idx) {
      if (idx == 0) {
        (_homeKey.currentState as dynamic)?.scrollToTop();
      } else if (idx == 1) {
        (_eventsKey.currentState as dynamic)?.scrollToTop();
      }
    } else {
      setState(() => currentIndex = idx);
    }
  }

  @override
  void initState() {
    super.initState();
    PushService.instance.openCategory.addListener(_handlePushTap);
    PushService.instance.targetPostId.addListener(_handlePushTap);
  }

  @override
  void dispose() {
    PushService.instance.openCategory.removeListener(_handlePushTap);
    PushService.instance.targetPostId.removeListener(_handlePushTap);
    super.dispose();
  }

  void _handlePushTap() {
    final category = PushService.instance.openCategory.value;
    final postId = PushService.instance.targetPostId.value;
    final targetIndex = category == PostCategory.event ? 1 : 0;
    if (currentIndex != targetIndex) {
      setState(() => currentIndex = targetIndex);
    }
    if (postId != null && postId.isNotEmpty) {
      PushService.instance.targetPostId.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          PostDetailModal.show(context, postId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final user = dataService.currentUser;
    final isLoggedOut = dataService.isLoggedOut;

    if (isLoggedOut) {
      if (dataService.logoutReason != null) {
        final reason = dataService.logoutReason;
        dataService.logoutReason = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📱 $reason'),
                backgroundColor: Colors.orange.shade900,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        });
      }
      return AuthScreen(
        onLoginComplete: () {
          setState(() => isAuthenticated = true);
          unawaited(PushService.instance.rebindToken());
        },
      );
    }

    if (dataService.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!isAuthenticated && !dataService.restoredCompletedSession) {
      return AuthScreen(
        onLoginComplete: () {
          setState(() => isAuthenticated = true);
          unawaited(PushService.instance.rebindToken());
        },
      );
    }

    if (!user.hasCompletedProgressiveForm) {
      return ProgressiveFormScreen(
        onComplete: () {
          setState(() {});
        },
      );
    }

    final cfg = context.select((MockDataService s) => s.config);
    final unreadNotifs = context.select(
      (MockDataService s) => s.notifications.where((n) => !n.isRead).length,
    );
    final activeRole = context.select((MockDataService s) => s.activeRole);
    // Publishing is reserved for elevated roles: a pure Student view has no
    // Create button (switch roles in Profile to publish).
    final canCreate = activeRole != UserRole.student;

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
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    height: 1.15,
                    color: cfg.primaryColor,
                  ),
                ),
                Text(
                  cfg.collegeShortCode,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
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
        onTap: _handleBottomNavTap,
      ),
    );
  }

  void _showCreateOptionsSheet(
    BuildContext context, {
    required MockDataService dataService,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header with title and close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'What would you like to publish?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Share updates, organize campus events, or photos',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 1. Create Event & Workshop
                  _buildPublishOptionCard(
                    title: 'Event & Workshop',
                    subtitle: 'Host competitions, hackathons & sessions with registrations',
                    badgeGradient: const [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                    icon: Icons.celebration_rounded,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      showDialog(
                        context: context,
                        builder: (c) => const CreateEventModal(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // 2. Create Campus Post
                  _buildPublishOptionCard(
                    title: 'Campus Post',
                    subtitle: 'Post announcements, achievements, notes & academic updates',
                    badgeGradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    icon: Icons.campaign_rounded,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      showDialog(
                        context: context,
                        builder: (c) => const CreatePostModal(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // 3. Upload Photo Gallery
                  _buildPublishOptionCard(
                    title: 'Photo Gallery',
                    subtitle: 'Publish campus event highlights & photo albums',
                    badgeGradient: const [Color(0xFF10B981), Color(0xFF047857)],
                    icon: Icons.collections_rounded,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      showDialog(
                        context: context,
                        builder: (c) => const CreateGalleryModal(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPublishOptionCard({
    required String title,
    required String subtitle,
    required List<Color> badgeGradient,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: badgeGradient.first.withOpacity(0.08),
        highlightColor: badgeGradient.first.withOpacity(0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: Row(
            children: [
              // Vibrant Gradient Icon Badge
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: badgeGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: badgeGradient.first.withOpacity(0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 23),
              ),
              const SizedBox(width: 14),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF64748B),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Arrow action indicator
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
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