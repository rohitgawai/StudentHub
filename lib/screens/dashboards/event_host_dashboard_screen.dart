import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/mock_data_service.dart';
import '../../widgets/create_event_modal.dart';


class EventHostDashboardScreen extends StatelessWidget {
  const EventHostDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final user = dataService.currentUser;
    final hostedEvents = dataService.posts.where((p) => p.isEvent && (p.authorId == user.id || p.authorName.contains(user.name))).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Event Host Dashboard'),
        backgroundColor: const Color(0xFFC2410C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Host New Event',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const CreateEventModal(),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC2410C), Color(0xFFFB8C00)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coordinator: ${user.name}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${hostedEvents.length} Events Hosted • ${hostedEvents.fold<int>(0, (sum, e) => sum + e.currentRegistrations)} Total Student Attendees',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFC2410C),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const CreateEventModal(),
                    );
                  },
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Create New Event'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'My Active Campus Events (${hostedEvents.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          if (hostedEvents.isEmpty)
            const Center(child: Text('No events created yet. Tap Create New Event to start!', style: TextStyle(color: Colors.grey)))
          else
            ...hostedEvents.map((event) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Venue: ${event.venue ?? "Campus"} • ${event.currentRegistrations}/${event.maxParticipants ?? "∞"} Registered'),
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: const Icon(Icons.event, color: Colors.orange),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Registered User IDs: ${event.registeredUserIds.join(", ")}', style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Export CSV Roster'),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Exporting participant roster for "${event.title}" to CSV...')),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                dataService.deletePost(event.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Event deleted.')),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}
