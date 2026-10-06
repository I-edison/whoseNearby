import 'package:flutter_test/flutter_test.dart';
import 'package:whosenearby/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const WhoseNearbyApp());
    // Splash shows brand name
    expect(find.textContaining('WhoseNearby'), findsOneWidget);
  });
}
