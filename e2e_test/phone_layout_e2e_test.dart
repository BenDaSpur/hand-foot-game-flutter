import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'test_utils.dart';

/// Phone-viewport coverage for compact action-dock / tap-target layout.
///
/// Existing suites default to [E2ETestViewport.desktop] for Chrome hit-testing.
/// This file exercises the phone breakpoint (≤430px width) separately.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Phone layout E2E', () {
    testWidgets('Game starts on phone viewport layout', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(
        tester,
        viewport: E2ETestViewport.phone,
      );
      addTearDown(() => E2ETestUtils.cleanShutdown(tester));

      expect(find.text('H&F'), findsOneWidget);
      expect(find.text('ROUND 1'), findsOneWidget);
      expect(find.text('Your Hand (11)'), findsOneWidget);
      expect(find.text('Draw from deck'), findsOneWidget);

      print('✅ Phone layout startup verified');
    });

    testWidgets('Draw and Play Cards work on phone action dock', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(
        tester,
        viewport: E2ETestViewport.phone,
      );
      addTearDown(() => E2ETestUtils.cleanShutdown(tester));

      await E2ETestUtils.safeTap(
        tester,
        find.text('Draw from deck'),
        debugLabel: 'Phone draw',
      );
      await E2ETestUtils.stabilize(tester);

      expect(find.text('Your Hand (13)'), findsOneWidget);
      expect(find.text('Play Cards'), findsOneWidget);

      await E2ETestUtils.safeTap(
        tester,
        find.text('Play Cards'),
        debugLabel: 'Phone Play Cards',
      );

      expect(
        await E2ETestUtils.waitForElement(
          tester,
          find.text('Multi-Meld Play-Down'),
        ),
        isTrue,
        reason: 'Phone Play Cards should open Multi-Meld Play-Down',
      );

      await E2ETestUtils.safeTap(
        tester,
        find.text('Cancel'),
        debugLabel: 'Phone close modal',
      );
      await E2ETestUtils.stabilize(tester);

      expect(find.text('Multi-Meld Play-Down'), findsNothing);
      print('✅ Phone action dock draw/play verified');
    });
  });
}
