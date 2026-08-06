import 'package:flutter_test/flutter_test.dart';
import 'package:student_hub/models/role_request_model.dart';
import 'package:student_hub/models/user_model.dart';
import 'package:student_hub/services/mock_data_service.dart';

void main() {
  testWidgets('limited-time Event Host role auto-expires', (WidgetTester tester) async {
    final service = MockDataService();
    try {
      while (service.isLoading) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Reset current user to a plain Student (default user is permanently a host)
      service.currentUser = UserModel(
        id: 'usr_test',
        name: 'Test Student',
        email: 'test@studenthub.edu',
        studentOrEmployeeId: 'SAITS/CS/2024/001',
        department: 'Computer Science & Engineering',
        year: 'Third Year',
        mobileNumber: '+91 90000 00000',
        avatarUrl: '',
        roles: [UserRole.student],
        savedPostIds: const [],
        registeredEventIds: const [],
      );

      // Submit a limited-time Event Host request
      service.submitRoleRequest(
        requestedRole: UserRole.eventHost,
        reason: 'Hosting hackathon for one week',
        phoneNumber: '+91 90000 00000',
        isLimitedAccess: true,
        durationDays: 1,
      );

      final request = service.roleRequests.first;
      expect(request.isLimitedAccess, isTrue);
      expect(request.durationDays, 1);
      expect(request.expiresAt, isNotNull);
      expect(service.currentUser.roles, isNot(contains(UserRole.eventHost)));

      // Admin approves
      service.updateRoleRequestStatus(request.id, RoleRequestStatus.approved, 'Approved');
      expect(service.currentUser.roles, contains(UserRole.eventHost));
      expect(service.currentUser.roleExpirations.containsKey(UserRole.eventHost), isTrue);

      // Backdate the expiry, then run the expiry check
      service.currentUser = service.currentUser.copyWith(
        roleExpirations: {UserRole.eventHost: DateTime.now().subtract(const Duration(minutes: 1))},
      );
      service.checkForExpiredRoles();

      expect(service.currentUser.roles, isNot(contains(UserRole.eventHost)));
      expect(service.currentUser.roleExpirations, isEmpty);
      expect(service.activeRole, UserRole.student);
      expect(service.posts, isNotEmpty);
      expect(
        service.notifications.any((n) => n.title.contains('Expired')),
        isTrue,
      );
    } finally {
      service.dispose();
    }
  });
}