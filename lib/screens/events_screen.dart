import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import '../widgets/post_card.dart';
import '../widgets/app_toast.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  final List<ScrollController> _scrollControllers = [
    ScrollController(),
    ScrollController(),
    ScrollController(),
  ];
  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
  }

  void scrollToTop() {
    final idx = tabController.index.clamp(0, _scrollControllers.length - 1);
    final controller = _scrollControllers[idx];
    if (controller.hasClients) {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _handleRefresh(MockDataService dataService) async {
    setState(() => isRefreshing = true);
    final success = await dataService.refreshFeed();
    if (mounted) {
      setState(() => isRefreshing = false);
      if (success) {
        AppToast.showSuccess(context, 'Events & workshops refreshed');
      } else {
        AppToast.showWarning(context, 'No internet · Showing cached events');
      }
    }
  }

  @override
  void dispose() {
    tabController.dispose();
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.watch<MockDataService>();
    final cfg = dataService.config;
    final user = dataService.currentUser;
    // Filter by Event, Workshop, and Registered
    final eventsOnly = dataService.posts
        .where((p) => p.category == PostCategory.event && dataService.matchesYear(p))
        .toList();
    final workshopsOnly = dataService.posts
        .where((p) => p.category == PostCategory.workshop && dataService.matchesYear(p))
        .toList();
    final registeredEvents = dataService.posts
        .where((e) => e.isEvent && user.registeredEventIds.contains(e.id))
        .toList();

    final savedIds = user.savedPostIds.toSet();
    final registeredIds = user.registeredEventIds.toSet();
    final congratulatedIds = user.congratulatedPostIds.toSet();
    final likedIds = user.likedPostIds.toSet();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Events & Workshops',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 1,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF262626) : Colors.transparent,
              ),
            ),
            child: TabBar(
              controller: tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF333333) : Colors.transparent,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
              unselectedLabelColor: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              tabs: [
                Tab(text: 'Events (${eventsOnly.length})'),
                Tab(text: 'Workshops (${workshopsOnly.length})'),
                Tab(text: 'Registered (${registeredEvents.length})'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          _buildEventList(
            context,
            eventsOnly,
            scrollController: _scrollControllers[0],
            cfg: cfg,
            savedIds: savedIds,
            registeredIds: registeredIds,
            congratulatedIds: congratulatedIds,
            likedIds: likedIds,
            dataService: dataService,
            emptyMessage: 'No upcoming events found.',
            onRefresh: () => _handleRefresh(dataService),
          ),
          _buildEventList(
            context,
            workshopsOnly,
            scrollController: _scrollControllers[1],
            cfg: cfg,
            savedIds: savedIds,
            registeredIds: registeredIds,
            congratulatedIds: congratulatedIds,
            likedIds: likedIds,
            dataService: dataService,
            emptyMessage: 'No workshops scheduled currently.',
            onRefresh: () => _handleRefresh(dataService),
          ),
          _buildEventList(
            context,
            registeredEvents,
            scrollController: _scrollControllers[2],
            cfg: cfg,
            savedIds: savedIds,
            registeredIds: registeredIds,
            congratulatedIds: congratulatedIds,
            likedIds: likedIds,
            dataService: dataService,
            emptyMessage: 'You have not registered for any events yet.',
            onRefresh: () => _handleRefresh(dataService),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(
    BuildContext context,
    List<PostModel> events, {
    ScrollController? scrollController,
    required AppConfig cfg,
    required Set<String> savedIds,
    required Set<String> registeredIds,
    required Set<String> congratulatedIds,
    required Set<String> likedIds,
    required MockDataService dataService,
    String emptyMessage = 'No upcoming events found.',
    Future<void> Function()? onRefresh,
  }) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_seat_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    Widget list = ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.only(top: 10, bottom: 96),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final post = events[index];
        return PostCard(
          key: ValueKey(post.id),
          post: post,
          config: cfg,
          isSaved: savedIds.contains(post.id),
          isRegistered: registeredIds.contains(post.id),
          isCongratulated: congratulatedIds.contains(post.id),
          isLiked: likedIds.contains(post.id),
          currentUserId: dataService.currentUser.id,
          onToggleSave: () {
            dataService.toggleSavePost(post.id);
          },
          onToggleRegister: () => _handleToggleRegister(dataService, post),
          onToggleCongratulate: () =>
              _handleToggleCongratulate(dataService, post),
          onToggleLike: () => _handleToggleLike(dataService, post),
        );
      },
    );

    if (onRefresh != null) {
      list = RefreshIndicator(
        color: const Color(0xFF1E1B4B),
        onRefresh: onRefresh,
        child: list,
      );
    }
    return list;
  }

  void _handleToggleRegister(MockDataService dataService, PostModel post) {
    dataService.toggleEventRegistration(post.id);
  }

  void _handleToggleCongratulate(MockDataService dataService, PostModel post) {
    dataService.toggleCongratulate(post.id);
  }

  void _handleToggleLike(MockDataService dataService, PostModel post) {
    dataService.toggleLikePost(post.id);
  }
}