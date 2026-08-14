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

/// A clean, feed-style dashboard for the Event Host. It shows only the host's
/// own uploads (Events & Workshops · Notices · Galleries), each rendered as a
/// full social card with like/save counts and images, plus Edit (title &
/// description only) and Delete actions. Publishing lives in the global
/// Create button, so no create controls clutter this screen.
class _EventHostDashboardScreenState extends State<EventHostDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const Color _accent = Color(0xFFC2410C);

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      accent: _accent,
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

    final myPosts = dataService.posts
        .where((p) => p.authorId == user.id || p.authorName.contains(user.name))
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
      appBar: AppBar(
        title: const Text('🎯 Host Dashboard'),
        centerTitle: false,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RegistrationStatsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.query_stats),
            label: const Text(
              'Stats',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _StatsHeader(
            name: user.name,
            accent: _accent,
            eventCount: myEvents.length,
            totalRegistrations: totalRegistrations,
            noticeCount: myNotices.length,
            galleryCount: myGalleries.length,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Material(
              color: _accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RegistrationStatsScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.query_stats, color: _accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📊 Registration Stats',
                              style: TextStyle(
                                color: _accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Registrations, attendance tracking & CSV/PDF export for your events — tap to open.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade500),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            color: Theme.of(context).cardColor,
            child: TabBar(
              controller: _tabController,
              labelColor: _accent,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _accent,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Hosted Events (${myEvents.length})'),
                Tab(text: 'Notices (${myNotices.length})'),
                Tab(text: 'Galleries (${myGalleries.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(context, dataService, myEvents,
                    'No events or workshops hosted yet.'),
                _buildList(context, dataService, myNotices,
                    'No notices published yet.'),
                _buildList(context, dataService, myGalleries,
                    'No galleries uploaded yet.'),
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
      return RefreshIndicator(
        onRefresh: () => dataService.refreshFeed(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
                    const SizedBox(height: 10),
                    Text(emptyMsg, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final user = dataService.currentUser;
    final config = dataService.config;

    return RefreshIndicator(
      onRefresh: () => dataService.refreshFeed(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: postsList.length,
        itemBuilder: (ctx, idx) {
          final post = postsList[idx];
          final isMine = post.authorId == user.id;
          return ManagedPostCard(
            post: post,
            config: config,
            isSaved: user.savedPostIds.contains(post.id),
            isRegistered: user.registeredEventIds.contains(post.id),
            isCongratulated: user.congratulatedPostIds.contains(post.id),
            isLiked: user.likedPostIds.contains(post.id),
            userYear: user.year,
            currentUserId: user.id,
            onToggleSave: () => dataService.toggleSavePost(post.id),
            onToggleRegister: () => dataService.toggleEventRegistration(post.id),
            onToggleCongratulate: () => dataService.toggleCongratulate(post.id),
            onToggleLike: () => dataService.toggleLikePost(post.id),
            onEdit: () => _showEditDialog(context, dataService, post),
            onDelete: () => _confirmDelete(context, dataService, post),
            onViewRegistrants: isMine && post.isEvent
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
      ),
    );
  }
}

/// Compact welcome row with three tappable-looking stat tiles, so upload
/// totals are visible without taking too much space.
class _StatsHeader extends StatelessWidget {
  final String name;
  final Color accent;
  final int eventCount;
  final int totalRegistrations;
  final int noticeCount;
  final int galleryCount;

  const _StatsHeader({
    required this.name,
    required this.accent,
    required this.eventCount,
    required this.totalRegistrations,
    required this.noticeCount,
    required this.galleryCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC2410C), Color(0xFFEA580C), Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC2410C).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stars_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Welcome, $name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.event_available,
                  count: eventCount,
                  label: 'Events',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatTile(
                  icon: Icons.how_to_reg,
                  count: totalRegistrations,
                  label: 'Registrations',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatTile(
                  icon: Icons.campaign,
                  count: noticeCount,
                  label: 'Notices',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatTile(
                  icon: Icons.photo_library_outlined,
                  count: galleryCount,
                  label: 'Galleries',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;

  const _StatTile({
    required this.icon,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: const Color(0xFFC2410C)),
          const SizedBox(height: 5),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFFC2410C),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}