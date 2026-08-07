import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_hub/config/app_config.dart';
import 'package:student_hub/models/user_model.dart';
import 'package:student_hub/services/mock_data_service.dart';

Future<MockDataService> _createService(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final service = MockDataService(initialConfig: AppConfig.defaultConfig());
  while (service.isLoading) {
    await tester.pump();
  }
  return service;
}

void main() {
  testWidgets('Urgent Announcement posts with duration and blocks same-department posts', (WidgetTester tester) async {
    final service = await _createService(tester);
    try {
      final posted = service.postAnnouncement(
        title: 'Fee Notice',
        description: 'Deadline extended',
        department: 'Computer Science & Engineering',
        duration: const Duration(days: 14),
        authorName: 'Dr. Ramesh K. Verma',
        authorRole: UserRole.faculty,
      );

      expect(posted, isTrue);
      final ann = service.activeAnnouncementFor('Computer Science & Engineering');
      expect(ann, isNotNull);
      expect(ann!.title, 'Fee Notice');
      expect(ann.expiresAt.difference(DateTime.now()).inDays, greaterThanOrEqualTo(13));

      final wait = service.canPostAnnouncement('Computer Science & Engineering');
      expect(wait, isNotNull);
      expect(wait!.inDays, greaterThanOrEqualTo(13));

      final blocked = service.postAnnouncement(
        title: 'Another Notice',
        description: 'Should be blocked',
        department: 'Computer Science & Engineering',
        duration: const Duration(days: 7),
        authorName: 'Prof. Ananya Sen',
        authorRole: UserRole.faculty,
      );
      expect(blocked, isFalse);
      expect(service.activeAnnouncementFor('Computer Science & Engineering')!.title, 'Fee Notice');

      final otherDept = service.postAnnouncement(
        title: 'IT Seminar',
        description: 'Allowed in another department',
        department: 'Information Technology',
        duration: const Duration(days: 7),
        authorName: 'Prof. Ananya Sen',
        authorRole: UserRole.faculty,
      );
      expect(otherDept, isTrue);
      expect(service.activeAnnouncementFor('Information Technology')!.title, 'IT Seminar');
    } finally {
      service.dispose();
    }
  });

  testWidgets('Expired announcement no longer blocks new posts', (WidgetTester tester) async {
    final service = await _createService(tester);
    try {
      final expired = service.postAnnouncement(
        title: 'Old Notice',
        description: 'Already expired',
        department: 'Computer Science & Engineering',
        duration: const Duration(days: -1),
        authorName: 'Admin',
        authorRole: UserRole.admin,
      );
      expect(expired, isTrue);
      expect(service.activeAnnouncements.where((a) => a.department == 'Computer Science & Engineering'), isEmpty);
      expect(service.canPostAnnouncement('Computer Science & Engineering'), isNull);

      final posted = service.postAnnouncement(
        title: 'Fresh Notice',
        description: 'New announcement allowed',
        department: 'Computer Science & Engineering',
        duration: const Duration(days: 7),
        authorName: 'Admin',
        authorRole: UserRole.admin,
      );
      expect(posted, isTrue);
      expect(service.activeAnnouncementFor('Computer Science & Engineering')!.title, 'Fresh Notice');
    } finally {
      service.dispose();
    }
  });
}
