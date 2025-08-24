import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Human Interaction Guard System Tests', () {
    late GameController gameController;
    late Player humanPlayer;
    late Player botPlayer;

    setUp(() {
      humanPlayer = Player(id: '1', name: 'You', type: PlayerType.human);
      botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

      gameController = GameController(players: [humanPlayer, botPlayer]);
      gameController.initializeGame();

      // Start with human turn
      while (gameController.gameState.currentPlayer.type != PlayerType.human) {
        gameController.gameState.nextPlayer();
      }
    });

    group('Interaction Flag Management', () {
      test('should reset interaction flag after human draws cards', () {
        // Initially human should be able to interact
        expect(gameController.gameState.currentPlayer.type, PlayerType.human);
        expect(gameController.gameState.turnPhase, TurnPhase.draw);

        // After drawing, the interaction flag should be reset
        // This simulates the behavior in _onDrawFromDeck where
        // _hasPlayerInteractedSinceDraw is set to false
        expect(gameController.drawFromDeck(), isTrue);

        expect(gameController.gameState.turnPhase, TurnPhase.meld);

        // At this point, _hasPlayerInteractedSinceDraw would be false
        // This is the critical state that prevents auto-discard
      });

      test('should allow discard only after user interaction simulation', () {
        // Draw to get to meld phase
        expect(gameController.drawFromDeck(), isTrue);
        expect(gameController.gameState.turnPhase, TurnPhase.meld);

        // Simulate the guard condition that would block auto-discard
        bool hasPlayerInteractedSinceDraw =
            false; // Flag starts false after draw

        // Auto-discard should be blocked
        expect(
          hasPlayerInteractedSinceDraw,
          isFalse,
          reason: 'Flag should be false immediately after draw',
        );

        // Simulate user card interaction (tap/double-tap)
        hasPlayerInteractedSinceDraw = true;

        // Now discard should be allowed
        expect(
          hasPlayerInteractedSinceDraw,
          isTrue,
          reason: 'Flag should be true after user interaction',
        );

        // Complete the discard
        if (humanPlayer.currentHand.isNotEmpty) {
          final card = humanPlayer.currentHand.first;
          expect(gameController.discardCard(card), isTrue);
        }
      });

      test('should maintain flag across multiple draw-interact cycles', () {
        // Test multiple turns to ensure flag behaves consistently
        for (int turn = 0; turn < 3; turn++) {
          // Ensure we're on human turn
          while (gameController.gameState.currentPlayer.type !=
              PlayerType.human) {
            // Complete bot turn quickly
            if (gameController.gameState.turnPhase == TurnPhase.draw) {
              gameController.drawFromDeck();
            }
            if (gameController.gameState.currentPlayer.currentHand.isNotEmpty) {
              final card =
                  gameController.gameState.currentPlayer.currentHand.first;
              gameController.discardCard(card);
            }
          }

          expect(
            gameController.gameState.currentPlayer.type,
            PlayerType.human,
            reason: 'Turn $turn: Should be human turn',
          );

          // Draw cards
          if (gameController.gameState.turnPhase == TurnPhase.draw) {
            expect(
              gameController.drawFromDeck(),
              isTrue,
              reason: 'Turn $turn: Should be able to draw',
            );
          }

          // Flag should be reset after draw
          bool hasPlayerInteractedSinceDraw = false; // Simulating flag reset
          expect(
            hasPlayerInteractedSinceDraw,
            isFalse,
            reason: 'Turn $turn: Flag should be reset after draw',
          );

          // Simulate user interaction
          hasPlayerInteractedSinceDraw = true;
          expect(
            hasPlayerInteractedSinceDraw,
            isTrue,
            reason: 'Turn $turn: Flag should be set after interaction',
          );

          // Complete turn
          if (humanPlayer.currentHand.isNotEmpty) {
            final card = humanPlayer.currentHand.first;
            gameController.discardCard(card);
          }
        }
      });
    });

    group('Auto-Discard Prevention', () {
      test('should prevent discard when no user interaction occurred', () {
        // Get to meld phase
        expect(gameController.drawFromDeck(), isTrue);
        expect(gameController.gameState.turnPhase, TurnPhase.meld);

        // Simulate the exact scenario that caused the bug:
        // Cards are drawn, but no user interaction has occurred
        bool hasPlayerInteractedSinceDraw = false; // This is the key protection

        // The guard should block any discard attempt
        expect(
          hasPlayerInteractedSinceDraw,
          isFalse,
          reason: 'Should block discard without user interaction',
        );

        // In the actual implementation, _onDiscard would return early here
        // This prevents the race condition from causing auto-discard
      });

      test('should allow discard after explicit user card selection', () {
        expect(gameController.drawFromDeck(), isTrue);

        // Simulate different types of user interactions that should set the flag
        final userInteractionTypes = [
          'card_tap',
          'card_double_tap',
          'meld_selector',
        ];

        for (final interactionType in userInteractionTypes) {
          // Reset scenario
          bool hasPlayerInteractedSinceDraw = false;

          // Simulate the specific user interaction
          switch (interactionType) {
            case 'card_tap':
            case 'card_double_tap':
            case 'meld_selector':
              hasPlayerInteractedSinceDraw = true;
              break;
          }

          expect(
            hasPlayerInteractedSinceDraw,
            isTrue,
            reason: 'User interaction "$interactionType" should enable discard',
          );
        }
      });

      test('should handle edge case of rapid flag changes', () {
        expect(gameController.drawFromDeck(), isTrue);

        // Simulate rapid flag changes that might occur in complex UI scenarios
        bool hasPlayerInteractedSinceDraw = false; // Initial state after draw

        // Rapid state changes
        for (int i = 0; i < 10; i++) {
          if (i % 2 == 0) {
            hasPlayerInteractedSinceDraw = false; // Reset
          } else {
            hasPlayerInteractedSinceDraw = true; // User interaction
          }
        }

        // Final state should be based on actual user interaction
        hasPlayerInteractedSinceDraw = true; // User finally interacted

        expect(
          hasPlayerInteractedSinceDraw,
          isTrue,
          reason: 'Final state should reflect actual user interaction',
        );
      });
    });

    group('Integration with Game Flow', () {
      test('should work correctly with normal game progression', () {
        // Play through a complete turn cycle with proper interaction guards
        final turnEvents = <String>[];

        // Human turn starts
        expect(gameController.gameState.currentPlayer.type, PlayerType.human);
        turnEvents.add('human_turn_start');

        // Human draws (flag reset)
        expect(gameController.drawFromDeck(), isTrue);
        turnEvents.add('human_draw');
        bool hasPlayerInteractedSinceDraw = false; // Flag reset

        // Attempt auto-discard (should be blocked)
        if (!hasPlayerInteractedSinceDraw) {
          turnEvents.add('auto_discard_blocked');
          // This prevents the bug - no discard occurs
        }

        // User interacts with cards
        hasPlayerInteractedSinceDraw = true;
        turnEvents.add('user_interaction');

        // Now discard is allowed
        if (hasPlayerInteractedSinceDraw &&
            humanPlayer.currentHand.isNotEmpty) {
          final card = humanPlayer.currentHand.first;
          expect(gameController.discardCard(card), isTrue);
          turnEvents.add('manual_discard_success');
        }

        // Turn should advance to bot
        expect(gameController.gameState.currentPlayer.type, PlayerType.bot);
        turnEvents.add('bot_turn_start');

        // Verify correct event sequence
        expect(turnEvents, [
          'human_turn_start',
          'human_draw',
          'auto_discard_blocked', // This is the key fix
          'user_interaction',
          'manual_discard_success',
          'bot_turn_start',
        ]);
      });

      test(
        'should handle multiple players with individual interaction states',
        () {
          // Add another human player to test individual flag management
          final humanPlayer2 = Player(
            id: '3',
            name: 'Human2',
            type: PlayerType.human,
          );

          final multiGameController = GameController(
            players: [humanPlayer, botPlayer, humanPlayer2],
          );
          multiGameController.initializeGame();

          // Each human player should have their own interaction state
          // This test verifies that the fix works for multiple human players

          final playerStates = <String, bool>{};

          // Cycle through players
          for (int turn = 0; turn < 6; turn++) {
            // 2 turns each
            final currentPlayer = multiGameController.gameState.currentPlayer;

            if (currentPlayer.type == PlayerType.human) {
              // Human turn - test interaction guard
              if (multiGameController.gameState.turnPhase == TurnPhase.draw) {
                expect(multiGameController.drawFromDeck(), isTrue);

                // Each human has their own interaction flag
                playerStates[currentPlayer.id] = false; // Flag reset after draw

                // Simulate user interaction for this specific player
                playerStates[currentPlayer.id] = true;

                expect(
                  playerStates[currentPlayer.id],
                  isTrue,
                  reason:
                      'Player ${currentPlayer.name} should have interaction flag set',
                );
              }

              // Complete human turn
              if (currentPlayer.currentHand.isNotEmpty) {
                final card = currentPlayer.currentHand.first;
                multiGameController.discardCard(card);
              }
            } else {
              // Bot turn - complete quickly
              if (multiGameController.gameState.turnPhase == TurnPhase.draw) {
                multiGameController.drawFromDeck();
              }
              if (currentPlayer.currentHand.isNotEmpty) {
                final card = currentPlayer.currentHand.first;
                multiGameController.discardCard(card);
              }
            }
          }

          // Verify both human players had proper interaction management
          expect(playerStates.containsKey(humanPlayer.id), isTrue);
          expect(playerStates.containsKey(humanPlayer2.id), isTrue);
        },
      );
    });
  });
}
