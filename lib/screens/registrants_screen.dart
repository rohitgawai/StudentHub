import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/form_models.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import '../utils/date_formatter.dart';
import '../utils/form_export.dart';
import 'compose_message_screen.dart';
import 'submission_detail_screen.dart';

/// Modern Registrant List & Analytics for an event or form:
/// - Real-time attendee analytics overview (Total, Capacity %, Department breakdown)
/// - Instant 1-tap direct download to Downloads folder (PDF / CSV) without share dialog
/// - Instant Broadcast Message to all attendees
/// - Search, filter, and attendee submission viewer
class RegistrantsScreen extends StatefulWidget {
  final PostModel post;

  const RegistrantsScreen({super.key, required this.post});

  @override
  State<RegistrantsScreen> createState() => _RegistrantsScreenState();
}

class _RegistrantsScreenState extends State<RegistrantsScreen> {
  String _query = '';
  String _selectedDept = 'All';
  bool _isExporting = false;

  MockDataService get _service =>
      Provider.of<MockDataService>(context, listen: false);

  Future<void> _handleDirectDownload(ExportFormat format) async {
    final submissions = _service.submissionsForPost(widget.post.id);
    if (submissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No registrations available to export.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final saved = await saveRegistrantExportDirectly(
        post: widget.post,
        submissions: submissions,
        format: format,
        collegeName: 'StudentHub Campus',
      );

      if (!mounted) return;
      final fileName = saved.fileName;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '📥 Downloaded: $fileName\nSaved to Downloads folder',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    final post = widget.post;
    final isEvent = post.isEvent;
    final accent = isEvent
        ? const Color(0xFF4F46E5) // Fresh Modern Indigo
        : const Color(0xFF0288D1);

    final submissions = service.submissionsForPost(post.id);
    final count = submissions.length;
    final maxSeats = post.maxParticipants;
    final capacityPercent = maxSeats != null && maxSeats > 0
        ? (count / maxSeats).clamp(0.0, 1.0)
        : 1.0;

    // Collect departments for quick filtering
    final departments = <String>{'All'};
    for (final s in submissions) {
      if (s.department.isNotEmpty) departments.add(s.department);
    }

    final filtered = submissions.where((s) {
      final matchesQuery = _query.trim().isEmpty ||
          s.name.toLowerCase().contains(_query.toLowerCase()) ||
          s.studentOrEmployeeId.toLowerCase().contains(_query.toLowerCase()) ||
          s.department.toLowerCase().contains(_query.toLowerCase());
      final matchesDept = _selectedDept == 'All' || s.department == _selectedDept;
      return matchesQuery && matchesDept;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          isEvent ? 'Event Registrations' : 'Form Responses',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Color(0xFF4F46E5), size: 20),
            tooltip: 'Message All Registrants',
            onPressed: () async {
              final sent = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => ComposeMessageScreen(post: post),
                ),
              );
              if (sent == true && mounted) setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Analytics & Instant Download Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E1B4B).withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event Title & Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: post.isRegistrationFull
                            ? Colors.red.withValues(alpha: 0.2)
                            : const Color(0xFF059669).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: post.isRegistrationFull
                              ? Colors.redAccent.withValues(alpha: 0.6)
                              : const Color(0xFF34D399),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        post.isRegistrationFull ? 'FULL' : 'ACTIVE',
                        style: TextStyle(
                          color: post.isRegistrationFull ? Colors.redAccent : const Color(0xFF34D399),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Metrics Grid
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'Total Attendees',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              maxSeats != null ? '$count / $maxSeats' : 'Unlimited',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              maxSeats != null ? '${(capacityPercent * 100).toInt()}% Capacity' : 'Seat Limit',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Instant Download & Broadcast Row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F172A),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isExporting ? null : () => _handleDirectDownload(ExportFormat.pdf),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.redAccent),
                        label: const Text(
                          'PDF Download',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isExporting ? null : () => _handleDirectDownload(ExportFormat.csv),
                        icon: const Icon(Icons.table_chart_rounded, size: 16, color: Color(0xFF38BDF8)),
                        label: const Text(
                          'CSV Download',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name, MIT ID, or department...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                ),
              ),
            ),
          ),

          // Department Filter Chips
          if (departments.length > 2)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: departments.map((d) {
                  final active = _selectedDept == d;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: active,
                      label: Text(d),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: active ? FontWeight.bold : FontWeight.w500,
                        color: active ? Colors.white : const Color(0xFF334155),
                      ),
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFF4F46E5),
                      showCheckmark: false,
                      side: BorderSide(
                        color: active ? const Color(0xFF4F46E5) : Colors.grey.shade300,
                      ),
                      onSelected: (_) => setState(() => _selectedDept = d),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 8),

          // Registrants List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline_rounded, size: 54, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          _query.isEmpty && _selectedDept == 'All'
                              ? 'No registrations recorded yet.'
                              : 'No matching attendees found.',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final s = filtered[idx];
                      return _buildAttendeeTile(context, s, accent);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendeeTile(BuildContext context, FormSubmission s, Color accent) {
    final displayName = s.name.isEmpty ? 'Anonymous Student' : s.name;
    final displayId = s.studentOrEmployeeId.isEmpty ? 'No ID' : s.studentOrEmployeeId;
    final displayYear = s.year.isEmpty ? 'Student' : s.year;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SubmissionDetailScreen(
                  submission: s,
                  accent: accent,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: Text(
                    displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4F46E5),
                      fontSize: 16,
                    ),
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
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              displayYear,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.department.isNotEmpty ? s.department : 'General Campus',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$displayId • ${formatEventDateTime(s.submittedAt)}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (s.mobileNumber.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.phone_rounded,
                      size: 18,
                      color: Colors.green.shade700,
                    ),
                    tooltip: 'Contact: ${s.mobileNumber}',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('📞 Contact: ${s.mobileNumber}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}