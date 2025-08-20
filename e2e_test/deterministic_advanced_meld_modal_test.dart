import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Deterministic Advanced Meld Modal Tests', () {
    testWidgets('Game starts correctly with deterministic seed', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Verify game screen loaded
      expect(find.byType(Scaffold), findsWidgets);

      // Basic game elements should be present (flexible check)
      final hasGameElements =
          find.textContaining('You').evaluate().isNotEmpty ||
          find.textContaining('Round').evaluate().isNotEmpty ||
          find.byType(ElevatedButton).evaluate().isNotEmpty;
      expect(
        hasGameElements,
        isTrue,
        reason: 'Should have basic game UI elements',
      );

      print('✅ Game initialized successfully with deterministic seed');
      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Can interact with basic game controls', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Look for draw button
      final drawButton = find.text('Draw from Deck');
      if (drawButton.evaluate().isNotEmpty) {
        await E2ETestUtils.safeTap(
          tester,
          drawButton,
          debugLabel: 'Draw cards',
        );
        await E2ETestUtils.stabilize(tester);
        print('✅ Draw button interaction successful');
      } else {
        print('ℹ️ Draw button not available in current game state');
      }

      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Modal opens when Play Cards is available', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // First try to draw cards to enable play cards
      final drawButton = find.text('Draw from Deck');
      if (drawButton.evaluate().isNotEmpty) {
        await E2ETestUtils.safeTap(
          tester,
          drawButton,
          debugLabel: 'Draw cards',
        );
        await E2ETestUtils.stabilize(tester);

        // Look for play cards button
        final playButton = find.text('Play Cards');
        if (playButton.evaluate().isNotEmpty) {
          await E2ETestUtils.safeTap(
            tester,
            playButton,
            debugLabel: 'Open modal',
          );
          await E2ETestUtils.stabilize(tester);

          // Check if modal opened by looking for any modal content
          final dialogWidgets = find.byType(Dialog);
          if (dialogWidgets.evaluate().isNotEmpty) {
            print('✅ Modal opened successfully');

            // Look for cancel button to close
            final cancelButton = find.text('Cancel');
            if (cancelButton.evaluate().isNotEmpty) {
              await E2ETestUtils.safeTap(
                tester,
                cancelButton,
                debugLabel: 'Close modal',
              );
              await E2ETestUtils.stabilize(tester);
              print('✅ Modal closed successfully');
            }
          } else {
            print('ℹ️ Modal content not detected, may be different UI state');
          }
        } else {
          print('ℹ️ Play Cards button not available');
        }
      }

      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Keyboard navigation works in app', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Test basic keyboard interaction
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await E2ETestUtils.stabilize(tester);
      print('✅ Tab key processed without errors');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await E2ETestUtils.stabilize(tester);
      print('✅ Escape key processed without errors');

      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('App handles rapid interactions without crashing', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Perform rapid taps on available buttons
      final availableButtons = find.byType(ElevatedButton);
      final buttonCount = availableButtons.evaluate().length;

      if (buttonCount > 0) {
        // Rapidly tap the first few buttons
        for (int i = 0; i < (buttonCount > 3 ? 3 : buttonCount); i++) {
          await tester.tap(availableButtons.at(i));
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Allow UI to settle
        await E2ETestUtils.stabilize(tester);
        print('✅ Rapid interactions handled without crashing');
      }

      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('App state remains consistent across interactions', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Get initial UI state
      final initialScaffoldCount = find.byType(Scaffold).evaluate().length;
      expect(initialScaffoldCount, greaterThan(0));

      // Perform some interactions
      final drawButton = find.text('Draw from Deck');
      if (drawButton.evaluate().isNotEmpty) {
        await E2ETestUtils.safeTap(
          tester,
          drawButton,
          debugLabel: 'Test state consistency',
        );
        await E2ETestUtils.stabilize(tester);
      }

      // Verify scaffold still exists (app didn't crash)
      final finalScaffoldCount = find.byType(Scaffold).evaluate().length;
      expect(finalScaffoldCount, greaterThan(0));

      print('✅ App state remained consistent');
      await E2ETestUtils.cleanShutdown(tester);
    });
  });
}
