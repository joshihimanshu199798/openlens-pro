import 'package:flutter_test/flutter_test.dart';
import 'package:openlens_pro/main.dart';

void main() {
  testWidgets('OpenLens Pro launches into the camera workspace', (WidgetTester tester) async {
    await tester.pumpWidget(const OpenLensApp());
    await tester.pump();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('VIDEO'), findsWidgets);
    expect(find.text('Recent Editing'), findsNothing);
  });
}
