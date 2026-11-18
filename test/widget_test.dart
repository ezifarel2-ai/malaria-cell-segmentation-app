import 'package:flutter_test/flutter_test.dart';
import 'package:belajarandroid1/main.dart';
import 'package:belajarandroid1/widgets/mask_split_inspector.dart';

void main() {
  testWidgets('MalariaVision smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MalariaVisionApp());
    await tester.pumpAndSettle();

    // Verify app title and main clinical elements are present
    expect(find.text('MalariaVision'), findsOneWidget);
    expect(find.byType(MaskSplitInspector), findsOneWidget);
    expect(find.text('METODE SEGMENTASI'), findsOneWidget);
  });
}
