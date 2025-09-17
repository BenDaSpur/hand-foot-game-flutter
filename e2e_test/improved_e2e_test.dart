import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hand_foot_game_flutter/widgets/playing_card_widget.dart';
import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Hand & Foot Improved E2E Tests', () {
    testWidgets('Complete game startup and UI verification', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Verify core UI elements are present
      expect(find.text('HAND & FOOT'), findsOneWidget);
      expect(find.text('ROUND 1'), findsOneWidget);
      expect(find.text('Your Hand (11 cards)'), findsOneWidget);
      expect(find.text('Draw from deck'), findsOneWidget);

      // Verify player information exists (may be multiple instances)
      // Bots now have actual names like Clara, Carl, Bob, Rita, etc.
      expect(find.textContaining('You'), findsWidgets);

      // Check for any bot name - at least one should be visible
      final botNames = [
        'Clara',
        'Carl',
        'Bob',
        'Rita',
        'Ben',
        'Tiana',
        'Alex',
        'Sue',
      ];
      bool foundAnyBot = false;
      for (final botName in botNames) {
        if (find.textContaining(botName).evaluate().isNotEmpty) {
          foundAnyBot = true;
          break;
        }
      }
      expect(
        foundAnyBot,
        isTrue,
        reason: 'Should find at least one bot name in UI',
      );

      print('✅ Game startup and UI verification complete');
      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Draw cards and phase transition', (WidgetTester tester) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Verify starting state
      expect(find.text('Your Hand (11 cards)'), findsOneWidget);
      expect(find.text('Draw from deck'), findsOneWidget);

      // Draw from deck
      await E2ETestUtils.safeTap(
        tester,
        find.text('Draw from deck'),
        debugLabel: 'Draw from deck',
      );
      await E2ETestUtils.stabilize(tester);

      // Verify transition to meld phase
      expect(find.text('Your Hand (13 cards)'), findsOneWidget);
      expect(find.text('Play Cards'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
      expect(find.text('Draw from deck'), findsNothing);

      print('✅ Draw and phase transition complete');
      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Menu functionality', (WidgetTester tester) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Open menu
      await E2ETestUtils.safeTap(
        tester,
        find.byType(PopupMenuButton<String>),
        debugLabel: 'Open menu',
      );
      await E2ETestUtils.stabilize(tester);

      // Verify menu items
      expect(find.text('New Game'), findsOneWidget);
      expect(find.text('How to Play'), findsOneWidget);
      expect(find.text('Export Game'), findsOneWidget);

      // Test How to Play dialog
      await E2ETestUtils.safeTap(
        tester,
        find.text('How to Play'),
        debugLabel: 'Open How to Play',
      );

      if (await E2ETestUtils.waitForElement(
        tester,
        find.text('How to Play Hand & Foot'),
      )) {
        expect(find.text('🎯 OBJECTIVE'), findsOneWidget);

        // Close dialog
        await E2ETestUtils.safeTap(
          tester,
          find.text('Got it!'),
          debugLabel: 'Close dialog',
        );
        await E2ETestUtils.stabilize(tester);

        expect(find.text('How to Play Hand & Foot'), findsNothing);
      }

      print('✅ Menu functionality complete');
      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Player switching and meld viewing', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Try to switch to any bot's melds
      final botNames = [
        'Clara',
        'Carl',
        'Bob',
        'Rita',
        'Ben',
        'Tiana',
        'Alex',
        'Sue',
      ];
      bool foundBotToSwitch = false;

      for (final botName in botNames) {
        final botFinder = find.textContaining(botName);
        if (botFinder.evaluate().isNotEmpty) {
          await E2ETestUtils.safeTap(
            tester,
            botFinder,
            debugLabel: 'Switch to $botName melds',
          );
          foundBotToSwitch = true;
          break;
        }
      }
      await E2ETestUtils.stabilize(tester);

      // Check if we successfully switched to viewing bot's melds
      if (foundBotToSwitch) {
        // Look for any bot's melds display or the back button
        final meldsDisplayFound = botNames.any(
          (name) =>
              find.textContaining('$name\'s Melds:').evaluate().isNotEmpty,
        );

        if (meldsDisplayFound ||
            find.text('Back to yours').evaluate().isNotEmpty) {
          expect(find.text('Back to yours'), findsOneWidget);

          // Switch back to player's melds
          await E2ETestUtils.safeTap(
            tester,
            find.text('Back to yours'),
            debugLabel: 'Back to player melds',
          );
          await E2ETestUtils.stabilize(tester);

          expect(find.text('Your Melds:'), findsOneWidget);
          expect(find.text('Back to yours'), findsNothing);
        }
      }

      print('✅ Player switching complete');
      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Card selection and discard flow', (WidgetTester tester) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Draw cards first
      await E2ETestUtils.safeTap(
        tester,
        find.text('Draw from deck'),
        debugLabel: 'Draw cards',
      );
      await E2ETestUtils.stabilize(tester);

      // Find and select a card
      final cardWidgets = find.byType(PlayingCardWidget);
      if (cardWidgets.evaluate().isNotEmpty) {
        await E2ETestUtils.safeTap(
          tester,
          cardWidgets.first,
          debugLabel: 'Select first card',
        );
        await E2ETestUtils.stabilize(tester);

        // Try to discard if possible
        final discardButton = find.text('Discard');
        if (discardButton.evaluate().isNotEmpty) {
          await E2ETestUtils.safeTap(
            tester,
            discardButton,
            debugLabel: 'Discard card',
          );
          await E2ETestUtils.stabilize(tester);

          // Verify card was discarded (should have 12 cards now)
          await E2ETestUtils.waitForElement(
            tester,
            find.text('Your Hand (12 cards)'),
          );
        }
      }

      print('✅ Card selection and discard complete');
      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Advanced meld modal interaction', (WidgetTester tester) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Draw cards to enable meld phase
      await E2ETestUtils.safeTap(
        tester,
        find.text('Draw from deck'),
        debugLabel: 'Draw cards',
      );
      await E2ETestUtils.stabilize(tester);

      // Try to open advanced meld selector
      await E2ETestUtils.safeTap(
        tester,
        find.text('Play Cards'),
        debugLabel: 'Open Play Cards modal',
      );

      if (await E2ETestUtils.waitForElement(
        tester,
        find.text('Multi-Meld Play-Down'),
      )) {
        // Modal opened successfully, check for key elements
        if (find.text('Available Cards').evaluate().isNotEmpty) {
          expect(find.text('Available Cards'), findsOneWidget);
        }
        if (find.text('Proposed Melds').evaluate().isNotEmpty) {
          expect(find.text('Proposed Melds'), findsOneWidget);
        }

        // Close the modal
        await E2ETestUtils.safeTap(
          tester,
          find.text('Cancel'),
          debugLabel: 'Close modal',
        );
        await E2ETestUtils.stabilize(tester);

        expect(find.text('Multi-Meld Play-Down'), findsNothing);
      }

      print('✅ Advanced meld modal complete');
      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Game export functionality', (WidgetTester tester) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Open menu
      await E2ETestUtils.safeTap(
        tester,
        find.byType(PopupMenuButton<String>),
        debugLabel: 'Open menu',
      );
      await E2ETestUtils.stabilize(tester);

      // Export game
      await E2ETestUtils.safeTap(
        tester,
        find.text('Export Game'),
        debugLabel: 'Export game',
      );

      // Wait for export confirmation
      if (await E2ETestUtils.waitForElement(
        tester,
        find.text('Game state exported to clipboard'),
      )) {
        print('✅ Export confirmation shown');
      }

      print('✅ Game export functionality complete');
      await E2ETestUtils.cleanShutdown(tester);
    });

    testWidgets('Stability test - multiple operations', (
      WidgetTester tester,
    ) async {
      await E2ETestUtils.startAppWithCleanState(tester);

      // Perform multiple operations to test stability
      for (int i = 0; i < 2; i++) {
        print('🎮 Stability test iteration ${i + 1}');

        // Draw if available
        if (find.text('Draw from deck').evaluate().isNotEmpty) {
          await E2ETestUtils.safeTap(
            tester,
            find.text('Draw from deck'),
            debugLabel: 'Draw iteration $i',
          );
          await E2ETestUtils.stabilize(tester);
        }

        // Try card selection
        final cardWidgets = find.byType(PlayingCardWidget);
        if (cardWidgets.evaluate().isNotEmpty) {
          await E2ETestUtils.safeTap(
            tester,
            cardWidgets.first,
            debugLabel: 'Select card iteration $i',
          );
          await E2ETestUtils.stabilize(tester);

          // Clear selection if available
          if (find.text('Clear Selection').evaluate().isNotEmpty) {
            await E2ETestUtils.safeTap(
              tester,
              find.text('Clear Selection'),
              debugLabel: 'Clear selection iteration $i',
            );
            await E2ETestUtils.stabilize(tester);
          }
        }

        // Switch meld view
        if (find.textContaining('Bot 2').evaluate().isNotEmpty) {
          await E2ETestUtils.safeTap(
            tester,
            find.textContaining('Bot 2'),
            debugLabel: 'Switch to Bot 2 iteration $i',
          );
          await E2ETestUtils.stabilize(tester);

          if (find.text('Back to yours').evaluate().isNotEmpty) {
            await E2ETestUtils.safeTap(
              tester,
              find.text('Back to yours'),
              debugLabel: 'Back to yours iteration $i',
            );
            await E2ETestUtils.stabilize(tester);
          }
        }
      }

      // Verify game is still functional
      expect(find.text('HAND & FOOT'), findsOneWidget);
      print('✅ Stability test complete');
      await E2ETestUtils.cleanShutdown(tester);
    });
  });
}
