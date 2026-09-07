import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';
import '../services/update_service.dart';
import '../widgets/post_detail_modal.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String selectedCat = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MockDataService>().syncNow();
      }
    });
  }

  bool _isAppUpdateNotif(NotificationModel n) {
    return n.relatedPostId == 'app_update' ||
        n.id.contains('update') ||
        n.title.toLowerCase().contains('update') ||
        n.body.toLowerCase().contains('what\'s new');
  }

  void _handleNotificationTap(BuildContext context, NotificationModel n) {
    final dataService = context.read<MockDataService>();
    if (!n.isRead) {
      dataService.markNotificationRead(n.id);
    }

    if (_isAppUpdateNotif(n)) {
      UpdateService.instance.checkForUpdate(context, silent: false, forceShow: true);
      return;
    }

    // Role decisions, admin broadcasts, and app updates must never deep-link into a post detail modal.
    if (n.relatedPostId != null &&
        n.relatedPostId!.isNotEmpty &&
        !_isRoleNotif(n) &&
        !_isAdminAnnouncement(n, dataService)) {
      // Direct deep link to post / event / gallery detail page!
      PostDetailModal.show(context, n.relatedPostId!);
    } else {
      _showNotificationDetail(context, n);
    }
  }

  /// True for role-related notifications (approved / rejected / removed /
  /// expired): their relatedPostId holds a role-request id ('req_...'), not a
  /// post id, so they must not render a "view post" hint or deep-link.
  bool _isRoleNotif(NotificationModel n) {
    final ref = n.relatedPostId ?? '';
    if (ref.startsWith('req_')) return true;
    return n.title.toLowerCase().contains('role');
  }

  bool _isAdminAnnouncement(NotificationModel n, MockDataService dataService) {
    if (n.id.startsWith('notif_admin_broadcast_') ||
        n.id.startsWith('announcement_') ||
        n.title.toLowerCase().contains('admin') ||
        n.body.toLowerCase().contains('admin') ||
        n.title.toLowerCase().contains('announcement') ||
        n.title.toLowerCase().contains('update') ||
        n.title.toLowerCase().contains('notice')) {
      return true;
    }
    if (n.relatedPostId != null && n.relatedPostId!.isNotEmpty) {
      final post = dataService.posts.cast<PostModel?>().firstWhere(
            (p) => p?.id == n.relatedPostId,
            orElse: () => null,
          );
      if (post != null &&
          (post.authorRole == UserRole.admin ||
              post.category == PostCategory.announcement)) {
        return true;
      }
    }
    return false;
  }

  void _showNotificationDetail(BuildContext context, NotificationModel n) {
    final catColor = _getCatColor(n.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: isDark ? const Color(0xFF2E2E38) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Designed decorative header banner with ambient gradient
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          catColor.withValues(alpha: 0.24),
                          const Color(0xFF18181B),
                        ]
                      : [
                          catColor.withValues(alpha: 0.12),
                          Colors.white,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: isDark ? 0.3 : 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getNotificationIcon(n), color: catColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.category.displayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: catColor,
                          ),
                        ),
                        Text(
                          _formatFullDateTime(n.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF71717A) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF262626) : Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

              SelectableText(
                n.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
                  ),
                ),
                child: SelectableText(
                  n.body,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? const Color(0xFFE4E4E7) : const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (n.title.toLowerCase().contains('update') ||
                      n.body.toLowerCase().contains('what\'s new')) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.system_update_rounded, size: 16),
                      label: const Text('Update Now'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        UpdateService.instance.checkForUpdate(context, silent: false, forceShow: true);
                      },
                    ),
                    const SizedBox(width: 10),
                  ],
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: catColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);
}

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<MockDataService>();
    final notifs = context.select((MockDataService s) => s.notifications);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = selectedCat == 'All'
        ? notifs
        : notifs
            .where(
              (n) =>
                  n.category.displayName.toLowerCase() ==
                  selectedCat.toLowerCase(),
            )
            .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Mark All as Read',
            onPressed: notifs.isEmpty
                ? null
                : () {
                    dataService.markAllNotificationsRead();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All notifications marked as read.'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear All Notifications',
            onPressed: notifs.isEmpty
                ? null
                : () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF262626) : Colors.transparent,
                          ),
                        ),
                        title: Text(
                          'Clear All Notifications?',
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        ),
                        content: Text(
                          'Are you sure you want to clear all campus notifications?',
                          style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : Colors.black54),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              dataService.clearAllNotifications();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Notifications cleared.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: const Text('Clear All'),
                          ),
                        ],
                      ),
                    );
                  },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Sleek Minimal Filter Pills
          Container(
            color: isDark ? const Color(0xFF121212) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: ['All', 'Academic', 'Events', 'General', 'Personal']
                    .map((cat) {
                      final isSelected = selectedCat == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: isDark ? const Color(0xFF3B82F6) : const Color(0xFF0F172A),
                          backgroundColor: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF1F5F9),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF475569)),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 12.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide.none,
                          ),
                          onSelected: (sel) => setState(() => selectedCat = cat),
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0)),

          // Dynamic Modern Social Feed List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => dataService.syncNow(),
              child: filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.45,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 64,
                                  color: isDark ? const Color(0xFF52525B) : Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No notifications in $selectedCat',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFFA1A1AA) : Colors.grey.shade600,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        indent: 72,
                        endIndent: 16,
                        color: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        final n = filtered[index];
                        final isUpdate = _isAppUpdateNotif(n);
                        final catColor = isUpdate ? const Color(0xFF2563EB) : _getCatColor(n.category);
                        final isUnread = !n.isRead;
                        final isAdminAnnounce = _isAdminAnnouncement(n, dataService);
                        final hasPost = n.relatedPostId != null &&
                            n.relatedPostId!.isNotEmpty &&
                            !_isRoleNotif(n);

                        return Dismissible(
                          key: ValueKey(n.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            color: Colors.red.shade600,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                                SizedBox(width: 6),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onDismissed: (_) {
                            dataService.deleteNotification(n.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Notification removed.'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: InkWell(
                            onTap: () => _handleNotificationTap(context, n),
                          child: Container(
                            color: isUnread
                                ? (isDark ? const Color(0xFF1E1E28) : const Color(0xFFF0F9FF))
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar Badge with Category Icon
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: catColor.withValues(alpha: isDark ? 0.25 : 0.12),
                                      child: Icon(
                                        _getNotificationIcon(n),
                                        color: catColor,
                                        size: 22,
                                      ),
                                    ),
                                    if (isUnread)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF121212) : Colors.white,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),

                                // Notification Text Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              n.title,
                                              style: TextStyle(
                                                fontWeight: isUnread
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                fontSize: 14,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatTime(n.timestamp),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isUnread
                                                  ? const Color(0xFF3B82F6)
                                                  : (isDark ? const Color(0xFF71717A) : Colors.grey.shade500),
                                              fontWeight: isUnread
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.35,
                                          color: isUnread
                                              ? (isDark ? const Color(0xFFE4E4E7) : const Color(0xFF1E293B))
                                              : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B)),
                                          fontWeight: isUnread
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      if (isUpdate) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.rocket_launch_rounded, size: 13, color: Color(0xFF2563EB)),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    'App Update • Tap to view & install',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else if (hasPost && !isAdminAnnounce) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.open_in_new_rounded,
                                              size: 13,
                                              color: catColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Tap to view post',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: catColor,
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
                          ),
                        ),
                      );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCatColor(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.academic:
        return const Color(0xFF2563EB); // Modern Indigo/Blue
      case NotificationCategory.events:
        return const Color(0xFFEA580C); // Modern Orange
      case NotificationCategory.general:
        return const Color(0xFF0D9488); // Modern Teal
      case NotificationCategory.personal:
        return const Color(0xFFE11D48); // Modern Rose/Pink
    }
  }

  IconData _getNotificationIcon(NotificationModel n) {
    if (_isAppUpdateNotif(n)) {
      return Icons.rocket_launch_rounded;
    }
    if (_isRoleNotif(n)) {
      final t = n.title.toLowerCase();
      if (t.contains('rejected') || t.contains('removed')) {
        return Icons.gpp_bad_rounded; // Shield with X — denial
      }
      if (t.contains('approved') || t.contains('granted')) {
        return Icons.workspace_premium_rounded; // Medal — granted role
      }
      return Icons.shield_rounded; // Generic role/account alert
    }
    switch (n.category) {
      case NotificationCategory.academic:
        return Icons.school_rounded;
      case NotificationCategory.events:
        return Icons.event_available_rounded;
      case NotificationCategory.general:
        return Icons.campaign_rounded;
      case NotificationCategory.personal:
        return Icons.favorite_rounded;
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }

  String _formatFullDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
