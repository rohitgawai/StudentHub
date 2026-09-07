import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import '../widgets/post_card.dart';

/// Full-page individual screen for posts and events, matching the experience of
/// standard social media apps (Twitter/X, Instagram, LinkedIn).
class PostDetailScreen extends StatelessWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  static Future<void> navigateTo(BuildContext context, String postId) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => PostDetailScreen(postId: postId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.watch<MockDataService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final post = dataService.posts.cast<PostModel?>().firstWhere(
          (p) => p?.id == postId,
          orElse: () => null,
        );

    if (post == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Post Unavailable'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 64,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'This post or event is no longer available',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'It may have been deleted or expired.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isSaved = dataService.currentUser.savedPostIds.contains(post.id);
    final isRegistered = dataService.currentUser.registeredEventIds.contains(post.id);
    final isCongratulated = dataService.currentUser.congratulatedPostIds.contains(post.id);
    final isLiked = dataService.currentUser.likedPostIds.contains(post.id);

    final titleText = post.isEvent
        ? 'Event Details'
        : post.category == PostCategory.gallery
            ? 'Gallery Showcase'
            : post.category == PostCategory.announcement
                ? 'Campus Announcement'
                : 'Post Details';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0.5,
        title: Text(
          titleText,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: isSaved ? 'Saved' : 'Save',
            icon: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: isSaved ? dataService.config.primaryColor : null,
            ),
            onPressed: () => dataService.toggleSavePost(post.id),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              Share.share(
                'Check out this ${post.isEvent ? "event" : "post"} on StudentHub: "${post.title}"\n${post.description}',
                subject: post.title,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PostCard(
                    post: post,
                    config: dataService.config,
                    isSaved: isSaved,
                    isRegistered: isRegistered,
                    isCongratulated: isCongratulated,
                    isLiked: isLiked,
                    currentUserId: dataService.currentUser.id,
                    onToggleSave: () => dataService.toggleSavePost(post.id),
                    onToggleRegister: () => dataService.toggleEventRegistration(post.id),
                    onToggleCongratulate: () => dataService.toggleCongratulate(post.id),
                    onToggleLike: () => dataService.toggleLikePost(post.id),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
