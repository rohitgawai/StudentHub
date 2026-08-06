enum NotificationCategory {
  academic,
  events,
  general,
  personal,
}

extension NotificationCategoryExtension on NotificationCategory {
  String get displayName {
    switch (this) {
      case NotificationCategory.academic:
        return 'Academic';
      case NotificationCategory.events:
        return 'Events';
      case NotificationCategory.general:
        return 'General';
      case NotificationCategory.personal:
        return 'Personal';
    }
  }
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime timestamp;
  final bool isRead;
  final String? relatedPostId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    this.isRead = false,
    this.relatedPostId,
  });

  NotificationModel copyWith({
    bool? isRead,
  }) {
    return NotificationModel(
      id: id,
      title: title,
      body: body,
      category: category,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      relatedPostId: relatedPostId,
    );
  }
}
