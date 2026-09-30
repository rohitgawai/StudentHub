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

  Set<String> _getRecipientIds(MockDataService service, PostModel post) {
    return <String>{
      ...post.registeredUserIds,
      ...service
          .submissionsForPost(post.id)
          .map((s) => s.userId),
    }..removeWhere((id) => id.isEmpty);
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both a title and message body.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final service = Provider.of<MockDataService>(context, listen: false);
    final recipientCount = _getRecipientIds(service, widget.post).length;

    setState(() => _sending = true);

    try {
      await service.sendMessageToRegistrants(
        post: widget.post,
        title: title,
        body: body,
      );

      navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '📨 Message sent to $recipientCount '
            '${widget.post.isEvent ? 'registered students' : 'respondents'}.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<MockDataService>(context);
    final post = service.posts.firstWhere(
      (p) => p.id == widget.post.id,
      orElse: () => widget.post,
    );
    final recipientCount = _getRecipientIds(service, post).length;
    final accent = post.isEvent ? service.config.eventColor : service.config.primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              _sending
                  ? 'Sending…'
                  : recipientCount == 0
                      ? 'No recipients registered'
                      : 'Send to $recipientCount students',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            onPressed: (_sending || recipientCount == 0) ? null : _send,
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
                    recipientCount == 0
                        ? 'No students have registered for "${post.title}" yet.'
                        : 'Recipients: $recipientCount students who registered for "${post.title}"',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
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