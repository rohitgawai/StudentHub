import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/form_models.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import '../utils/date_formatter.dart';
import '../utils/form_export.dart';
import 'compose_message_screen.dart';
import 'submission_detail_screen.dart';

/// Registrant list for one post: every student who registered / filled the
/// form, with search, CSV+PDF download and one-click message to all.
class RegistrantsScreen extends StatefulWidget {
  final PostModel post;

  const RegistrantsScreen({super.key, required this.post});

  @override
  State<RegistrantsScreen> createState() => _RegistrantsScreenState();
}

class _RegistrantsScreenState extends State<RegistrantsScreen> {
  String _query = '';

  MockDataService get _service =>
      Provider.of<MockDataService>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    final service = _service;
    final post = widget.post;
    final isEvent = post.isEvent;
    final accent = isEvent
        ? service.config.eventColor
        : service.config.primaryColor;
    final submissions = service.submissionsForPost(post.id);
    final filtered = _query.trim().isEmpty
        ? submissions
        : submissions
              .where(
                (s) =>
                    s.name.toLowerCase().contains(_query.toLowerCase()) ||
                    s.studentOrEmployeeId
                        .toLowerCase()
                        .contains(_query.toLowerCase()) ||
                    s.department
                        .toLowerCase()
                        .contains(_query.toLowerCase()),
              )
              .toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        title: const Text('Registrations'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Summary header — big thumb-friendly actions.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${submissions.length} · ${isEvent ? 'registered' : 'responses'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.download_outlined,
                        label: 'Download',
                        onTap: () => _showDownloadSheet(context, accent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.send_outlined,
                        label: 'Message all',
                        onTap: () async {
                          final sent = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => ComposeMessageScreen(post: post),
                            ),
                          );
                          if (sent == true && mounted) setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name, MIT ID, department…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      submissions.isEmpty
                          ? 'No registrations yet.\nShare this ${isEvent ? 'event' : 'post'} to get responses.'
                          : 'No students match your search.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final s = filtered[idx];
                      return _RegistrantTile(submission: s, accent: accent);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showDownloadSheet(BuildContext context, Color accent) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Download registrant data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a format — both include name, MIT ID, department, year and every form answer.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DownloadTile(
                      icon: Icons.picture_as_pdf,
                      label: 'PDF',
                      sublabel: 'Readable report',
                      color: Colors.red.shade600,
                      accent: accent,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _export(ExportFormat.pdf);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DownloadTile(
                      icon: Icons.table_view_outlined,
                      label: 'CSV',
                      sublabel: 'Excel friendly',
                      color: Colors.green.shade700,
                      accent: accent,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _export(ExportFormat.csv);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(ExportFormat format) async {
    final submissions = _service.submissionsForPost(widget.post.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await writeRegistrantExport(
        post: widget.post,
        submissions: submissions,
        format: format,
        collegeName: _service.config.collegeName,
      );
      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: format == ExportFormat.pdf
                ? 'application/pdf'
                : 'text/csv',
          ),
        ],
        subject: '${widget.post.title} — registrations',
      );
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('⚠️ Could not create the file. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('export failed: $e');
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1565C0),
          side: const BorderSide(color: Color(0xFF1565C0), width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final Color accent;
  final VoidCallback onTap;

  const _DownloadTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 30, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistrantTile extends StatelessWidget {
  final FormSubmission submission;
  final Color accent;

  const _RegistrantTile({required this.submission, required this.accent});

  @override
  Widget build(BuildContext context) {
    final s = submission;
    final service = Provider.of<MockDataService>(context, listen: false);
    final displayName = s.name.isEmpty ? 'Student' : s.name;

    final displayId = s.studentOrEmployeeId.isEmpty ? 'No ID' : s.studentOrEmployeeId;

    final displayYear = s.year.isEmpty ? (service.currentUser.year.isNotEmpty ? service.currentUser.year : 'Student') : s.year;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: accent.withValues(alpha: 0.14),
                child: Text(
                  displayName.isEmpty ? '?' : displayName.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            s.department.isEmpty
                                ? '—'
                                : '${s.department} · $displayYear',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$displayId · ${formatEventDateTime(s.submittedAt)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (s.mobileNumber.isNotEmpty) ...[
                IconButton(
                  icon: Icon(
                    Icons.phone_outlined,
                    size: 20,
                    color: Colors.green.shade700,
                  ),
                  tooltip: 'Call ${s.mobileNumber}',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('📞 ${s.mobileNumber}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}