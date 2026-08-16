import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_hub/models/user_model.dart';
import 'package:student_hub/models/post_model.dart';
import 'package:student_hub/services/mock_data_service.dart';
import 'package:student_hub/screens/user_profile_screen.dart';
import 'package:student_hub/screens/events_screen.dart';
import 'package:student_hub/models/form_models.dart';
import 'package:student_hub/utils/form_export.dart';
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

    test('buildRegistrantCsv properly formats rows and prevents merged cells or line corruption', () {
      final post = PostModel(
        id: 'event_test_1',
        title: 'Flutter Workshop 2026',
        description: 'Deep dive into Flutter',
        authorId: 'faculty_01',
        authorName: 'Dr. Jane Doe',
        authorRole: UserRole.faculty,
        department: 'Computer Science',
        timestamp: DateTime.now(),
        category: PostCategory.workshop,
        eventDate: DateTime(2026, 8, 20),
        form: const FormDefinition(
          id: 'form_1',
          title: 'Workshop Form',
          fields: [
            FormFieldSpec(
              id: 'Dietary Preference',
              type: FormFieldType.shortText,
              label: 'Dietary Preference',
            ),
            FormFieldSpec(
              id: 'Experience Level',
              type: FormFieldType.shortText,
              label: 'Experience Level',
            ),
          ],
        ),
      );

      final List<FormSubmission> submissions = [
        FormSubmission(
          id: 'sub_1',
          postId: 'event_test_1',
          userId: 'user_01',
          name: 'Rohit Sharma',
          studentOrEmployeeId: 'MIT2024001',
          department: 'Computer Science',
          year: '3rd Year',
          mobileNumber: '9876543210',
          submittedAt: DateTime(2026, 8, 16, 10, 30),
          answers: {
            'Dietary Preference': 'Vegetarian, No Onion\nNo Garlic',
            'Experience Level': 'Intermediate "Pro"',
          },
        ),
        FormSubmission(
          id: 'sub_2',
          postId: 'event_test_1',
          userId: 'user_02',
          name: 'Priya Patel',
          studentOrEmployeeId: 'MIT2024002',
          department: 'Information Technology',
          year: '2nd Year',
          mobileNumber: '9876543211',
          submittedAt: DateTime(2026, 8, 16, 11, 00),
          answers: {
            'Dietary Preference': 'Standard',
            'Experience Level': 'Beginner',
          },
        ),
      ];

      final csv = buildRegistrantCsv(post: post, submissions: submissions);

      // Verify UTF-8 BOM
      expect(csv.startsWith('\uFEFF'), isTrue);

      // Split lines by CRLF
      final lines = csv.substring(1).split('\r\n').where((l) => l.isNotEmpty).toList();
      expect(lines.length, equals(3)); // 1 header + 2 rows

      // Verify Header
      expect(lines[0], contains('"Sr. No."'));
      expect(lines[0], contains('"Full Name"'));
      expect(lines[0], contains('"Student ID"'));

      // Verify First Row (Quotes and multiline properly escaped)
      expect(lines[1], contains('"1"'));
      expect(lines[1], contains('"Rohit Sharma"'));
      expect(lines[1], contains('"MIT2024001"'));
      expect(lines[1], contains('Intermediate ""Pro""'));

      // Verify Second Row
      expect(lines[2], contains('"2"'));
      expect(lines[2], contains('"Priya Patel"'));
      expect(lines[2], contains('"MIT2024002"'));
    });
  });
}
