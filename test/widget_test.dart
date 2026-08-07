import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_hub/main.dart';
import 'package:student_hub/services/mock_data_service.dart';

void main() {
  testWidgets('StudentHub app renders correctly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MockDataService(),
        child: const StudentHubApp(),
      ),
    );

    // Initial frame pump
    await tester.pump();
  });
}
