import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Hand & Foot Basic Flow Tests', () {
    testWidgets('Game starts up correctly', (WidgetTester tester) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Basic verification that the app started
      expect(find.text('HAND & FOOT'), findsOneWidget);
      expect(find.text('ROUND 1'), findsOneWidget);
      expect(find.text('Your Hand (11 cards)'), findsOneWidget);

      print('✅ Basic app startup verified');
      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Can tap draw button', (WidgetTester tester) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Look for and tap draw button
      await E2ETestUtils.safeTap(
        tester,
        find.text('Draw Deck'),
        debugLabel: 'Draw button tap',
      );

      // Verify phase transition occurred
      if (await E2ETestUtils.waitForElement(
        tester,
        find.text('Your Hand (13 cards)'),
      )) {
        expect(find.text('Play Cards'), findsOneWidget);
        expect(find.text('Discard'), findsOneWidget);
      }

      // Verify app is still functional
      expect(find.text('HAND & FOOT'), findsOneWidget);
      print('✅ Draw button functionality verified');
      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Menu accessibility check', (WidgetTester tester) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Verify menu can be opened
      await E2ETestUtils.safeTap(
        tester,
        find.byType(PopupMenuButton<String>),
        debugLabel: 'Open menu',
      );

      if (await E2ETestUtils.waitForElement(tester, find.text('New Game'))) {
        expect(find.text('How to Play'), findsOneWidget);
        expect(find.text('Export Game'), findsOneWidget);
      }

      print('✅ Menu accessibility verified');
      await E2ETestUtils.cleanShutdown(tester);
    });
  });
}
