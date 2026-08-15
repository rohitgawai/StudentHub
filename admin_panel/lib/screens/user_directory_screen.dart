import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';
import '../models/admin_user_model.dart';

class UserDirectoryScreen extends StatefulWidget {
  const UserDirectoryScreen({super.key});

  @override
  State<UserDirectoryScreen> createState() => _UserDirectoryScreenState();
}

class _UserDirectoryScreenState extends State<UserDirectoryScreen> {
  String _search = '';

  String _formatRoleName(String roleKey) {
    switch (roleKey.toLowerCase()) {
      case 'student':
        return 'Student';
      case 'host':
      case 'eventhost':
        return 'Host';
      case 'faculty':
        return 'Faculty';
      case 'banned':
        return 'Banned';
      default:
        return roleKey[0].toUpperCase() + roleKey.substring(1);
    }
  }

  void _showRoleChangeDialog(BuildContext context, AdminUserModel user) {
    String selectedRole = user.role.toLowerCase();
    if (selectedRole == 'eventhost' || selectedRole == 'event_host') selectedRole = 'host';
    if (selectedRole == 'banned' || selectedRole == 'admin') selectedRole = 'student';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Change User Role',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User: ${user.fullName} (${user.email})', style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: ['student', 'host', 'faculty'].contains(selectedRole) ? selectedRole : 'student',
                dropdownColor: AdminTheme.surfaceDark,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Select App Role',
                  filled: true,
                  fillColor: AdminTheme.bgDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(value: 'host', child: Text('Host (Event Host)')),
                  DropdownMenuItem(value: 'faculty', child: Text('Faculty')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedRole = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: AdminTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primary),
              onPressed: () async {
                Navigator.pop(ctx);
                final service = Provider.of<AdminSupabaseService>(context, listen: false);
                await service.updateUserRole(user.id, selectedRole);
              },
              child: Text('Update Role', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteUserDialog(BuildContext context, AdminUserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete User Account',
          style: GoogleFonts.outfit(color: AdminTheme.statusDanger, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to completely delete ${user.fullName} (${user.email})?',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminTheme.statusDanger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminTheme.statusDanger.withValues(alpha: 0.4)),
              ),
              child: Text(
                '⚠️ This will permanently remove the student from the user directory and erase their profile.',
                style: GoogleFonts.inter(color: AdminTheme.statusDanger, fontSize: 12),
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
              final deleted = await service.deleteUser(user.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(deleted
                        ? 'User account permanently deleted from server and device.'
                        : 'Delete failed. The account was NOT removed — check the server/network and try again.'),
                    backgroundColor: deleted
                        ? AdminTheme.statusOnline
                        : AdminTheme.statusDanger,
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 18),
            label: Text('Permanently Delete', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<AdminSupabaseService>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final filtered = service.allUsers.where((u) {
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
              Expanded(
                child: Text(
                  'User Directory & Roles',
                  style: GoogleFonts.outfit(fontSize: isDesktop ? 20 : 18, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Total: ${filtered.length}',
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
              hintText: 'Filter by name, email, or student ID...',
              hintStyle: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AdminTheme.textMuted, size: 20),
              filled: true,
              fillColor: AdminTheme.surfaceCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),

          // User Data Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminTheme.borderDark),
              ),
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No Users Found',
                        style: GoogleFonts.outfit(color: AdminTheme.textMuted, fontSize: 16),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, color: AdminTheme.borderDark),
                      itemBuilder: (ctx, index) {
                        final user = filtered[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: isDesktop
                              ? Row(
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
                                              if (user.isVerifiedStudent) ...[
                                                const SizedBox(width: 6),
                                                const Icon(Icons.verified, color: AdminTheme.statusVerified, size: 16),
                                              ],
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: user.isBanned
                                                      ? AdminTheme.statusDanger.withValues(alpha: 0.2)
                                                      : AdminTheme.statusOnline.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  user.isBanned ? 'BANNED' : 'ACTIVE',
                                                  style: GoogleFonts.inter(
                                                    color: user.isBanned ? AdminTheme.statusDanger : AdminTheme.statusOnline,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
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
                                    _buildActionButtons(user, service),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: AdminTheme.primary.withValues(alpha: 0.2),
                                          child: Text(
                                            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      user.fullName,
                                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                  if (user.isVerifiedStudent) ...[
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.verified, color: AdminTheme.statusVerified, size: 14),
                                                  ],
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: user.isBanned
                                                          ? AdminTheme.statusDanger.withValues(alpha: 0.2)
                                                          : AdminTheme.statusOnline.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      user.isBanned ? 'BANNED' : 'ACTIVE',
                                                      style: GoogleFonts.inter(
                                                        color: user.isBanned ? AdminTheme.statusDanger : AdminTheme.statusOnline,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                '${user.email} • ID: ${user.studentId ?? 'N/A'}',
                                                style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 11),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    _buildActionButtons(user, service),
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

  Widget _buildActionButtons(AdminUserModel user, AdminSupabaseService service) {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        Chip(
          label: Text(_formatRoleName(user.role)),
          backgroundColor: AdminTheme.primary.withValues(alpha: 0.2),
          labelStyle: GoogleFonts.inter(color: AdminTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: const Icon(Icons.edit_rounded, color: AdminTheme.accentCyan, size: 20),
          tooltip: 'Change Role',
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(6),
          onPressed: () => _showRoleChangeDialog(context, user),
        ),
        if (user.isBanned)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.statusOnline,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.lock_open_rounded, size: 14),
            label: const Text('Unban', style: TextStyle(fontSize: 11)),
            onPressed: () async {
              await service.toggleBanUser(user.id, false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Student has been unbanned successfully!'),
                    backgroundColor: AdminTheme.statusOnline,
                  ),
                );
              }
            },
          )
        else
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminTheme.statusDanger,
              side: const BorderSide(color: AdminTheme.statusDanger),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.block_rounded, size: 14),
            label: const Text('Ban', style: TextStyle(fontSize: 11)),
            onPressed: () async {
              await service.toggleBanUser(user.id, true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Student has been banned.'),
                    backgroundColor: AdminTheme.statusDanger,
                  ),
                );
              }
            },
          ),
        IconButton(
          icon: const Icon(Icons.delete_forever_rounded, color: AdminTheme.statusDanger, size: 20),
          tooltip: 'Delete Account Permanently',
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(6),
          onPressed: () => _showDeleteUserDialog(context, user),
        ),
      ],
    );
  }
}
