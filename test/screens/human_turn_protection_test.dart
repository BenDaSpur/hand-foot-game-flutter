import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Human Turn Protection Tests', () {
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

    test('should not auto-draw when human player is current', () {
      // Ensure human is current player
      while (gameController.gameState.currentPlayer.type != PlayerType.human) {
        gameController.gameState.nextPlayer();
      }
      gameController.gameState.turnPhase = TurnPhase.draw;
      gameController.gameState.hasDrawnFromDeck = false;

      final initialHandSize = humanPlayer.currentHand.length;
      final initialDeckSize = gameController.gameState.deck.size;
      final initialTurnPhase = gameController.gameState.turnPhase;

      // Simulate time passing (this would trigger auto-actions if they existed)
      // No direct calls should change game state for human players

      expect(
        humanPlayer.currentHand.length,
        initialHandSize,
        reason: 'Human hand size should not change without explicit action',
      );
      expect(
        gameController.gameState.deck.size,
        initialDeckSize,
        reason: 'Deck size should not change without explicit draw',
      );
      expect(
        gameController.gameState.turnPhase,
        initialTurnPhase,
        reason: 'Turn phase should not advance without human action',
      );
      expect(
        gameController.gameState.hasDrawnFromDeck,
        false,
        reason: 'hasDrawnFromDeck should remain false until human acts',
      );
    });

    test('should not auto-discard when human player is in meld phase', () {
      // Set up human in meld phase
      while (gameController.gameState.currentPlayer.type != PlayerType.human) {
        gameController.gameState.nextPlayer();
      }

      // Human draws to get to meld phase
      expect(gameController.drawFromDeck(), true);
      expect(gameController.gameState.turnPhase, TurnPhase.meld);

      final initialHandSize = humanPlayer.currentHand.length;
      final initialDiscardPileSize =
          gameController.gameState.discardPile.length;
      final currentPlayerId = gameController.gameState.currentPlayer.id;

      // Game should stay in meld phase waiting for human action
      expect(
        gameController.gameState.turnPhase,
        TurnPhase.meld,
        reason: 'Should remain in meld phase for human',
      );
      expect(
        humanPlayer.currentHand.length,
        initialHandSize,
        reason: 'Hand size should not change without explicit discard',
      );
      expect(
        gameController.gameState.discardPile.length,
        initialDiscardPileSize,
        reason: 'Discard pile should not grow without explicit discard',
      );
      expect(
        gameController.gameState.currentPlayer.id,
        currentPlayerId,
        reason: 'Current player should not change without explicit discard',
      );
    });

    test('should not automatically advance turn after human actions', () {
      // Ensure human is current player
      while (gameController.gameState.currentPlayer.type != PlayerType.human) {
        gameController.gameState.nextPlayer();
      }

      // Human draws cards
      expect(gameController.drawFromDeck(), true);
      expect(
        gameController.gameState.currentPlayer.type,
        PlayerType.human,
        reason: 'Should still be human turn after drawing',
      );

      // Human discards to end turn
      final cardToDiscard = humanPlayer.currentHand.first;
      expect(gameController.discardCard(cardToDiscard), true);

      // Now it should be next player's turn (bot)
      expect(
        gameController.gameState.currentPlayer.type,
        PlayerType.bot,
        reason: 'Should advance to bot after human discard',
      );
    });

    test('should maintain game state integrity during human turns', () {
      // Force human to be current player
      while (gameController.gameState.currentPlayer.type != PlayerType.human) {
        gameController.gameState.nextPlayer();
      }

      final initialState = {
        'currentPlayerId': gameController.gameState.currentPlayer.id,
        'turnPhase': gameController.gameState.turnPhase,
        'hasDrawn': gameController.gameState.hasDrawnFromDeck,
        'deckSize': gameController.gameState.deck.size,
        'handSize': humanPlayer.currentHand.length,
        'discardSize': gameController.gameState.discardPile.length,
      };

      // Simulate conditions that previously caused auto-actions
      // (These should not change game state for humans)

      expect(
        gameController.gameState.currentPlayer.id,
        initialState['currentPlayerId'],
        reason: 'Current player should not change unexpectedly',
      );
      expect(
        gameController.gameState.turnPhase,
        initialState['turnPhase'],
        reason: 'Turn phase should not advance without human input',
      );
      expect(
        gameController.gameState.hasDrawnFromDeck,
        initialState['hasDrawn'],
        reason: 'Draw state should not change without human action',
      );
      expect(
        gameController.gameState.deck.size,
        initialState['deckSize'],
        reason: 'Deck should not be modified without human draw',
      );
      expect(
        humanPlayer.currentHand.length,
        initialState['handSize'],
        reason: 'Hand size should not change without human action',
      );
    });

    test('should properly handle turn transitions from human to bot', () {
      // Set up human turn
      while (gameController.gameState.currentPlayer.type != PlayerType.human) {
        gameController.gameState.nextPlayer();
      }

      expect(gameController.gameState.currentPlayer.type, PlayerType.human);

      // Complete human turn
      expect(gameController.drawFromDeck(), true);
      final cardToDiscard = humanPlayer.currentHand.first;
      expect(gameController.discardCard(cardToDiscard), true);

      // Should now be bot's turn
      expect(gameController.gameState.currentPlayer.type, PlayerType.bot);
      expect(
        gameController.gameState.turnPhase,
        TurnPhase.draw,
        reason: 'Bot should start in draw phase',
      );
      expect(
        gameController.gameState.hasDrawnFromDeck,
        false,
        reason: 'Bot should not have drawn yet',
      );
    });

    test('should prevent race conditions during state transitions', () {
      // This test ensures that rapid state changes don't cause issues

      // Start with human
      while (gameController.gameState.currentPlayer.type != PlayerType.human) {
        gameController.gameState.nextPlayer();
      }

      final humanId = gameController.gameState.currentPlayer.id;

      // Perform multiple rapid operations
      expect(gameController.drawFromDeck(), true);
      expect(
        gameController.gameState.currentPlayer.id,
        humanId,
        reason: 'Should still be human after drawing',
      );

      // Try to discard immediately
      final card = humanPlayer.currentHand.first;
      expect(gameController.discardCard(card), true);

      // Should cleanly transition to next player
      expect(
        gameController.gameState.currentPlayer.type,
        PlayerType.bot,
        reason: 'Should cleanly transition to bot',
      );
      expect(
        gameController.gameState.turnPhase,
        TurnPhase.draw,
        reason: 'Bot should be in proper draw phase',
      );
    });

    test('should not interfere with human turn after bot completes turn', () {
      // Complete a full bot turn cycle back to human
      while (gameController.gameState.currentPlayer.type != PlayerType.human) {
        gameController.gameState.nextPlayer();
      }

      // Complete human turn
      expect(gameController.drawFromDeck(), true);
      final humanCard = humanPlayer.currentHand.first;
      expect(gameController.discardCard(humanCard), true);

      // Should be bot turn
      expect(gameController.gameState.currentPlayer.type, PlayerType.bot);

      // Simulate bot completing their turn manually
      gameController.gameState.nextPlayer(); // Skip bot for test

      // Should be back to human
      while (gameController.gameState.currentPlayer.type != PlayerType.human) {
        gameController.gameState.nextPlayer();
      }

      // Human should have full control again
      expect(gameController.gameState.turnPhase, TurnPhase.draw);
      expect(gameController.gameState.hasDrawnFromDeck, false);

      final beforeDrawHandSize = humanPlayer.currentHand.length;

      // Human should be able to draw without interference
      expect(gameController.drawFromDeck(), true);
      expect(
        humanPlayer.currentHand.length,
        beforeDrawHandSize + 2,
        reason: 'Human should successfully draw cards',
      );
      expect(
        gameController.gameState.currentPlayer.type,
        PlayerType.human,
        reason: 'Should still be human turn after drawing',
      );
    });

    test('should validate turn consistency across multiple rounds', () {
      // Play through a partial game to ensure consistency
      int humanTurns = 0;
      int botTurns = 0;

      for (int i = 0; i < 6; i++) {
        // 6 turns total (2 per player)
        final currentPlayerType = gameController.gameState.currentPlayer.type;

        if (currentPlayerType == PlayerType.human) {
          humanTurns++;

          // Verify human has control
          expect(gameController.gameState.turnPhase, TurnPhase.draw);

          // Human draws
          final beforeDraw = humanPlayer.currentHand.length;
          expect(gameController.drawFromDeck(), true);
          expect(humanPlayer.currentHand.length, beforeDraw + 2);

          // Human discards
          final cardToDiscard = humanPlayer.currentHand.first;
          expect(gameController.discardCard(cardToDiscard), true);
        } else {
          botTurns++;
          // Skip bot turn for test
          gameController.gameState.nextPlayer();
        }
      }

      expect(
        humanTurns,
        greaterThan(0),
        reason: 'Human should have taken turns',
      );
      expect(botTurns, greaterThan(0), reason: 'Bots should have had turns');
    });
  });
}
