import 'package:flutter_test/flutter_test.dart';
import 'package:intentguard/app.dart';

void main() {
  testWidgets('app title placeholder', (tester) async {
    await tester.pumpWidget(const IntentGuardApp());
    expect(find.text('IntentGuard'), findsOneWidget);
  });
}
