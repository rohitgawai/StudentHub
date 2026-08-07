import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_config.dart';
import '../models/post_model.dart';
import 'role_badge.dart';
import 'pdf_viewer_modal.dart';
import 'app_image.dart';

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
  final String userYear;
  final VoidCallback? onToggleSave;
  final VoidCallback? onToggleRegister;
  final VoidCallback? onToggleCongratulate;

  const PostCard({
    super.key,
    required this.post,
    required this.config,
    required this.isSaved,
    required this.isRegistered,
    this.isCongratulated = false,
    required this.userYear,
    this.onToggleSave,
    this.onToggleRegister,
    this.onToggleCongratulate,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _pressed = false;

  Color get _categoryColor => widget.config.colorForCategory(widget.post.category);

  bool get _isEvent => widget.post.isEvent;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share Post / Announcement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  post.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF25D366),
                    child: Icon(Icons.share, color: Colors.white),
                  ),
                  title: const Text('Share via Apps (System Share Sheet)'),
                  subtitle: const Text('WhatsApp, Telegram, Messages, Mail...'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Share.share(shareText, subject: post.title);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.copy, color: Colors.blue),
                  ),
                  title: const Text('Copy Post Link & Details'),
                  subtitle: const Text('Copy formatted text to clipboard'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Clipboard.setData(ClipboardData(text: shareText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '📋 Post details & link copied to clipboard!',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
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

  void _openFirstAttachment(BuildContext context) {
    final post = widget.post;
    if (post.attachments.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => PdfViewerModal(attachment: post.attachments.first),
    );
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
                  color: Colors.black.withValues(
                    alpha: _pressed ? 0.10 : 0.04,
                  ),
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
                                    color: categoryColor.withValues(
                                      alpha: 0.3,
                                    ),
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
                        Text(
                          post.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),

                        // Optional Post Image
                        if (post.imageUrl != null) ...[
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
                                          color: (post.isRegistrationFull
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

  /// Type-aware actions:
  /// · Event/Workshop → Register (primary) · Save · Share
  /// · Achievement    → Congratulate · Share
  /// · Everything else → View PDF · Save · Share
  Widget _buildSmartActionBar(BuildContext context) {
    final post = widget.post;

    final List<Widget> actions = [];

    if (_isAchievement) {
      actions.add(
        _SmartAction(
          icon: Icons.volunteer_activism_outlined,
          activeIcon: Icons.volunteer_activism,
          active: widget.isCongratulated,
          label: widget.isCongratulated ? 'Congratulated' : 'Congratulate',
          count: '${post.congratulateCount}',
          color: widget.config.achievementColor,
          burstOnActivate: true,
          onTap: widget.onToggleCongratulate,
        ),
      );
    } else {
      if (post.attachments.isNotEmpty) {
        actions.add(
          _SmartAction(
            icon: Icons.picture_as_pdf_outlined,
            activeIcon: Icons.picture_as_pdf,
            active: true,
            label: 'View PDF',
            color: widget.config.academicColor,
            onTap: () => _openFirstAttachment(context),
          ),
        );
      }
      actions.add(
        _SmartAction(
          icon: Icons.bookmark_border,
          activeIcon: Icons.bookmark,
          active: widget.isSaved,
          label: widget.isSaved ? 'Saved' : 'Save',
          count: '${post.saveCount}',
          color: widget.config.primaryColor,
          burstOnActivate: true,
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
          (a) =>
              Padding(padding: const EdgeInsets.only(right: 4), child: a),
        ),
        const Spacer(),
        if (_isEvent)
          _RegisterButton(
            config: widget.config,
            isRegistered: widget.isRegistered,
            isFull: post.isRegistrationFull && !widget.isRegistered,
            onPressed: post.isRegistrationFull && !widget.isRegistered
                ? null
                : widget.onToggleRegister,
          ),
      ],
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

/// A labeled action chip with a springy pop animation and an optional
/// "heart burst" that fires when the action transitions to active.
class _SmartAction extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? count;
  final Color color;
  final bool active;
  final bool burstOnActivate;
  final VoidCallback? onTap;

  const _SmartAction({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.count,
    required this.color,
    required this.active,
    this.burstOnActivate = false,
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

  @override
  void didUpdateWidget(_SmartAction old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) {
      _pop.forward(from: 0.35);
    }
    if (widget.burstOnActivate && widget.active && !old.active) {
      _burst.forward(from: 0);
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
                      return Positioned(
                        bottom: 8 + t * 30,
                        child: Opacity(
                          opacity: (1 - t) * 0.9,
                          child: Icon(
                            Icons.favorite,
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
        backgroundColor: isRegistered ? Colors.grey.shade300 : config.eventColor,
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
            : (isFull ? 'Full' : 'Register Now'),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}