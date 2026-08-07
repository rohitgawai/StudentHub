import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_hub/config/app_config.dart';
import 'package:student_hub/models/user_model.dart';
import 'package:student_hub/services/mock_data_service.dart';

Future<MockDataService> _createService(WidgetTester tester) async {
  final service = MockDataService(initialConfig: AppConfig.defaultConfig());
  while (service.isLoading) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  return service;
}

void main() {
  testWidgets('profile and last active role persist across app restarts', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    // Session 1: edit profile and switch active perspective to Event Host.
    final s1 = await _createService(tester);
    try {
      s1.updateUserProfile(
        name: 'Rohit Kumar',
        department: 'Information Technology',
        year: 'Final Year',
      );
      s1.switchActiveRole(UserRole.eventHost);
      // Deterministically flush the debounced snapshot to the mocked store.
      await s1.flushLocalSave();
    } finally {
      s1.dispose();
    }

    // "Restart" the app: a brand new service reading the same device storage.
    final s2 = await _createService(tester);
    try {
      expect(s2.currentUser.name, 'Rohit Kumar');
      expect(s2.currentUser.department, 'Information Technology');
      expect(s2.currentUser.year, 'Final Year');
      expect(s2.activeRole, UserRole.eventHost);
      expect(s2.posts, isNotEmpty);
    } finally {
      s2.dispose();
    }
  });

  testWidgets('no stored state falls back to defaults', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = await _createService(tester);
    try {
      expect(service.currentUser.name, isNotEmpty);
      expect(service.activeRole, UserRole.student);
      expect(service.posts, isNotEmpty);
    } finally {
      service.dispose();
    }
  });
}
