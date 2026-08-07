import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/post_model.dart';
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

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
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
    final dataService = context.read<MockDataService>();
    final cfg = context.select((MockDataService s) => s.config);
    final user = context.select((MockDataService s) => s.currentUser);
    final allEvents = dataService.posts.where((p) => p.isEvent).toList();
    final registeredEvents = allEvents
        .where((e) => user.registeredEventIds.contains(e.id))
        .toList();
    final myHostedEvents = allEvents
        .where((e) => e.authorId == user.id)
        .toList();

    final savedIds = user.savedPostIds.toSet();
    final registeredIds = user.registeredEventIds.toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎉 Events Hub'),
        bottom: TabBar(
          controller: tabController,
          indicatorColor: cfg.eventColor,
          labelColor: cfg.eventColor,
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
                  MaterialPageRoute(
                    builder: (ctx) => const EventHostDashboardScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          _buildEventList(
            context,
            allEvents,
            cfg: cfg,
            savedIds: savedIds,
            registeredIds: registeredIds,
            userYear: user.year,
            dataService: dataService,
          ),
          _buildEventList(
            context,
            registeredEvents,
            cfg: cfg,
            savedIds: savedIds,
            registeredIds: registeredIds,
            userYear: user.year,
            dataService: dataService,
            emptyMessage: 'You have not registered for any events yet.',
          ),
          _buildEventList(
            context,
            myHostedEvents,
            cfg: cfg,
            savedIds: savedIds,
            registeredIds: registeredIds,
            userYear: user.year,
            dataService: dataService,
            emptyMessage: 'You have not hosted any events yet.',
          ),
        ],
      ),
      floatingActionButton:
          (user.hasRole(UserRole.eventHost) || user.hasRole(UserRole.admin))
          ? FloatingActionButton.extended(
              backgroundColor: cfg.eventColor,
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

  Widget _buildEventList(
    BuildContext context,
    List events, {
    required AppConfig cfg,
    required Set<String> savedIds,
    required Set<String> registeredIds,
    required String userYear,
    required MockDataService dataService,
    String emptyMessage = 'No upcoming events found.',
  }) {
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
        final post = events[index] as PostModel;
        return PostCard(
          post: post,
          config: cfg,
          isSaved: savedIds.contains(post.id),
          isRegistered: registeredIds.contains(post.id),
          userYear: userYear,
          onToggleSave: () {
            dataService.toggleSavePost(post.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved to Profile!'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          onToggleRegister: () => _handleToggleRegister(dataService, post),
        );
      },
    );
  }

  void _handleToggleRegister(MockDataService dataService, PostModel post) {
    final wasRegistered = dataService.currentUser.registeredEventIds.contains(
      post.id,
    );
    dataService.toggleEventRegistration(post.id);
    final isRegistered = dataService.currentUser.registeredEventIds.contains(
      post.id,
    );
    if (wasRegistered == isRegistered) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isRegistered
              ? '🎉 Successfully registered for ${post.title}!'
              : 'Unregistered from event.',
        ),
        backgroundColor: isRegistered ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
