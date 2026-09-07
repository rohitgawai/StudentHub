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
    String? id,
    String? title,
    String? body,
    NotificationCategory? category,
    DateTime? timestamp,
    bool? isRead,
    String? relatedPostId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      relatedPostId: relatedPostId ?? this.relatedPostId,
    );
  }
}
