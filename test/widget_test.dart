import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sketchmind/main.dart';

void main() {
  testWidgets('App opens authentication flow when no user exists', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const SketchMindApp());
    await tester.pumpAndSettle();

    expect(find.text('SketchMind Hesap'), findsOneWidget);
  });
}
