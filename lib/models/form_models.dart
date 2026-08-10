import 'package:flutter/material.dart';

/// Enum for what a field pulls from the user's profile at fill time.
enum ProfileSource { name, id, department, year, mobile }

/// Enum for dropdown fields that resolve their options from app config.
enum OptionSource { none, departments, academicYears }

/// A clickable external link attached to a post/event (e.g. Google Meet,
/// Google Form, brochure page). Rendered as chip buttons on the card.
class PostLink {
  final String label;
  final String url;

  const PostLink({required this.label, required this.url});

  PostLink copyWith({String? label, String? url}) =>
      PostLink(label: label ?? this.label, url: url ?? this.url);

  Map<String, dynamic> toJson() => {'label': label, 'url': url};

  static PostLink fromJson(Map<String, dynamic> m) => PostLink(
    label: m['label']?.toString() ?? '',
    url: m['url']?.toString() ?? '',
  );
}

/// The 11 field kinds a host/faculty can add to a form.
enum FormFieldType {
  header,
  shortText,
  longText,
  singleChoice,
  multiChoice,
  dropdown,
  number,
  phone,
  email,
  date,
  rating;

  String get displayName => switch (this) {
    FormFieldType.header => 'Header / Section',
    FormFieldType.shortText => 'Short text',
    FormFieldType.longText => 'Long text',
    FormFieldType.singleChoice => 'Single choice',
    FormFieldType.multiChoice => 'Multiple choice',
    FormFieldType.dropdown => 'Dropdown',
    FormFieldType.number => 'Number',
    FormFieldType.phone => 'Phone number',
    FormFieldType.email => 'Email',
    FormFieldType.date => 'Date',
    FormFieldType.rating => 'Rating (1–5)',
  };

  IconData get icon => switch (this) {
    FormFieldType.header => Icons.title_outlined,
    FormFieldType.shortText => Icons.short_text_outlined,
    FormFieldType.longText => Icons.notes_outlined,
    FormFieldType.singleChoice => Icons.radio_button_checked,
    FormFieldType.multiChoice => Icons.check_box_outlined,
    FormFieldType.dropdown => Icons.arrow_drop_down_circle_outlined,
    FormFieldType.number => Icons.tag_outlined,
    FormFieldType.phone => Icons.phone_android_outlined,
    FormFieldType.email => Icons.alternate_email_outlined,
    FormFieldType.date => Icons.calendar_today_outlined,
    FormFieldType.rating => Icons.star_outline_rounded,
  };

  bool get isChoice =>
      this == FormFieldType.singleChoice ||
      this == FormFieldType.multiChoice ||
      this == FormFieldType.dropdown;

  bool get isTextInput =>
      this == FormFieldType.shortText ||
      this == FormFieldType.longText ||
      this == FormFieldType.number ||
      this == FormFieldType.phone ||
      this == FormFieldType.email;
}

/// One question/block inside a form definition.
class FormFieldSpec {
  final String id;
  final FormFieldType type;
  final String label;
  final String hint;
  final bool required;
  final List<String> options;
  final ProfileSource? profileSource;
  final OptionSource optionSource;

  const FormFieldSpec({
    required this.id,
    required this.type,
    this.label = '',
    this.hint = '',
    this.required = false,
    this.options = const [],
    this.profileSource,
    this.optionSource = OptionSource.none,
  });

  bool get isHeader => type == FormFieldType.header;
  bool get isChoice => type.isChoice;
  bool get hasDynamicOptions => optionSource != OptionSource.none;

  FormFieldSpec copyWith({
    String? id,
    FormFieldType? type,
    String? label,
    String? hint,
    bool? required,
    List<String>? options,
    ProfileSource? profileSource,
    OptionSource? optionSource,
  }) => FormFieldSpec(
    id: id ?? this.id,
    type: type ?? this.type,
    label: label ?? this.label,
    hint: hint ?? this.hint,
    required: required ?? this.required,
    options: options ?? this.options,
    profileSource: profileSource ?? this.profileSource,
    optionSource: optionSource ?? this.optionSource,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'label': label,
    'hint': hint,
    'required': required,
    'options': options,
    'profileSource': profileSource?.name,
    'optionSource': optionSource.name,
  };

  static FormFieldSpec fromJson(Map<String, dynamic> m) => FormFieldSpec(
    id: m['id']?.toString() ?? '',
    type: FormFieldType.values.firstWhere(
      (t) => t.name == m['type'],
      orElse: () => FormFieldType.shortText,
    ),
    label: m['label']?.toString() ?? '',
    hint: m['hint']?.toString() ?? '',
    required: m['required'] as bool? ?? false,
    options: ((m['options'] as List?) ?? const []).cast<String>(),
    profileSource: m['profileSource'] == null
        ? null
        : ProfileSource.values.firstWhere(
            (s) => s.name == m['profileSource'],
            orElse: () => ProfileSource.name,
          ),
    optionSource: OptionSource.values.firstWhere(
      (s) => s.name == m['optionSource'],
      orElse: () => OptionSource.none,
    ),
  );
}

