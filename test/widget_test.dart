import 'package:flutter_test/flutter_test.dart';
import 'package:belajarandroid1/main.dart';

void main() {
  testWidgets('MalariaVision Lab smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MalariaVisionApp());
    await tester.pumpAndSettle();

    // Verify title and main clinical elements are present
    expect(find.text('MalariaVision Lab'), findsOneWidget);
    expect(find.text('MICROSCOPE VIEWPORT'), findsOneWidget);
    expect(find.text('PIPELINE CONFIGURATOR'), findsOneWidget);
  });
}
