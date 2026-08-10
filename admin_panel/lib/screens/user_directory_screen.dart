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
    if (selectedRole == 'eventhost') selectedRole = 'host';
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
                initialValue: ['student', 'host', 'faculty'].contains(selectedRole) ? selectedRole : 'student',
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
              await service.deleteUser(user.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User account permanently deleted.'),
                    backgroundColor: AdminTheme.statusOnline,
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

    final filtered = service.allUsers.where((u) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (u.studentId?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'User Directory & Roles',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              Text(
                'Total: ${filtered.length} Users',
                style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            onChanged: (val) => setState(() => _search = val),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Filter users by name, email, or student ID...',
              hintStyle: GoogleFonts.inter(color: AdminTheme.textMuted),
              prefixIcon: const Icon(Icons.search, color: AdminTheme.textMuted),
              filled: true,
              fillColor: AdminTheme.surfaceCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),

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
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, color: AdminTheme.borderDark),
                      itemBuilder: (ctx, index) {
                        final user = filtered[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: AdminTheme.primary.withValues(alpha: 0.2),
                            child: Text(
                              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                user.fullName,
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                              ),
                              const SizedBox(width: 8),
                              if (user.isVerifiedStudent)
                                const Icon(Icons.verified, color: AdminTheme.statusVerified, size: 16),
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
                          subtitle: Text(
                            '${user.email} • ID: ${user.studentId ?? 'N/A'}',
                            style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(
                                label: Text(_formatRoleName(user.role)),
                                backgroundColor: AdminTheme.primary.withValues(alpha: 0.2),
                                labelStyle: GoogleFonts.inter(color: AdminTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, color: AdminTheme.accentCyan),
                                tooltip: 'Change Role',
                                onPressed: () => _showRoleChangeDialog(context, user),
                              ),

                              // Explicit Ban & Unban Button Pair
                              if (user.isBanned)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AdminTheme.statusOnline,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.lock_open_rounded, size: 16),
                                  label: const Text('Unban User'),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.block_rounded, size: 16),
                                  label: const Text('Ban User'),
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

                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_forever_rounded, color: AdminTheme.statusDanger),
                                tooltip: 'Delete User Account Permanently',
                                onPressed: () => _showDeleteUserDialog(context, user),
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
