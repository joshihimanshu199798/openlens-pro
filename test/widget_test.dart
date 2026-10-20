import 'package:flutter_test/flutter_test.dart';
import 'package:openlens_pro/main.dart';

void main() {
  testWidgets('OpenLens Pro launches', (WidgetTester tester) async {
    await tester.pumpWidget(const OpenLensApp());
    await tester.pump();
    expect(find.text('OPENLENS'), findsOneWidget);
    expect(find.text('PRO CAMERA'), findsNothing);
    expect(find.byTooltip('Filters and looks'), findsOneWidget);
  });
}
