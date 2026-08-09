import 'user_model.dart';

enum PostCategory {
  announcement,
  event,
  academic,
  workshop,
  achievement,
  gallery,
  placement,
  urgent,
  urgentAnnouncement,
}

extension PostCategoryExtension on PostCategory {
  String get displayName {
    switch (this) {
      case PostCategory.announcement:
        return 'Announcement';
      case PostCategory.event:
        return 'Event';
      case PostCategory.academic:
        return 'Academic';
      case PostCategory.workshop:
        return 'Workshop';
      case PostCategory.achievement:
        return 'Achievement';
      case PostCategory.gallery:
        return 'Gallery';
      case PostCategory.placement:
        return 'Placement';
      case PostCategory.urgent:
        return 'Urgent';
      case PostCategory.urgentAnnouncement:
        return 'Urgent Announcement';
    }
  }
}

class PostAttachment {
  final String title;
  final String fileType; // pdf, image, doc
  final String url;
  final String fileSize;

  PostAttachment({
    required this.title,
    required this.fileType,
    required this.url,
    required this.fileSize,
  });
}

class PostModel {
  final String id;
  final String title;
  final String description;
  final PostCategory category;
  final String department;
  final String? targetYear; // null means all years
  final String authorName;
  final UserRole authorRole;
  final String authorId;
  final DateTime timestamp;
  final String? imageUrl;
  final List<String> imageUrls; // gallery posts: 3-6 images
  final List<PostAttachment> attachments;
  final bool isUrgent;
  final bool isPinned;
  final int saveCount;
  final int congratulateCount;
  final int likeCount;
  final List<String> congratulatedUserIds;
  final List<String> likedUserIds;
  
  // Optional Event/Workshop details
  final String? venue;
  final DateTime? eventDate;
  final DateTime? registrationDeadline;
  final int? maxParticipants;
  final List<String> registeredUserIds;

  PostModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.department,
    this.targetYear,
    required this.authorName,
    required this.authorRole,
    required this.authorId,
    required this.timestamp,
    this.imageUrl,
    this.imageUrls = const [],
    this.attachments = const [],
    this.isUrgent = false,
    this.isPinned = false,
    this.saveCount = 0,
    this.congratulateCount = 0,
    this.likeCount = 0,
    this.congratulatedUserIds = const [],
    this.likedUserIds = const [],
    this.venue,
    this.eventDate,
    this.registrationDeadline,
    this.maxParticipants,
    this.registeredUserIds = const [],
  });

  bool get isEvent => category == PostCategory.event || category == PostCategory.workshop;
  int get currentRegistrations => registeredUserIds.length;
  bool get isRegistrationFull => maxParticipants != null && currentRegistrations >= maxParticipants!;

  PostModel copyWith({
    String? id,
    String? title,
    String? description,
    PostCategory? category,
    String? department,
    String? targetYear,
    String? authorName,
    UserRole? authorRole,
    String? authorId,
    DateTime? timestamp,
    String? imageUrl,
    List<String>? imageUrls,
    List<PostAttachment>? attachments,
    bool? isUrgent,
    bool? isPinned,
    int? saveCount,
    int? congratulateCount,
    int? likeCount,
    List<String>? congratulatedUserIds,
    List<String>? likedUserIds,
    String? venue,
    DateTime? eventDate,
    DateTime? registrationDeadline,
    int? maxParticipants,
    List<String>? registeredUserIds,
  }) {
    return PostModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      department: department ?? this.department,
      targetYear: targetYear ?? this.targetYear,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      authorId: authorId ?? this.authorId,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      attachments: attachments ?? this.attachments,
      isUrgent: isUrgent ?? this.isUrgent,
      isPinned: isPinned ?? this.isPinned,
      saveCount: saveCount ?? this.saveCount,
      congratulateCount: congratulateCount ?? this.congratulateCount,
      likeCount: likeCount ?? this.likeCount,
      congratulatedUserIds:
          congratulatedUserIds ?? this.congratulatedUserIds,
      likedUserIds: likedUserIds ?? this.likedUserIds,
      venue: venue ?? this.venue,
      eventDate: eventDate ?? this.eventDate,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      registeredUserIds: registeredUserIds ?? this.registeredUserIds,
    );
  }
}
