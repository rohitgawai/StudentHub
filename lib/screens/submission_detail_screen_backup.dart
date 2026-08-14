import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/form_models.dart';
import '../services/mock_data_service.dart';

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

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        title: const Text('Student Details'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Student header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: accent.withValues(alpha: 0.14),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        displayId,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.description_outlined, size: 17, color: accent),
                    const SizedBox(width: 7),
                    Text(
                      hasForm ? 'Form responses (${post!.form!.title})' : 'Form responses',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(s.submittedAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18),
                if (!hasForm && answerRows.isEmpty)
                  Text(
                    'Quick registration (no form attached).',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  )
                else if (answerRows.isEmpty)
                  Text(
                    'Registered for form event: "${post?.form?.title ?? 'Form'}"',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  )
                else
                  ...answerRows,
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Profile info section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 17, color: accent),
                    const SizedBox(width: 7),
                    const Text(
                      'Profile information',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18),
                _InfoRow(label: 'Department', value: displayDept),
                _InfoRow(label: 'Academic year', value: displayYear),
                _InfoRow(label: 'Mobile number', value: displayMobile),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    String pad(int v) => v.toString().padLeft(2, '0');
    return '${pad(dt.day)}/${pad(dt.month)}/${dt.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
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
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }
}
