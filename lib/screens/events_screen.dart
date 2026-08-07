import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';
import '../widgets/post_card.dart';
import 'dashboards/event_host_dashboard_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _handleRefresh(MockDataService dataService) async {
    setState(() => isRefreshing = true);
    final success = await dataService.refreshFeed();
    if (mounted) {
      setState(() => isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✨ Events refreshed!'
                : '⚠️ No network · Connect to the internet to refresh',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    // Same underlying feed, filtered down to Events + Workshops.
    final allEvents = dataService.posts.where((p) => p.isEvent).toList();
    final registeredEvents = allEvents
        .where((e) => user.registeredEventIds.contains(e.id))
        .toList();
    final myHostedEvents = allEvents
        .where((e) => e.authorId == user.id)
        .toList();

    final savedIds = user.savedPostIds.toSet();
    final registeredIds = user.registeredEventIds.toSet();
    final congratulatedIds = user.congratulatedPostIds.toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎉 Events'),
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
      body: Column(
        children: [
          // A gentle reminder that this is just the event view of one feed.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: cfg.eventColor.withValues(alpha: 0.06),
            child: Row(
              children: [
                Icon(Icons.filter_alt, size: 16, color: cfg.eventColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Filtered from campus feed · Events & Workshops',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cfg.eventColor,
                    ),
                  ),
                ),
                if (isRefreshing)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cfg.eventColor,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    color: cfg.eventColor,
                    iconSize: 20,
                    tooltip: 'Refresh Events',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () => _handleRefresh(dataService),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                _buildEventList(
                  context,
                  allEvents,
                  cfg: cfg,
                  savedIds: savedIds,
                  registeredIds: registeredIds,
                  congratulatedIds: congratulatedIds,
                  userYear: user.year,
                  dataService: dataService,
                  onRefresh: () => _handleRefresh(dataService),
                ),
                _buildEventList(
                  context,
                  registeredEvents,
                  cfg: cfg,
                  savedIds: savedIds,
                  registeredIds: registeredIds,
                  congratulatedIds: congratulatedIds,
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
                  congratulatedIds: congratulatedIds,
                  userYear: user.year,
                  dataService: dataService,
                  emptyMessage: 'You have not hosted any events yet.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(
    BuildContext context,
    List events, {
    required AppConfig cfg,
    required Set<String> savedIds,
    required Set<String> registeredIds,
    required Set<String> congratulatedIds,
    required String userYear,
    required MockDataService dataService,
    String emptyMessage = 'No upcoming events found.',
    Future<void> Function()? onRefresh,
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

    Widget list = ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final post = events[index] as PostModel;
        return PostCard(
          post: post,
          config: cfg,
          isSaved: savedIds.contains(post.id),
          isRegistered: registeredIds.contains(post.id),
          isCongratulated: congratulatedIds.contains(post.id),
          userYear: userYear,
          onToggleSave: () {
            dataService.toggleSavePost(post.id);
          },
          onToggleRegister: () => _handleToggleRegister(dataService, post),
          onToggleCongratulate: () =>
              _handleToggleCongratulate(dataService, post),
        );
      },
    );

    if (onRefresh != null) {
      list = RefreshIndicator(
        color: cfg.eventColor,
        onRefresh: onRefresh,
        child: list,
      );
    }
    return list;
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

  void _handleToggleCongratulate(MockDataService dataService, PostModel post) {
    dataService.toggleCongratulate(post.id);
    final isCongratulated =
        dataService.currentUser.congratulatedPostIds.contains(post.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCongratulated
              ? '👏 Congratulated ${post.authorName}!'
              : 'Removed congratulations',
        ),
        backgroundColor: isCongratulated
            ? const Color(0xFF8E24AA)
            : Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}