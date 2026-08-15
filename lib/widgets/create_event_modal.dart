import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/form_models.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import '../utils/date_formatter.dart';
import 'custom_dropdown.dart';
import 'image_picker_field.dart';
import 'link_form_editor.dart';

class CreateEventModal extends StatefulWidget {
  const CreateEventModal({super.key});

  @override
  State<CreateEventModal> createState() => _CreateEventModalState();
}

class _CreateEventModalState extends State<CreateEventModal> {
  final _formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final venueController = TextEditingController();
  final maxSeatsController = TextEditingController(text: '100');
  String? targetYear;
  String? selectedImageUrl;
  PostCategory eventKind = PostCategory.event;
  bool _isPublishing = false;

  List<PostLink> links = [];
  FormDefinition? form;

  late String department;
  DateTime eventDate = DateTime.now().add(const Duration(days: 3));
  DateTime regDeadline = DateTime.now().add(const Duration(days: 2));

  @override
  void initState() {
    super.initState();
    final dataService = Provider.of<MockDataService>(context, listen: false);
    department = dataService.currentUser.department;
  }

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    venueController.dispose();
    maxSeatsController.dispose();
    super.dispose();
  }

  Future<void> _publishEvent() async {
    final dataService = Provider.of<MockDataService>(context, listen: false);

    if (!_formKey.currentState!.validate()) return;

    final image = selectedImageUrl;
    if (image == null || image.trim().isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(Icons.image_not_supported_outlined,
              color: Colors.orange, size: 40),
          title: const Text('Cover image required'),
          content: const Text(
            'Please upload a cover image before publishing your event.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isPublishing = true);

    final online = await dataService.checkBackendReachable();
    if (!mounted) return;
    if (!online) {
      setState(() => _isPublishing = false);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(Icons.wifi_off, color: Colors.red, size: 40),
          title: const Text('No Internet Connection'),
          content: const Text(
            'Please turn on your internet and try again. Your event was not published.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final maxCap = int.tryParse(maxSeatsController.text.trim()) ?? 100;

    final newEvent = PostModel(
      id: 'pst_${DateTime.now().millisecondsSinceEpoch}',
      title: titleController.text.trim(),
      description: descController.text.trim(),
      category: eventKind,
      department: department,
      targetYear: targetYear,
      authorName: dataService.currentUser.name,
      authorRole: dataService.activeRole,
      authorId: dataService.currentUser.id,
      authorAvatarUrl: dataService.currentUser.avatarUrl,
      timestamp: DateTime.now(),
      imageUrl: selectedImageUrl,
      venue: venueController.text.trim(),
      eventDate: eventDate,
      registrationDeadline: regDeadline,
      maxParticipants: maxCap,
      registeredUserIds: const [],
      links: links,
      form: form,
    );

    dataService.addPost(newEvent);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚀 Event published to Campus Feed & Events Hub!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<DateTime?> _pickEventDateTime({
    required DateTime initial,
    required DateTime first,
    required DateTime last,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (date == null) return null;
    if (!mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    if (!mounted) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final cfg = dataService.config;
    final yearOptions = ['All Academic Years', ...cfg.academicYears];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.event_available_rounded, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Create Event & Workshops',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          physics: const BouncingScrollPhysics(),
          children: [
            // Kind Selector
            SegmentedButton<PostCategory>(
              segments: const [
                ButtonSegment(
                  value: PostCategory.event,
                  label: Text('🎪 Campus Event', style: TextStyle(fontWeight: FontWeight.bold)),
                  icon: Icon(Icons.event_rounded),
                ),
                ButtonSegment(
                  value: PostCategory.workshop,
                  label: Text('🛠️ Workshop', style: TextStyle(fontWeight: FontWeight.bold)),
                  icon: Icon(Icons.construction_rounded),
                ),
              ],
              selected: {eventKind},
              onSelectionChanged: (selection) {
                setState(() => eventKind = selection.first);
              },
            ),
            const SizedBox(height: 14),

            // Event Details Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Event Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Event Title *',
                      hintText: 'e.g. HackCampus 2026 24-Hour Hackathon',
                      prefixIcon: const Icon(Icons.event_note_rounded, color: Colors.orange),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter event title' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Event Description *',
                      hintText: 'Rules, prerequisites, agenda and team details...',
                      prefixIcon: const Icon(Icons.description_outlined, color: Colors.orange),
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter event details' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: venueController,
                    decoration: InputDecoration(
                      labelText: 'Venue / Hall / Lab *',
                      hintText: 'e.g. Main Auditorium / Lab 302',
                      prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.orange),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter venue' : null,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: maxSeatsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Max Capacity',
                            prefixIcon: const Icon(Icons.groups_outlined, color: Colors.orange),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomDropdownField<String>(
                          value: department,
                          labelText: 'Host Dept',
                          items: cfg.departments,
                          itemLabel: (d) => d,
                          onChanged: (val) {
                            if (val != null) setState(() => department = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Target Academic Year Card (No "(Optional)")
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CustomDropdownField<String>(
                value: targetYear ?? 'All Academic Years',
                labelText: 'Target Academic Year',
                prefixIcon: Icons.calendar_month_outlined,
                items: yearOptions,
                itemLabel: (y) => y,
                onChanged: (val) {
                  setState(() {
                    targetYear = (val == 'All Academic Years') ? null : val;
                  });
                },
              ),
            ),
            const SizedBox(height: 14),

            // Required Cover Image Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Event Cover Poster *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ImagePickerField(
                    label: 'Cover Image',
                    initialUrl: selectedImageUrl,
                    onImageSelected: (url) {
                      setState(() => selectedImageUrl = url);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Date & Deadline Schedule Cards
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date & Schedule',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),

                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    tileColor: const Color(0xFFF8FAFC),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.event_rounded, color: Colors.orange, size: 20),
                    ),
                    title: const Text(
                      'Event Date & Time',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text(formatEventDateTime(eventDate)),
                    trailing: const Icon(Icons.edit_calendar_rounded, size: 20),
                    onTap: () async {
                      final d = await _pickEventDateTime(
                        initial: eventDate,
                        first: DateTime.now(),
                        last: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) {
                        setState(() => eventDate = d);
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    tileColor: const Color(0xFFF8FAFC),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timer_outlined, color: Colors.red, size: 20),
                    ),
                    title: const Text(
                      'Registration Deadline',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text(formatEventDateTime(regDeadline)),
                    trailing: const Icon(Icons.edit_calendar_rounded, size: 20),
                    onTap: () async {
                      final d = await _pickEventDateTime(
                        initial: regDeadline,
                        first: DateTime.now(),
                        last: eventDate,
                      );
                      if (d != null) {
                        setState(() => regDeadline = d);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Registration Form & Custom Fields
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: LinkFormEditor(
                accent: cfg.eventColor,
                initialFormLabel: titleController.text.trim().isEmpty
                    ? 'Event Registration'
                    : titleController.text.trim(),
                onLinksChanged: (links) => setState(() => this.links = links),
                onFormChanged: (form) => setState(() => this.form = form),
              ),
            ),

            const SizedBox(height: 24),

            // Glowing Publish Button
            Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF97316).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isPublishing ? null : _publishEvent,
                child: _isPublishing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Publish Event',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

