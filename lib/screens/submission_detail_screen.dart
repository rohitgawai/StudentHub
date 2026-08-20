import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/form_models.dart';
import '../services/mock_data_service.dart';
import '../utils/external_links.dart';

/// Full per-student view: profile snapshot + every form answer.
class SubmissionDetailScreen extends StatelessWidget {
  final FormSubmission submission;
  final Color accent;

  const SubmissionDetailScreen({
    super.key,
    required this.submission,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final s = submission;
    final service = Provider.of<MockDataService>(context);
    final post = service.posts
        .where((p) => p.id == s.postId)
        .firstOrNull;

    final byId = <String, FormFieldSpec>{};
    if (post?.form != null) {
      for (final f in post!.form!.fields) {
        byId[f.id] = f;
      }
    }

    final displayName = s.name.isEmpty ? 'Student' : s.name;

    final displayId = s.studentOrEmployeeId.isEmpty ? 'No MIT ID provided' : s.studentOrEmployeeId;

    final displayDept = s.department.isEmpty ? (post?.department ?? 'General') : s.department;

    final displayYear = s.year.isEmpty ? (service.currentUser.year.isNotEmpty ? service.currentUser.year : 'Student') : s.year;

    final displayMobile = s.mobileNumber.isEmpty ? (service.currentUser.mobileNumber.isNotEmpty ? service.currentUser.mobileNumber : 'N/A') : s.mobileNumber;

    final hasForm = post?.form != null;

    // Link-only events (no registration form) surface their attached link
    // here instead of a (non-existent) form response.
    final isLinkOnlyEvent = post != null &&
        post.isEvent &&
        post.form == null &&
        post.links.isNotEmpty;

    final answerRows = <Widget>[];
    if (hasForm) {
      s.answers.forEach((key, value) {
        final field = byId[key];
        final text = value is List ? value.join(', ') : '$value';
        if (text.trim().isEmpty) return;
        answerRows.add(
          _InfoRow(
            label: field?.label.isNotEmpty == true ? field!.label : key,
            value: text,
          ),
        );
      });
      if (answerRows.isEmpty && post!.form!.fields.isNotEmpty) {
        bool showedFallback = false;
        for (final field in post.form!.fields) {
          if (field.isHeader) continue;
          final val = s.answers[field.id]?.toString();
          if (val != null && val.isNotEmpty) {
            answerRows.add(
              _InfoRow(
                label: field.label,
                value: val,
              ),
            );
            showedFallback = true;
          }
        }
        if (!showedFallback) {
          answerRows.add(
            _InfoRow(
              label: 'Registration',
              value: 'Registered for event: "${post.form!.title}"',
            ),
          );
        }
      }
    } else {
      s.answers.forEach((key, value) {
        final field = byId[key];
        final text = value is List ? value.join(', ') : '$value';
        if (text.trim().isEmpty) return;
        answerRows.add(
          _InfoRow(
            label: field?.label.isNotEmpty == true ? field!.label : key,
            value: text,
          ),
        );
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          displayName,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          // Profile header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: accent.withValues(alpha: isDark ? 0.25 : 0.14),
                  child: Text(
                    displayName.isEmpty ? '?' : displayName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        displayId,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Form answers
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isLinkOnlyEvent
                          ? Icons.link_rounded
                          : Icons.description_outlined,
                      size: 17,
                      color: accent,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      isLinkOnlyEvent
                          ? 'Link attached'
                          : hasForm
                              ? 'Form responses (${post!.form!.title})'
                              : 'Form responses',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(s.submittedAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18),
                if (isLinkOnlyEvent)
                  ...post.links.map(
                    (link) => _LinkRow(link: link, accent: accent),
                  )
                else if (!hasForm && answerRows.isEmpty)
                  Text(
                    'Quick registration (no form attached).',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600,
                    ),
                  )
                else if (answerRows.isEmpty)
                  Text(
                    'No answers recorded.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600,
                    ),
                  )
                else
                  ...answerRows,
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Profile snapshot (academic info)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 17,
                      color: accent,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Profile details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18),
                _InfoRow(label: 'Department', value: displayDept),
                _InfoRow(label: 'Year of study', value: displayYear),
                _InfoRow(label: 'Mobile number', value: displayMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _LinkRow extends StatelessWidget {
  final PostLink link;
  final Color accent;

  const _LinkRow({required this.link, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label =
        link.label.isEmpty ? 'Registration link' : link.label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => openExternalLink(context, link.url),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.2 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.open_in_new_rounded, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      link.url,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}