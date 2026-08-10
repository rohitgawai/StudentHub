import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/role_request_model.dart';
import '../services/mock_data_service.dart';
import '../widgets/role_badge.dart';
import '../widgets/post_card.dart';
import '../widgets/role_request_modal.dart';
import '../widgets/profile_avatar_zoom_dialog.dart';
import '../widgets/edit_profile_modal.dart';
import '../widgets/app_image.dart';
import 'dashboards/admin_dashboard_screen.dart';
import 'dashboards/faculty_dashboard_screen.dart';
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
    final myRoleRequests = roleRequests
        .where((r) => r.userId == user.id)
        .toList();

    // Filter approved roles for dropdown (excluding Admin)
    final allowedSwitcherRoles = user.roles
        .where((r) => r != UserRole.admin)
        .toList();
    final bool canSwitchRoles = allowedSwitcherRoles.length > 1;

    // Requirement 5: For Faculty role, filter out "Student" from assigned roles display
    final displayAssignedRoles = user.roles.where((r) {
      if (r == UserRole.admin) return false;
      if (user.hasRole(UserRole.faculty) && r == UserRole.student) return false;
      return true;
    }).toList();

    // Requirement 7: Apply for role button visibility & expiration logic.
    // Hidden whenever the user holds Event Host or Faculty (both are granted
    // via this flow): a temporary Host role hides it until it expires, after
    // which the role is removed and the button reappears; a confirmed Faculty
    // role hides it permanently.
    final bool hasHostRole = user.hasRole(UserRole.eventHost);
    final bool hasFacultyRole = user.hasRole(UserRole.faculty);
    final bool canApplyForRoles = !hasHostRole && !hasFacultyRole;

    // Check if host/faculty role expired notification is present
    final bool showRoleExpiredNotice = notifications.any(
      (n) => n.title.contains('Access Expired'),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile Details',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const EditProfileModal(),
              );
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Profile Header Card
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  Row(
                    children: [
                      // Requirement 3: Tap profile picture to zoom like Instagram with edit option
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
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundImage: resolveImageProvider(
                                user.avatarUrl,
                              ),
                              child: user.avatarUrl.isEmpty
                                  ? const Icon(Icons.person, size: 36)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.zoom_in,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (user.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified,
                                    size: 18,
                                    color: Colors.blue,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.studentOrEmployeeId,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${user.department} • ${user.year}',
                              style: TextStyle(
                                fontSize: 12,
                                color: cfg.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Requirement 4: Edit Details button over profile tab
                      IconButton(
                        icon: const Icon(Icons.edit_note, color: Colors.blue),
                        tooltip: 'Edit Profile Details',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => const EditProfileModal(),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Requirement 2 & 1: Active Perspective dropdown menu change (compact & bounded layout)
                  if (canSwitchRoles) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cfg.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cfg.primaryColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.swap_horiz,
                            size: 18,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Active Perspective: ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<UserRole>(
                                  value:
                                      allowedSwitcherRoles.contains(activeRole)
                                      ? activeRole
                                      : allowedSwitcherRoles.first,
                                  isDense: true,
                                  menuMaxHeight: 220,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 18,
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
                                    return DropdownMenuItem<UserRole>(
                                      value: role,
                                      child: RoleBadge(
                                        role: role,
                                        isCompact: true,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Requirement 5: Roles Badges Row (Student hidden when Faculty is active)
                  Row(
                    children: [
                      const Text(
                        'Assigned Roles: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: displayAssignedRoles
                              .map(
                                (r) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    RoleBadge(role: r, isCompact: true),
                                    if (user.isRoleExpiring(r))
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: _buildExpiryTag(
                                          user.getRoleExpiry(r)!,
                                        ),
                                      ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Requirement 7: Role Expiration Warning Notice if applicable
                  if (showRoleExpiredNotice) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
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

                  // Requirement 7: Apply for Role Button (Hidden while any elevated role is held; re-appears when it expires)
                  if (cfg.allowRoleSelfApplication && canApplyForRoles)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => const RoleRequestModal(),
                          );
                        },
                        icon: const Icon(Icons.add_moderator, size: 16),
                        label: Text(
                          showRoleExpiredNotice
                              ? 'Re-Apply for Event Host / Faculty Role'
                              : 'Apply for Event Host / Faculty Role',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Role Dashboards shortcut: only for the ACTIVE role view.
                  // A Student view never gets dashboard access, even when
                  // elevated roles are held.
                  if (activeRole != UserRole.student) ...[
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        if (activeRole == UserRole.admin)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF7B1FA2),
                                  side: const BorderSide(
                                    color: Color(0xFF7B1FA2),
                                    width: 1.5,
                                  ),
                                  backgroundColor: const Color(
                                    0xFF7B1FA2,
                                  ).withValues(alpha: 0.08),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) =>
                                        const AdminDashboardScreen(),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.admin_panel_settings,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Admin Control Panel',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (activeRole == UserRole.faculty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0369A1),
                                  side: const BorderSide(
                                    color: Color(0xFF0369A1),
                                    width: 1.5,
                                  ),
                                  backgroundColor: const Color(
                                    0xFF0369A1,
                                  ).withValues(alpha: 0.08),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) =>
                                        const FacultyDashboardScreen(),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.menu_book,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Faculty Dashboard',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (activeRole == UserRole.eventHost)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFC2410C),
                                  side: const BorderSide(
                                    color: Color(0xFFC2410C),
                                    width: 1.5,
                                  ),
                                  backgroundColor: const Color(
                                    0xFFC2410C,
                                  ).withValues(alpha: 0.08),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) =>
                                        const EventHostDashboardScreen(),
                                  ),
                                ),
                                icon: const Icon(Icons.event, size: 16),
                                label: const Text(
                                  'Host Dashboard',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],

                  // Role Requests Status Box
                  if (myRoleRequests.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Role Application Statuses:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ...myRoleRequests.map(
                            (req) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Text(
                                    '${req.requestedRole.displayName}: ',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  _buildStatusBadge(req.status),
                                  if (req.isLimitedAccess &&
                                      req.expiresAt != null) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '${req.termLabel} • till ${_formatDate(req.expiresAt!)}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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

          SliverToBoxAdapter(
            child: IndexedStack(
              index: tabController.index,
              children: [
                _buildList(
                  savedPosts,
                  'Tap the bookmark icon on any feed post to save it for quick access later.',
                  cfg: cfg,
                  userYear: user.year,
                  isSavedForAll: true,
                  dataService: dataService,
                ),
                _buildList(
                  registeredEvents,
                  'You haven\'t registered for any upcoming campus events yet.',
                  cfg: cfg,
                  userYear: user.year,
                  isRegisteredForAll: true,
                  dataService: dataService,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryTag(DateTime expiry) {
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    final isExpiringSoon = daysLeft <= 7;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: (isExpiringSoon ? Colors.orange : Colors.green).withValues(
          alpha: 0.15,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        daysLeft < 1
            ? 'Expires today'
            : 'Expires in $daysLeft day${daysLeft > 1 ? 's' : ''}',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: isExpiringSoon
              ? Colors.orange.shade900
              : Colors.green.shade800,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Widget _buildStatusBadge(RoleRequestStatus status) {
    Color color;
    String label;
    switch (status) {
      case RoleRequestStatus.pending:
        color = Colors.orange;
        label = 'Pending Review';
        break;
      case RoleRequestStatus.approved:
        color = Colors.green;
        label = 'Approved';
        break;
      case RoleRequestStatus.rejected:
        color = Colors.red;
        label = 'Rejected';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildList(
    List posts,
    String emptyMsg, {
    required AppConfig cfg,
    required String userYear,
    required MockDataService dataService,
    bool isSavedForAll = false,
    bool isRegisteredForAll = false,
  }) {
    if (posts.isEmpty) {
      return Container(
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
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      itemBuilder: (ctx, idx) {
        final post = posts[idx] as PostModel;
        return PostCard(
          post: post,
          config: cfg,
          isSaved:
              isSavedForAll ||
              dataService.currentUser.savedPostIds.contains(post.id),
          isRegistered:
              isRegisteredForAll ||
              dataService.currentUser.registeredEventIds.contains(post.id),
          isCongratulated: dataService.currentUser.congratulatedPostIds.contains(
            post.id,
          ),
          isLiked: dataService.currentUser.likedPostIds.contains(post.id),
          userYear: userYear,
          currentUserId: dataService.currentUser.id,
          onToggleSave: () {
            dataService.toggleSavePost(post.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved!'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          onToggleLike: () {
            dataService.toggleLikePost(post.id);
            final isLiked =
                dataService.currentUser.likedPostIds.contains(post.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isLiked ? '❤️ Liked!' : 'Removed like'),
                backgroundColor: isLiked
                    ? Colors.redAccent
                    : Colors.orange,
                duration: const Duration(seconds: 1),
              ),
            );
          },
        );
      },
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
