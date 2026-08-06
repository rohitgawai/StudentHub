import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';
import '../widgets/post_card.dart';
import '../widgets/create_event_modal.dart';
import 'dashboards/event_host_dashboard_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with SingleTickerProviderStateMixin {
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final user = dataService.currentUser;
    final allEvents = dataService.posts.where((p) => p.isEvent).toList();
    final registeredEvents = allEvents.where((e) => user.registeredEventIds.contains(e.id)).toList();
    final myHostedEvents = allEvents.where((e) => e.authorId == user.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎉 Events Hub'),
        bottom: TabBar(
          controller: tabController,
          indicatorColor: dataService.config.eventColor,
          labelColor: dataService.config.eventColor,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'All (${allEvents.length})'),
            Tab(text: 'My Registered (${registeredEvents.length})'),
            Tab(text: 'My Hosted (${myHostedEvents.length})'),
          ],
        ),
        actions: [
          if (user.hasRole(UserRole.eventHost) || user.hasRole(UserRole.admin))
            IconButton(
              icon: const Icon(Icons.dashboard_outlined),
              tooltip: 'Host Management Dashboard',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const EventHostDashboardScreen()),
                );
              },
            ),
        ],
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          _buildEventList(context, allEvents),
          _buildEventList(context, registeredEvents, emptyMessage: 'You have not registered for any events yet.'),
          _buildEventList(context, myHostedEvents, emptyMessage: 'You have not hosted any events yet.'),
        ],
      ),
      floatingActionButton: (user.hasRole(UserRole.eventHost) || user.hasRole(UserRole.admin))
          ? FloatingActionButton.extended(
              backgroundColor: dataService.config.eventColor,
              foregroundColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const CreateEventModal(),
                );
              },
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Host Event'),
            )
          : null,
    );
  }

  Widget _buildEventList(BuildContext context, List events, {String emptyMessage = 'No upcoming events found.'}) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_seat_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(emptyMessage, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: events.length,
      itemBuilder: (context, index) {
        return PostCard(post: events[index]);
      },
    );
  }
}
