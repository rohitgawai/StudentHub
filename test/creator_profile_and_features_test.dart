import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_hub/models/user_model.dart';
import 'package:student_hub/models/post_model.dart';
import 'package:student_hub/services/mock_data_service.dart';
import 'package:student_hub/screens/user_profile_screen.dart';
import 'package:student_hub/screens/events_screen.dart';
import 'package:student_hub/screens/notifications_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  group('Creator Profile & Social Interactions Tests', () {
    test('MockDataService toggleLikeProfile updates count and sends social notification', () async {
      final service = MockDataService();
      const authorId = 'faculty_01';
      const authorName = 'Prof. Alan Turing';

      final initialLikes = service.getProfileLikes(authorId);
      expect(service.isProfileLiked(authorId), isFalse);

      service.toggleLikeProfile(authorId, authorName);
      expect(service.isProfileLiked(authorId), isTrue);
      expect(service.getProfileLikes(authorId), equals(initialLikes + 1));

      // Check notification dispatch
      final notifs = service.notifications;
      expect(notifs.any((n) => n.title.contains('Profile Liked')), isTrue);
      service.dispose();
    });

    testWidgets('UserProfileScreen renders creator info without phone or dashboard', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = MockDataService();

      await tester.pumpWidget(
        ChangeNotifierProvider<MockDataService>.value(
          value: service,
          child: const MaterialApp(
            home: UserProfileScreen(
              authorId: 'faculty_01',
              authorName: 'Dr. Katherine Johnson',
              authorRole: UserRole.faculty,
              department: 'Aerospace Engineering',
              year: 'Faculty Member',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify name, department, role badge are rendered
      expect(find.text('Dr. Katherine Johnson'), findsOneWidget);
      expect(find.textContaining('Aerospace Engineering'), findsWidgets);
      expect(find.textContaining('Appreciate Profile'), findsOneWidget);

      // Verify phone number and dashboard are NOT present
      expect(find.textContaining('Mobile Number'), findsNothing);
      expect(find.textContaining('Dashboard'), findsNothing);
      expect(find.byIcon(Icons.dashboard_outlined), findsNothing);

      // Tap profile like button
      await tester.tap(find.textContaining('Appreciate Profile'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Appreciated'), findsWidgets);
      service.dispose();
    });

    testWidgets('EventsScreen displays Events, Workshops, and Registered tabs', (tester) async {
      final service = MockDataService();

      await tester.pumpWidget(
        ChangeNotifierProvider<MockDataService>.value(
          value: service,
          child: const MaterialApp(
            home: EventsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Events ('), findsOneWidget);
      expect(find.textContaining('Workshops ('), findsOneWidget);
      expect(find.textContaining('Registered ('), findsOneWidget);
      // 'Hosted' tab should no longer exist
      expect(find.textContaining('Hosted ('), findsNothing);
      service.dispose();
    });

    testWidgets('NotificationsScreen renders modern feed and filter pills', (tester) async {
      final service = MockDataService();

      await tester.pumpWidget(
        ChangeNotifierProvider<MockDataService>.value(
          value: service,
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Academic'), findsOneWidget);
      expect(find.text('Events'), findsOneWidget);
      service.dispose();
    });
  });
}
