import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import '../widgets/post_card.dart';
import '../widgets/post_card_skeleton.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  String selectedCategory = 'All';
  String searchQuery = '';
  final searchController = TextEditingController();
  bool isRefreshing = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
                ? '✨ Campus feed refreshed!'
                : '⚠️ No network · Connect to the internet to refresh',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleToggleSave(MockDataService dataService, PostModel post) {
    dataService.toggleSavePost(post.id);
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

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<MockDataService>();
    // Narrow subscriptions: this screen only rebuilds when the data it
    // actually renders changes.
    final cfg = context.select((MockDataService s) => s.config);
    final isLoading = context.select((MockDataService s) => s.isLoading);
    final userYear = context.select((MockDataService s) => s.currentUser.year);
    final savedIds = context.select(
      (MockDataService s) => s.currentUser.savedPostIds,
    );
    final registeredIds = context.select(
      (MockDataService s) => s.currentUser.registeredEventIds,
    );
    final congratulatedIds = context.select(
      (MockDataService s) => s.currentUser.congratulatedPostIds,
    );
    final userDept = context.select(
      (MockDataService s) => s.currentUser.department,
    );

    final categories = ['All', ...cfg.postCategories]
        .where((c) => c != 'Event' && c != 'Workshop')
        .toList();
    final posts = dataService.getPersonalizedFeed(
      categoryFilter: selectedCategory,
      searchQuery: searchQuery,
      excludeEvents: true,
    );

    final headerAnnouncement = dataService.activeAnnouncementFor(userDept);

    return Scaffold(
      body: Column(
        children: [
          // Urgent Announcement Banner
          if (cfg.enableUrgentBanner &&
              (headerAnnouncement != null ||
                  cfg.announcementBannerText.isNotEmpty))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cfg.urgentColor, cfg.urgentColor.withRed(240)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.campaign_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerAnnouncement?.title ??
                              cfg.announcementBannerText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (headerAnnouncement != null)
                          Text(
                            '${headerAnnouncement.remainingLabel} • posted by ${headerAnnouncement.authorName}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Search Bar & Refresh Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (val) => setState(() => searchQuery = val),
                    decoration: InputDecoration(
                      hintText: '🔍 Search posts, events, faculty...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setState(() => searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Rolling circle refresh button
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: isRefreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Icon(Icons.refresh_rounded, color: cfg.primaryColor),
                    tooltip: 'Refresh Feed',
                    onPressed: isRefreshing
                        ? null
                        : () => _handleRefresh(dataService),
                  ),
                ),
              ],
            ),
          ),

          // Priority Filter Chips — tinted by the category color system
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: categories.map((cat) {
                final isSelected = selectedCategory == cat;
                final chipColor = cat == 'All'
                    ? cfg.primaryColor
                    : cfg.colorForCategory(
                        PostCategory.values.firstWhere(
                          (c) => c.displayName == cat,
                          orElse: () => PostCategory.announcement,
                        ),
                      );
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: chipColor.withValues(alpha: 0.18),
                    checkmarkColor: chipColor,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? chipColor
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    side: isSelected
                        ? BorderSide(color: chipColor.withValues(alpha: 0.4))
                        : null,
                    onSelected: (selected) {
                      setState(() => selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 4),

          // Pull-to-refresh feed; skeleton placeholders while initial data loads
          Expanded(
            child: RefreshIndicator(
              color: cfg.primaryColor,
              onRefresh: () => _handleRefresh(dataService),
              child: isLoading
                  ? const FeedSkeleton()
                  : posts.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.feed_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No posts match your filters',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        return PostCard(
                          post: post,
                          config: cfg,
                          isSaved: savedIds.contains(post.id),
                          isRegistered: registeredIds.contains(post.id),
                          isCongratulated: congratulatedIds.contains(post.id),
                          userYear: userYear,
                          onToggleSave: () =>
                              _handleToggleSave(dataService, post),
                          onToggleRegister: () =>
                              _handleToggleRegister(dataService, post),
                          onToggleCongratulate: () =>
                              _handleToggleCongratulate(dataService, post),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}