import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/post_model.dart';
import 'post_card.dart';

/// Social-media style management card: renders the full [PostCard] (images,
/// likes/saves counts, events details) and adds an Edit / Delete action row
/// for the content owner. Used by the Host and Faculty dashboards.
class ManagedPostCard extends StatelessWidget {
  final PostModel post;
  final AppConfig config;
  final bool isSaved;
  final bool isRegistered;
  final bool isCongratulated;
  final bool isLiked;
  final String userYear;
  final String? currentUserId;
  final VoidCallback? onToggleSave;
  final VoidCallback? onToggleRegister;
  final VoidCallback? onToggleCongratulate;
  final VoidCallback? onToggleLike;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ManagedPostCard({
    super.key,
    required this.post,
    required this.config,
    required this.isSaved,
    required this.isRegistered,
    this.isCongratulated = false,
    this.isLiked = false,
    required this.userYear,
    this.currentUserId,
    this.onToggleSave,
    this.onToggleRegister,
    this.onToggleCongratulate,
    this.onToggleLike,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PostCard(
          post: post,
          config: config,
          isSaved: isSaved,
          isRegistered: isRegistered,
          isCongratulated: isCongratulated,
          isLiked: isLiked,
          userYear: userYear,
          currentUserId: currentUserId,
          onToggleSave: onToggleSave,
          onToggleRegister: onToggleRegister,
          onToggleCongratulate: onToggleCongratulate,
          onToggleLike: onToggleLike,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}