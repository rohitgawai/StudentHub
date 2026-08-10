import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';
import '../models/admin_user_model.dart';

class StudentLookupScreen extends StatefulWidget {
  const StudentLookupScreen({super.key});

  @override
  State<StudentLookupScreen> createState() => _StudentLookupScreenState();
}

class _StudentLookupScreenState extends State<StudentLookupScreen> {
  final _searchController = TextEditingController();
  AdminUserModel? _selectedStudent;

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<AdminSupabaseService>(context);

    final searchResults = service.allUsers.where((u) {
      if (_searchController.text.isEmpty) return true;
      final q = _searchController.text.toLowerCase();
      return u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (u.studentId?.toLowerCase().contains(q) ?? false) ||
          (u.branch?.toLowerCase().contains(q) ?? false) ||
          (u.mobileNumber?.toLowerCase().contains(q) ?? false);
    }).toList();

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
                  color: AdminTheme.accentCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.badge_rounded, color: AdminTheme.accentCyan, size: 28),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'College Student Inspector',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Search any student to check their MIT ID, Mobile Number, academic details, and verification status.',
                    style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Field
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Type Name, MIT ID / PRN, Email, Mobile No, or Department...',
              hintStyle: GoogleFonts.inter(color: AdminTheme.textMuted),
              prefixIcon: const Icon(Icons.search, color: AdminTheme.textMuted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AdminTheme.textMuted),
                      onPressed: () => setState(() => _searchController.clear()),
                    )
                  : null,
              filled: true,
              fillColor: AdminTheme.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AdminTheme.borderDark),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Results List
                Expanded(
                  flex: 3,
                  child: ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final student = searchResults[index];
                      final isSelected = _selectedStudent?.id == student.id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => setState(() => _selectedStudent = student),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? AdminTheme.primary.withValues(alpha: 0.15) : AdminTheme.surfaceCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AdminTheme.primary : AdminTheme.borderDark,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AdminTheme.primary.withValues(alpha: 0.3),
                                  child: Text(
                                    student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : 'S',
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
                                          Text(
                                            student.fullName,
                                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                                          ),
                                          const SizedBox(width: 6),
                                          if (student.isVerifiedStudent)
                                            const Icon(Icons.verified, color: AdminTheme.statusVerified, size: 16),
                                        ],
                                      ),
                                      Text(
                                        '${student.studentId ?? 'No ID'} • ${student.branch ?? 'General'}',
                                        style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: AdminTheme.textMuted),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 24),

                // Detailed Inspector Card
                if (_selectedStudent != null)
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(24),
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
                                radius: 30,
                                backgroundColor: AdminTheme.primary,
                                child: Text(
                                  _selectedStudent!.fullName.isNotEmpty ? _selectedStudent!.fullName[0].toUpperCase() : 'S',
                                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedStudent!.fullName,
                                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    Text(
                                      _selectedStudent!.email,
                                      style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32, color: AdminTheme.borderDark),
                          _buildDetailRow('MIT ID / Roll No', _selectedStudent!.studentId ?? 'Not provided'),
                          _buildDetailRow('Mobile Number', _selectedStudent!.mobileNumber ?? 'Not provided'),
                          _buildDetailRow('Branch / Dept', _selectedStudent!.branch ?? 'Unassigned'),
                          _buildDetailRow('Academic Year', _selectedStudent!.year ?? 'N/A'),
                          _buildDetailRow('App Role', _selectedStudent!.role.toUpperCase()),
                          _buildDetailRow(
                            'College Verification Status',
                            _selectedStudent!.isVerifiedStudent ? 'Verified College Student' : 'Unverified / Guest',
                            isBadge: true,
                            badgeColor: _selectedStudent!.isVerifiedStudent ? AdminTheme.statusVerified : AdminTheme.textMuted,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _selectedStudent!.isVerifiedStudent
                                        ? AdminTheme.statusDanger
                                        : AdminTheme.statusVerified,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  onPressed: () async {
                                    final success = await service.toggleVerifyStudent(
                                      _selectedStudent!.id,
                                      _selectedStudent!.isVerifiedStudent,
                                    );
                                    if (success) {
                                      setState(() {
                                        _selectedStudent = AdminUserModel.fromMap({
                                          ..._selectedStudent!.toMap(),
                                          'is_verified_student': !_selectedStudent!.isVerifiedStudent,
                                        });
                                      });
                                    }
                                  },
                                  icon: Icon(
                                    _selectedStudent!.isVerifiedStudent
                                        ? Icons.remove_moderator_rounded
                                        : Icons.verified_user_rounded,
                                  ),
                                  label: Text(
                                    _selectedStudent!.isVerifiedStudent
                                        ? 'Remove Verified Status'
                                        : 'Mark as Verified College Student',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AdminTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AdminTheme.borderDark),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.touch_app_rounded, size: 48, color: AdminTheme.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'Select a student from the left list',
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                            ),
                            Text(
                              'Click any student to inspect their full academic identity, Mobile No & grant verification.',
                              style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
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

  Widget _buildDetailRow(String label, String value, {bool isBadge = false, Color? badgeColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13)),
          if (isBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (badgeColor ?? AdminTheme.primary).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: GoogleFonts.inter(color: badgeColor ?? AdminTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            )
          else
            Text(
              value,
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            ),
        ],
      ),
    );
  }
}
