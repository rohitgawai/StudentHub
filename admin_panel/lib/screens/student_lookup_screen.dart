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
    final isDesktop = MediaQuery.of(context).size.width >= 900;

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
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminTheme.accentCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.badge_rounded, color: AdminTheme.accentCyan, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'College Student Inspector',
                      style: GoogleFonts.outfit(fontSize: isDesktop ? 20 : 18, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      'Search any student to check their MIT ID, Mobile Number, academic details, and verification status.',
                      style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search Name, MIT ID, Mobile No, Dept...',
              hintStyle: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AdminTheme.textMuted, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AdminTheme.textMuted, size: 20),
                      onPressed: () => setState(() => _searchController.clear()),
                    )
                  : null,
              filled: true,
              fillColor: AdminTheme.surfaceCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AdminTheme.borderDark),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Desktop Left List
                      Expanded(
                        flex: 3,
                        child: _buildStudentListView(searchResults),
                      ),
                      const SizedBox(width: 20),
                      // Desktop Right Inspector Card
                      Expanded(
                        flex: 4,
                        child: _selectedStudent != null
                            ? _buildInspectorCard(service)
                            : _buildEmptyStateCard(),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedStudent != null) ...[
                          _buildInspectorCard(service),
                          const SizedBox(height: 16),
                        ],
                        SizedBox(
                          height: 400,
                          child: _buildStudentListView(searchResults),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentListView(List<AdminUserModel> searchResults) {
    if (searchResults.isEmpty) {
      return Center(
        child: Text(
          'No Students Found',
          style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final student = searchResults[index];
        final isSelected = _selectedStudent?.id == student.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => setState(() => _selectedStudent = student),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? AdminTheme.primary.withValues(alpha: 0.15) : AdminTheme.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AdminTheme.primary : AdminTheme.borderDark,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AdminTheme.primary.withValues(alpha: 0.3),
                    child: Text(
                      student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : 'S',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                student.fullName,
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (student.isVerifiedStudent) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: AdminTheme.statusVerified, size: 14),
                            ],
                          ],
                        ),
                        Text(
                          '${student.studentId ?? 'No ID'} • ${student.branch ?? 'General'}',
                          style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: AdminTheme.textMuted, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInspectorCard(AdminSupabaseService service) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AdminTheme.primary,
                child: Text(
                  _selectedStudent!.fullName.isNotEmpty ? _selectedStudent!.fullName[0].toUpperCase() : 'S',
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedStudent!.fullName,
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      _selectedStudent!.email,
                      style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AdminTheme.borderDark),
          _buildDetailRow('MIT ID / Roll No', _selectedStudent!.studentId ?? 'Not provided'),
          _buildDetailRow('Mobile Number', _selectedStudent!.mobileNumber ?? 'Not provided'),
          _buildDetailRow('Branch / Dept', _selectedStudent!.branch ?? 'Unassigned'),
          _buildDetailRow('Academic Year', _selectedStudent!.year ?? 'N/A'),
          _buildDetailRow('App Role', _selectedStudent!.role.toUpperCase()),
          _buildDetailRow(
            'Verification Status',
            _selectedStudent!.isVerifiedStudent ? 'Verified Student' : 'Unverified',
            isBadge: true,
            badgeColor: _selectedStudent!.isVerifiedStudent ? AdminTheme.statusVerified : AdminTheme.textMuted,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedStudent!.isVerifiedStudent
                    ? AdminTheme.statusDanger
                    : AdminTheme.statusVerified,
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                size: 18,
              ),
              label: Text(
                _selectedStudent!.isVerifiedStudent
                    ? 'Remove Verification'
                    : 'Grant Verified Status',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderDark),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.touch_app_rounded, size: 40, color: AdminTheme.textMuted),
            const SizedBox(height: 10),
            Text(
              'Select a student to inspect',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
            ),
            Text(
              'Click any student from the list to view full details.',
              style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBadge = false, Color? badgeColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12)),
          const SizedBox(width: 8),
          if (isBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (badgeColor ?? AdminTheme.primary).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                style: GoogleFonts.inter(color: badgeColor ?? AdminTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            Flexible(
              child: Text(
                value,
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }
}
