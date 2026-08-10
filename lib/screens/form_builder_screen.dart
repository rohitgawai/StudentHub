import 'package:flutter/material.dart';
import '../models/form_models.dart';

/// Fullscreen, mobile-first form builder for hosts & faculty. Opens with a
/// template picker (or blank), then an editable list of questions: add, edit,
/// reorder, duplicate, delete. Pops with the finished [FormDefinition].
class FormBuilderScreen extends StatefulWidget {
  final FormDefinition? initial;
  final String? initialTitle;
  final Color accent;

  const FormBuilderScreen({
    super.key,
    this.initial,
    this.initialTitle,
    this.accent = const Color(0xFF1E88E5),
  });

  @override
  State<FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends State<FormBuilderScreen> {
  late final TextEditingController titleCtrl;
  late final TextEditingController headerCtrl;
  final _formKey = GlobalKey<FormState>();
  late List<FormFieldSpec> _fields;
  bool _allowResubmit = false;
  String _selectedTemplate = 'Blank';

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    titleCtrl = TextEditingController(
      text: initial?.title ?? widget.initialTitle ?? '',
    );
    headerCtrl = TextEditingController(text: initial?.headerText ?? '');
    _fields = initial == null ? <FormFieldSpec>[] : List.of(initial.fields);
    _allowResubmit = initial?.allowResubmit ?? false;
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    headerCtrl.dispose();
    super.dispose();
  }

  void _applyTemplate(FormTemplate template) {
    setState(() {
      _selectedTemplate = template.name;
      _fields = fieldsForTemplate(template);
      if (titleCtrl.text.trim().isEmpty) {
        titleCtrl.text = '${template.name} Form';
      }
    });
  }

  Future<void> _addField(FormFieldType type) async {
    String initialLabel = '';
    if (type == FormFieldType.header) {
      initialLabel = 'Section title';
    } else if (type == FormFieldType.email) {
      initialLabel = 'Email Address';
    } else if (type == FormFieldType.phone) {
      initialLabel = 'Phone Number';
    }

    final field = FormFieldSpec(
      id: newFieldId(type),
      type: type,
      label: initialLabel,
      options: type.isChoice ? ['Option 1', 'Option 2'] : const [],
    );
    final configured = await _editField(field);
    if (configured == null || !mounted) return;
    setState(() => _fields.add(configured));
  }