/// The full form definition a host attaches to an event/workshop/post.
class FormDefinition {
  final String id;
  final String title;
  final String headerText;
  final List<FormFieldSpec> fields;
  final bool allowResubmit;

  const FormDefinition({
    required this.id,
    required this.title,
    this.headerText = '',
    this.fields = const [],
    this.allowResubmit = false,
  });

  int get questionCount => fields.where((f) => !f.isHeader).length;

  FormDefinition copyWith({
    String? id,
    String? title,
    String? headerText,
    List<FormFieldSpec>? fields,
    bool? allowResubmit,
  }) => FormDefinition(
    id: id ?? this.id,
    title: title ?? this.title,
    headerText: headerText ?? this.headerText,
    fields: fields ?? this.fields,
    allowResubmit: allowResubmit ?? this.allowResubmit,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'headerText': headerText,
    'fields': fields.map((f) => f.toJson()).toList(),
    'allowResubmit': allowResubmit,
  };

  static FormDefinition? fromJson(dynamic value) {
    if (value is! Map) return null;
    final m = value.cast<String, dynamic>();
    return FormDefinition(
      id: m['id']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      headerText: m['headerText']?.toString() ?? '',
      fields: ((m['fields'] as List?) ?? const [])
          .whereType<Map>()
          .map((f) => FormFieldSpec.fromJson(f.cast<String, dynamic>()))
          .toList(),
      allowResubmit: m['allowResubmit'] as bool? ?? false,
    );
  }
}

/// One filled form entry. Included with a snapshot of the student's profile
/// at submit time so hosts can view/download data even without a user
/// directory. [formId] is null for quick one-tap registrations.
class FormSubmission {
  final String id;
  final String postId;
  final String? formId;
  final String userId;
  final String name;
  final String studentOrEmployeeId;
  final String department;
  final String year;
  final String mobileNumber;
  final Map<String, dynamic> answers;
  final DateTime submittedAt;

  const FormSubmission({
    required this.id,
    required this.postId,
    this.formId,
    required this.userId,
    required this.name,
    this.studentOrEmployeeId = '',
    this.department = '',
    this.year = '',
    this.mobileNumber = '',
    this.answers = const {},
    required this.submittedAt,
  });

  FormSubmission copyWith({
    String? name,
    String? studentOrEmployeeId,
    String? department,
    String? year,
    String? mobileNumber,
    Map<String, dynamic>? answers,
  }) => FormSubmission(
    id: id,
    postId: postId,
    formId: formId,
    userId: userId,
    name: name ?? this.name,
    studentOrEmployeeId: studentOrEmployeeId ?? this.studentOrEmployeeId,
    department: department ?? this.department,
    year: year ?? this.year,
    mobileNumber: mobileNumber ?? this.mobileNumber,
    answers: answers ?? this.answers,
    submittedAt: submittedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'postId': postId,
    'formId': formId,
    'userId': userId,
    'name': name,
    'studentOrEmployeeId': studentOrEmployeeId,
    'department': department,
    'year': year,
    'mobileNumber': mobileNumber,
    'answers': answers,
    'submittedAt': submittedAt.toIso8601String(),
  };

  static FormSubmission fromJson(Map<String, dynamic> m) => FormSubmission(
    id: m['id']?.toString() ?? '',
    postId: m['postId']?.toString() ?? '',
    formId: m['formId'] as String?,
    userId: m['userId']?.toString() ?? '',
    name: m['name']?.toString() ?? '',
    studentOrEmployeeId: m['studentOrEmployeeId']?.toString() ?? '',
    department: m['department']?.toString() ?? '',
    year: m['year']?.toString() ?? '',
    mobileNumber: m['mobileNumber']?.toString() ?? '',
    answers: ((m['answers'] as Map?) ?? const {}).cast<String, dynamic>(),
    submittedAt:
        DateTime.tryParse(m['submittedAt']?.toString() ?? '') ??
        DateTime.now(),
  );
}

/// A ready-to-use starting layout for the form builder.
class FormTemplate {
  final String name;
  final String description;
  final IconData icon;
  final List<FormFieldSpec> fields;

  const FormTemplate({
    required this.name,
    required this.description,
    required this.icon,
    required this.fields,
  });
}

int _fieldCounter = 0;
String _nextFieldId(String prefix) => '${prefix}_${_fieldCounter++}';

