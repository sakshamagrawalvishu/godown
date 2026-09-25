import 'package:flutter_test/flutter_test.dart';
import 'package:godown_app/main.dart';

void main() {
  testWidgets('App boots to splash/login flow', (WidgetTester tester) async {
    await tester.pumpWidget(const GodownApp());
    await tester.pump();
    // Splash shows while the stored token is validated.
    expect(find.text('Godown Management'), findsWidgets);
  });
}
