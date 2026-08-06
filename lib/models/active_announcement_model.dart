import 'user_model.dart';

class ActiveAnnouncement {
  final String id;
  final String title;
  final String description;
  final String authorName;
  final UserRole authorRole;
  final String department;
  final DateTime postedAt;
  final DateTime expiresAt;

  ActiveAnnouncement({
    required this.id,
    required this.title,
    required this.description,
    required this.authorName,
    required this.authorRole,
    required this.department,
    required this.postedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remaining {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String get remainingLabel {
    if (isExpired) return 'Expired';
    final r = remaining;
    if (r.inDays >= 1) {
      return '${r.inDays} day${r.inDays > 1 ? 's' : ''} left';
    }
    final hours = r.inHours;
    if (hours >= 1) {
      return '$hours hr${hours > 1 ? 's' : ''} left';
    }
    final minutes = r.inMinutes;
    return '${minutes > 1 ? minutes : 1} min${minutes > 1 ? 's' : ''} left';
  }
}
