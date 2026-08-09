import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import '../utils/date_formatter.dart';
import 'custom_dropdown.dart';
import 'image_picker_field.dart';

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
  String? selectedImageUrl;
  PostCategory eventKind = PostCategory.event;

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

    final online = await dataService.checkBackendReachable();
    if (!mounted) return;
    if (!online) {
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
      authorName: dataService.currentUser.name,
      authorRole: dataService.activeRole,
      authorId: dataService.currentUser.id,
      timestamp: DateTime.now(),
      imageUrl: selectedImageUrl,
      venue: venueController.text.trim(),
      eventDate: eventDate,
      registrationDeadline: regDeadline,
      maxParticipants: maxCap,
      registeredUserIds: const [],
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎉 Create Event & Workshops'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<PostCategory>(
              segments: const [
                ButtonSegment(
                  value: PostCategory.event,
                  label: Text('🎪 Event'),
                  icon: Icon(Icons.event),
                ),
                ButtonSegment(
                  value: PostCategory.workshop,
                  label: Text('🛠️ Workshop'),
                  icon: Icon(Icons.construction),
                ),
              ],
              selected: {eventKind},
              onSelectionChanged: (selection) {
                setState(() => eventKind = selection.first);
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Event Title',
                prefixIcon: const Icon(Icons.event_note),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter event title' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: descController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Event Description',
                prefixIcon: const Icon(Icons.description_outlined),
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter event details' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: venueController,
              decoration: InputDecoration(
                labelText: 'Venue / Hall / Room ',
                hintText: 'e.g. Main Auditorium / Lab 102',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      prefixIcon: const Icon(Icons.groups_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomDropdownField<String>(
                    value: department,
                    labelText: 'Host Dept',
                    items: dataService.config.departments,
                    itemLabel: (d) => d,
                    onChanged: (val) {
                      if (val != null) setState(() => department = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Required cover image upload
            ImagePickerField(
              label: 'Cover Image',
              initialUrl: selectedImageUrl,
              onImageSelected: (url) {
                setState(() => selectedImageUrl = url);
              },
            ),
            const SizedBox(height: 14),

            // Date Pickers
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              leading: const Icon(Icons.event, color: Colors.orange),
              title: const Text('Event Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(formatEventDateTime(eventDate)),
              trailing: const Icon(Icons.edit_calendar),
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
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              leading: const Icon(Icons.timer, color: Colors.red),
              title: const Text('Registration Deadline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(formatEventDateTime(regDeadline)),
              trailing: const Icon(Icons.edit_calendar),
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

            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: dataService.config.eventColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _publishEvent();
              },
              child: const Text(
                'Publish Event',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
