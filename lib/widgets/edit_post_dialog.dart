import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/form_models.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import 'link_form_editor.dart';

/// Shared edit dialog for the Host & Faculty dashboards: title + description,
/// plus the Links & Form editor. Pops with the fully updated [PostModel].
Future<PostModel?> showEditPostDialog(
  BuildContext context, {
  required PostModel post,
  required Color accent,
}) {
  return showDialog<PostModel>(
    context: context,
    builder: (_) => EditPostDialog(post: post, accent: accent),
  );
}

class EditPostDialog extends StatefulWidget {
  final PostModel post;
  final Color accent;

  const EditPostDialog({super.key, required this.post, required this.accent});

  @override
  State<EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<EditPostDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late List<PostLink> _links;
  FormDefinition? _form;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.post.title);
    _descCtrl = TextEditingController(text: widget.post.description);
    _links = List.of(widget.post.links);
    _form = widget.post.form;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final dataService = Provider.of<MockDataService>(
      context,
      listen: false,
    );
    final updated = widget.post.copyWith(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      links: _links,
      form: _form,
    );
    dataService.updatePost(updated);
    Navigator.of(context).pop(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Post updated successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        '✏️ Edit ${widget.post.isEvent ? 'Event/Workshop' : 'Post'}',
        style: const TextStyle(fontSize: 17),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            LinkFormEditor(
              initialLinks: _links,
              initialForm: _form,
              accent: widget.accent,
              initialFormLabel: widget.post.title,
              onLinksChanged: (links) => _links = links,
              onFormChanged: (form) => _form = form,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.accent,
            foregroundColor: Colors.white,
          ),
          onPressed: _save,
          child: const Text(
            'Save Changes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}