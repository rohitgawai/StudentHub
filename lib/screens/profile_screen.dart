import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/role_request_model.dart';
import '../services/mock_data_service.dart';
import '../widgets/post_card.dart';
import '../widgets/role_request_modal.dart';
import '../widgets/profile_avatar_zoom_dialog.dart';
import '../widgets/edit_profile_modal.dart';
import '../widgets/app_image.dart';
import 'dashboards/admin_dashboard_screen.dart';
import 'role_application_status_screen.dart';
import 'dashboards/faculty_dashboard_screen.dart';
import '../services/update_service.dart';
import 'dashboards/event_host_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    tabController.removeListener(_onTabChanged);
    tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<MockDataService>();
    final user = context.select((MockDataService s) => s.currentUser);
    final cfg = context.select((MockDataService s) => s.config);
    final activeRole = context.select((MockDataService s) => s.activeRole);
    final posts = context.select((MockDataService s) => s.posts);
    final roleRequests = context.select((MockDataService s) => s.roleRequests);
    final notifications = context.select(
      (MockDataService s) => s.notifications,
    );

    final savedPosts = posts
        .where((p) => user.savedPostIds.contains(p.id))
        .toList();
    final registeredEvents = posts
        .where((p) => user.registeredEventIds.contains(p.id))
        .toList();
    final pendingApplications = roleRequests
        .where((r) => r.userId == user.id && r.status == RoleRequestStatus.pending)
        .toList();
    final pendingApplication =
        pendingApplications.isEmpty ? null : pendingApplications.first;

    final allowedSwitcherRoles = user.roles
        .where((r) => r != UserRole.admin)
        .toList();
    final bool canSwitchRoles = allowedSwitcherRoles.length > 1;

    final bool hasHostRole = user.hasRole(UserRole.eventHost);
    final bool hasFacultyRole = user.hasRole(UserRole.faculty);
    final bool canApplyForRoles = !hasHostRole && !hasFacultyRole;

    final bool showRoleExpiredNotice = notifications.any(
      (n) => n.title.contains('Access Expired'),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Profile Options',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            surfaceTintColor: Colors.transparent,
            onSelected: (val) {
              if (val == 'theme') {
                _showThemeDialog(context, dataService);
              } else if (val == 'edit') {
                showDialog(
                  context: context,
                  builder: (ctx) => const EditProfileModal(),
                );
              } else if (val == 'feed_scope') {
                _showFeedScopeDialog(context, dataService, user.year);
              } else if (val == 'reset_password') {
                _showResetPasswordDialog(context, dataService, user.email);
              } else if (val == 'check_updates') {
                UpdateService.instance.checkForUpdate(context, silent: false);
              } else if (val == 'logout') {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Log Out'),
                    content: const Text('Are you sure you want to log out of StudentHub?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          dataService.logout();
                        },
                        child: const Text('Log Out', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (ctx) {
              final isHostOrFaculty =
                  hasHostRole || hasFacultyRole || user.hasRole(UserRole.admin);
              return [
                PopupMenuItem(
                  value: 'theme',
                  child: Row(
                    children: [
                      Icon(Icons.palette_outlined, size: 18, color: cfg.primaryColor),
                      const SizedBox(width: 10),
                      const Text(
                        'Theme & Appearance',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Edit Profile Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isHostOrFaculty) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'feed_scope',
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Feed Scope',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                dataService.showAllYearsFeed
                                    ? 'All Academic Years'
                                    : 'My Year (${user.year.isNotEmpty ? user.year : "Default"})',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'reset_password',
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_reset_rounded,
                        size: 18,
                        color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Reset Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'check_updates',
                  child: Row(
                    children: [
                      Icon(
                        Icons.system_update_rounded,
                        size: 18,
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0038D8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Check for Updates (v${UpdateService.currentVersionName})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: const [
                      Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await dataService.refreshUserProfile();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Floating Profile Header Card
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Upper Active Perspective Switcher (Clean, Simple Dynamic Text)
                    if (canSwitchRoles) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 16,
                              color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Active Perspective: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade700,
                              ),
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<UserRole>(
                                value:
                                    allowedSwitcherRoles.contains(activeRole)
                                    ? activeRole
                                    : allowedSwitcherRoles.first,
                                isDense: true,
                                borderRadius: BorderRadius.circular(16),
                                elevation: 4,
                                dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                                menuMaxHeight: 220,
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade700,
                                ),
                                onChanged: (UserRole? newRole) {
                                  if (newRole != null) {
                                    dataService.switchActiveRole(newRole);
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Switched view perspective to ${newRole.displayName}',
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                },
                                items: allowedSwitcherRoles.map((role) {
                                  final isCurrent = role == activeRole;
                                  return DropdownMenuItem<UserRole>(
                                    value: role,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          role.displayName,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: isCurrent
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isCurrent
                                                ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF312E81))
                                                : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                          ),
                                        ),
                                        if (isCurrent) ...[
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.check,
                                            size: 14,
                                            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF312E81),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Centered Profile Avatar
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => ProfileAvatarZoomDialog(
                            avatarUrl: user.avatarUrl,
                          ),
                        );
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: cfg.primaryColor.withValues(alpha: 0.12),
                            backgroundImage: resolveImageProvider(
                              user.avatarUrl,
                            ),
                            child: user.avatarUrl.isEmpty
                                ? Text(
                                    user.name.isNotEmpty
                                        ? user.name.substring(0, 1).toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: cfg.primaryColor,
                                    ),
                                  )
                                : null,
                          ),
                          if (user.isVerified)
                            Positioned(
                              bottom: 0,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF121212) : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified,
                                  size: 22,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Centered User Name
                    Text(
                      user.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // MIT Unique ID
                    Text(
                      'MIT Unique ID: ${user.studentOrEmployeeId}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Department & Year
                    Text(
                      '${user.department} • ${user.year}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF60A5FA) : cfg.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    if (user.mobileNumber.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: isDark ? const Color(0xFF71717A) : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user.mobileNumber,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Role Expiration Warning Notice if applicable
                    if (showRoleExpiredNotice) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '⚠️ Your temporary role has expired! You can re-apply below.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Apply for Role Button
                    if (cfg.allowRoleSelfApplication && canApplyForRoles) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (pendingApplication != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (c) => RoleApplicationStatusScreen(
                                    application: pendingApplication,
                                  ),
                                ),
                              );
                            } else {
                              showDialog(
                                context: context,
                                builder: (ctx) => const RoleRequestModal(),
                              );
                            }
                          },
                          icon: Icon(
                            pendingApplication != null
                                ? Icons.hourglass_top
                                : Icons.add_moderator,
                            size: 16,
                          ),
                          label: Text(
                            pendingApplication != null
                                ? 'Application Under Review'
                                : showRoleExpiredNotice
                                    ? 'Re-Apply for Event Host / Faculty Role'
                                    : 'Apply for Event Host / Faculty Role',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Role Dashboards shortcut: only for the ACTIVE role view.
                    if (activeRole != UserRole.student) ...[
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          if (activeRole == UserRole.admin)
                            Material(
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) => const AdminDashboardScreen(),
                                  ),
                                ),
                                child: Ink(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF581C87), Color(0xFF7E22CE)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF7E22CE).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Admin Control Panel',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (activeRole == UserRole.faculty)
                            Material(
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) => const FacultyDashboardScreen(),
                                  ),
                                ),
                                child: Ink(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF312E81).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.menu_book, color: Colors.white, size: 20),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Faculty Dashboard',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.insights, color: Colors.white70, size: 18),
                                      SizedBox(width: 6),
                                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (activeRole == UserRole.eventHost)
                            Material(
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) => const EventHostDashboardScreen(),
                                  ),
                                ),
                                child: Ink(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF312E81).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.event_available, color: Colors.white, size: 20),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Host Dashboard',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.insights, color: Colors.white70, size: 18),
                                      SizedBox(width: 6),
                                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Tabs: Saved Posts & Registered Events
          SliverPersistentHeader(
            pinned: true,
            delegate: _ProfileTabBarDelegate(
              tabBar: TabBar(
                controller: tabController,
                labelColor: cfg.primaryColor,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: cfg.primaryColor,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.bookmark_outline, size: 18),
                    text: 'Saved (${savedPosts.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    text: 'Registered (${registeredEvents.length})',
                  ),
                ],
              ),
            ),
          ),

          if (tabController.index == 0)
            _buildListSliver(
              savedPosts,
              'Tap the bookmark icon on any feed post to save it for quick access later.',
              cfg: cfg,
              isSavedForAll: true,
              dataService: dataService,
            )
          else
            _buildListSliver(
              registeredEvents,
              'You haven\'t registered for any upcoming campus events yet.',
              cfg: cfg,
              isRegisteredForAll: true,
              dataService: dataService,
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    ),
  );
}

  Widget _buildListSliver(
    List<PostModel> posts,
    String emptyMsg, {
    required AppConfig cfg,
    required MockDataService dataService,
    bool isSavedForAll = false,
    bool isRegisteredForAll = false,
  }) {
    if (posts.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cfg.primaryColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cfg.primaryColor.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSavedForAll ? Icons.bookmark_border : Icons.event_note,
                size: 48,
                color: cfg.primaryColor.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                isSavedForAll ? 'No Saved Posts' : 'No Registered Events',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptyMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SliverList.builder(
      itemCount: posts.length,
      itemBuilder: (ctx, idx) {
        final post = posts[idx];
        return PostCard(
          key: ValueKey(post.id),
          post: post,
          config: dataService.config,
          isSaved: dataService.currentUser.savedPostIds.contains(post.id),
          isRegistered: dataService.currentUser.registeredEventIds.contains(post.id),
          isCongratulated: dataService.currentUser.congratulatedPostIds.contains(post.id),
          isLiked: dataService.currentUser.likedPostIds.contains(post.id),
          currentUserId: dataService.currentUser.id,
          onToggleSave: () => dataService.toggleSavePost(post.id),
          onToggleLike: () => dataService.toggleLikePost(post.id),
        );
      },
    );
  }

  void _showResetPasswordDialog(
    BuildContext context,
    MockDataService dataService,
    String email,
  ) {
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();
    String errorText = '';
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final accent = isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA);

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: accent, size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Reset Password',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account: $email',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reset is only allowed from the device where the password was originally set.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF71717A) : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  enabled: !isResetting,
                  decoration: InputDecoration(
                    labelText: 'New Password (min 6 characters)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  enabled: !isResetting,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (errorText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isResetting ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isResetting
                    ? null
                    : () async {
                        final newPassword = newPasswordController.text;
                        if (newPassword.length < 6) {
                          setDialogState(
                            () => errorText =
                                'Password must be at least 6 characters.',
                          );
                          return;
                        }
                        if (newPassword != confirmController.text) {
                          setDialogState(
                            () => errorText = 'Passwords do not match.',
                          );
                          return;
                        }
                        setDialogState(() {
                          isResetting = true;
                          errorText = '';
                        });
                        try {
                          await dataService.resetPassword(
                            email: email,
                            password: newPassword,
                          );
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '✅ Password reset successfully! '
                                  'You can now log in with your new password.',
                                ),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 4),
                              ),
                            );
                        } catch (e) {
                          setDialogState(() {
                            isResetting = false;
                            errorText = e.toString();
                          });
                        }
                      },
                child: isResetting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Reset Password'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFeedScopeDialog(
    BuildContext context,
    MockDataService dataService,
    String userYear,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final showAll = dataService.showAllYearsFeed;
            final effectiveYear =
                userYear.trim().isNotEmpty ? userYear : 'My Year';

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.tune_rounded, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF312E81), size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Feed Scope',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'As a creator/faculty, choose which posts appear in your campus feed:',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      dataService.setShowAllYearsFeed(false);
                      setDialogState(() {});
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Feed filtered to $effectiveYear only.'),
                          backgroundColor: const Color(0xFF312E81),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: !showAll
                            ? const Color(0xFF312E81).withValues(alpha: isDark ? 0.25 : 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !showAll
                              ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF312E81))
                              : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                          width: !showAll ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            !showAll
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: !showAll
                                ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF312E81))
                                : Colors.grey.shade500,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$effectiveYear (Default)',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: !showAll
                                        ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF312E81))
                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Only view posts targeted to your year and all years',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      dataService.setShowAllYearsFeed(true);
                      setDialogState(() {});
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Feed set to All Academic Years.'),
                          backgroundColor: Color(0xFF312E81),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: showAll
                            ? const Color(0xFF312E81).withValues(alpha: isDark ? 0.25 : 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: showAll
                              ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF312E81))
                              : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                          width: showAll ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            showAll
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: showAll
                                ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF312E81))
                                : Colors.grey.shade500,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'All Academic Years',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: showAll
                                        ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF312E81))
                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'View posts across 1st, 2nd, 3rd, and Final years',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showThemeDialog(BuildContext context, MockDataService dataService) {
    final currentMode = dataService.themeMode;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Theme & Appearance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose your preferred visual theme for StudentHub.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 18),
                _themeOptionTile(
                  ctx,
                  dataService,
                  title: 'System Default',
                  subtitle: 'Automatically adapts to your device theme',
                  icon: Icons.brightness_auto_rounded,
                  mode: ThemeMode.system,
                  isSelected: currentMode == ThemeMode.system,
                ),
                const SizedBox(height: 8),
                _themeOptionTile(
                  ctx,
                  dataService,
                  title: 'Light Mode',
                  subtitle: 'Always bright and clean',
                  icon: Icons.light_mode_rounded,
                  mode: ThemeMode.light,
                  isSelected: currentMode == ThemeMode.light,
                ),
                const SizedBox(height: 8),
                _themeOptionTile(
                  ctx,
                  dataService,
                  title: 'Dark Mode',
                  subtitle: 'Comfortable on eyes in dark environments',
                  icon: Icons.dark_mode_rounded,
                  mode: ThemeMode.dark,
                  isSelected: currentMode == ThemeMode.dark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _themeOptionTile(
    BuildContext ctx,
    MockDataService dataService, {
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
    required bool isSelected,
  }) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final primary = dataService.config.primaryColor;
    return InkWell(
      onTap: () {
        dataService.setThemeMode(mode);
        Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: isDark ? 0.2 : 0.08)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primary
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? primary.withValues(alpha: 0.15)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? primary
                    : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? primary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: primary, size: 22)
            else
              Icon(Icons.circle_outlined,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  size: 22),
          ],
        ),
      ),
    );
  }
}

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  _ProfileTabBarDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 2 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileTabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar;
  }
}
