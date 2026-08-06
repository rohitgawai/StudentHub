import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../services/mock_data_service.dart';
import 'role_badge.dart';
import 'pdf_viewer_modal.dart';

class PostCard extends StatelessWidget {
  final PostModel post;

  const PostCard({
    super.key,
    required this.post,
  });

  Color _getCategoryColor(MockDataService dataService, PostCategory category) {
    final cfg = dataService.config;
    switch (category) {
      case PostCategory.academic:
        return cfg.academicColor;
      case PostCategory.event:
      case PostCategory.workshop:
        return cfg.eventColor;
      case PostCategory.urgent:
        return cfg.urgentColor;
      case PostCategory.achievement:
        return cfg.achievementColor;
      case PostCategory.placement:
      case PostCategory.announcement:
        return cfg.primaryColor;
      case PostCategory.gallery:
        return cfg.successColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<MockDataService>(context);
    final user = dataService.currentUser;
    final categoryColor = _getCategoryColor(dataService, post.category);
    final isSaved = user.savedPostIds.contains(post.id);
    final isRegistered = post.registeredUserIds.contains(user.id);

    // Target Year Warning (PRD Section 10)
    final bool hasYearMismatch = post.targetYear != null && post.targetYear != user.year;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target Year Header Alert (PRD requirement)
          if (hasYearMismatch)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This update is primarily intended for ${post.targetYear} students.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author Info & Post Category Chip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: categoryColor.withOpacity(0.15),
                      child: Text(
                        post.authorName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: categoryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  post.authorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              RoleBadge(role: post.authorRole, isCompact: true),
                            ],
                          ),
                          Text(
                            '${post.department} • ${_formatTimestamp(post.timestamp)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        post.category.displayName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: categoryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Post Title
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: 8),

                // Post Description
                Text(
                  post.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),

                // Optional Post Image
                if (post.imageUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      post.imageUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        height: 140,
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(Icons.image, size: 48, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],

                // Event Details Box (if post is an Event/Workshop)
                if (post.isEvent) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dataService.config.eventColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: dataService.config.eventColor.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: dataService.config.eventColor),
                            const SizedBox(width: 6),
                            Text(
                              post.venue ?? 'Campus Auditorium',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            if (post.maxParticipants != null)
                              Text(
                                '${post.currentRegistrations}/${post.maxParticipants} Seats',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: post.isRegistrationFull ? Colors.red : Colors.green.shade700,
                                ),
                              ),
                          ],
                        ),
                        if (post.eventDate != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 16, color: dataService.config.eventColor),
                              const SizedBox(width: 6),
                              Text(
                                _formatEventDate(post.eventDate!),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Attachments List (PDF attachments)
                if (post.attachments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...post.attachments.map((att) => InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => PdfViewerModal(attachment: att),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  att.title,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Tap to read PDF • ${att.fileSize}',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.blue),
                        ],
                      ),
                    ),
                  )),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Action Buttons Row (Save, Share, Register)
                Row(
                  children: [
                    // Save / Bookmark
                    IconButton(
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: isSaved ? dataService.config.primaryColor : Colors.grey,
                      ),
                      onPressed: () {
                        dataService.toggleSavePost(post.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isSaved ? 'Removed from saved posts' : 'Saved to Profile!'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    Text(
                      '${post.saveCount}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),

                    const SizedBox(width: 16),

                    // Share
                    IconButton(
                      icon: const Icon(Icons.share_outlined, color: Colors.grey),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied post link for: "${post.title}"'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),

                    const Spacer(),

                    // Register Button if Event
                    if (post.isEvent) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRegistered
                              ? Colors.grey.shade300
                              : dataService.config.eventColor,
                          foregroundColor: isRegistered ? Colors.black87 : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: post.isRegistrationFull && !isRegistered
                            ? null
                            : () {
                                dataService.toggleEventRegistration(post.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isRegistered
                                          ? 'Unregistered from event.'
                                          : '🎉 Successfully registered for ${post.title}!',
                                    ),
                                    backgroundColor: isRegistered ? Colors.orange : Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                        icon: Icon(
                          isRegistered ? Icons.check_circle : Icons.how_to_reg,
                          size: 16,
                        ),
                        label: Text(
                          isRegistered
                              ? 'Registered'
                              : (post.isRegistrationFull ? 'Full' : 'Register Now'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatEventDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
