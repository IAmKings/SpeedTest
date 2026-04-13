import 'package:flutter_test/flutter_test.dart';
import 'package:speed_test_app/app/app.dart';

void main() {
  testWidgets('Speed Test App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SpeedTestApp());
    await tester.pumpAndSettle();

    // Verify that the Speed Test title is shown
    expect(find.text('Speed Test'), findsOneWidget);

    // Verify that the Start Test button is present
    expect(find.text('Start Test'), findsOneWidget);
  });
}
