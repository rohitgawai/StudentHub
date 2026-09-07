import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_config.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';
import '../screens/form_fill_screen.dart';
import '../utils/date_formatter.dart';
import '../utils/external_links.dart';
import 'role_badge.dart';
import 'pdf_viewer_modal.dart';
import 'app_image.dart';
import 'gallery_viewer_modal.dart';
import 'post_image_zoom_modal.dart';
import '../screens/user_profile_screen.dart';

/// A post card that stays decoupled from the data service, owning the
/// micro-interactions: press-lift, animated save/like/congratulate, Instagram-style
/// aspect ratio images, distinct category designs, and type-aware smart action bars.
class PostCard extends StatefulWidget {
  final PostModel post;
  final AppConfig config;
  final bool isSaved;
  final bool isRegistered;
  final bool isCongratulated;
  final bool isLiked;
  final String? currentUserId;
  final VoidCallback? onToggleSave;
  final VoidCallback? onToggleRegister;
  final VoidCallback? onToggleCongratulate;
  final VoidCallback? onToggleLike;

  /// When set, the owner's "N registered" chip becomes tappable and opens the
  /// registrant list (wired by the host/faculty dashboards).
  final VoidCallback? onViewRegistrants;

  const PostCard({
    super.key,
    required this.post,
    required this.config,
    required this.isSaved,
    required this.isRegistered,
    this.isCongratulated = false,
    this.isLiked = false,
    this.currentUserId,
    this.onToggleSave,
    this.onToggleRegister,
    this.onToggleCongratulate,
    this.onToggleLike,
    this.onViewRegistrants,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _pressed = false;

  Color get _categoryColor =>
      widget.config.colorForCategory(widget.post.category);

  bool get _isEvent => widget.post.isEvent;
  bool get _isWorkshop => widget.post.category == PostCategory.workshop;
  bool get _isGallery => widget.post.category == PostCategory.gallery;
  bool get _isAchievement => widget.post.category == PostCategory.achievement;

  void _sharePostDynamic(BuildContext context) {
    final post = widget.post;
    final String shareText = '''
📢 ${post.title}

${post.description}

🏫 Department: ${post.department}
${post.isEvent && post.venue != null ? "📍 Venue: ${post.venue}\n" : ""}${post.isEvent && post.eventDate != null ? "📅 Event Date: ${_formatEventDate(post.eventDate!)}\n" : ""}
📲 Shared via StudentHub: https://studenthub.edu/post/${post.id}
''';

    Share.share(shareText, subject: post.title);
  }

  void _showActionFeedback(BuildContext context, String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final categoryColor = _categoryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: post.isUrgent
                      ? widget.config.urgentColor.withValues(
                          alpha: _pressed ? 0.35 : 0.2,
                        )
                      : (_isAchievement
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                          : (_isGallery
                              ? const Color(0xFF0284C7).withValues(alpha: 0.14)
                              : Colors.black.withValues(
                                  alpha: _pressed ? (isDark ? 0.3 : 0.08) : (isDark ? 0.2 : 0.035),
                                ))),
                  blurRadius: post.isUrgent ? 16 : (_pressed ? 16 : 12),
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? (_isAchievement
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                        : (_isGallery
                            ? const Color(0xFF0284C7).withValues(alpha: 0.5)
                            : (_isWorkshop
                                ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                                : const Color(0xFF334155))))
                    : (_isAchievement
                        ? const Color(0xFFFDE68A)
                        : (_isGallery
                            ? const Color(0xFFBAE6FD)
                            : (_isWorkshop
                                ? const Color(0xFFE0E7FF)
                                : Colors.grey.shade200))),
                width: (_isAchievement || _isGallery) ? 1.5 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Differentiating Category Top Banner Strip for Events & Workshops
                  _buildCategoryBannerStrip(post, categoryColor),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author Info Header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) => UserProfileScreen(
                                      authorId: post.authorId,
                                      authorName: post.authorName,
                                      authorRole: post.authorRole,
                                      authorAvatarUrl: post.authorAvatarUrl,
                                      department: post.department,
                                      year: post.targetYear,
                                    ),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                radius: 19,
                                backgroundColor: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFF1F5F9),
                                child: ClipOval(
                                  child: Builder(
                                    builder: (context) {
                                      final dataService = Provider.of<MockDataService>(context, listen: true);
                                      final avatarUrl = (post.authorAvatarUrl != null && post.authorAvatarUrl!.isNotEmpty)
                                          ? post.authorAvatarUrl!
                                          : (dataService.getAuthorAvatar(post.authorId, post.authorName) ?? '');

                                      if (avatarUrl.isNotEmpty) {
                                        return AppImage(
                                          source: avatarUrl,
                                          fit: BoxFit.cover,
                                          width: 38,
                                          height: 38,
                                          errorChild: Text(
                                            post.authorName.isNotEmpty
                                                ? post.authorName.substring(0, 1).toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : const Color(0xFF334155),
                                              fontSize: 13,
                                            ),
                                          ),
                                        );
                                      }
                                      return Text(
                                        post.authorName.isNotEmpty
                                            ? post.authorName.substring(0, 1).toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF334155),
                                          fontSize: 13,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (c) => UserProfileScreen(
                                        authorId: post.authorId,
                                        authorName: post.authorName,
                                        authorRole: post.authorRole,
                                        authorAvatarUrl: post.authorAvatarUrl,
                                        department: post.department,
                                        year: post.targetYear,
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            post.authorName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13.5,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              height: 1.2,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (post.authorRole != UserRole.student) ...[
                                          const SizedBox(width: 4),
                                          RoleBadge(
                                            role: post.authorRole,
                                            isCompact: true,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${post.department} • ${_formatTimestamp(post.timestamp)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        fontWeight: FontWeight.w400,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Post Title
                        if (post.title.isNotEmpty) ...[
                          Text(
                            post.title,
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              height: 1.25,
                            ),
                          ),
                        ],

                        // Post Description
                        if (post.description.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          _ExpandableDescription(text: post.description),
                        ],

                        // Gallery & Cover Images — Only display verified synced images
                        Builder(
                          builder: (context) {
                            final validGallery = post.imageUrls
                                .where((u) =>
                                    u.trim().isNotEmpty &&
                                    !u.startsWith('data:') &&
                                    !u.startsWith('local://') &&
                                    !u.startsWith('file://'))
                                .toList();
                            final hasValidCover = post.imageUrl != null &&
                                post.imageUrl!.trim().isNotEmpty &&
                                !post.imageUrl!.startsWith('data:') &&
                                !post.imageUrl!.startsWith('local://') &&
                                !post.imageUrl!.startsWith('file://');

                            if (_isGallery && validGallery.isNotEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  _GalleryCarousel(images: validGallery),
                                ],
                              );
                            } else if (hasValidCover) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  GestureDetector(
                                    onTap: () => showPostImageZoomModal(
                                      context,
                                      imageUrl: post.imageUrl!,
                                      title: post.title,
                                      category: post.category,
                                      authorName: post.authorName,
                                      department: post.department,
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 1.15,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          color: const Color(0xFFF1F5F9),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            AppImage(
                                              source: post.imageUrl!,
                                              height: double.infinity,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                            Positioned(
                                              right: 10,
                                              bottom: 10,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.55),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: const [
                                                    Icon(
                                                      Icons.zoom_in_rounded,
                                                      size: 13,
                                                      color: Colors.white,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Zoom',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),

                        // Event & Workshop Details Box
                        if (post.isEvent) ...[
                          const SizedBox(height: 12),
                          _buildEventDetailsBox(post, categoryColor, isDark),
                        ],

                        // Modern PDF Attachment Tile
                        if (post.attachments.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ...post.attachments.map(
                            (att) => InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) =>
                                      PdfViewerModal(attachment: att),
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0A0A0A)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF262626)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade900.withValues(alpha: isDark ? 0.3 : 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.picture_as_pdf_rounded,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            att.title,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Tap to view • ${att.fileSize}',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: isDark ? const Color(0xFF71717A) : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF312E81) : const Color(0xFF1E1B4B),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'View',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],

                        // External links. For events the chips only appear
                        // alongside a registration form (the form takes
                        // priority on Register); link-only events surface
                        // their link through the Register button instead.
                        if (post.links.isNotEmpty &&
                            (!_isEvent || post.form != null)) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final link in post.links)
                                ActionChip(
                                  avatar: Icon(
                                    Icons.open_in_new_rounded,
                                    size: 14,
                                    color: categoryColor,
                                  ),
                                  label: Text(
                                    link.label.isEmpty
                                        ? 'Open link'
                                        : link.label,
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  side: BorderSide(
                                    color: categoryColor.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  backgroundColor: categoryColor.withValues(
                                    alpha: isDark ? 0.15 : 0.08,
                                  ),
                                  labelStyle: TextStyle(
                                    color: categoryColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  onPressed: () =>
                                      openExternalLink(context, link.url),
                                ),
                            ],
                          ),
                        ],

                        // Response form attached to a post
                        if (!_isEvent && post.form != null && post.form!.title.trim().isNotEmpty && post.form!.fields.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => openRegistrationForm(context, post),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0A0A0A)
                                    : categoryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF262626)
                                      : categoryColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: categoryColor.withValues(alpha: isDark ? 0.25 : 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.assignment_outlined,
                                      size: 20,
                                      color: categoryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          post.form!.title,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: categoryColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Tap to open response form',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? const Color(0xFF71717A) : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: categoryColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Fill Form',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 6),

                        _buildSmartActionBar(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBannerStrip(PostModel post, Color categoryColor) {
    if (_isWorkshop) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: const [
            Icon(Icons.psychology_alt_rounded, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Text(
              '🎓 Interactive Workshop · Hands-on Learning',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }

    if (post.isEvent) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: const [
            Icon(Icons.event_rounded, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Text(
              '📅 Campus Event · Live & Interactive',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEventDetailsBox(PostModel post, Color categoryColor, [bool isDark = false]) {
    final eventDate = post.eventDate;
    final maxSeats = post.maxParticipants;
    final count = post.currentRegistrations;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Date Calendar Box
          if (eventDate != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _monthShort(eventDate),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '${eventDate.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Venue, Timing & Seats Details (Perfectly aligned with consistent icons and spacing)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        post.venue ?? 'Campus Auditorium',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                if (eventDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_filled_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFF71717A) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatEventDate(eventDate),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                if (maxSeats != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.event_seat_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFF71717A) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$count / $maxSeats Seats Available',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: post.isRegistrationFull
                              ? Colors.redAccent
                              : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _monthShort(DateTime dt) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[dt.month - 1];
  }

  Widget _buildSmartActionBar(BuildContext context) {
    final post = widget.post;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> actions = [];

    // Like is available on every post
    actions.add(
      _SmartAction(
        icon: Icons.favorite_border_rounded,
        activeIcon: Icons.favorite_rounded,
        active: widget.isLiked,
        label: widget.isLiked ? 'Liked' : 'Like',
        count: '${post.likeCount}',
        color: const Color(0xFFE11D48),
        burstOnActivate: true,
        onTap: () {
          widget.onToggleLike?.call();
        },
      ),
    );

    if (_isAchievement) {
      actions.add(
        _SmartAction(
          icon: Icons.celebration_outlined,
          activeIcon: Icons.celebration_rounded,
          active: widget.isCongratulated,
          label: widget.isCongratulated ? 'Congratulated' : 'Congratulate',
          count: '${post.congratulateCount}',
          color: const Color(0xFFD97706),
          burstOnActivate: true,
          burstStyle: _BurstStyle.confetti,
          onTap: () {
            widget.onToggleCongratulate?.call();
          },
        ),
      );
    } else {
      actions.add(
        _SmartAction(
          icon: Icons.bookmark_border_rounded,
          activeIcon: Icons.bookmark_rounded,
          active: widget.isSaved,
          label: widget.isSaved ? 'Saved' : 'Save',
          count: '${post.saveCount}',
          color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
          burstOnActivate: true,
          burstIcon: Icons.bookmark_added_rounded,
          onTap: () {
            widget.onToggleSave?.call();
          },
        ),
      );
    }

    actions.add(
      _SmartAction(
        icon: Icons.ios_share_rounded,
        activeIcon: Icons.ios_share_rounded,
        active: true,
        label: 'Share',
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        onTap: () => _sharePostDynamic(context),
      ),
    );

    return Row(
      children: [
        ...actions.map(
          (a) => Padding(padding: const EdgeInsets.only(right: 4), child: a),
        ),
        const Spacer(),
        if (_isEvent) ...[
          if (widget.currentUserId != null &&
              widget.post.authorId == widget.currentUserId)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onViewRegistrants,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF4F46E5).withValues(alpha: 0.2)
                      : const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      size: 15,
                      color: Color(0xFF818CF8),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${post.currentRegistrations} registered',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF818CF8),
                      ),
                    ),
                    if (widget.onViewRegistrants != null) ...[
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: Color(0xFF818CF8),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            _RegisterButton(
              config: widget.config,
              isRegistered: widget.isRegistered,
              isFull: post.isRegistrationFull && !widget.isRegistered,
              onPressed: (widget.post.isRegistrationFull ||
                          _isRegistrationClosed(widget.post)) &&
                      !widget.isRegistered
                  ? null
                  : () => _handleRegisterPress(context),
            ),
        ],
      ],
    );
  }

  void _handleRegisterPress(BuildContext context) {
    final dataService = context.read<MockDataService>();
    final post = widget.post;

    if (widget.isRegistered) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
              SizedBox(width: 8),
              Text('Cancel Registration?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'You cannot register again once cancelled. Are you sure you want to cancel your registration?',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Keep Registration', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                dataService.cancelRegistrationPermanently(post.id);
                _showActionFeedback(context, 'Registration cancelled', Icons.cancel_outlined, Colors.redAccent);
              },
              child: const Text('Cancel It', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      if (dataService.currentUser.cancelledEventIds.contains(post.id)) {
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.block, color: Colors.red, size: 24),
                SizedBox(width: 8),
                Text('Cannot Register', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'You have previously cancelled your registration for this event and cannot re-register.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      if (post.form != null && post.form!.fields.isNotEmpty) {
        openRegistrationForm(context, post);
      } else {
        dataService.toggleEventRegistration(post.id);
        _showActionFeedback(context, '🎉 Registered successfully!', Icons.check_circle_rounded, const Color(0xFF059669));
        // Link-only events: registration is counted like a no-form event AND
        // the first attached link opens in the browser as usual.
        if (_isEvent && post.links.isNotEmpty) {
          openExternalLink(context, post.links.first.url);
        }
      }
    }
  }

  bool _isRegistrationClosed(PostModel post) {
    if (post.registrationDeadline != null &&
        DateTime.now().isAfter(post.registrationDeadline!)) {
      return true;
    }
    return false;
  }

  String _formatTimestamp(DateTime dt) => formatTimeAgo(dt);
  String _formatEventDate(DateTime dt) => formatEventDateTime(dt);
}

class _ExpandableDescription extends StatefulWidget {
  final String text;

  const _ExpandableDescription({required this.text});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();

    final isLong = widget.text.length > 140;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _expanded || !isLong
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Text(
            widget.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.0,
              color: isDark ? const Color(0xFFE4E4E7) : const Color(0xFF334155),
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
          ),
          secondChild: Text(
            widget.text,
            style: TextStyle(
              fontSize: 13.0,
              color: isDark ? const Color(0xFFE4E4E7) : const Color(0xFF334155),
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
          ),
        ),
        if (isLong)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _expanded ? 'Show less' : 'Read more',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Instagram square aspect ratio swipeable slider for gallery posts.
class _GalleryCarousel extends StatefulWidget {
  final List<String> images;

  const _GalleryCarousel({required this.images});

  @override
  State<_GalleryCarousel> createState() => _GalleryCarouselState();
}

class _GalleryCarouselState extends State<_GalleryCarousel> {
  final _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    return GestureDetector(
      onTap: () =>
          showGalleryViewer(context, images: images, initialIndex: _current),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            AspectRatio(
              aspectRatio: 1.05, // Instagram square photo aspect ratio
              child: PageView.builder(
                controller: _controller,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, index) => AppImage(
                  source: images[index],
                  height: double.infinity,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (images.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (i) {
                    final active = i == _current;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
            if (images.length > 1)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${_current + 1}/${images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _BurstStyle { single, confetti }

const List<String> _confettiEmojis = ['🎉', '👏', '⭐', '🎊', '🏅'];

class _ConfettiParticle {
  final double angle;
  final double span;
  final double size;
  final double spin;
  final double delay;
  final String? emoji;
  final IconData? icon;

  const _ConfettiParticle({
    required this.angle,
    required this.span,
    required this.size,
    required this.spin,
    required this.delay,
    this.emoji,
    this.icon,
  });
}

/// A labeled action chip with spring elastic bounce animation
class _SmartAction extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? count;
  final Color color;
  final bool active;
  final bool burstOnActivate;
  final IconData burstIcon;
  final _BurstStyle burstStyle;
  final VoidCallback? onTap;

  const _SmartAction({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.count,
    required this.color,
    required this.active,
    this.burstOnActivate = false,
    this.burstIcon = Icons.favorite,
    this.burstStyle = _BurstStyle.single,
    this.onTap,
  });

  @override
  State<_SmartAction> createState() => _SmartActionState();
}

class _SmartActionState extends State<_SmartAction>
    with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  late final Animation<double> _popCurve = CurvedAnimation(
    parent: _pop,
    curve: Curves.elasticOut,
  );

  List<_ConfettiParticle> _particles = const [];

  @override
  void didUpdateWidget(_SmartAction old) {
    super.didUpdateWidget(old);
    if (!old.active && widget.active) {
      _pop.forward(from: 0.0);
      if (widget.burstOnActivate) {
        _spawnParticles();
        _burst.forward(from: 0.0);
      }
    }
  }

  void _spawnParticles() {
    final rng = math.Random();
    if (widget.burstStyle == _BurstStyle.confetti) {
      _particles = List.generate(8, (i) {
        final angle = (i / 8) * 2 * math.pi + (rng.nextDouble() - 0.5) * 0.4;
        return _ConfettiParticle(
          angle: angle,
          span: 24.0 + rng.nextDouble() * 20.0,
          size: 11.0 + rng.nextDouble() * 4.0,
          spin: (rng.nextDouble() - 0.5) * 3.0,
          delay: rng.nextDouble() * 0.15,
          emoji: _confettiEmojis[rng.nextInt(_confettiEmojis.length)],
        );
      });
    } else {
      _particles = [
        _ConfettiParticle(
          angle: -math.pi / 2,
          span: 28.0,
          size: 16.0,
          spin: 0,
          delay: 0,
          icon: widget.burstIcon,
        ),
      ];
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = active
        ? widget.color
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        _pop.forward(from: 0.0);
        if (!active && widget.burstOnActivate) {
          _spawnParticles();
          _burst.forward(from: 0.0);
        }
        widget.onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ScaleTransition(
                  scale: _popCurve,
                  child: Icon(
                    active ? widget.activeIcon : widget.icon,
                    size: 20,
                    color: color,
                  ),
                ),
                if (widget.burstOnActivate)
                  AnimatedBuilder(
                    animation: _burst,
                    builder: (context, _) {
                      if (!_burst.isAnimating) return const SizedBox.shrink();
                      final t = _burst.value;
                      if (widget.burstStyle == _BurstStyle.confetti) {
                        return Positioned.fill(
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: _particles.map((p) {
                              final pt = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
                              final dx = math.cos(p.angle) * p.span * pt;
                              final dy = math.sin(p.angle) * p.span * pt - (pt * pt * 10);
                              final opacity = (1.0 - pt).clamp(0.0, 1.0);
                              return Transform.translate(
                                offset: Offset(dx, dy),
                                child: Transform.rotate(
                                  angle: p.spin * pt,
                                  child: Opacity(
                                    opacity: opacity,
                                    child: Text(
                                      p.emoji ?? '🎉',
                                      style: TextStyle(fontSize: p.size),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }
                      return Positioned(
                        bottom: 8 + t * 30,
                        child: Opacity(
                          opacity: (1 - t) * 0.9,
                          child: Icon(
                            widget.burstIcon,
                            size: 14 + t * 10,
                            color: widget.color,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (widget.count != null && widget.count != '0') ...[
                  const SizedBox(width: 3),
                  Text(
                    widget.count!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: active ? widget.color : (isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fresh Modern Register button: Vibrant Indigo CTA when active, Fresh Emerald badge when registered
class _RegisterButton extends StatelessWidget {
  final AppConfig config;
  final bool isRegistered;
  final bool isFull;
  final VoidCallback? onPressed;

  const _RegisterButton({
    required this.config,
    required this.isRegistered,
    required this.isFull,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isRegistered) {
      return Material(
        color: Colors.transparent,
        child: Ink(
          height: 36,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
              width: 1.2,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Registered',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 36,
      decoration: BoxDecoration(
        gradient: isFull
            ? null
            : const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isFull ? (isDark ? const Color(0xFF27272A) : Colors.grey.shade300) : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isFull
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFull ? Icons.lock_clock_outlined : Icons.how_to_reg_rounded,
                  size: 16,
                  color: isFull ? (isDark ? const Color(0xFF71717A) : Colors.grey.shade600) : Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  isFull ? 'Seats Full' : 'Register Now',
                  style: TextStyle(
                    color: isFull ? (isDark ? const Color(0xFF71717A) : Colors.grey.shade700) : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