/// Preset form templates. Prefill fields bind to the student's profile
/// so the fill screen is one-tap friendly.
const List<FormTemplate> kFormTemplates = [
  FormTemplate(
    name: 'Contact Information',
    description: 'Name, MIT ID, department & mobile — the classic attendee form',
    icon: Icons.contact_page_outlined,
    fields: [
      FormFieldSpec(
        id: 'hd_contact',
        type: FormFieldType.header,
        label: 'About yourself',
      ),
      FormFieldSpec(
        id: 'fullName',
        type: FormFieldType.shortText,
        label: 'Full Name *',
        required: true,
        profileSource: ProfileSource.name,
      ),
      FormFieldSpec(
        id: 'mitId',
        type: FormFieldType.shortText,
        label: 'MIT ID (Student / Employee) *',
        required: true,
        profileSource: ProfileSource.id,
      ),
      FormFieldSpec(
        id: 'dept',
        type: FormFieldType.dropdown,
        label: 'Department *',
        required: true,
        optionSource: OptionSource.departments,
        profileSource: ProfileSource.department,
      ),
      FormFieldSpec(
        id: 'year',
        type: FormFieldType.dropdown,
        label: 'Academic Year *',
        required: true,
        optionSource: OptionSource.academicYears,
        profileSource: ProfileSource.year,
      ),
      FormFieldSpec(
        id: 'mobile',
        type: FormFieldType.phone,
        label: 'Mobile Number *',
        required: true,
        profileSource: ProfileSource.mobile,
      ),
    ],
  ),
  FormTemplate(
    name: 'Event Registration',
    description: 'Attendee details with participation preferences',
    icon: Icons.event_available_outlined,
    fields: [
      FormFieldSpec(
        id: 'hd_event',
        type: FormFieldType.header,
        label: 'Event registration details',
      ),
      FormFieldSpec(
        id: 'fullName',
        type: FormFieldType.shortText,
        label: 'Full Name *',
        required: true,
        profileSource: ProfileSource.name,
      ),
      FormFieldSpec(
        id: 'mitId',
        type: FormFieldType.shortText,
        label: 'MIT ID *',
        required: true,
        profileSource: ProfileSource.id,
      ),
      FormFieldSpec(
        id: 'teamSize',
        type: FormFieldType.dropdown,
        label: 'Team Size',
        options: ['Solo (1)', '2 members', '3 members', '4 members', '5 members'],
      ),
      FormFieldSpec(
        id: 'mode',
        type: FormFieldType.singleChoice,
        label: 'Mode of Participation',
        required: true,
        options: ['Offline', 'Online'],
      ),
      FormFieldSpec(
        id: 'notes',
        type: FormFieldType.longText,
        label: 'Anything we should know?',
        hint: 'Optional request, dietary need, etc.',
      ),
    ],
  ),
  FormTemplate(
    name: 'Feedback Form',
    description: 'Rating + short comments — great after an event',
    icon: Icons.rate_review_outlined,
    fields: [
      FormFieldSpec(
        id: 'hd_feedback',
        type: FormFieldType.header,
        label: 'Share your feedback',
      ),
      FormFieldSpec(
        id: 'rating',
        type: FormFieldType.rating,
        label: 'Overall rating *',
        required: true,
      ),
      FormFieldSpec(
        id: 'useful',
        type: FormFieldType.singleChoice,
        label: 'Was the content useful? *',
        required: true,
        options: ['Yes, very useful', 'Somewhat', 'Not really'],
      ),
      FormFieldSpec(
        id: 'suggest',
        type: FormFieldType.longText,
        label: 'What did you like, or what can we improve?',
        hint: 'Optional',
      ),
      FormFieldSpec(
        id: 'contact',
        type: FormFieldType.email,
        label: 'Email (for follow-up)',
        hint: 'Optional',
      ),
    ],
  ),
  FormTemplate(
    name: 'RSVP',
    description: 'Quick attendance confirmation',
    icon: Icons.event_repeat_outlined,
    fields: [
      FormFieldSpec(
        id: 'hd_rsvp',
        type: FormFieldType.header,
        label: 'Please confirm your attendance',
      ),
      FormFieldSpec(
        id: 'attend',
        type: FormFieldType.singleChoice,
        label: 'Will you attend? *',
        required: true,
        options: ['Yes, I will be there', 'No, can\'t make it', 'Maybe'],
      ),
      FormFieldSpec(
        id: 'guests',
        type: FormFieldType.dropdown,
        label: 'Number of guests',
        options: ['0', '1', '2', '3'],
      ),
      FormFieldSpec(
        id: 'requests',
        type: FormFieldType.longText,
        label: 'Special requests',
        hint: 'Optional',
      ),
    ],
  ),
];

List<FormFieldSpec> _templateFields(FormTemplate t) =>
    t.fields.map((f) => f.copyWith(id: _nextFieldId(f.id))).toList();

/// Returns a deep copy of a template's fields with fresh ids.
List<FormFieldSpec> fieldsForTemplate(FormTemplate template) =>
    _templateFields(template);

/// Creates a fresh blank form definition (no questions yet).
FormDefinition blankForm({String? title}) => FormDefinition(
  id: 'frm_${DateTime.now().millisecondsSinceEpoch}',
  title: title?.trim().isNotEmpty == true
      ? title!.trim()
      : 'Untitled Form',
);

String newFieldId(FormFieldType type) => _nextFieldId(type.name);