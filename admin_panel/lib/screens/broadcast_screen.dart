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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign_rounded, color: AdminTheme.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Broadcast Announcements',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Send official system notifications or push alerts directly to student phones.',
                    style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AdminTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AdminTheme.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compose Announcement',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Announcement Title',
                        labelStyle: GoogleFonts.inter(color: AdminTheme.textMuted),
                        filled: true,
                        fillColor: AdminTheme.bgDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Body
                    TextField(
                      controller: _bodyController,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Announcement Body / Details',
                        labelStyle: GoogleFonts.inter(color: AdminTheme.textMuted),
                        filled: true,
                        fillColor: AdminTheme.bgDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Targeting Filters
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedBranch,
                            dropdownColor: AdminTheme.surfaceDark,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Target Department',
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
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedYear,
                            dropdownColor: AdminTheme.surfaceDark,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Target Academic Year',
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
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSending
                            ? null
                            : () async {
                                if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please fill out both Title and Body.')),
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
                                        content: Text('📢 Announcement Broadcasted Successfully!'),
                                        backgroundColor: AdminTheme.statusOnline,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed to broadcast announcement.'),
                                        backgroundColor: AdminTheme.statusDanger,
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: _isSending
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : const Icon(Icons.send_rounded, color: Colors.white),
                        label: Text(
                          _isSending ? 'Broadcasting...' : 'Broadcast Push Notice Now',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
}
