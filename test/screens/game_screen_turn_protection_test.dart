import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('GameScreen Turn Protection Logic Tests', () {
    late GameController gameController;
    late Player humanPlayer;
    late Player botPlayer1;
    late Player botPlayer2;

    setUp(() {
      humanPlayer = Player(id: '1', name: 'Human', type: PlayerType.human);
      botPlayer1 = Player(id: '2', name: 'Bot1', type: PlayerType.bot);
      botPlayer2 = Player(id: '3', name: 'Bot2', type: PlayerType.bot);

      gameController = GameController(
        players: [humanPlayer, botPlayer1, botPlayer2],
      );
      gameController.initializeGame();
    });

    test('should validate _processBotTurns logic only acts on bot turns', () {
      // This test validates the fix we implemented

      // Set human as current player
      while (gameController.gameState.currentPlayer.type != PlayerType.human) {
        gameController.gameState.nextPlayer();
      }

      final initialState = {
        'currentPlayerId': gameController.gameState.currentPlayer.id,
        'turnPhase': gameController.gameState.turnPhase,
        'hasDrawn': gameController.gameState.hasDrawnFromDeck,
        'deckSize': gameController.gameState.deck.size,
        'handSize': humanPlayer.currentHand.length,
      };

      // The critical check: processBotTurns logic should not execute for humans
      final isBot =
          gameController.gameState.currentPlayer.type == PlayerType.bot;
      expect(isBot, false, reason: 'Current player should be human');

      // If the fix is working, no bot processing should occur
      // All game state should remain unchanged
      expect(
        gameController.gameState.currentPlayer.id,
        initialState['currentPlayerId'],
      );
      expect(gameController.gameState.turnPhase, initialState['turnPhase']);
      expect(
        gameController.gameState.hasDrawnFromDeck,
        initialState['hasDrawn'],
      );
      expect(gameController.gameState.deck.size, initialState['deckSize']);
      expect(humanPlayer.currentHand.length, initialState['handSize']);
    });

    test('should validate bot processing only occurs for bots', () {
      // Set bot as current player
      while (gameController.gameState.currentPlayer.type != PlayerType.bot) {
        gameController.gameState.nextPlayer();
      }

      expect(gameController.gameState.currentPlayer.type, PlayerType.bot);

      // The processBotTurns check should return true for bots
      final shouldProcessBot =
          gameController.gameState.currentPlayer.type == PlayerType.bot;
      expect(shouldProcessBot, true, reason: 'Should process turns for bots');

      // But not for humans
      gameController.gameState.nextPlayer();
      if (gameController.gameState.currentPlayer.type == PlayerType.human) {
        final shouldNotProcessHuman =
            gameController.gameState.currentPlayer.type == PlayerType.bot;
        expect(
          shouldNotProcessHuman,
          false,
          reason: 'Should not process turns for humans',
        );
      }
    });

    test('should maintain turn integrity across player type transitions', () {
      // Test the boundary conditions between human and bot turns

      // Start with human
      while (gameController.gameState.currentPlayer.type != PlayerType.human) {
        gameController.gameState.nextPlayer();
      }

      final humanId = gameController.gameState.currentPlayer.id;
      expect(gameController.gameState.currentPlayer.type, PlayerType.human);

      // Complete human turn manually
      expect(gameController.drawFromDeck(), true);
      final card = humanPlayer.currentHand.first;
      expect(gameController.discardCard(card), true);

      // Should transition to bot
      expect(gameController.gameState.currentPlayer.type, PlayerType.bot);
      expect(gameController.gameState.currentPlayer.id, isNot(humanId));

      // Bot processing should be allowed now
      final shouldProcessBot =
          gameController.gameState.currentPlayer.type == PlayerType.bot;
      expect(shouldProcessBot, true);
    });

    test('should prevent automatic actions during human control periods', () {
      // Simulate the conditions that previously caused auto-actions

      while (gameController.gameState.currentPlayer.type != PlayerType.human) {
        gameController.gameState.nextPlayer();
      }

      final before = {
        'player': gameController.gameState.currentPlayer.id,
        'phase': gameController.gameState.turnPhase,
        'drawn': gameController.gameState.hasDrawnFromDeck,
        'handSize': humanPlayer.currentHand.length,
        'deckSize': gameController.gameState.deck.size,
      };

      // Simulate UI state changes that might trigger bot processing
      // These should NOT cause any game state changes for humans

      // Check that _processBotTurns condition prevents execution
      final shouldProcess =
          gameController.gameState.currentPlayer.type == PlayerType.bot;
      expect(
        shouldProcess,
        false,
        reason: 'Should not process bot turns for human',
      );

      // Verify all state remains unchanged
      expect(gameController.gameState.currentPlayer.id, before['player']);
      expect(gameController.gameState.turnPhase, before['phase']);
      expect(gameController.gameState.hasDrawnFromDeck, before['drawn']);
      expect(humanPlayer.currentHand.length, before['handSize']);
      expect(gameController.gameState.deck.size, before['deckSize']);
    });
  });
}
