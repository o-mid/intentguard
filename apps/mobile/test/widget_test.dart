import 'package:flutter_test/flutter_test.dart';
import 'package:intentguard/app.dart';
import 'package:intentguard/core/di/injection.dart';
import 'package:intentguard/core/storage/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await getIt.reset();
    await configureDependencies(storage: MemoryTokenStorage());
  });

  testWidgets('shows login when unauthenticated', (tester) async {
    await tester.pumpWidget(const IntentGuardApp());
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
  });
}
