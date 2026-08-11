import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';
import '../models/admin_user_model.dart';

class RoleRemovalsScreen extends StatefulWidget {
  const RoleRemovalsScreen({super.key});

  @override
  State<RoleRemovalsScreen> createState() => _RoleRemovalsScreenState();
}

class _RoleRemovalsScreenState extends State<RoleRemovalsScreen> {
  String _search = '';

  String _formatRoleName(String roleKey) {
    switch (roleKey.toLowerCase()) {
      case 'host':
      case 'eventhost':
        return 'Host';
      case 'faculty':
        return 'Faculty';
      default:
        return roleKey[0].toUpperCase() + roleKey.substring(1);
    }
  }

  void _showRemoveRoleDialog(BuildContext context, AdminUserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Confirm Role Removal',
          style: GoogleFonts.outfit(color: AdminTheme.statusDanger, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revert ${user.fullName} (${user.email}) from ${_formatRoleName(user.role)} back to standard Student status?',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Text(
                '📢 A push & in-app notification will be sent to the user: "Your role has been removed, you can contact if you have any query." The user can re-apply for roles anytime.',
                style: GoogleFonts.inter(color: AdminTheme.primaryLight, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AdminTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.statusDanger),
            onPressed: () async {
              Navigator.pop(ctx);
              final service = Provider.of<AdminSupabaseService>(context, listen: false);
              final success = await service.removeUserRoleWithNotice(user.id, user.fullName);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Role removed and notification sent to ${user.fullName}.'
                          : 'Failed to remove role.',
                    ),
                    backgroundColor: success ? AdminTheme.statusOnline : AdminTheme.statusDanger,
                  ),
                );
              }
            },
            icon: const Icon(Icons.remove_moderator_rounded, color: Colors.white, size: 18),
            label: Text('Remove Role', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<AdminSupabaseService>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    // Filter users who currently hold special roles (Host or Faculty)
    final roleHolders = service.allUsers.where((u) {
      final r = u.role.toLowerCase();
      final hasHostInList = u.roles.contains('host') || u.roles.contains('eventhost') || u.roles.contains('event_host');
      final hasFacultyInList = u.roles.contains('faculty');
      final isRoleHolder = r == 'host' || r == 'eventhost' || r == 'faculty' || hasHostInList || hasFacultyInList;
      if (!isRoleHolder) return false;
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (u.studentId?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminTheme.statusDanger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.remove_moderator_rounded, color: AdminTheme.statusDanger, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Role Removals Management',
                      style: GoogleFonts.outfit(fontSize: isDesktop ? 20 : 18, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Revoke Host / Faculty privileges and revert users to standard Student status with instant notification.',
                      style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                'Active Holders: ${roleHolders.length}',
                style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            onChanged: (val) => setState(() => _search = val),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search active role holders by name, email, or ID...',
              hintStyle: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AdminTheme.textMuted, size: 20),
              filled: true,
              fillColor: AdminTheme.surfaceCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),

          // List
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminTheme.borderDark),
              ),
              child: roleHolders.isEmpty
                  ? Center(
                      child: Text(
                        'No Active Host / Faculty Role Holders Found',
                        style: GoogleFonts.outfit(color: AdminTheme.textMuted, fontSize: 15),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: roleHolders.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, color: AdminTheme.borderDark),
                      itemBuilder: (ctx, index) {
                        final user = roleHolders[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AdminTheme.primary.withValues(alpha: 0.2),
                                child: Text(
                                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            user.fullName,
                                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text(_formatRoleName(user.role)),
                                          backgroundColor: AdminTheme.primary.withValues(alpha: 0.25),
                                          labelStyle: GoogleFonts.inter(color: AdminTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${user.email} • ID: ${user.studentId ?? 'N/A'}',
                                      style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AdminTheme.statusDanger,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                icon: const Icon(Icons.remove_moderator_rounded, size: 16),
                                label: const Text('Remove Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () => _showRemoveRoleDialog(context, user),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
