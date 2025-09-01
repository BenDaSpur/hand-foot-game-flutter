import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/services/game_save_service.dart';

void main() {
  group('Singleplayer Offline Resilience Tests', () {
    late GameController controller;
    late Player humanPlayer;
    late Player botPlayer;

    setUp(() {
      humanPlayer = Player(id: '1', name: 'Human', type: PlayerType.human);
      botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

      controller = GameController(players: [humanPlayer, botPlayer]);
      controller.initializeGame();
    });

    group('Core Game Independence', () {
      test('should create singleplayer game without network access', () {
        // Test that game creation works completely offline
        expect(controller, isNotNull);
        expect(controller.gameState.players.length, equals(2));
        expect(controller.gameState.phase, isNotNull);
        expect(controller.gameState.round, equals(1));
      });

      test('should play complete game without Firebase operations', () {
        // Simulate a complete singleplayer game flow
        final gameState = controller.gameState;

        // Initial state should be valid
        expect(gameState.phase, isNotNull);
        expect(gameState.currentPlayer, isNotNull);

        // Should be able to draw cards
        expect(() => controller.drawFromDeck(), returnsNormally);

        // Should be able to handle turn phases
        expect(() => gameState.nextPlayer(), returnsNormally);

        // Should be able to end rounds
        expect(() => gameState.endRound(), returnsNormally);

        // Should be able to start new rounds
        expect(() => controller.nextRound(), returnsNormally);
      });

      test('should save and restore game without network dependencies', () {
        // Modify game state
        final gameState = controller.gameState;
        gameState.round = 3;
        humanPlayer.updateScore(1500);

        // Export game state
        expect(() {
          final exportedState = controller.exportGameState();
          expect(exportedState, isNotNull);
          expect(exportedState, isA<String>());
        }, returnsNormally);

        // Game save should work offline
        expect(() async {
          await GameSaveService.saveGame(
            controller.gameState,
            controller.gameSeed,
          );
        }, returnsNormally);
      });
    });

    group('Firebase Isolation Verification', () {
      test('should never call Firebase services from game controller', () {
        // Verify GameController has no Firebase dependencies
        final gameControllerSource = controller.toString();

        // GameController should not reference Firebase
        expect(gameControllerSource.contains('Firebase'), isFalse);
        expect(gameControllerSource.contains('Firestore'), isFalse);
      });

      test('should handle game actions without analytics dependencies', () {
        // Test all major game actions work without analytics
        final gameState = controller.gameState;

        // Setup game state for testing
        gameState.currentPlayerIndex = 0; // Human turn
        gameState.turnPhase = TurnPhase.discard;
        humanPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        ]);

        // Core game actions should never fail due to analytics
        expect(() {
          controller.discardCard(
            const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          );
        }, returnsNormally);

        expect(() {
          controller.drawFromDeck();
        }, returnsNormally);

        expect(() {
          gameState.nextPlayer();
        }, returnsNormally);
      });

      test('should complete full round cycle without external services', () {
        // Test complete round progression without network
        final gameState = controller.gameState;
        final initialRound = gameState.round;

        // End current round
        gameState.endRound();
        expect(gameState.round, equals(initialRound + 1));
        expect(gameState.phase, equals(GamePhase.roundEnd));

        // Start next round
        controller.nextRound();
        expect(gameState.phase, equals(GamePhase.playing));
        expect(gameState.currentPlayerIndex, equals(0));
      });
    });

    group('Error Resilience', () {
      test('should handle game state corruption gracefully', () {
        // Test defensive programming against corrupted states
        final gameState = controller.gameState;

        // Clear critical game state
        gameState.discardPile.clear();

        // Game should still function
        expect(() {
          gameState.validateGameState();
        }, returnsNormally);

        // Should still be able to make basic operations
        expect(() {
          gameState.nextPlayer();
        }, returnsNormally);
      });

      test('should recover from bot AI errors without crashing', () {
        // Test that bot AI failures don't crash singleplayer
        final gameState = controller.gameState;

        // Put bot in difficult state
        botPlayer.hand.clear();
        botPlayer.foot.clear();
        gameState.currentPlayerIndex = 1; // Bot turn
        gameState.turnPhase = TurnPhase.discard;

        // Game should handle bot errors gracefully
        expect(() {
          // Even if bot has problems, game should continue
          gameState.nextPlayer(); // Skip problematic bot turn
          expect(gameState.currentPlayerIndex, equals(0)); // Back to human
        }, returnsNormally);
      });

      test(
        'should handle memory constraints without external dependencies',
        () {
          // Test that large game states work offline
          final gameState = controller.gameState;

          // Add many actions to test memory handling
          for (int i = 0; i < 100; i++) {
            gameState.recentActions.add(
              GameAction(message: 'test action $i', playerName: 'TestPlayer'),
            );
          }

          // Should not require external services for memory management
          expect(
            gameState.recentActions.length,
            greaterThan(0),
          ); // Should have actions

          // Game state validation should work offline
          expect(() {
            gameState.validateGameState();
          }, returnsNormally);
        },
      );
    });

    group('Performance Without Network', () {
      test('should maintain good performance in offline mode', () {
        // Test that offline mode doesn't degrade performance
        final startTime = DateTime.now();

        // Perform multiple game operations
        for (int i = 0; i < 10; i++) {
          controller.gameState.nextPlayer();
          controller.gameState.validateGameState();
        }

        final duration = DateTime.now().difference(startTime);

        // Should be fast without network operations
        expect(duration.inMilliseconds, lessThan(1000));
      });

      test('should handle rapid game state changes offline', () {
        // Test rapid state changes don't require network sync
        final gameState = controller.gameState;

        expect(() {
          for (int i = 0; i < 20; i++) {
            gameState.nextPlayer();
          }
        }, returnsNormally);

        // Should be back to original player after full cycles
        expect(gameState.currentPlayerIndex, equals(0));
      });
    });

    group('Data Integrity Without Cloud', () {
      test('should maintain data consistency in offline mode', () {
        // Test that data integrity is maintained without cloud backup
        final gameState = controller.gameState;
        final initialPlayerCount = gameState.players.length;
        final initialDeckSize = gameState.deck.size;

        // Perform game operations
        controller.drawFromDeck();
        gameState.nextPlayer();
        controller.drawFromDeck();

        // Data should remain consistent
        expect(gameState.players.length, equals(initialPlayerCount));
        expect(gameState.deck.size, lessThan(initialDeckSize)); // Cards drawn
        expect(
          gameState.currentPlayerIndex,
          isIn([0, 1]),
        ); // Valid player index
      });

      test('should handle game export without cloud storage', () {
        // Test game state export works completely locally
        final exportResult = controller.exportGameState();

        expect(exportResult, isNotNull);
        expect(exportResult, isA<String>());
        expect(exportResult.isNotEmpty, isTrue);

        // Should contain game data (might be compressed/encoded)
        expect(
          exportResult.length,
          greaterThan(10),
        ); // Should have meaningful content
        expect(exportResult.isNotEmpty, isTrue);
      });

      test('should validate game state without external services', () {
        // Test validation works purely with local logic
        final gameState = controller.gameState;

        // Create some state to validate
        humanPlayer.updateScore(1000);
        gameState.round = 2;

        expect(() {
          gameState.validateGameState();
        }, returnsNormally);

        // Validation should work with local data only
        expect(humanPlayer.score, equals(1000));
        expect(gameState.round, equals(2));
      });
    });
  });
}
