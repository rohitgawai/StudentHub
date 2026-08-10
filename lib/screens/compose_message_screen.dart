import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/post_model.dart';
import '../services/mock_data_service.dart';

/// One-click message composer: title + message, sent as push + in-app bell
/// to every student registered / who filled the form for this post.
class ComposeMessageScreen extends StatefulWidget {
  final PostModel post;

  const ComposeMessageScreen({super.key, required this.post});

  @override
  State<ComposeMessageScreen> createState() => _ComposeMessageScreenState();
}

class _ComposeMessageScreenState extends State<ComposeMessageScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final service = Provider.of<MockDataService>(context, listen: false);
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty && body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Write a short message before sending.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _sending = true);
    service.sendMessageToRegistrants(
      post: widget.post,
      title: title,
      body: body,
    );
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '📨 Message sent to ${service.submissionsForPost(widget.post.id).length} '
          '${widget.post.isEvent ? 'registered students' : 'respondents'}.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<MockDataService>(context);
    final post = widget.post;
    final count = service.submissionsForPost(post.id).length;
    final accent = post.isEvent ? service.config.eventColor : service.config.primaryColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        title: const Text('📨 Message students'),
        centerTitle: false,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_outlined, size: 19),
            label: Text(
              _sending ? 'Sending…' : 'Send to $count students',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            onPressed: _sending ? null : _send,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.groups_2_outlined, size: 20, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recipients: $count students who registered for "${post.title}"',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: 'Message title',
              hintText: 'e.g. Venue change / Reminder',
              prefixIcon: const Icon(Icons.title_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _bodyCtrl,
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Message',
              hintText: 'What would you like to tell the students?',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Students receive this as a push notification AND in the in-app notification bell.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
          ),
        ],
      ),
    );
  }
}