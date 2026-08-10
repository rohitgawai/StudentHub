import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_config.dart';
import '../models/post_model.dart';
import '../screens/form_fill_screen.dart';
import '../utils/date_formatter.dart';
import '../utils/external_links.dart';
import 'role_badge.dart';
import 'pdf_viewer_modal.dart';
import 'app_image.dart';
import 'gallery_viewer_modal.dart';

/// A post card that stays decoupled from the data service (it never
/// subscribes), so unrelated data changes don't rebuild cards. It owns the
/// micro-interactions: press-lift, animated save/congratulate, and the
/// type-aware smart action bar.
class PostCard extends StatefulWidget {
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
    required this.userYear,
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
  bool get _isGallery => widget.post.category == PostCategory.gallery;
  bool get _isAchievement => widget.post.category == PostCategory.achievement;

  void _sharePostDynamic(BuildContext context) {
    final post = widget.post;
    final String shareText =
        '''
📢 ${post.title}

${post.description}

🏫 Department: ${post.department}
${post.isEvent && post.venue != null ? "📍 Venue: ${post.venue}\n" : ""}${post.isEvent && post.eventDate != null ? "📅 Event Date: ${_formatEventDate(post.eventDate!)}\n" : ""}
📲 Shared via StudentHub: https://studenthub.edu/post/${post.id}
''';

    // Directly opens the system share sheet — no in-app dialog.
    Share.share(shareText, subject: post.title);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final categoryColor = _categoryColor;
    final hasYearMismatch =
        post.targetYear != null && post.targetYear != widget.userYear;

    return RepaintBoundary(
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _pressed ? 0.10 : 0.04),
                  blurRadius: _pressed ? 18 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: post.isUrgent
                    ? Colors.red.shade300
                    : Colors.grey.shade200,
                width: post.isUrgent ? 1.5 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Target Year Header Alert Banner
                  if (hasYearMismatch)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      color: Colors.amber.shade50,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Target Audience: ${post.targetYear} students',
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
                              backgroundColor: categoryColor.withValues(
                                alpha: 0.15,
                              ),
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
                                      RoleBadge(
                                        role: post.authorRole,
                                        isCompact: true,
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${post.department} • ${_formatTimestamp(post.timestamp)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Flexible(
                              flex: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: categoryColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  post.category.displayName.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: categoryColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Post Title — the first thing the eye lands on.
                        Text(
                          post.title,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Post Description
                        _ExpandableDescription(text: post.description),

                        // Gallery Images — fixed-size slider with dots
                        if (_isGallery && post.imageUrls.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _GalleryCarousel(images: post.imageUrls),
                        ] else if (post.imageUrl != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AppImage(
                              source: post.imageUrl,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],

                        // Event Details Box (if post is an Event/Workshop)
                        if (post.isEvent) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: categoryColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: categoryColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        post.venue ?? 'Campus Auditorium',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (post.maxParticipants != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (post.isRegistrationFull
                                                      ? Colors.red
                                                      : Colors.green)
                                                  .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '${post.currentRegistrations}/${post.maxParticipants} Seats',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: post.isRegistrationFull
                                                ? Colors.red
                                                : Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (post.eventDate != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: categoryColor,
                                      ),
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
                          ...post.attachments.map(
                            (att) => InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) =>
                                      PdfViewerModal(attachment: att),
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.red,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            'Tap to view document • ${att.fileSize}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.remove_red_eye_outlined,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // External links (Meet, registration form, brochure…)
                        if (post.links.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final link in post.links)
                                ActionChip(
                                  avatar: Icon(
                                    Icons.open_in_new,
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
                                    alpha: 0.08,
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

                        // Response form attached to a regular (non-event) post
                        if (!_isEvent && post.form != null) ...[
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
                                color: categoryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: categoryColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: categoryColor.withValues(alpha: 0.15),
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
                                            color: Colors.grey.shade700,
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

  /// · Event/Workshop → Register (primary) · Save · Share
  /// · Achievement    → Congratulate · Share
  /// · Everything else → Save · Share
  Widget _buildSmartActionBar(BuildContext context) {
    final post = widget.post;

    final List<Widget> actions = [];

    // Like is available on every post.
    actions.add(
      _SmartAction(
        icon: Icons.favorite_border,
        activeIcon: Icons.favorite,
        active: widget.isLiked,
        label: widget.isLiked ? 'Liked' : 'Like',
        count: '${post.likeCount}',
        color: Colors.redAccent,
        burstOnActivate: true,
        onTap: widget.onToggleLike,
      ),
    );

    if (_isAchievement) {
      actions.add(
        _SmartAction(
          icon: Icons.celebration,
          activeIcon: Icons.celebration,
          active: widget.isCongratulated,
          label: widget.isCongratulated ? 'Congratulated' : 'Congratulate',
          count: '${post.congratulateCount}',
          color: widget.config.achievementColor,
          burstOnActivate: true,
          burstStyle: _BurstStyle.confetti,
          onTap: widget.onToggleCongratulate,
        ),
      );
    } else {
      actions.add(
        _SmartAction(
          icon: Icons.bookmark_border,
          activeIcon: Icons.bookmark,
          active: widget.isSaved,
          label: widget.isSaved ? 'Saved' : 'Save',
          count: '${post.saveCount}',
          color: widget.config.primaryColor,
          burstOnActivate: true,
          burstIcon: Icons.bookmark_added,
          onTap: widget.onToggleSave,
        ),
      );
    }

    actions.add(
      _SmartAction(
        icon: Icons.ios_share,
        activeIcon: Icons.ios_share,
        active: true,
        label: 'Share',
        color: Colors.grey.shade600,
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
            // The event host cannot register for their own event; show the
            // current registrant count instead of a Register button. Tapping
            // it (when wired) opens the registrant list.
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onViewRegistrants,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.config.eventColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.config.eventColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 16,
                      color: widget.config.eventColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${post.currentRegistrations} registered',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: widget.config.eventColor,
                      ),
                    ),
                    if (widget.onViewRegistrants != null) ...[
                      const SizedBox(width: 3),
                      Icon(
                        Icons.chevron_right,
                        size: 13,
                        color: widget.config.eventColor,
                      ),
                    ],
                  ],
                ),
              ),
            )
          else if (widget.post.form != null)
            // Events with an attached form: Register opens the in-app form.
            _RegisterButton(
              config: widget.config,
              isRegistered: widget.isRegistered,
              isFull: widget.post.isRegistrationFull && !widget.isRegistered,
              onPressed:
                  (widget.post.isRegistrationFull ||
                          _isRegistrationClosed(widget.post)) &&
                      !widget.isRegistered
                      ? null
                      : () => openRegistrationForm(context, widget.post),
            )
          else
            _RegisterButton(
              config: widget.config,
              isRegistered: widget.isRegistered,
              isFull: post.isRegistrationFull && !widget.isRegistered,
              onPressed: post.isRegistrationFull && !widget.isRegistered
                  ? null
                  : widget.onToggleRegister,
            ),
        ],
      ],
    );
  }

  /// Past the registration deadline: quick toggle is blocked (form events are
  /// guarded in submitForm), the button is disabled for everyone.
  bool _isRegistrationClosed(PostModel post) {
    final deadline = post.registrationDeadline;
    return deadline != null && DateTime.now().isAfter(deadline);
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '0m ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatEventDate(DateTime dt) => formatEventDateTime(dt);
}

/// Instagram-style collapsible description: clipped to a few lines with a
/// "View more" reveal and a "Show less" collapse back to the default height.
class _ExpandableDescription extends StatefulWidget {
  final String text;

  const _ExpandableDescription({required this.text});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  static const int _collapsedLines = 3;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 14, height: 1.45);
    final textStyle = style.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final plain = TextPainter(
          text: TextSpan(text: widget.text, style: textStyle),
          maxLines: _collapsedLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final didExceed = plain.didExceedMaxLines;

        if (!didExceed) {
          return Text(widget.text, style: textStyle);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: textStyle,
              maxLines: _expanded ? null : _collapsedLines,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _expanded ? 'Show less' : 'View more',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Fixed-size swipeable slider for gallery posts. Every image is rendered at
/// the same height/width (BoxFit.cover) and dots indicate the current slide.
class _GalleryCarousel extends StatefulWidget {
  final List<String> images;

  const _GalleryCarousel({required this.images});

  @override
  State<_GalleryCarousel> createState() => _GalleryCarouselState();
}

class _GalleryCarouselState extends State<_GalleryCarousel> {
  static const double _imageHeight = 240;

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
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            SizedBox(
              height: _imageHeight,
              width: double.infinity,
              child: PageView.builder(
                controller: _controller,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, index) => AppImage(
                  source: images[index],
                  height: _imageHeight,
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
                right: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
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

/// How a burst renders when an action transitions to active:
/// a single rising icon, or an emoji-confetti explosion.
enum _BurstStyle { single, confetti }

const List<String> _confettiEmojis = ['🎉', '👏', '⭐', '🎊', '🏅'];

/// A single confetti fragment thrown by a celebratory burst.
class _ConfettiParticle {
  final double angle; // radians, 0 = straight up
  final double span; // travel distance in px at t=1
  final double size; // px
  final double spin; // total rotation in radians
  final double delay; // 0..1 fraction of the burst
  final String? emoji; // celebratory emoji particle
  final IconData? icon; // icon particle

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

/// A labeled action chip with a springy pop animation and an optional
/// celebratory burst that fires when the action transitions to active.
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
    if (widget.active != old.active) {
      _pop.forward(from: 0.35);
    }
    if (widget.burstOnActivate && widget.active && !old.active) {
      if (widget.burstStyle == _BurstStyle.confetti) {
        _burst.duration = const Duration(milliseconds: 750);
        _particles = _makeConfetti();
      } else {
        _burst.duration = const Duration(milliseconds: 600);
      }
      _burst.forward(from: 0);
    }
  }

  List<_ConfettiParticle> _makeConfetti() {
    final rnd = math.Random();
    return List.generate(
      14,
      (i) {
        final fan = (rnd.nextDouble() - 0.5) * 2.1;
        final isEmoji = i.isEven;
        return _ConfettiParticle(
          angle: -math.pi / 2 + fan,
          span: 55 + rnd.nextDouble() * 95,
          size: 11 + rnd.nextDouble() * 8,
          spin: (rnd.nextDouble() - 0.5) * 2.4,
          delay: rnd.nextDouble() * 0.25,
          emoji: isEmoji
              ? _confettiEmojis[(i ~/ 2) % _confettiEmojis.length]
              : null,
          icon: isEmoji
              ? null
              : (i ~/ 2).isEven
                  ? Icons.celebration
                  : Icons.auto_awesome,
        );
      },
    );
  }

  Widget _confettiParticle(_ConfettiParticle p, double t) {
    final progress = t <= p.delay ? 0.0 : (t - p.delay) / (1 - p.delay);
    final eased = Curves.easeInCubic.transform(progress);
    final size = p.size + 9 * Curves.easeOutCubic.transform(progress);
    final dx = math.cos(p.angle) * p.span * eased;
    final dy = -math.sin(p.angle) * p.span * eased;
    return Positioned(
      left: 70 + dx - size / 2,
      top: 60 + dy - size / 2,
      child: Opacity(
        opacity: (1 - progress) * 0.95,
        child: Transform.rotate(
          angle: p.spin * progress,
          child: p.emoji != null
              ? Text(p.emoji!, style: TextStyle(fontSize: size))
              : Icon(p.icon, size: size, color: widget.color),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pop.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? widget.color : Colors.grey.shade500;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                ScaleTransition(
                  scale: _popCurve,
                  child: Icon(
                    widget.active ? widget.activeIcon : widget.icon,
                    size: 22,
                    color: color,
                  ),
                ),
                // The burst exists only while the animation is playing; at
                // rest it is not in the tree at all, so no icon sits over the
                // action before it is performed.
                if (widget.burstOnActivate)
                  AnimatedBuilder(
                    animation: _burst,
                    builder: (context, child) {
                      if (!_burst.isAnimating) return const SizedBox.shrink();
                      final t = _burst.value;
                      if (widget.burstStyle == _BurstStyle.confetti) {
                        return Positioned(
                          left: -59,
                          top: -49,
                          child: IgnorePointer(
                            child: SizedBox(
                              width: 140,
                              height: 120,
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  for (final p in _particles)
                                    _confettiParticle(p, t),
                                ],
                              ),
                            ),
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
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (widget.count != null) ...[
                  const SizedBox(width: 3),
                  Text(
                    widget.count!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
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
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isRegistered
            ? Colors.grey.shade300
            : config.eventColor,
        foregroundColor: isRegistered ? Colors.black87 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isRegistered ? 0 : 2,
      ),
      onPressed: onPressed,
      icon: Icon(
        isRegistered ? Icons.check_circle : Icons.how_to_reg,
        size: 16,
      ),
      label: Text(
        isRegistered
            ? 'Registered'
            : (isFull ? 'Registrations closed' : 'Register Now'),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
