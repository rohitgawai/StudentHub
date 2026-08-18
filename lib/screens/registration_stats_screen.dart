import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import '../utils/date_formatter.dart';
import '../utils/form_export.dart';
import 'registrants_screen.dart';

/// Entry screen for host/faculty: every event/workshop/post of theirs that
/// has registrations or form responses, with counts, capacity progress bars,
/// search, and direct PDF/CSV export.
class RegistrationStatsScreen extends StatefulWidget {
  const RegistrationStatsScreen({super.key});

  @override
  State<RegistrationStatsScreen> createState() =>
      _RegistrationStatsScreenState();
}

class _RegistrationStatsScreenState extends State<RegistrationStatsScreen> {
  String _searchQuery = '';
  bool _isExporting = false;

  List<PostModel> _buildRows(MockDataService service) {
    final user = service.currentUser;
    return service.posts
        .where(
          (p) =>
              (p.authorId == user.id || p.authorName.contains(user.name)) &&
              (p.form != null ||
                  p.registeredUserIds.isNotEmpty ||
                  service.submissionsForPost(p.id).isNotEmpty),
        )
        .toList();
  }

  int _countFor(MockDataService service, PostModel post) {
    final subCount = service.submissionsForPost(post.id).length;
    final regCount = post.registeredUserIds.length;
    return regCount > subCount ? regCount : subCount;
  }

  Future<void> _exportAll(
    MockDataService service,
    List<PostModel> rows,
    ExportFormat format,
  ) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No registration data to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      int savedCount = 0;
      for (final post in rows) {
        final subs = service.submissionsForPost(post.id);
        if (subs.isEmpty) continue;
        await saveRegistrantExportDirectly(
          post: post,
          submissions: subs,
          format: format,
          collegeName: 'StudentHub',
        );
        savedCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '📥 $savedCount ${format.name.toUpperCase()} ${savedCount == 1 ? "report" : "reports"} saved to Downloads folder',
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<MockDataService>(context);
    final allRows = _buildRows(service);

    final filteredRows = _searchQuery.trim().isEmpty
        ? allRows
        : allRows.where((p) {
            final q = _searchQuery.toLowerCase();
            return p.title.toLowerCase().contains(q) ||
                p.description.toLowerCase().contains(q) ||
                (p.venue ?? '').toLowerCase().contains(q);
          }).toList();

    final totalRegistrations = allRows.fold<int>(
      0,
      (sum, p) => sum + _countFor(service, p),
    );

    final now = DateTime.now();
    final upcomingCount = allRows
        .where((p) => p.isEvent && (p.eventDate == null || p.eventDate!.isAfter(now)))
        .length;
    final pastCount = allRows.length - upcomingCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Registration Analytics',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            PopupMenuButton<ExportFormat>(
              tooltip: 'Export Registrations',
              onSelected: (format) => _exportAll(service, allRows, format),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1E1B4B).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.download_rounded, size: 16, color: Color(0xFF1E1B4B)),
                    SizedBox(width: 4),
                    Text(
                      'Export',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1B4B),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF1E1B4B)),
                  ],
                ),
              ),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: ExportFormat.pdf,
                  child: Row(
                    children: const [
                      Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                      SizedBox(width: 10),
                      Text('Download as PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: ExportFormat.csv,
                  child: Row(
                    children: const [
                      Icon(Icons.table_chart, color: Colors.green, size: 18),
                      SizedBox(width: 10),
                      Text('Download as CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: allRows.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.query_stats,
                    size: 56,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No registrations yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When students register for your events or fill your forms,\nthey appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Top Summary Card
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$totalRegistrations Total Registrations',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${allRows.length} Total Events & Forms',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1B4B).withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.insights_rounded,
                              color: Color(0xFF1E1B4B),
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$upcomingCount Upcoming',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$pastCount Completed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search your events or forms...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1E1B4B)),
                      ),
                    ),
                  ),
                ),

                // Event Analytics List
                Expanded(
                  child: filteredRows.isEmpty
                      ? Center(
                          child: Text(
                            'No matching events found.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          itemCount: filteredRows.length,
                          itemBuilder: (ctx, idx) {
                            final post = filteredRows[idx];
                            final count = _countFor(service, post);
                            return _EventAnalyticsCard(
                              post: post,
                              count: count,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RegistrantsScreen(post: post),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _EventAnalyticsCard extends StatelessWidget {
  final PostModel post;
  final int count;
  final VoidCallback onTap;

  const _EventAnalyticsCard({
    required this.post,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEvent = post.isEvent;
    final maxCapacity = post.maxParticipants ?? 100;
    final double fillPercentage = maxCapacity > 0
        ? (count / maxCapacity).clamp(0.0, 1.0)
        : 0.0;
    final int percentInt = (fillPercentage * 100).round();

    final isUpcoming = isEvent &&
        (post.eventDate == null || post.eventDate!.isAfter(DateTime.now()));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isEvent ? const Color(0xFF312E81) : Colors.blue)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEvent ? Icons.event_available : Icons.description_outlined,
                        color: isEvent ? const Color(0xFF312E81) : Colors.blue.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  post.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (isEvent)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUpcoming
                                        ? Colors.green.shade50
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isUpcoming
                                          ? Colors.green.shade200
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    isUpcoming ? 'UPCOMING' : 'PAST',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: isUpcoming
                                          ? Colors.green.shade800
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isEvent
                                ? (post.eventDate != null
                                    ? formatEventDateTime(post.eventDate!)
                                    : post.venue ?? 'Campus')
                                : (post.description.isEmpty
                                    ? post.category.displayName
                                    : post.description),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Capacity Progress Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Capacity: $count / $maxCapacity Seats',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '$percentInt% filled',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF312E81),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fillPercentage,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percentInt >= 90
                          ? Colors.redAccent
                          : percentInt >= 50
                              ? Colors.orange
                              : const Color(0xFF312E81),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom Action Row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_outline, size: 16, color: Color(0xFF312E81)),
                      const SizedBox(width: 6),
                      Text(
                        '$count ${count == 1 ? 'Registrant' : 'Registrants'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF312E81),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'View Attendees →',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF312E81),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}