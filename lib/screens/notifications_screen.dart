import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../services/mock_data_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String selectedCat = 'All';

  void _showNotificationDetail(BuildContext context, NotificationModel n) {
    final dataService = context.read<MockDataService>();
    if (!n.isRead) {
      dataService.markNotificationRead(n.id);
    }

    final catColor = _getCatColor(n.category);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Header Row (Gmail Inbox Style)
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: catColor.withValues(alpha: 0.15),
                    child: Icon(_getCatIcon(n.category), color: catColor, size: 20),
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
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Title
              SelectableText(
                n.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Full Message Body
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SelectableText(
                  n.body,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<MockDataService>();
    final notifs = context.select((MockDataService s) => s.notifications);

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
      appBar: AppBar(
        title: const Text('🔔 Campus Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark All as Read',
            onPressed: () {
              dataService.markAllNotificationsRead();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All notifications marked as read.'),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: ['All', 'Academic', 'Events', 'General', 'Personal']
                  .map((cat) {
                    final isSelected = selectedCat == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (sel) => setState(() => selectedCat = cat),
                      ),
                    );
                  })
                  .toList(),
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No notifications in this category',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final n = filtered[index];
                      final catColor = _getCatColor(n.category);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: n.isRead ? 1 : 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: n.isRead ? Colors.transparent : catColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        color: n.isRead
                            ? Theme.of(context).cardColor
                            : catColor.withValues(alpha: 0.05),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: catColor.withValues(alpha: 0.2),
                                child: Icon(
                                  _getCatIcon(n.category),
                                  color: catColor,
                                  size: 20,
                                ),
                              ),
                              if (!n.isRead)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                n.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    _formatTime(n.timestamp),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Tap to read full →',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: catColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            _showNotificationDetail(context, n);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getCatColor(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.academic:
        return Colors.blue.shade700;
      case NotificationCategory.events:
        return Colors.orange.shade800;
      case NotificationCategory.general:
        return Colors.blueGrey;
      case NotificationCategory.personal:
        return Colors.purple;
    }
  }

  IconData _getCatIcon(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.academic:
        return Icons.school;
      case NotificationCategory.events:
        return Icons.event;
      case NotificationCategory.general:
        return Icons.campaign;
      case NotificationCategory.personal:
        return Icons.person;
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 1) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  String _formatFullDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
