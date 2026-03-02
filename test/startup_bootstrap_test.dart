import 'package:flutter_test/flutter_test.dart';

import 'package:sketchmind/main.dart';

void main() {
  testWidgets('shows startup error screen when cloud bootstrap fails',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const SketchMindApp(
        bootstrapStatus: AppBootstrapStatus(
          envLoaded: true,
          firebaseReady: false,
          authReady: false,
          startupError: 'Firebase başlatılamadı',
        ),
      ),
    );

    expect(find.text('Başlatma Hatası'), findsOneWidget);
    expect(find.textContaining('Firebase başlatılamadı'), findsOneWidget);
  });
}
