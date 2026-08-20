import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/form_models.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';
import '../utils/date_formatter.dart';

/// Opens the registration/response form for a post. Routes based on state:
///  - not registered & form attached  -> editable form, prefilled from profile
///  - already submitted               -> read-only summary (+ edit/withdraw when allowed)
Future<void> openRegistrationForm(
  BuildContext context,
  PostModel post,
) async {
  final service = Provider.of<MockDataService>(context, listen: false);
  if (service.currentUser.cancelledEventIds.contains(post.id)) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Registration Blocked', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'sorry,you cant no more register for event,if you eager contact host/faculty',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: service.config.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FormFillScreen(post: post),
    ),
  );
}

class FormFillScreen extends StatefulWidget {
  final PostModel post;

  /// Pre-fills every answer (used when editing an existing submission).
  final Map<String, dynamic>? initialAnswers;

  /// When true, submits via [MockDataService.updateMySubmission] instead of
  /// creating a new submission.
  final bool editing;

  const FormFillScreen({
    super.key,
    required this.post,
    this.initialAnswers,
    this.editing = false,
  });

  @override
  State<FormFillScreen> createState() => _FormFillScreenState();
}

class _FormFillScreenState extends State<FormFillScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _textCtrls;
  late final Map<String, String> _singleSelections;
  late final Map<String, List<String>> _multiSelections;
  late final Map<String, String> _dropdownSelections;
  late final Map<String, DateTime> _dateSelections;
  late final Map<String, int> _ratings;

  UserModel? _user;
  bool _submitting = false;

  MockDataService get _service =>
      Provider.of<MockDataService>(context, listen: false);

  FormDefinition? get _form => widget.post.form;

  @override
  void initState() {
    super.initState();
    _user = _service.currentUser;
    _textCtrls = {};
    _singleSelections = {};
    _multiSelections = {};
    _dropdownSelections = {};
    _dateSelections = {};
    _ratings = {};
    final form = _form;
    if (form != null) {
      for (final f in form.fields) {
        if (f.isHeader) continue;
        String? prefilled;
        final existing = widget.initialAnswers?[f.id];
        if (existing != null && existing.toString().isNotEmpty) {
          prefilled = existing is List ? existing.join(',') : '$existing';
        } else {
          prefilled = _prefillFor(f);
        }
        switch (f.type) {
          case FormFieldType.shortText:
          case FormFieldType.longText:
          case FormFieldType.number:
          case FormFieldType.phone:
          case FormFieldType.email:
            _textCtrls[f.id] = TextEditingController(text: prefilled ?? '');
          case FormFieldType.singleChoice:
            _singleSelections[f.id] = prefilled ?? '';
          case FormFieldType.multiChoice:
            _multiSelections[f.id] = prefilled == null || prefilled.isEmpty
                ? []
                : (prefilled.split(','));
          case FormFieldType.dropdown:
            _dropdownSelections[f.id] = prefilled ?? '';
          case FormFieldType.date:
            if (prefilled != null) {
              _dateSelections[f.id] = DateTime.tryParse(prefilled) ??
                  DateTime.now().add(const Duration(days: 1));
            }
          case FormFieldType.rating:
            _ratings[f.id] = int.tryParse(prefilled ?? '') ?? 0;
          case FormFieldType.header:
            break;
        }
      }
    }
  }

  String? _prefillFor(FormFieldSpec field) {
    final source = field.profileSource;
    final user = _user;
    if (source == null || user == null) return null;
    return switch (source) {
      ProfileSource.name => user.name,
      ProfileSource.id => user.studentOrEmployeeId,
      ProfileSource.department => user.department,
      ProfileSource.year => user.year,
      ProfileSource.mobile =>
        user.mobileNumber.isEmpty ? null : user.mobileNumber,
    };
  }

  @override
  void dispose() {
    for (final c in _textCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _optionsFor(FormFieldSpec f) {
    if (f.options.isNotEmpty) return f.options;
    final config = _service.config;
    return switch (f.optionSource) {
      OptionSource.departments => config.departments,
      OptionSource.academicYears => config.academicYears,
      OptionSource.none => const [],
    };
  }

  String? _validate(FormFieldSpec f) {
    if (!f.required) return null;
    switch (f.type) {
      case FormFieldType.shortText:
      case FormFieldType.longText:
        final v = _textCtrls[f.id]?.text.trim() ?? '';
        return v.isEmpty ? 'Please answer this question' : null;
      case FormFieldType.number:
        final v = _textCtrls[f.id]?.text.trim() ?? '';
        if (v.isEmpty) return 'Please answer this question';
        return double.tryParse(v) == null
            ? 'Enter a valid number'
            : null;
      case FormFieldType.phone:
        final v = _textCtrls[f.id]?.text.trim() ?? '';
        if (v.isEmpty) return 'Please answer this question';
        final digits = v.replaceAll(RegExp(r'\D'), '');
        return digits.length < 10 ? 'Enter a valid mobile number' : null;
      case FormFieldType.email:
        final v = _textCtrls[f.id]?.text.trim() ?? '';
        if (v.isEmpty) return 'Please answer this question';
        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
            ? null
            : 'Enter a valid email address';
      case FormFieldType.singleChoice:
      case FormFieldType.dropdown:
        return (_singleSelections[f.id] ?? '').isEmpty &&
                (_dropdownSelections[f.id] ?? '').isEmpty
            ? 'Please choose an option'
            : null;
      case FormFieldType.multiChoice:
        return (_multiSelections[f.id] ?? const []).isEmpty
            ? 'Please select at least one option'
            : null;
      case FormFieldType.date:
        return _dateSelections[f.id] == null ? 'Please pick a date' : null;
      case FormFieldType.rating:
        return (_ratings[f.id] ?? 0) == 0
            ? 'Please tap a star rating'
            : null;
      case FormFieldType.header:
        return null;
    }
  }

  Map<String, dynamic> _collectAnswers() {
    final answers = <String, dynamic>{};
    final form = _form;
    if (form == null) return answers;
    for (final f in form.fields) {
      if (f.isHeader) continue;
      switch (f.type) {
        case FormFieldType.shortText:
        case FormFieldType.longText:
        case FormFieldType.number:
        case FormFieldType.phone:
        case FormFieldType.email:
          final v = _textCtrls[f.id]?.text.trim() ?? '';
          if (v.isNotEmpty || f.required) answers[f.id] = v;
        case FormFieldType.singleChoice:
          final v = _singleSelections[f.id] ?? '';
          if (v.isNotEmpty || f.required) answers[f.id] = v;
        case FormFieldType.multiChoice:
          final v = _multiSelections[f.id] ?? const [];
          if (v.isNotEmpty || f.required) answers[f.id] = v;
        case FormFieldType.dropdown:
          final v = _dropdownSelections[f.id] ?? '';
          if (v.isNotEmpty || f.required) answers[f.id] = v;
        case FormFieldType.date:
          final v = _dateSelections[f.id];
          if (v != null || f.required) {
            answers[f.id] = v?.toIso8601String() ?? '';
          }
        case FormFieldType.rating:
          final v = _ratings[f.id] ?? 0;
          if (v != 0 || f.required) answers[f.id] = v;
        case FormFieldType.header:
          break;
      }
    }
    return answers;
  }

  Future<void> _submit() async {
    final form = _form;
    if (form == null) return;
    final valid = _formKey.currentState?.validate() ?? false;
    // Choice/dropdown/rating sections render errors from state, so a rebuild
    // after a failed validation surfaces them immediately.
    setState(() {});
    if (!valid) return;
    setState(() => _submitting = true);
    final answers = _collectAnswers();
    final ok = widget.editing
        ? await Future.value(true)
        : await _service.submitForm(post: widget.post, answers: answers);
    if (ok && widget.editing) {
      _service.updateMySubmission(postId: widget.post.id, answers: answers);
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration is closed for this event.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.of(context).pop(true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.editing
                ? '✅ Your response was updated.'
                : widget.post.isEvent
                    ? '🎉 Registered successfully for "${widget.post.title}"!'
                    : '✅ Response submitted!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  bool get _alreadySubmitted =>
      _service.submissionsForPost(widget.post.id).any(
        (s) => s.userId == _service.currentUser.id,
      );

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final form = _form;
    final isEvent = post.isEvent;
    final accent = isEvent
        ? _service.config.eventColor
        : _service.config.primaryColor;

    if (form == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Form')),
        body: const Center(child: Text('This form is no longer available.')),
      );
    }

    final submitted = _alreadySubmitted;
    final mySubmission = _service
        .submissionsForPost(post.id)
        .where((s) => s.userId == _service.currentUser.id)
        .firstOrNull;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        title: Text(isEvent ? '📝 Event Registration' : '📝 Form'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            if (post.authorId == _service.currentUser.id || _service.currentUser.hasRole(UserRole.faculty)) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    Icon(Icons.remove_red_eye_outlined, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '👁️ Host Form Preview Mode',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          const Text(
                            'You are reviewing your published form. Submissions are disabled for the creator.',
                            style: TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Hero card with the post title
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.75)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    form.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (form.headerText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      form.headerText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.how_to_reg,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isEvent ? post.title : 'Response form',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (submitted) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEvent
                            ? 'You are registered! Tap "Edit" above to update your details.'
                            : 'You already submitted a response.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (mySubmission != null)
                _SubmissionSummaryCard(submission: mySubmission, form: form),
              if (isEvent && submitted) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.amber, size: 24),
                              SizedBox(width: 8),
                              Text('Cancel Registration?',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          content: const Text(
                            'You cant register again,So are tou sure cancel registration ?',
                            style: TextStyle(fontSize: 14, height: 1.4),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogCtx).pop(),
                              child: const Text('No',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(dialogCtx).pop();
                                _service.cancelRegistrationPermanently(widget.post.id);
                                if (mounted) Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Registration cancelled.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              },
                              child: const Text('Yes',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.event_busy_outlined, size: 18),
                    label: const Text(
                      'Cancel my registration',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 14),
              Text(
                'Fill in your details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              for (final f in form.fields) ...[
                _fieldWidget(f, accent),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: (post.authorId == _service.currentUser.id || _service.currentUser.hasRole(UserRole.faculty))
                  ? Colors.grey.shade400
                  : accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(
              (post.authorId == _service.currentUser.id || _service.currentUser.hasRole(UserRole.faculty))
                  ? Icons.lock_outline
                  : Icons.send_outlined,
              size: 19,
            ),
            label: Text(
              (post.authorId == _service.currentUser.id || _service.currentUser.hasRole(UserRole.faculty))
                  ? 'Host Preview Mode (Disabled)'
                  : _submitting
                      ? 'Submitting…'
                      : isEvent
                          ? 'Register for Event'
                          : 'Submit Response',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
                  onPressed: (_submitting || submitted || post.authorId == _service.currentUser.id || _service.currentUser.hasRole(UserRole.faculty))
                ? null
                : _submit,
          ),
        ),
      ),
    );
  }

  Widget _fieldWidget(FormFieldSpec f, Color accent) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (f.isHeader) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                f.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final requiredTag = f.required
        ? Text('*', style: TextStyle(color: Colors.red.shade600))
        : const SizedBox.shrink();
    final label = Row(
      children: [
        Flexible(
          child: Text(
            f.label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 3),
        requiredTag,
      ],
    );

    switch (f.type) {
      case FormFieldType.shortText:
      case FormFieldType.longText:
      case FormFieldType.number:
      case FormFieldType.phone:
      case FormFieldType.email:
        final type = f.type;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label,
            const SizedBox(height: 7),
            TextFormField(
              controller: _textCtrls[f.id],
              maxLines: type == FormFieldType.longText ? 4 : 1,
              keyboardType: switch (type) {
                FormFieldType.number => TextInputType.number,
                FormFieldType.phone => TextInputType.phone,
                FormFieldType.email => TextInputType.emailAddress,
                _ => TextInputType.text,
              },
              decoration: InputDecoration(
                hintText: f.hint.isEmpty ? null : f.hint,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                  ),
                ),
              ),
              validator: (_) => _validate(f),
            ),
          ],
        );

      case FormFieldType.singleChoice:
      case FormFieldType.multiChoice:
        final options = _optionsFor(f);
        final multi = f.type == FormFieldType.multiChoice;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label,
            const SizedBox(height: 7),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                ),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < options.length; i++)
                    _ChoiceTile(
                      title: options[i],
                      selected: multi
                          ? (_multiSelections[f.id] ?? const []).contains(
                              options[i],
                            )
                          : _singleSelections[f.id] == options[i],
                      multi: multi,
                      accent: accent,
                      onTap: () {
                        setState(() {
                          if (multi) {
                            final list = List<String>.from(
                              _multiSelections[f.id] ?? const [],
                            );
                            if (list.contains(options[i])) {
                              list.remove(options[i]);
                            } else {
                              list.add(options[i]);
                            }
                            _multiSelections[f.id] = list;
                          } else {
                            _singleSelections[f.id] = options[i];
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            if (_validate(f) != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  _validate(f)!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        );

      case FormFieldType.dropdown:
        final options = _optionsFor(f);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label,
            const SizedBox(height: 7),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  showDragHandle: true,
                  builder: (ctx) => SafeArea(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            f.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        for (final o in options)
                          ListTile(
                            title: Text(
                              o,
                              style: const TextStyle(fontSize: 14),
                            ),
                            trailing: _dropdownSelections[f.id] == o
                                ? Icon(Icons.check_circle, color: accent)
                                : null,
                            onTap: () => Navigator.of(ctx).pop(o),
                          ),
                      ],
                    ),
                  ),
                );
                if (picked != null && mounted) {
                  setState(() => _dropdownSelections[f.id] = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        (_dropdownSelections[f.id] ?? '').isEmpty
                            ? 'Choose an option'
                            : _dropdownSelections[f.id]!,
                        style: TextStyle(
                          fontSize: 14,
                          color: (_dropdownSelections[f.id] ?? '').isEmpty
                              ? Colors.grey.shade500
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
            if (_validate(f) != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  _validate(f)!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        );

      case FormFieldType.date:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label,
            const SizedBox(height: 7),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final today = DateTime.now();
                final todayDate = DateTime(today.year, today.month, today.day);
                final maxDate =
                    todayDate.add(const Duration(days: 365));
                var initial = _dateSelections[f.id] ?? todayDate.add(const Duration(days: 1));
                if (initial.isBefore(todayDate)) {
                  initial = todayDate.add(const Duration(days: 1));
                } else if (initial.isAfter(maxDate)) {
                  initial = maxDate;
                }
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: todayDate,
                  lastDate: maxDate,
                );
                if (picked != null && mounted) {
                  setState(() => _dateSelections[f.id] = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 10),
                    Text(
                      _dateSelections[f.id] == null
                          ? 'Pick a date'
                          : formatEventDateTime(_dateSelections[f.id]!),
                      style: TextStyle(
                        fontSize: 14,
                        color: _dateSelections[f.id] == null
                            ? Colors.grey.shade500
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case FormFieldType.rating:
        final rating = _ratings[f.id] ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label,
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      icon: Icon(
                        i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 28,
                      ),
                      onPressed: () => setState(() => _ratings[f.id] = i),
                    ),
                ],
              ),
            ),
          ],
        );

      case FormFieldType.header:
        return const SizedBox.shrink();
    }
  }
}

class _ChoiceTile extends StatelessWidget {
  final String title;
  final bool selected;
  final bool multi;
  final Color accent;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.title,
    required this.selected,
    required this.multi,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              multi
                  ? (selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded)
                  : (selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked),
              color: selected ? accent : Colors.grey.shade500,
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.grey.shade400 : Colors.black54),
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 17, color: accent),
          ],
        ),
      ),
    );
  }
}

class _SubmissionSummaryCard extends StatelessWidget {
  final FormSubmission submission;
  final FormDefinition form;

  const _SubmissionSummaryCard({
    required this.submission,
    required this.form,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final byId = {for (final f in form.fields) f.id: f};
    final rows = <Widget>[];
    submission.answers.forEach((key, value) {
      final label = byId[key]?.label.isNotEmpty == true
          ? byId[key]!.label
          : key;
      final text = value is List ? value.join(', ') : '$value';
      if (text.isEmpty) return;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
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
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    });
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined,
                  size: 18, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Your submitted details',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }
}