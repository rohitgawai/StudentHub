import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';
import '../layouts/responsive_admin_shell.dart';

class DashboardScreen extends StatelessWidget {
  final Function(AdminTab) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<AdminSupabaseService>(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final isMobile = width < 600;

    final pendingRoles = service.roleRequests.where((r) => r.status == 'pending').length;
    final pendingReports = service.reportedPosts.where((r) => r.status == 'pending').length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Welcome Card
          Container(
            padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
            decoration: BoxDecoration(
              gradient: AdminTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AdminTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back, Admin 👋',
                        style: GoogleFonts.outfit(
                          fontSize: isDesktop ? 26 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Manage your student community, approve role requests, and broadcast notices effortlessly.',
                        style: GoogleFonts.inter(
                          fontSize: isDesktop ? 14 : 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AdminTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => onNavigate(AdminTab.broadcast),
                    icon: const Icon(Icons.campaign_rounded),
                    label: Text(
                      'New Announcement',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // KPI Stats Grid
          GridView.count(
            crossAxisCount: isDesktop ? 4 : (isMobile ? 1 : 2),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: isDesktop ? 1.6 : (isMobile ? 2.5 : 1.4),
            children: [
              _buildKpiCard(
                title: 'Live Online Students',
                value: '${service.onlineUsers.length}',
                subtitle: 'Active app sessions right now',
                icon: Icons.sensors_rounded,
                color: AdminTheme.statusOnline,
                onTap: () => onNavigate(AdminTab.onlineUsers),
              ),
              _buildKpiCard(
                title: 'Total Students',
                value: '${service.allUsers.length}',
                subtitle: 'Registered accounts',
                icon: Icons.people_alt_rounded,
                color: AdminTheme.statusVerified,
                onTap: () => onNavigate(AdminTab.userDirectory),
              ),
              _buildKpiCard(
                title: 'Role Applications',
                value: '$pendingRoles',
                subtitle: 'Pending approval (CR/Leads)',
                icon: Icons.verified_user_rounded,
                color: AdminTheme.statusPending,
                onTap: () => onNavigate(AdminTab.roleRequests),
              ),
              _buildKpiCard(
                title: 'Flagged Posts',
                value: '$pendingReports',
                subtitle: 'Reports awaiting moderation',
                icon: Icons.gavel_rounded,
                color: AdminTheme.statusDanger,
                onTap: () => onNavigate(AdminTab.contentModeration),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Section Header
          Text(
            'Quick Action Shortcuts',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildShortcutButton(
                icon: Icons.badge_rounded,
                label: 'Check Student Identity',
                color: AdminTheme.accentCyan,
                onTap: () => onNavigate(AdminTab.studentLookup),
              ),
              _buildShortcutButton(
                icon: Icons.verified_user_rounded,
                label: 'Approve Role Requests',
                color: AdminTheme.statusPending,
                onTap: () => onNavigate(AdminTab.roleRequests),
              ),
              _buildShortcutButton(
                icon: Icons.campaign_rounded,
                label: 'Send Push Alert',
                color: AdminTheme.primary,
                onTap: () => onNavigate(AdminTab.broadcast),
              ),
              _buildShortcutButton(
                icon: Icons.gavel_rounded,
                label: 'Moderate Spam Posts',
                color: AdminTheme.statusDanger,
                onTap: () => onNavigate(AdminTab.contentModeration),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdminTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminTheme.borderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminTheme.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                ],
              ),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AdminTheme.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AdminTheme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminTheme.borderDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
