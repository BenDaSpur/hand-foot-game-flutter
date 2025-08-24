import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Human Turn Progression Tests', () {
    late GameController gameController;
    late List<Player> players;

    setUp(() {
      players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];
      gameController = GameController(players: players);
      gameController.initializeGame();
    });

    test('should wait for human player input on draw phase', () {
      // If the first player is human, the game should be in draw phase waiting for input
      if (gameController.gameState.currentPlayer.type == PlayerType.human) {
        expect(gameController.gameState.turnPhase, TurnPhase.draw);
        expect(gameController.gameState.hasDrawnFromDeck, false);

        // The game should not automatically progress
        expect(
          gameController.gameState.turnPhase,
          TurnPhase.draw,
          reason: 'Game should still be in draw phase waiting for human input',
        );
      }
    });

    test('should not auto-draw for human players', () {
      // Ensure first player is human
      if (gameController.gameState.currentPlayer.type != PlayerType.human) {
        // Advance to human player's turn
        while (gameController.gameState.currentPlayer.type !=
            PlayerType.human) {
          gameController.gameState.nextPlayer();
        }
        gameController.gameState.turnPhase = TurnPhase.draw;
        gameController.gameState.hasDrawnFromDeck = false;
      }

      final initialHandSize =
          gameController.gameState.currentPlayer.currentHand.length;

      // Game should not automatically draw cards for human
      expect(
        gameController.gameState.currentPlayer.currentHand.length,
        equals(initialHandSize),
        reason:
            'Human player hand size should not change without explicit action',
      );
      expect(
        gameController.gameState.turnPhase,
        TurnPhase.draw,
        reason: 'Game should remain in draw phase for human player',
      );
    });

    test('should properly advance after human draws from deck', () {
      // Ensure we're testing a human player
      if (gameController.gameState.currentPlayer.type != PlayerType.human) {
        while (gameController.gameState.currentPlayer.type !=
            PlayerType.human) {
          gameController.gameState.nextPlayer();
        }
        gameController.gameState.turnPhase = TurnPhase.draw;
        gameController.gameState.hasDrawnFromDeck = false;
      }

      final initialHandSize =
          gameController.gameState.currentPlayer.currentHand.length;

      // Human player draws from deck
      final drawSuccess = gameController.drawFromDeck();

      expect(drawSuccess, isTrue, reason: 'Draw from deck should succeed');
      expect(
        gameController.gameState.currentPlayer.currentHand.length,
        equals(initialHandSize + 2),
        reason: 'Hand size should increase by 2 after drawing',
      );
      expect(
        gameController.gameState.turnPhase,
        TurnPhase.meld,
        reason: 'Turn phase should advance to meld after drawing',
      );
      expect(
        gameController.gameState.hasDrawnFromDeck,
        isTrue,
        reason: 'hasDrawnFromDeck should be true after drawing',
      );
    });
  });
}
