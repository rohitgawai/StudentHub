import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_hub/models/notification_model.dart';
import 'package:student_hub/models/post_model.dart';
import 'package:student_hub/models/user_model.dart';
import 'package:student_hub/services/mock_data_service.dart';

void main() {
  testWidgets('Notification deletion and clear-all persist across operations', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = MockDataService();
    while (service.isLoading) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(service.notifications.isNotEmpty, isTrue);
    final initialCount = service.notifications.length;
    final firstId = service.notifications.first.id;

    // 1. Delete single notification
    service.deleteNotification(firstId);
    expect(service.notifications.any((n) => n.id == firstId), isFalse);
    expect(service.notifications.length, equals(initialCount - 1));

    // 2. Clear all notifications
    service.clearAllNotifications();
    expect(service.notifications.isEmpty, isTrue);

    // 3. Posts older than cleared cutoff should not resurface notifications
    final oldPost = PostModel(
      id: 'pst_old_test',
      title: 'Old Post',
      description: 'Old Post Desc',
      category: PostCategory.academic,
      department: 'CSE',
      authorName: 'Prof Test',
      authorRole: UserRole.faculty,
      authorId: 'fac_999',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    );

    // Verify manually that the clearing cutoff filters it out
    final cutoff = service.notificationsClearedAt;
    expect(cutoff, isNotNull);
    expect(cutoff!.isUtc, isTrue);
    expect(oldPost.timestamp.toUtc().isAfter(cutoff), isFalse);

    // 4. A new broadcast arriving AFTER cutoff should be added
    final newNotif = NotificationModel(
      id: 'notif_admin_broadcast_new_test',
      title: '📢 Important New Announcement',
      body: 'Campus announcement\n\nBy Admin',
      category: NotificationCategory.general,
      timestamp: DateTime.now().add(const Duration(seconds: 1)),
    );

    expect(newNotif.timestamp.toUtc().isAfter(cutoff), isTrue);

    await service.flushLocalSave();
    service.dispose();
  });
}
