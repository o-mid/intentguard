import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intentguard/bootstrap.dart';
import 'package:intentguard/core/storage/token_storage.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> snap(String name) async {
    await binding.takeScreenshot(name);
  }

  Future<void> settle(WidgetTester tester, {int pumps = 12}) async {
    for (var i = 0; i < pumps; i++) {
      await tester.pump(const Duration(milliseconds: 350));
    }
  }

  testWidgets(
    'intentguard demo walkthrough',
    (tester) async {
      await GetIt.instance.reset();
      await bootstrapApp(
        storage: MemoryTokenStorage(),
        apiBase: const String.fromEnvironment(
          'API_BASE',
          defaultValue: 'http://127.0.0.1:8080',
        ),
      );
      await settle(tester, pumps: 24);
      await snap('01-login');

      await tester.tap(find.text('Sign in'));
      await settle(tester, pumps: 28);
      await snap('02-home');

      await tester.tap(find.text('Balances'));
      await settle(tester, pumps: 18);
      await snap('03-balances');

      final back = find.byTooltip('Back');
      if (back.evaluate().isNotEmpty) {
        await tester.tap(back);
        await settle(tester, pumps: 12);
      }

      await tester.tap(find.text('New intent'));
      await settle(tester, pumps: 16);
      await snap('04-composer');

      // Prefer short fixture chip for mock planner.
      final chip = find.text('swap 10 USDC');
      if (chip.evaluate().isNotEmpty) {
        await tester.ensureVisible(chip.first);
        await tester.tap(chip.first);
        await settle(tester, pumps: 8);
      }
      await snap('05-composer-ready');

      await tester.tap(find.text('Create plan'));
      // Wait for navigation to plan review.
      var onReview = false;
      for (var i = 0; i < 40 && !onReview; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.text('Plan review').evaluate().isNotEmpty) {
          onReview = true;
        }
      }
      expect(onReview, isTrue, reason: 'did not reach plan review');
      await settle(tester, pumps: 10);
      await snap('06-plan-review');

      // Approve each step in order.
      for (var step = 0; step < 4; step++) {
        final approve = find.text('Approve');
        if (approve.evaluate().isEmpty) {
          break;
        }
        await tester.ensureVisible(approve.first);
        await tester.tap(approve.first);
        await settle(tester, pumps: 20);
        await snap('07-approve-step-${step + 1}');
        if (find.textContaining('completed').evaluate().isNotEmpty ||
            find.textContaining('Completed').evaluate().isNotEmpty) {
          break;
        }
      }
      await settle(tester, pumps: 12);
      await snap('08-plan-completed');

      // History
      if (back.evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Back').first);
        await settle(tester, pumps: 12);
      }
      if (find.text('History').evaluate().isNotEmpty) {
        await tester.tap(find.text('History').first);
        await settle(tester, pumps: 16);
        await snap('09-history');
      }

      // Reject path: compose policy reject
      if (find.byTooltip('Back').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Back').first);
        await settle(tester, pumps: 10);
      }
      if (find.text('New intent').evaluate().isNotEmpty) {
        await tester.tap(find.text('New intent'));
        await settle(tester, pumps: 12);
        final rejectChip = find.text('swap 150 USDC');
        if (rejectChip.evaluate().isNotEmpty) {
          await tester.ensureVisible(rejectChip.first);
          await tester.tap(rejectChip.first);
          await settle(tester, pumps: 6);
        }
        await tester.tap(find.text('Create plan'));
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 400));
          if (find.textContaining('policy').evaluate().isNotEmpty ||
              find.textContaining('Rejected').evaluate().isNotEmpty ||
              find.text('Plan review').evaluate().isNotEmpty) {
            break;
          }
        }
        await settle(tester, pumps: 10);
        await snap('10-policy-reject');
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
