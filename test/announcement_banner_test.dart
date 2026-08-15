import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_hub/config/app_config.dart';
import 'package:student_hub/models/post_model.dart';
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
  group('Year-wise Feed Filtering', () {
    testWidgets('matchesYear correctly matches targetYear and user academic years', (
      WidgetTester tester,
    ) async {
      final service = await _createService(tester);
      try {
        final allYearsPost = PostModel(
          id: 'p_all',
          title: 'Campus Wide Post',
          description: 'All years',
          category: PostCategory.announcement,
          department: 'Computer Science & Engineering',
          targetYear: 'All',
          authorName: 'Admin',
          authorRole: UserRole.admin,
          authorId: 'admin_1',
          timestamp: DateTime.now(),
        );

        final thirdYearPost = PostModel(
          id: 'p_3rd',
          title: '3rd Year Lab',
          description: 'CSE 3rd Year only',
          category: PostCategory.academic,
          department: 'Computer Science & Engineering',
          targetYear: 'Third Year',
          authorName: 'Faculty',
          authorRole: UserRole.faculty,
          authorId: 'fac_1',
          timestamp: DateTime.now(),
        );

        final finalYearPost = PostModel(
          id: 'p_final',
          title: 'Placement Drive',
          description: 'Final Year only',
          category: PostCategory.placement,
          department: 'Computer Science & Engineering',
          targetYear: 'Final Year',
          authorName: 'Placement Officer',
          authorRole: UserRole.faculty,
          authorId: 'fac_2',
          timestamp: DateTime.now(),
        );

        // Third year user
        expect(service.matchesYear(allYearsPost, 'Third Year'), isTrue);
        expect(service.matchesYear(thirdYearPost, 'Third Year'), isTrue);
        expect(service.matchesYear(finalYearPost, 'Third Year'), isFalse);

        // Final year user
        expect(service.matchesYear(allYearsPost, 'Final Year'), isTrue);
        expect(service.matchesYear(thirdYearPost, 'Final Year'), isFalse);
        expect(service.matchesYear(finalYearPost, 'Final Year'), isTrue);

        // First year user
        expect(service.matchesYear(allYearsPost, 'First Year'), isTrue);
        expect(service.matchesYear(thirdYearPost, 'First Year'), isFalse);
        expect(service.matchesYear(finalYearPost, 'First Year'), isFalse);
      } finally {
        service.dispose();
      }
    });

    testWidgets('getPersonalizedFeed hard-excludes posts for non-matching years', (
      WidgetTester tester,
    ) async {
      final service = await _createService(tester);
      try {
        service.updateUserProfile(
          name: 'Aarav Sharma',
          department: 'Computer Science & Engineering',
          year: 'First Year',
        );

        final firstYearFeed = service.getPersonalizedFeed();
        // A first year student should NOT see posts targeted specifically to Third Year or Final Year
        for (final post in firstYearFeed) {
          expect(
            post.targetYear == null ||
                post.targetYear == 'All' ||
                post.targetYear == 'ALL' ||
                post.targetYear == 'First Year',
            isTrue,
          );
        }

        // Switch to Third Year
        service.updateUserProfile(
          name: 'Aarav Sharma',
          department: 'Computer Science & Engineering',
          year: 'Third Year',
        );

        final thirdYearFeed = service.getPersonalizedFeed();
        // Third year student should see Third Year posts
        expect(thirdYearFeed.any((p) => p.targetYear == 'Third Year'), isTrue);
        // But NOT Final Year posts
        expect(thirdYearFeed.any((p) => p.targetYear == 'Final Year'), isFalse);

        await service.flushLocalSave();
      } finally {
        service.dispose();
      }
    });
  });
}
