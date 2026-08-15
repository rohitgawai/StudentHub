import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/post_model.dart';
import '../../services/mock_data_service.dart';
import '../../widgets/edit_post_dialog.dart';
import '../../widgets/managed_post_card.dart';
import '../registration_stats_screen.dart';
import '../registrants_screen.dart';

class EventHostDashboardScreen extends StatefulWidget {
  const EventHostDashboardScreen({super.key});

  @override
  State<EventHostDashboardScreen> createState() =>
      _EventHostDashboardScreenState();
}

class _EventHostDashboardScreenState extends State<EventHostDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Direct silent auto-refresh without pull-to-refresh or buttons
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MockDataService>().refreshFeed();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showEditDialog(
    BuildContext context,
    MockDataService dataService,
    PostModel post,
  ) async {
    final updated = await showEditPostDialog(
      context,
      post: post,
      accent: const Color(0xFF312E81),
    );
    if (updated != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Post updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MockDataService dataService,
    PostModel post,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🗑️ Delete Post?'),
        content: Text('"${post.title}" will be removed from the campus feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final deleted = await dataService.deletePost(post.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? '🗑️ Post deleted successfully.'
              : '⚠️ Could not delete: only the author can delete a post.',
        ),
        backgroundColor: deleted ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final user = dataService.currentUser;

    final uName = user.name.trim().toLowerCase();
    final myPosts = dataService.posts
        .where(
          (p) =>
              p.authorId == user.id ||
              (uName.isNotEmpty &&
                  (p.authorName.trim().toLowerCase() == uName ||
                      p.authorName.toLowerCase().contains(uName))),
        )
        .toList();
    final myEvents = myPosts.where((p) => p.isEvent).toList();
    final myNotices = myPosts
        .where((p) => !p.isEvent && p.category != PostCategory.gallery)
        .toList();
    final myGalleries =
        myPosts.where((p) => p.category == PostCategory.gallery).toList();

    final totalRegistrations = myEvents.fold<int>(
      0,
      (sum, p) {
        final subCount = dataService.submissionsForPost(p.id).length;
        final regCount = p.registeredUserIds.length;
        return sum + (regCount > subCount ? regCount : subCount);
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Host Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Column(
        children: [
          // Sleek Creator Card (No redundant avatar)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E1B4B).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${myEvents.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'Hosted Events',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalRegistrations',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'Total Registrations',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegistrationStatsScreen(),
                        ),
                      );
                    },
                    child: Ink(
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.analytics_outlined, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'View Analytics & Export (PDF/CSV)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Clean Segmented Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1E1B4B),
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: const Color(0xFF312E81),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.5),
              tabs: [
                Tab(text: 'Events (${myEvents.length})'),
                Tab(text: 'Notices (${myNotices.length})'),
                Tab(text: 'Galleries (${myGalleries.length})'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(context, dataService, myEvents, 'No events or workshops hosted yet.'),
                _buildList(context, dataService, myNotices, 'No notices published yet.'),
                _buildList(context, dataService, myGalleries, 'No galleries uploaded yet.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    MockDataService dataService,
    List<PostModel> postsList,
    String emptyMsg,
  ) {
    if (postsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              emptyMsg,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final user = dataService.currentUser;
    final config = dataService.config;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: postsList.length,
      itemBuilder: (ctx, idx) {
        final post = postsList[idx];
        return ManagedPostCard(
          post: post,
          config: config,
          isSaved: user.savedPostIds.contains(post.id),
          isRegistered: user.registeredEventIds.contains(post.id),
          isCongratulated: user.congratulatedPostIds.contains(post.id),
          isLiked: user.likedPostIds.contains(post.id),
          currentUserId: user.id,
          onToggleSave: () => dataService.toggleSavePost(post.id),
          onToggleRegister: () => dataService.toggleEventRegistration(post.id),
          onToggleCongratulate: () => dataService.toggleCongratulate(post.id),
          onToggleLike: () => dataService.toggleLikePost(post.id),
          onEdit: () => _showEditDialog(context, dataService, post),
          onDelete: () => _confirmDelete(context, dataService, post),
          onViewRegistrants: post.isEvent
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RegistrantsScreen(post: post),
                    ),
                  );
                }
              : null,
        );
      },
    );
  }
}