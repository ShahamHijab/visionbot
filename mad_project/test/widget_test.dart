import 'package:flutter_test/flutter_test.dart';

import 'package:mad_project/main.dart';

void main() {
  testWidgets('App starts with splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VisionBotApp());

    // Verify that splash screen is shown
    expect(find.text('Vision Bot'), findsOneWidget);
    expect(find.text('A Smart Surveillance System'), findsOneWidget);
  });
}