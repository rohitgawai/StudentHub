import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';
import '../models/admin_user_model.dart';

class AdminsScreen extends StatefulWidget {
  const AdminsScreen({super.key});

  @override
  State<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends State<AdminsScreen> {
  String _formatRoleName(String roleKey) {
    switch (roleKey.toLowerCase()) {
      case 'student':
        return 'Student';
      case 'host':
      case 'eventhost':
        return 'Host';
      case 'faculty':
        return 'Faculty';
      case 'admin':
        return 'Admin';
      case 'banned':
        return 'Banned';
      default:
        return roleKey[0].toUpperCase() + roleKey.substring(1);
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}-${two(local.month)}-${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<AdminSupabaseService>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Admin Accounts',
                  style: GoogleFonts.outfit(fontSize: isDesktop ? 20 : 18, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Total: ${service.admins.length}',
                style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Accounts with the admin role — they control this panel. Managed only by SQL; not editable here.',
            style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminTheme.borderDark),
              ),
              child: service.admins.isEmpty
                  ? Center(
                      child: Text(
                        'No Admin Accounts Found',
                        style: GoogleFonts.outfit(color: AdminTheme.textMuted, fontSize: 16),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: service.admins.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, color: AdminTheme.borderDark),
                      itemBuilder: (ctx, index) {
                        final admin = service.admins[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: isDesktop
                              ? Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AdminTheme.primary.withValues(alpha: 0.2),
                                      child: Text(
                                        admin.fullName.isNotEmpty ? admin.fullName[0].toUpperCase() : 'A',
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
                                                  admin.fullName,
                                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(Icons.verified, color: AdminTheme.statusVerified, size: 16),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AdminTheme.primary.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'ADMIN',
                                                  style: GoogleFonts.inter(
                                                    color: AdminTheme.primaryLight,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            admin.email,
                                            style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildDetailChips(admin),
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
                                            admin.fullName.isNotEmpty ? admin.fullName[0].toUpperCase() : 'A',
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
                                                      admin.fullName,
                                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.verified, color: AdminTheme.statusVerified, size: 14),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AdminTheme.primary.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      'ADMIN',
                                                      style: GoogleFonts.inter(
                                                        color: AdminTheme.primaryLight,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                admin.email,
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
                                    _buildDetailChips(admin),
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

  Widget _buildDetailChips(AdminUserModel admin) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _detailChip(Icons.badge_outlined, 'User ID: ${admin.id}'),
        _detailChip(Icons.admin_panel_settings_rounded, 'Roles: ${admin.roles.map((r) => _formatRoleName(r)).join(', ')}'),
        if (admin.mobileNumber != null)
          _detailChip(Icons.phone_outlined, admin.mobileNumber!),
        if (admin.activeDeviceId != null)
          _detailChip(Icons.devices_rounded, 'Device: ${admin.activeDeviceId}'),
        if (admin.lastSeen != null)
          _detailChip(Icons.schedule_rounded, 'Updated: ${_formatDate(admin.lastSeen)}'),
      ],
    );
  }

  Widget _detailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AdminTheme.bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminTheme.borderDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AdminTheme.accentCyan),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}