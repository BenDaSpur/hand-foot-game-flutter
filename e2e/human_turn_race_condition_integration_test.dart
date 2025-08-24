import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/screens/game_screen.dart';

void main() {
  group('Human Turn Race Condition Integration Tests', () {
    testWidgets(
      'should prevent auto-draw and auto-discard during human turns',
      (WidgetTester tester) async {
        // Create a test game with predictable setup
        final humanPlayer = Player(
          id: '1',
          name: 'You',
          type: PlayerType.human,
        );
        final botPlayer1 = Player(id: '2', name: 'Bot1', type: PlayerType.bot);
        final botPlayer2 = Player(id: '3', name: 'Bot2', type: PlayerType.bot);

        final gameController = GameController(
          players: [humanPlayer, botPlayer1, botPlayer2],
          seed: 12345, // Fixed seed for reproducible testing
        );
        gameController.initializeGame();

        // Ensure human starts
        while (gameController.gameState.currentPlayer.type !=
            PlayerType.human) {
          gameController.gameState.nextPlayer();
        }

        // Build the GameScreen widget
        await tester.pumpWidget(
          MaterialApp(home: GameScreen(gameController: gameController)),
        );

        await tester.pumpAndSettle();

        // Verify initial state - human turn with draw buttons
        expect(gameController.gameState.currentPlayer.type, PlayerType.human);
        expect(gameController.gameState.turnPhase, TurnPhase.draw);
        expect(gameController.gameState.hasDrawnFromDeck, false);

        // Should see draw buttons
        expect(find.text('Draw from Deck'), findsOneWidget);

        final initialHandSize = humanPlayer.currentHand.length;
        final initialDeckSize = gameController.gameState.deck.size;

        // Wait a moment to see if any auto-actions occur
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));

        // Verify NO auto-actions occurred
        expect(
          gameController.gameState.currentPlayer.type,
          PlayerType.human,
          reason: 'Should still be human turn',
        );
        expect(
          gameController.gameState.turnPhase,
          TurnPhase.draw,
          reason: 'Should still be in draw phase',
        );
        expect(
          gameController.gameState.hasDrawnFromDeck,
          false,
          reason: 'Should not have auto-drawn',
        );
        expect(
          humanPlayer.currentHand.length,
          initialHandSize,
          reason: 'Hand size should be unchanged',
        );
        expect(
          gameController.gameState.deck.size,
          initialDeckSize,
          reason: 'Deck size should be unchanged',
        );

        // Now manually click draw button
        await tester.tap(find.text('Draw from Deck'));
        await tester.pumpAndSettle();

        // Verify proper draw occurred
        expect(
          gameController.gameState.currentPlayer.type,
          PlayerType.human,
          reason: 'Should still be human turn after draw',
        );
        expect(
          gameController.gameState.turnPhase,
          TurnPhase.meld,
          reason: 'Should advance to meld phase after draw',
        );
        expect(
          gameController.gameState.hasDrawnFromDeck,
          true,
          reason: 'Should have drawn from deck',
        );
        expect(
          humanPlayer.currentHand.length,
          initialHandSize + 2,
          reason: 'Hand size should increase by 2',
        );

        // Should no longer see draw buttons, but should see meld/discard UI
        expect(find.text('Draw from Deck'), findsNothing);
        expect(find.text('Play Cards'), findsOneWidget);

        // Verify no auto-discard occurs
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          gameController.gameState.currentPlayer.type,
          PlayerType.human,
          reason: 'Should still be human turn - no auto-discard',
        );
        expect(
          gameController.gameState.turnPhase,
          TurnPhase.meld,
          reason: 'Should still be in meld phase',
        );

        // The human should need to manually select and discard
        // This test verifies that auto-discard prevention is working
      },
    );

    testWidgets('should handle multiple human turns without race conditions', (
      WidgetTester tester,
    ) async {
      final humanPlayer = Player(id: '1', name: 'You', type: PlayerType.human);
      final botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

      final gameController = GameController(
        players: [humanPlayer, botPlayer],
        seed: 54321,
      );
      gameController.initializeGame();

      await tester.pumpWidget(
        MaterialApp(home: GameScreen(gameController: gameController)),
      );

      await tester.pumpAndSettle();

      // Play through multiple turns to test consistency
      for (int turn = 0; turn < 3; turn++) {
        // Ensure we're on human turn
        while (gameController.gameState.currentPlayer.type !=
            PlayerType.human) {
          // Skip bot turn programmatically for test speed
          if (gameController.gameState.turnPhase == TurnPhase.draw) {
            gameController.drawFromDeck();
          }
          if (gameController.gameState.currentPlayer.currentHand.isNotEmpty) {
            final card =
                gameController.gameState.currentPlayer.currentHand.first;
            gameController.discardCard(card);
          }
          await tester.pump();
        }

        // Human turn verification
        expect(
          gameController.gameState.currentPlayer.type,
          PlayerType.human,
          reason: 'Turn $turn: Should be human turn',
        );
        expect(
          gameController.gameState.turnPhase,
          TurnPhase.draw,
          reason: 'Turn $turn: Should start in draw phase',
        );

        // Verify draw button is present and no auto-actions
        expect(
          find.text('Draw from Deck'),
          findsOneWidget,
          reason: 'Turn $turn: Should show draw button',
        );

        await tester.pump(const Duration(milliseconds: 200));

        // Still should be human turn with no changes
        expect(
          gameController.gameState.currentPlayer.type,
          PlayerType.human,
          reason: 'Turn $turn: Should still be human after wait',
        );
        expect(
          gameController.gameState.turnPhase,
          TurnPhase.draw,
          reason: 'Turn $turn: Should still be draw phase after wait',
        );

        // Manual draw
        await tester.tap(find.text('Draw from Deck'));
        await tester.pumpAndSettle();

        expect(
          gameController.gameState.turnPhase,
          TurnPhase.meld,
          reason: 'Turn $turn: Should advance to meld after manual draw',
        );

        // Complete turn by discarding
        if (humanPlayer.currentHand.isNotEmpty) {
          final card = humanPlayer.currentHand.first;
          gameController.discardCard(card);
        }

        await tester.pump();
      }
    });

    testWidgets(
      'should maintain UI state consistency during rapid interactions',
      (WidgetTester tester) async {
        final humanPlayer = Player(
          id: '1',
          name: 'You',
          type: PlayerType.human,
        );
        final botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

        final gameController = GameController(
          players: [humanPlayer, botPlayer],
        );
        gameController.initializeGame();

        // Start with human turn
        while (gameController.gameState.currentPlayer.type !=
            PlayerType.human) {
          gameController.gameState.nextPlayer();
        }

        await tester.pumpWidget(
          MaterialApp(home: GameScreen(gameController: gameController)),
        );

        await tester.pumpAndSettle();

        // Perform rapid UI interactions to test for race conditions
        for (int i = 0; i < 10; i++) {
          // Rapid pumps to simulate UI refresh cycles
          await tester.pump(const Duration(milliseconds: 1));

          // State should remain consistent
          expect(
            gameController.gameState.currentPlayer.type,
            PlayerType.human,
            reason: 'Iteration $i: Should remain human turn',
          );

          // UI should remain stable
          expect(
            find.text('Draw from Deck'),
            findsOneWidget,
            reason: 'Iteration $i: Draw button should remain visible',
          );
        }

        // Final verification - still human turn, no auto-actions
        expect(gameController.gameState.currentPlayer.type, PlayerType.human);
        expect(gameController.gameState.turnPhase, TurnPhase.draw);
        expect(gameController.gameState.hasDrawnFromDeck, false);
      },
    );

    testWidgets(
      'should prevent phantom taps and gestures from triggering actions',
      (WidgetTester tester) async {
        final humanPlayer = Player(
          id: '1',
          name: 'You',
          type: PlayerType.human,
        );
        final botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

        final gameController = GameController(
          players: [humanPlayer, botPlayer],
        );
        gameController.initializeGame();

        // Start with human turn
        while (gameController.gameState.currentPlayer.type !=
            PlayerType.human) {
          gameController.gameState.nextPlayer();
        }

        await tester.pumpWidget(
          MaterialApp(home: GameScreen(gameController: gameController)),
        );

        await tester.pumpAndSettle();

        // Draw cards to get to meld phase
        await tester.tap(find.text('Draw from Deck'));
        await tester.pumpAndSettle();

        expect(gameController.gameState.turnPhase, TurnPhase.meld);

        final initialTurnPlayer = gameController.gameState.currentPlayer.id;

        // Simulate phantom gestures/taps that shouldn't trigger actions
        // Test tapping in empty areas
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();

        await tester.tapAt(const Offset(100, 100));
        await tester.pump();

        // Player and phase should be unchanged
        expect(
          gameController.gameState.currentPlayer.id,
          initialTurnPlayer,
          reason: 'Phantom taps should not change current player',
        );
        expect(
          gameController.gameState.turnPhase,
          TurnPhase.meld,
          reason: 'Phantom taps should not change turn phase',
        );

        // Test rapid gesture sequences
        for (int i = 0; i < 5; i++) {
          await tester.fling(find.byType(GameScreen), const Offset(50, 0), 100);
          await tester.pump(const Duration(milliseconds: 10));
        }

        // State should still be stable
        expect(gameController.gameState.currentPlayer.id, initialTurnPlayer);
        expect(gameController.gameState.turnPhase, TurnPhase.meld);
      },
    );

    testWidgets('should handle widget rebuilds without triggering actions', (
      WidgetTester tester,
    ) async {
      final humanPlayer = Player(id: '1', name: 'You', type: PlayerType.human);
      final botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

      final gameController = GameController(players: [humanPlayer, botPlayer]);
      gameController.initializeGame();

      while (gameController.gameState.currentPlayer.type != PlayerType.human) {
        gameController.gameState.nextPlayer();
      }

      await tester.pumpWidget(
        MaterialApp(home: GameScreen(gameController: gameController)),
      );

      await tester.pumpAndSettle();

      final initialState = {
        'player': gameController.gameState.currentPlayer.id,
        'phase': gameController.gameState.turnPhase,
        'hasDrawn': gameController.gameState.hasDrawnFromDeck,
        'handSize': humanPlayer.currentHand.length,
      };

      // Force multiple widget rebuilds
      for (int i = 0; i < 10; i++) {
        // Trigger rebuild by changing something irrelevant
        await tester.binding.reassembleApplication();
        await tester.pumpAndSettle();

        // Game state should remain unchanged
        expect(
          gameController.gameState.currentPlayer.id,
          initialState['player'],
          reason: 'Rebuild $i: Player should not change',
        );
        expect(
          gameController.gameState.turnPhase,
          initialState['phase'],
          reason: 'Rebuild $i: Phase should not change',
        );
        expect(
          gameController.gameState.hasDrawnFromDeck,
          initialState['hasDrawn'],
          reason: 'Rebuild $i: Draw state should not change',
        );
        expect(
          humanPlayer.currentHand.length,
          initialState['handSize'],
          reason: 'Rebuild $i: Hand size should not change',
        );
      }

      // UI elements should still be present and functional
      expect(find.text('Draw from Deck'), findsOneWidget);

      // Manual interaction should still work
      await tester.tap(find.text('Draw from Deck'));
      await tester.pumpAndSettle();

      expect(
        gameController.gameState.turnPhase,
        TurnPhase.meld,
        reason: 'Manual draw should work after rebuilds',
      );
    });
  });
}
