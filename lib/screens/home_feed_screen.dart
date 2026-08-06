import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';
import '../widgets/post_card.dart';
import '../widgets/create_post_modal.dart';
import '../widgets/create_event_modal.dart';

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
    await dataService.refreshFeed();
    if (mounted) {
      setState(() => isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Campus feed refreshed!'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final cfg = dataService.config;

    final categories = ['All', ...cfg.postCategories];
    final posts = dataService.getPersonalizedFeed(
      categoryFilter: selectedCategory,
      searchQuery: searchQuery,
    );

    // Requirement 3: "post update" feature only for hosts, faculty, or admin
    final bool canPostUpdate = dataService.activeRole == UserRole.eventHost ||
        dataService.activeRole == UserRole.faculty ||
        dataService.activeRole == UserRole.admin;

    final headerAnnouncement = dataService.activeAnnouncementFor(dataService.currentUser.department);

    return Scaffold(
      body: Column(
        children: [
          // Urgent Announcement Banner
          if (cfg.enableUrgentBanner &&
              (headerAnnouncement != null || cfg.announcementBannerText.isNotEmpty))
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
                  const Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerAnnouncement?.title ?? cfg.announcementBannerText,
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
                      hintText: 'Search campus notices, events, faculty...',
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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

                // Requirement 9: Rolling circle refresh button under search/selection menu
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
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
                    onPressed: isRefreshing ? null : () => _handleRefresh(dataService),
                  ),
                ),
              ],
            ),
          ),

          // Priority Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: categories.map((cat) {
                final isSelected = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: cfg.primaryColor.withOpacity(0.2),
                    checkmarkColor: cfg.primaryColor,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? cfg.primaryColor : Theme.of(context).colorScheme.onSurface,
                    ),
                    onSelected: (selected) {
                      setState(() => selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 4),

          // Requirement 9: Pull-to-refresh feed wrapped in RefreshIndicator
          Expanded(
            child: RefreshIndicator(
              color: cfg.primaryColor,
              onRefresh: () => _handleRefresh(dataService),
              child: posts.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.feed_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('No posts match your filters', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        return PostCard(post: posts[index]);
                      },
                    ),
            ),
          ),
        ],
      ),

      // FAB for creating posts or events based on role (Hidden for Students)
      floatingActionButton: canPostUpdate
          ? FloatingActionButton.extended(
              backgroundColor: cfg.primaryColor,
              foregroundColor: Colors.white,
              onPressed: () {
                _showCreateOptionsModal(context, dataService);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Post Update', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  void _showCreateOptionsModal(BuildContext context, MockDataService dataService) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'What would you like to publish?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.announcement, color: Colors.blue),
                  ),
                  title: const Text('New Announcement / Notice'),
                  subtitle: const Text('Post academic updates, attachments, or achievements'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    showDialog(
                      context: context,
                      builder: (c) => const CreatePostModal(),
                    );
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: const Icon(Icons.event, color: Colors.orange),
                  ),
                  title: const Text('New Campus Event'),
                  subtitle: const Text('Publish hackathons, workshops, or competitions'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    showDialog(
                      context: context,
                      builder: (c) => const CreateEventModal(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
