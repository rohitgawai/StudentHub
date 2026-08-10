import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';

class ContentModerationScreen extends StatelessWidget {
  const ContentModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<AdminSupabaseService>(context);

    final pendingReports = service.reportedPosts.where((r) => r.status == 'pending').toList();

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
                  color: AdminTheme.statusDanger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.gavel_rounded, color: AdminTheme.statusDanger, size: 28),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Content & Post Moderation',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Review reported posts and keep your student community safe.',
                    style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: pendingReports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_user_rounded, size: 48, color: AdminTheme.statusOnline),
                        const SizedBox(height: 12),
                        Text(
                          'No Flagged Posts Awaiting Moderation',
                          style: GoogleFonts.outfit(fontSize: 16, color: Colors.white),
                        ),
                        Text(
                          'All student reports have been resolved.',
                          style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: pendingReports.length,
                    itemBuilder: (context, index) {
                      final report = pendingReports[index];

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
                                const Icon(Icons.report_problem_rounded, color: AdminTheme.statusDanger, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Reported Reason: ${report.reportReason}',
                                  style: GoogleFonts.inter(
                                    color: AdminTheme.statusDanger,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Reported by: ${report.reporterName}',
                                  style: GoogleFonts.inter(color: AdminTheme.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AdminTheme.bgDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AdminTheme.borderDark),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Author: ${report.authorName}',
                                    style: GoogleFonts.inter(color: AdminTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    report.postContent,
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AdminTheme.textMuted,
                                    side: const BorderSide(color: AdminTheme.borderDark),
                                  ),
                                  onPressed: () async {
                                    await service.dismissReport(report.id);
                                  },
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  label: const Text('Dismiss Report'),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AdminTheme.statusDanger,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    await service.deletePost(report.postId, report.id);
                                  },
                                  icon: const Icon(Icons.delete_forever_rounded, size: 18),
                                  label: const Text('Delete Post from App'),
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
}
