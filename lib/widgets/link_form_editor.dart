import 'package:flutter/material.dart';

import '../models/form_models.dart';
import '../screens/form_builder_screen.dart';

/// Reusable "Links & Form" builder section for post/event creation and
/// editing. Owns its state and reports changes via callbacks so the parent
/// keeps the final values at publish/save time.
///
/// Mobile-first: big tap targets, chip-style link chips, and a fullscreen
/// form builder for form creation.
class LinkFormEditor extends StatefulWidget {
  final List<PostLink> initialLinks;
  final FormDefinition? initialForm;
  final Color accent;
  final String? initialFormLabel;
  final ValueChanged<List<PostLink>>? onLinksChanged;
  final ValueChanged<FormDefinition?>? onFormChanged;

  const LinkFormEditor({
    super.key,
    this.initialLinks = const [],
    this.initialForm,
    this.accent = const Color(0xFF1E88E5),
    this.initialFormLabel,
    this.onLinksChanged,
    this.onFormChanged,
  });

  @override
  State<LinkFormEditor> createState() => _LinkFormEditorState();
}

class _LinkFormEditorState extends State<LinkFormEditor> {
  late List<PostLink> _links;
  FormDefinition? _form;

  @override
  void initState() {
    super.initState();
    _links = List.of(widget.initialLinks);
    _form = widget.initialForm;
  }

  void _notifyLinks() {
    final copy = List<PostLink>.of(_links);
    widget.onLinksChanged?.call(copy);
  }

  Future<void> _addLink() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _AddLinkDialog(),
    );
    if (result == null || !mounted) return;
    setState(() {
      _links.add(PostLink(label: result.$1, url: result.$2));
    });
    _notifyLinks();
  }

  Future<void> _createOrEditForm() async {
    final created = await Navigator.of(context).push<FormDefinition>(
      MaterialPageRoute(
        builder: (_) => FormBuilderScreen(
          initial: _form,
          initialTitle: widget.initialFormLabel,
          accent: widget.accent,
        ),
      ),
    );
    if (created == null || !mounted) return;
    setState(() => _form = created);
    widget.onFormChanged?.call(created);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Link chips
        if (_links.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _links.length; i++)
                InputChip(
                  avatar: Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: widget.accent,
                  ),
                  label: Text(
                    _links[i].label.isEmpty ? _links[i].url : _links[i].label,
                    style: const TextStyle(fontSize: 12),
                  ),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => setState(() {
                    _links.removeAt(i);
                    _notifyLinks();
                  }),
                  deleteIconColor: Colors.grey.shade600,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // Form attached summary card
        if (_form != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.assignment_outlined,
                    size: 18, color: widget.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _form!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${_form!.questionCount} questions attached',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  tooltip: 'Edit form',
                  visualDensity: VisualDensity.compact,
                  onPressed: _createOrEditForm,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 17, color: Colors.red),
                  tooltip: 'Remove form',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _form = null;
                    widget.onFormChanged?.call(null);
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // 1-Row Compact Action Buttons
        Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final linkColor = isDark ? const Color(0xFF60A5FA) : widget.accent;
            final formColor = _form != null
                ? (isDark ? const Color(0xFF34D399) : Colors.green)
                : (isDark ? const Color(0xFFA78BFA) : widget.accent);

            return Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: linkColor,
                      backgroundColor: isDark
                          ? const Color(0xFF60A5FA).withValues(alpha: 0.12)
                          : widget.accent.withValues(alpha: 0.04),
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF60A5FA).withValues(alpha: 0.5)
                            : widget.accent.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _addLink,
                    icon: const Icon(Icons.add_link, size: 16),
                    label: const Text(
                      '+ Link 🔗',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: formColor,
                      backgroundColor: isDark
                          ? (_form != null
                              ? const Color(0xFF34D399).withValues(alpha: 0.14)
                              : const Color(0xFFA78BFA).withValues(alpha: 0.12))
                          : (_form != null
                              ? Colors.green.withValues(alpha: 0.06)
                              : widget.accent.withValues(alpha: 0.04)),
                      side: BorderSide(
                        color: isDark
                            ? (_form != null
                                ? const Color(0xFF34D399).withValues(alpha: 0.6)
                                : const Color(0xFFA78BFA).withValues(alpha: 0.5))
                            : (_form != null
                                ? Colors.green
                                : widget.accent.withValues(alpha: 0.4)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _createOrEditForm,
                    icon: Icon(
                      _form == null ? Icons.post_add_outlined : Icons.check_circle_outline,
                      size: 16,
                    ),
                    label: Text(
                      _form == null ? '+ Form 📝' : 'Form Added ✓',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AddLinkDialog extends StatefulWidget {
  const _AddLinkDialog();

  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<_AddLinkDialog> {
  final _labelCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _labelCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('🔗 Add link', style: TextStyle(fontSize: 17)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _labelCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Link label',
                hintText: 'e.g. Google Meet, Registration form',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL *',
                hintText: 'https://…',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                final uri = Uri.tryParse(value);
                if (value.isEmpty ||
                    uri == null ||
                    uri.host.isEmpty ||
                    (uri.scheme != 'http' && uri.scheme != 'https')) {
                  return 'Enter a valid http(s) link';
                }
                return null;
              },
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
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            final label = _labelCtrl.text.trim().isEmpty
                ? 'Open link'
                : _labelCtrl.text.trim();
            Navigator.of(context).pop((label, _urlCtrl.text.trim()));
          },
          child: const Text('Add',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}