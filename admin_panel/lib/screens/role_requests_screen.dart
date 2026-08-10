import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';
import '../models/role_request_model.dart';

class RoleRequestsScreen extends StatefulWidget {
  const RoleRequestsScreen({super.key});

  @override
  State<RoleRequestsScreen> createState() => _RoleRequestsScreenState();
}

class _RoleRequestsScreenState extends State<RoleRequestsScreen> {
  String _selectedFilter = 'pending';

  String _formatRoleName(String roleKey) {
    switch (roleKey.toLowerCase()) {
      case 'student':
        return 'Student';
      case 'host':
      case 'eventhost':
        return 'Host';
      case 'faculty':
        return 'Faculty';
      default:
        return roleKey[0].toUpperCase() + roleKey.substring(1);
    }
  }

  void _showReviewDialog(BuildContext context, RoleRequestModel req, bool approve) {
    final noteController = TextEditingController(
      text: approve ? 'Role approved by Admin.' : 'Role request rejected.',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          approve ? 'Approve Role Application' : 'Reject Role Application',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Applicant: ${req.userName} (${req.userEmail})',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Target Role: ${_formatRoleName(req.requestedRole)}',
              style: GoogleFonts.inter(color: AdminTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Review Note / Reason',
                labelStyle: GoogleFonts.inter(color: AdminTheme.textMuted),
                filled: true,
                fillColor: AdminTheme.bgDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AdminTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? AdminTheme.statusOnline : AdminTheme.statusDanger,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final service = Provider.of<AdminSupabaseService>(context, listen: false);
              final success = await service.reviewRoleRequest(
                requestId: req.id,
                userId: req.userId,
                targetRole: req.requestedRole.toLowerCase(),
                approve: approve,
                note: noteController.text,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Role request updated successfully!'
                          : 'Failed to update role request.',
                    ),
                    backgroundColor: success ? AdminTheme.statusOnline : AdminTheme.statusDanger,
                  ),
                );
              }
            },
            child: Text(
              approve ? 'Confirm Approve' : 'Confirm Reject',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<AdminSupabaseService>(context);

    final filtered = service.roleRequests.where((r) {
      if (_selectedFilter == 'all') return true;
      return r.status == _selectedFilter;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Row
          Row(
            children: [
              Text(
                'Role Applications Queue',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              _buildFilterChip('pending', 'Pending (${service.roleRequests.where((r) => r.status == 'pending').length})'),
              const SizedBox(width: 8),
              _buildFilterChip('approved', 'Approved'),
              const SizedBox(width: 8),
              _buildFilterChip('rejected', 'Rejected'),
              const SizedBox(width: 8),
              _buildFilterChip('all', 'All'),
            ],
          ),
          const SizedBox(height: 24),

          // List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_turned_in_rounded, size: 48, color: AdminTheme.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No ${_selectedFilter.toUpperCase()} Role Requests',
                          style: GoogleFonts.outfit(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final req = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AdminTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AdminTheme.borderDark),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AdminTheme.primary.withValues(alpha: 0.2),
                                  child: Text(
                                    req.userName.isNotEmpty ? req.userName[0].toUpperCase() : 'A',
                                    style: GoogleFonts.outfit(color: AdminTheme.primaryLight, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        req.userName,
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                                      ),
                                      Text(
                                        req.userEmail,
                                        style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: req.status == 'approved'
                                        ? AdminTheme.statusOnline.withValues(alpha: 0.2)
                                        : req.status == 'rejected'
                                            ? AdminTheme.statusDanger.withValues(alpha: 0.2)
                                            : AdminTheme.statusPending.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Requested Role: ${_formatRoleName(req.requestedRole)}',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: req.status == 'approved'
                                          ? AdminTheme.statusOnline
                                          : req.status == 'rejected'
                                              ? AdminTheme.statusDanger
                                              : AdminTheme.statusPending,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Reason / Notes:',
                              style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AdminTheme.bgDark,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                req.reason,
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Applied: ${DateFormat('MMM dd, yyyy • hh:mm a').format(req.createdAt)}',
                                  style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                                ),
                                if (req.status == 'pending')
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AdminTheme.statusDanger,
                                          side: const BorderSide(color: AdminTheme.statusDanger),
                                        ),
                                        onPressed: () => _showReviewDialog(context, req, false),
                                        icon: const Icon(Icons.close_rounded, size: 18),
                                        label: const Text('Reject'),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AdminTheme.statusOnline,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => _showReviewDialog(context, req, true),
                                        icon: const Icon(Icons.check_rounded, size: 18),
                                        label: const Text('Approve Role'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = key),
      selectedColor: AdminTheme.primary,
      backgroundColor: AdminTheme.surfaceCard,
      labelStyle: GoogleFonts.inter(
        color: isSelected ? Colors.white : AdminTheme.textMuted,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