  Future<FormFieldSpec?> _editField(FormFieldSpec field) {
    return showDialog<FormFieldSpec>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FieldConfigDialog(
        field: field,
        accent: widget.accent,
      ),
    );
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _fields.length) return;
    setState(() {
      final item = _fields.removeAt(index);
      _fields.insert(target, item);
    });
  }

  void _save() {
    final title = titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please give the form a title.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      FormDefinition(
        id: widget.initial?.id ?? 'frm_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        headerText: headerCtrl.text.trim(),
        fields: _fields,
        allowResubmit: _allowResubmit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.accent,
        foregroundColor: Colors.white,
        title: Text(_isEditing ? '✏️ Edit Form' : '📋 Create Form'),
        actions: [
          TextButton(
            onPressed: _save,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              _isEditing ? 'Save Form' : 'Create Form',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: _save,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_isEditing) ...[
              Text(
                'Start from a template or build blank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 10),
              // Template chips — big thumb-friendly tiles with active selection state.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TemplateChip(
                    icon: Icons.note_add_outlined,
                    label: 'Blank',
                    accent: widget.accent,
                    isSelected: _selectedTemplate == 'Blank',
                    onTap: () => setState(() {
                      _fields = [];
                      _selectedTemplate = 'Blank';
                    }),
                  ),
                  for (final t in kFormTemplates)
                    _TemplateChip(
                      icon: t.icon,
                      label: t.name,
                      accent: widget.accent,
                      isSelected: _selectedTemplate == t.name,
                      onTap: () => _applyTemplate(t),
                    ),
                ],
              ),
              const SizedBox(height: 18),
            ],

            TextFormField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'Form Title *',
                prefixIcon: const Icon(Icons.title_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: headerCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Header description (optional)',
                prefixIcon: const Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Text(
                  'Questions (${_fields.where((f) => !f.isHeader).length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  _allowResubmit
                      ? 'Students can edit responses'
                      : 'One response per student',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Allow re-submission / editing',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Students can edit their response until the deadline',
                style: TextStyle(fontSize: 11),
              ),
              value: _allowResubmit,
              onChanged: (v) => setState(() => _allowResubmit = v),
            ),
            const SizedBox(height: 8),

            if (_fields.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 42),
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: widget.accent.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.library_add_outlined,
                        size: 44, color: widget.accent),
                    const SizedBox(height: 10),
                    const Text(
                      'No questions yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Tap "Add question" below to get started',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (var i = 0; i < _fields.length; i++) ...[
                _FieldTile(
                  field: _fields[i],
                  index: i,
                  total: _fields.length,
                  accent: widget.accent,
                  onTap: () async {
                    final updated = await _editField(_fields[i]);
                    if (updated != null && mounted) {
                      setState(() => _fields[i] = updated);
                    }
                  },
                  onMoveUp: i > 0 ? () => _move(i, -1) : null,
                  onMoveDown: i < _fields.length - 1 ? () => _move(i, 1) : null,
                  onDuplicate: () => setState(
                    () => _fields.insert(
                      i + 1,
                      _fields[i].copyWith(id: newFieldId(_fields[i].type)),
                    ),
                  ),
                  onDelete: () => setState(() => _fields.removeAt(i)),
                ),
                const SizedBox(height: 8),
              ],

            const SizedBox(height: 16),

            // Big thumb-friendly "Add question" tile.
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: widget.accent.withValues(alpha: 0.5),
                ),
              ),
              tileColor: widget.accent.withValues(alpha: 0.08),
              leading: Icon(Icons.add_circle_outline,
                  color: widget.accent, size: 26),
              title: const Text(
                'Add question',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Icon(Icons.chevron_right, color: widget.accent),
              onTap: () async {
                final type = await showModalBottomSheet<FormFieldType>(
                  context: context,
                  showDragHandle: true,
                  builder: (ctx) => _FieldTypeSheet(accent: widget.accent),
                );
                if (type != null && mounted) await _addField(type);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;

  const _TemplateChip({
    required this.icon,
    required this.label,
    required this.accent,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? accent : accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(22),
      elevation: isSelected ? 1 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: isSelected ? Colors.white : accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : accent,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check, size: 16, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final FormFieldSpec field;
  final int index;
  final int total;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _FieldTile({
    required this.field,
    required this.index,
    required this.total,
    required this.accent,
    required this.onTap,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isHeader = field.isHeader;
    return Container(
      decoration: BoxDecoration(
        color: isHeader
            ? accent.withValues(alpha: 0.06)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHeader
              ? accent.withValues(alpha: 0.3)
              : Colors.grey.shade300,
          width: isHeader ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  field.type.icon,
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.label.isEmpty ? 'Untitled Question' : field.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isHeader ? accent : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          field.isHeader
                              ? 'Section Header'
                              : field.type.displayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (field.required && !field.isHeader) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: const Text(
                              'Required',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _MiniIconButton(
                icon: Icons.keyboard_arrow_up,
                tooltip: 'Move up',
                onTap: onMoveUp,
              ),
              _MiniIconButton(
                icon: Icons.keyboard_arrow_down,
                tooltip: 'Move down',
                onTap: onMoveDown,
              ),
              _MiniIconButton(
                icon: Icons.copy_outlined,
                tooltip: 'Duplicate',
                onTap: onDuplicate,
              ),
              _MiniIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                color: Colors.red.shade400,
                onTap: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color ?? Colors.grey.shade500),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }
}

/// Bottom sheet listing every field type with a big tappable tile.
class _FieldTypeSheet extends StatelessWidget {
  final Color accent;

  const _FieldTypeSheet({required this.accent});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Text(
            'Choose Question Type or Option',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          for (final type in FormFieldType.values)
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              leading: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(type.icon, size: 20, color: accent),
              ),
              title: Text(
                type.displayName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.of(context).pop(type),
            ),
        ],
      ),
    );
  }
}

/// Configures one field: label, hint, required, options for choice fields.
class _FieldConfigDialog extends StatefulWidget {
  final FormFieldSpec field;
  final Color accent;

  const _FieldConfigDialog({required this.field, required this.accent});

  @override
  State<_FieldConfigDialog> createState() => _FieldConfigDialogState();
}

class _FieldConfigDialogState extends State<_FieldConfigDialog> {
  late final TextEditingController labelCtrl;
  late final TextEditingController hintCtrl;
  late bool required;
  late List<TextEditingController> optionCtrls;

  FormFieldSpec get field => widget.field;

  @override
  void initState() {
    super.initState();
    labelCtrl = TextEditingController(text: field.label);
    hintCtrl = TextEditingController(text: field.hint);
    required = field.required;
    optionCtrls = field.options
        .map((o) => TextEditingController(text: o))
        .toList();
  }

  @override
  void dispose() {
    labelCtrl.dispose();
    hintCtrl.dispose();
    for (final c in optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  FormFieldSpec _build() {
    final labelText = labelCtrl.text.trim();
    return FormFieldSpec(
      id: field.id,
      type: field.type,
      label: labelText.isEmpty
          ? (field.isHeader ? 'Section title' : field.type.displayName)
          : labelText,
      hint: hintCtrl.text.trim(),
      required: field.isHeader ? false : required,
      options: field.isChoice
          ? optionCtrls
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList()
          : const [],
      profileSource: field.profileSource,
      optionSource: field.optionSource,
    );
  }

  String _getLabelHintText(FormFieldType type) {
    return switch (type) {
      FormFieldType.header => 'e.g., Personal Information',
      FormFieldType.shortText => 'e.g., What is your full name?',
      FormFieldType.longText => 'e.g., Describe your project experience',
      FormFieldType.singleChoice => 'e.g., What is your shirt size?',
      FormFieldType.multiChoice => 'e.g., Which topics interest you?',
      FormFieldType.dropdown => 'e.g., Select your year of study',
      FormFieldType.number => 'e.g., What is your age?',
      FormFieldType.phone => 'e.g., What is your contact number?',
      FormFieldType.email => 'e.g., What is your email address?',
      FormFieldType.date => 'e.g., Date of event attendance',
      FormFieldType.rating => 'e.g., How would you rate this session?',
    };
  }

  String _getHelperHintText(FormFieldType type) {
    return switch (type) {
      FormFieldType.header => 'Optional section description',
      FormFieldType.shortText => 'e.g., Enter answer in 1-2 words',
      FormFieldType.longText => 'e.g., Provide details below',
      FormFieldType.singleChoice => 'e.g., Choose one option',
      FormFieldType.multiChoice => 'e.g., Select all that apply',
      FormFieldType.dropdown => 'e.g., Tap to pick from list',
      FormFieldType.number => 'e.g., Digits only',
      FormFieldType.phone => 'e.g., Enter 10-digit mobile number',
      FormFieldType.email => 'e.g., Enter valid @student.edu email',
      FormFieldType.date => 'e.g., Pick a date',
      FormFieldType.rating => 'e.g., Select 1 (Poor) to 5 (Excellent)',
    };
  }

  @override
  Widget build(BuildContext context) {
    final showOptions = field.isChoice;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Icon(field.type.icon, color: widget.accent, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              field.isHeader ? 'Edit Section Header' : 'Edit Question Details',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: labelCtrl,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: field.isHeader ? 'Section title' : 'Question label / title *',
                hintText: _getLabelHintText(field.type),
                border: const OutlineInputBorder(),
              ),
            ),
            if (!field.isHeader) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: hintCtrl,
                decoration: InputDecoration(
                  labelText: 'Helper text (optional)',
                  hintText: _getHelperHintText(field.type),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Required question',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                value: required,
                onChanged: (v) => setState(() => required = v),
              ),
            ],
            if (showOptions) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  field.type == FormFieldType.dropdown
                      ? 'Dropdown Choices'
                      : 'Answer Options',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < optionCtrls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        field.type == FormFieldType.singleChoice
                            ? Icons.radio_button_unchecked
                            : field.type == FormFieldType.multiChoice
                                ? Icons.check_box_outline_blank
                                : Icons.arrow_drop_down_circle_outlined,
                        size: 18,
                        color: widget.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: optionCtrls[i],
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Option ${i + 1}',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: optionCtrls.length > 2
                            ? () => setState(() => optionCtrls.removeAt(i))
                            : null,
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => optionCtrls.add(TextEditingController())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add option'),
                ),
              ),
            ],
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
          onPressed: () {
            final configured = _build();
            if (showOptions && configured.options.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add at least 2 options.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            Navigator.of(context).pop(configured);
          },
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}