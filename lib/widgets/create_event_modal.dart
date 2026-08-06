import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';

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
  final imageUrlController = TextEditingController();

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
    imageUrlController.dispose();
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
              decoration: const InputDecoration(
                labelText: 'Event Title *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter event title' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Event Description & Agenda *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter event details' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: venueController,
              decoration: const InputDecoration(
                labelText: 'Venue / Hall / Room *',
                hintText: 'e.g. Main Auditorium / Lab 102',
                border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: 'Max Capacity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: department,
                    decoration: const InputDecoration(
                      labelText: 'Host Dept',
                      border: OutlineInputBorder(),
                    ),
                    items: dataService.config.departments
                        .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => department = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Event Banner Image URL',
                hintText: 'https://images.unsplash.com/...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Date Pickers
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.event, color: Colors.orange),
              title: const Text('Event Date & Time'),
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
            const SizedBox(height: 12),

            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.timer, color: Colors.red),
              title: const Text('Registration Deadline'),
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
                  imageUrl: imageUrlController.text.trim().isNotEmpty
                      ? imageUrlController.text.trim()
                      : 'https://images.unsplash.com/photo-1511578314322-379afb476865?auto=format&fit=crop&q=80&w=800',
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
