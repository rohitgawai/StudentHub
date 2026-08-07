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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        color: n.isRead
                            ? Theme.of(context).cardColor
                            : Colors.blue.shade50.withValues(alpha: 0.4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getCatColor(
                              n.category,
                            ).withValues(alpha: 0.2),
                            child: Icon(
                              _getCatIcon(n.category),
                              color: _getCatColor(n.category),
                            ),
                          ),
                          title: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                n.body,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(n.timestamp),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            dataService.markNotificationRead(n.id);
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
        return Colors.blue;
      case NotificationCategory.events:
        return Colors.orange;
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
}
