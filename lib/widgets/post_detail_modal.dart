import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';
import '../screens/post_detail_screen.dart';
import 'post_card.dart';

/// Screen and modal accessor that opens an individual full page post/event.
class PostDetailModal extends StatelessWidget {
  final String postId;

  const PostDetailModal({super.key, required this.postId});

  static Future<void> show(BuildContext context, String postId) {
    return PostDetailScreen.navigateTo(context, postId);
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.watch<MockDataService>();
    final post = dataService.posts.firstWhere(
      (p) => p.id == postId,
      orElse: () => PostModel(
        id: '',
        title: 'Post Not Found',
        description: 'This post may have been removed or is unavailable.',
        category: PostCategory.announcement,
        department: 'Campus',
        authorName: 'StudentHub',
        authorRole: UserRole.admin,
        authorId: '',
        timestamp: DateTime.now(),
      ),
    );

    final isSaved = dataService.currentUser.savedPostIds.contains(post.id);
    final isRegistered = dataService.currentUser.registeredEventIds.contains(post.id);
    final isCongratulated = dataService.currentUser.congratulatedPostIds.contains(post.id);
    final isLiked = dataService.currentUser.likedPostIds.contains(post.id);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 750),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                post.isEvent
                    ? '🎉 Event Details'
                    : post.category == PostCategory.gallery
                        ? '📸 Gallery Showcase'
                        : '📢 Post Details',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: PostCard(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
