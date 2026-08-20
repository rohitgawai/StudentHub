import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';
import '../services/admin_session.dart';
import '../screens/dashboard_screen.dart';
import '../screens/online_users_screen.dart';
import '../screens/role_requests_screen.dart';
import '../screens/student_lookup_screen.dart';
import '../screens/user_directory_screen.dart';
import '../screens/admins_screen.dart';
import '../screens/role_removals_screen.dart';
import '../screens/content_moderation_screen.dart';
import '../screens/broadcast_screen.dart';
import '../screens/admin_login_screen.dart';

enum AdminTab {
  dashboard,
  onlineUsers,
  roleRequests,
  studentLookup,
  userDirectory,
  admins,
  roleRemovals,
  contentModeration,
  broadcast,
}

class ResponsiveAdminShell extends StatefulWidget {
  const ResponsiveAdminShell({
    super.key,
    this.adminUserId = '',
    this.adminName = 'Admin',
  });

  /// Verified server-side by the verify-admin edge function during login.
  final String adminUserId;
  final String adminName;

  @override
  State<ResponsiveAdminShell> createState() => _ResponsiveAdminShellState();
}

class _ResponsiveAdminShellState extends State<ResponsiveAdminShell> {
  AdminTab _currentTab = AdminTab.dashboard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = Provider.of<AdminSupabaseService>(context, listen: false);
      service.adminUserId = widget.adminUserId;
      service.fetchUsers();
      service.fetchAdmins();
      service.fetchRoleRequests();
      service.fetchReportedContent();
    });
  }

  /// Returns to the login screen and clears the persisted 1-day session, so
  /// the next launch requires a fresh server-verified login.
  void _logout() {
    AdminSession.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }

  Widget _buildTabScreen() {
    switch (_currentTab) {
      case AdminTab.dashboard:
        return DashboardScreen(onNavigate: (tab) => setState(() => _currentTab = tab));
      case AdminTab.onlineUsers:
        return const OnlineUsersScreen();
      case AdminTab.roleRequests:
        return const RoleRequestsScreen();
      case AdminTab.studentLookup:
        return const StudentLookupScreen();
      case AdminTab.userDirectory:
        return const UserDirectoryScreen();
      case AdminTab.admins:
        return const AdminsScreen();
      case AdminTab.roleRemovals:
        return const RoleRemovalsScreen();
      case AdminTab.contentModeration:
        return const ContentModerationScreen();
      case AdminTab.broadcast:
        return const BroadcastScreen();
    }
  }

  String _getTabTitle(AdminTab tab) {
    switch (tab) {
      case AdminTab.dashboard:
        return 'Dashboard Overview';
      case AdminTab.onlineUsers:
        return 'Live Online Active Users';
      case AdminTab.roleRequests:
        return 'Student Role Applications';
      case AdminTab.studentLookup:
        return 'Student College Lookup';
      case AdminTab.userDirectory:
        return 'User & Privilege Directory';
      case AdminTab.admins:
        return 'Admin Accounts';
      case AdminTab.roleRemovals:
        return 'Role Removals Management';
      case AdminTab.contentModeration:
        return 'Content & Post Moderation';
      case AdminTab.broadcast:
        return 'Broadcast Announcement System';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final adminService = Provider.of<AdminSupabaseService>(context);

    return Scaffold(
      backgroundColor: AdminTheme.bgDark,
      drawer: isDesktop ? null : _buildDrawer(adminService),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(adminService),
          Expanded(
            child: Column(
              children: [
                _buildTopAppBar(isDesktop, adminService),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(
                      key: ValueKey(_currentTab),
                      child: _buildTabScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppBar(bool isDesktop, AdminSupabaseService service) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AdminTheme.surfaceDark,
        border: Border(bottom: BorderSide(color: AdminTheme.borderDark)),
      ),
      child: Row(
        children: [
          if (!isDesktop)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          Expanded(
            child: Text(
              _getTabTitle(_currentTab),
              style: GoogleFonts.outfit(
                fontSize: isDesktop ? 22 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          // Live Online Pill Counter
          InkWell(
            onTap: () => setState(() => _currentTab = AdminTab.onlineUsers),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AdminTheme.statusOnline.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AdminTheme.statusOnline.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AdminTheme.statusOnline,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${service.onlineUsers.length} Online',
                    style: GoogleFonts.inter(
                      color: AdminTheme.statusOnline,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AdminTheme.textMuted),
            tooltip: 'Refresh Data',
            onPressed: () {
              service.refreshOnlinePresence();
              service.fetchUsers();
              service.fetchAdmins();
              service.fetchRoleRequests();
              service.fetchReportedContent();
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AdminTheme.statusDanger),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(AdminSupabaseService service) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AdminTheme.surfaceDark,
        border: Border(right: BorderSide(color: AdminTheme.borderDark)),
      ),
      child: Column(
        children: [
          // Logo & Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                        children: const [
                          TextSpan(
                            text: 'Student',
                            style: TextStyle(fontWeight: FontWeight.w400, color: Colors.white),
                          ),
                          TextSpan(
                            text: 'Hub',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF60A5FA)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'ADMIN PANEL',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AdminTheme.accentCyan,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminTheme.borderDark),
          const SizedBox(height: 12),

          // Menu List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _sidebarNavItem(
                  AdminTab.dashboard,
                  Icons.dashboard_rounded,
                  'Dashboard Overview',
                ),
                _sidebarNavItem(
                  AdminTab.onlineUsers,
                  Icons.sensors_rounded,
                  'Live Online Users',
                  badgeCount: service.onlineUsers.length,
                  badgeColor: AdminTheme.statusOnline,
                ),
                _sidebarNavItem(
                  AdminTab.roleRequests,
                  Icons.verified_user_rounded,
                  'Role Applications',
                  badgeCount: service.roleRequests.where((r) => r.status == 'pending').length,
                  badgeColor: AdminTheme.statusPending,
                ),
                _sidebarNavItem(
                  AdminTab.studentLookup,
                  Icons.badge_rounded,
                  'Student Lookup',
                ),
                _sidebarNavItem(
                  AdminTab.userDirectory,
                  Icons.people_alt_rounded,
                  'User Directory',
                ),
                _sidebarNavItem(
                  AdminTab.admins,
                  Icons.admin_panel_settings_rounded,
                  'Admins',
                  badgeCount: service.admins.length,
                ),
                _sidebarNavItem(
                  AdminTab.roleRemovals,
                  Icons.remove_moderator_rounded,
                  'Role Removals',
                ),
                _sidebarNavItem(
                  AdminTab.contentModeration,
                  Icons.gavel_rounded,
                  'Content Moderation',
                  badgeCount: service.reportedPosts.where((r) => r.status == 'pending').length,
                  badgeColor: AdminTheme.statusDanger,
                ),
                _sidebarNavItem(
                  AdminTab.broadcast,
                  Icons.campaign_rounded,
                  'Broadcast Alert',
                ),
              ],
            ),
          ),

          // Admin Footer Profile Card
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminTheme.borderDark),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AdminTheme.primary,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.adminName.isEmpty ? 'Admin Control' : widget.adminName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        'Super Administrator',
                        style: GoogleFonts.inter(
                          color: AdminTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AdminTheme.statusDanger, size: 20),
                  tooltip: 'Logout',
                  onPressed: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarNavItem(
    AdminTab tab,
    IconData icon,
    String label, {
    int badgeCount = 0,
    Color badgeColor = AdminTheme.primary,
  }) {
    final isSelected = _currentTab == tab;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _currentTab = tab);
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? AdminTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
              border: Border.all(
                color: isSelected ? AdminTheme.primary.withValues(alpha: 0.4) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AdminTheme.primaryLight : AdminTheme.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : AdminTheme.textMuted,
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(AdminSupabaseService service) {
    return Drawer(
      backgroundColor: AdminTheme.surfaceDark,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AdminTheme.bgDark,
              border: Border(bottom: BorderSide(color: AdminTheme.borderDark)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                        children: const [
                          TextSpan(
                            text: 'Student',
                            style: TextStyle(fontWeight: FontWeight.w400, color: Colors.white),
                          ),
                          TextSpan(
                            text: 'Hub',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF60A5FA)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Admin Control Center',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _sidebarNavItem(AdminTab.dashboard, Icons.dashboard_rounded, 'Dashboard Overview'),
                _sidebarNavItem(AdminTab.onlineUsers, Icons.sensors_rounded, 'Live Online Users', badgeCount: service.onlineUsers.length),
                _sidebarNavItem(AdminTab.roleRequests, Icons.verified_user_rounded, 'Role Applications'),
                _sidebarNavItem(AdminTab.studentLookup, Icons.badge_rounded, 'Student Lookup'),
                _sidebarNavItem(AdminTab.userDirectory, Icons.people_alt_rounded, 'User Directory'),
                _sidebarNavItem(AdminTab.admins, Icons.admin_panel_settings_rounded, 'Admins', badgeCount: service.admins.length),
                _sidebarNavItem(AdminTab.roleRemovals, Icons.remove_moderator_rounded, 'Role Removals'),
                _sidebarNavItem(AdminTab.contentModeration, Icons.gavel_rounded, 'Content Moderation'),
                _sidebarNavItem(AdminTab.broadcast, Icons.campaign_rounded, 'Broadcast Alert'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
