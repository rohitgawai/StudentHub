import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/post_model.dart';
import '../../services/mock_data_service.dart';
import '../../widgets/managed_post_card.dart';

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
  ) {
    final titleCtrl = TextEditingController(text: post.title);
    final descCtrl = TextEditingController(text: post.description);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('✏️ Edit ${post.isEvent ? 'Event' : 'Post'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final updated = post.copyWith(
                title: titleCtrl.text.trim(),
                description: descCtrl.text.trim(),
              );
              dataService.updatePost(updated);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Post updated successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Host Dashboard'),
        centerTitle: false,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _StatsHeader(
            name: user.name,
            accent: _accent,
            eventCount: myEvents.length,
            noticeCount: myNotices.length,
            galleryCount: myGalleries.length,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 10),
            Text(emptyMsg, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final user = dataService.currentUser;
    final config = dataService.config;

    return ListView.builder(
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
          userYear: user.year,
          currentUserId: user.id,
          onToggleSave: () => dataService.toggleSavePost(post.id),
          onToggleRegister: () => dataService.toggleEventRegistration(post.id),
          onToggleCongratulate: () => dataService.toggleCongratulate(post.id),
          onToggleLike: () => dataService.toggleLikePost(post.id),
          onEdit: () => _showEditDialog(context, dataService, post),
          onDelete: () => _confirmDelete(context, dataService, post),
        );
      },
    );
  }
}

/// Compact welcome row with three tappable-looking stat tiles, so upload
/// totals are visible without taking too much space.
class _StatsHeader extends StatelessWidget {
  final String name;
  final Color accent;
  final int eventCount;
  final int noticeCount;
  final int galleryCount;

  const _StatsHeader({
    required this.name,
    required this.accent,
    required this.eventCount,
    required this.noticeCount,
    required this.galleryCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFC2410C), Color(0xFFFB8C00)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, $name',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.event_available,
                  count: eventCount,
                  label: 'Events & Workshops',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  icon: Icons.campaign,
                  count: noticeCount,
                  label: 'Campus Posts',
                ),
              ),
              const SizedBox(width: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFC2410C)),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFFC2410C),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}