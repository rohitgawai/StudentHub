import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
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
  String? selectedImageUrl = 'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?auto=format&fit=crop&q=80&w=800';

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

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎉 Create Campus Event'),
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
            TextFormField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Event Title *',
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
                labelText: 'Event Description & Agenda *',
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
                labelText: 'Venue / Hall / Room *',
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

            // Requirement 10: Image Upload / Selector
            ImagePickerField(
              label: 'Event Cover / Banner Image (Optional)',
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
              subtitle: Text('${eventDate.day}/${eventDate.month}/${eventDate.year} at ${eventDate.hour}:00'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: eventDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) {
                  setState(() => eventDate = DateTime(d.year, d.month, d.day, 10, 0));
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
              subtitle: Text('${regDeadline.day}/${regDeadline.month}/${regDeadline.year} at 23:59'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: regDeadline,
                  firstDate: DateTime.now(),
                  lastDate: eventDate,
                );
                if (d != null) {
                  setState(() => regDeadline = DateTime(d.year, d.month, d.day, 23, 59));
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
                if (!_formKey.currentState!.validate()) return;

                final maxCap = int.tryParse(maxSeatsController.text.trim()) ?? 100;

                final newEvent = PostModel(
                  id: 'pst_${DateTime.now().millisecondsSinceEpoch}',
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  category: PostCategory.event,
                  department: department,
                  authorName: dataService.currentUser.name,
                  authorRole: dataService.activeRole,
                  authorId: dataService.currentUser.id,
                  timestamp: DateTime.now(),
                  imageUrl: selectedImageUrl ?? 'https://images.unsplash.com/photo-1511578314322-379afb476865?auto=format&fit=crop&q=80&w=800',
                  venue: venueController.text.trim(),
                  eventDate: eventDate,
                  registrationDeadline: regDeadline,
                  maxParticipants: maxCap,
                  registeredUserIds: [dataService.currentUser.id],
                );

                dataService.addPost(newEvent);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🚀 Event published to Campus Feed & Events Hub!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Publish Event', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
