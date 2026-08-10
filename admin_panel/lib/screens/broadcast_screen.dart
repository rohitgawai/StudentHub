import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String _selectedBranch = 'ALL';
  String _selectedYear = 'ALL';
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isMobile = MediaQuery.of(context).size.width < 600;

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
                  color: AdminTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign_rounded, color: AdminTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Broadcast Announcements',
                      style: GoogleFonts.outfit(fontSize: isDesktop ? 20 : 18, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      'Send official system notifications or push alerts directly to student phones.',
                      style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
                decoration: BoxDecoration(
                  color: AdminTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminTheme.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compose System Push Notice',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Announcement Title',
                        labelStyle: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13),
                        hintText: 'e.g., Campus Maintenance Alert / Mid-term Exam Schedule',
                        hintStyle: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: AdminTheme.bgDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Body
                    TextField(
                      controller: _bodyController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Announcement Body / Details',
                        labelStyle: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: AdminTheme.bgDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Responsive Targeting Filters
                    if (isMobile) ...[
                      _buildBranchDropdown(),
                      const SizedBox(height: 14),
                      _buildYearDropdown(),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(child: _buildBranchDropdown()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildYearDropdown()),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSending ? null : () => _handleSendBroadcast(context),
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        label: Text(
                          _isSending ? 'Broadcasting Notice...' : 'Broadcast Push Notice Now',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedBranch,
      dropdownColor: AdminTheme.surfaceDark,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Target Department',
        labelStyle: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
        filled: true,
        fillColor: AdminTheme.bgDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: ['ALL', 'CSE', 'ECE', 'MECH', 'CIVIL', 'IT'].map((b) {
        return DropdownMenuItem(value: b, child: Text(b == 'ALL' ? 'All Departments' : b));
      }).toList(),
      onChanged: (val) {
        if (val != null) setState(() => _selectedBranch = val);
      },
    );
  }

  Widget _buildYearDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedYear,
      dropdownColor: AdminTheme.surfaceDark,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Target Academic Year',
        labelStyle: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
        filled: true,
        fillColor: AdminTheme.bgDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: ['ALL', '1st Year', '2nd Year', '3rd Year', '4th Year'].map((y) {
        return DropdownMenuItem(value: y, child: Text(y == 'ALL' ? 'All Years' : y));
      }).toList(),
      onChanged: (val) {
        if (val != null) setState(() => _selectedYear = val);
      },
    );
  }

  Future<void> _handleSendBroadcast(BuildContext context) async {
    if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both title and body for the announcement.'),
          backgroundColor: AdminTheme.statusDanger,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    final service = Provider.of<AdminSupabaseService>(context, listen: false);
    final success = await service.sendBroadcastAnnouncement(
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      targetBranch: _selectedBranch,
      targetYear: _selectedYear,
    );

    setState(() => _isSending = false);

    if (mounted) {
      if (success) {
        _titleController.clear();
        _bodyController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📢 Push notification alert sent successfully to student devices!'),
            backgroundColor: AdminTheme.statusOnline,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send broadcast alert. Please try again.'),
            backgroundColor: AdminTheme.statusDanger,
          ),
        );
      }
    }
  }
}
