import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Newly Drawn Cards Persistence During Gameplay', () {
    test(
      'should maintain newly drawn card highlighting throughout player\'s entire turn',
      () {
        // Create a game with human player first
        final humanPlayer = Player(
          id: '1',
          name: 'Human',
          type: PlayerType.human,
        );
        final botPlayer1 = Player(id: '2', name: 'Bot 1', type: PlayerType.bot);
        final botPlayer2 = Player(id: '3', name: 'Bot 2', type: PlayerType.bot);

        final controller = GameController(
          players: [humanPlayer, botPlayer1, botPlayer2],
        );
        controller.initializeGame();

        // Verify human player goes first
        expect(controller.gameState.currentPlayer.id, '1');
        expect(controller.gameState.currentPlayer.type, PlayerType.human);

        // Human player draws cards
        expect(controller.drawFromDeck(), true);

        // Verify newly drawn cards are highlighted
        final handSize = humanPlayer.currentHand.length;
        final expectedNewCardCount = GameState.requiredDrawCount;
        for (int i = handSize - expectedNewCardCount; i < handSize; i++) {
          expect(
            humanPlayer.isCardIndexNewlyDrawn(i),
            true,
            reason: 'Card at index $i should be highlighted as newly drawn',
          );
        }

        // During meld phase, newly drawn cards should still be highlighted
        expect(controller.gameState.turnPhase.name, 'meld');
        for (int i = handSize - expectedNewCardCount; i < handSize; i++) {
          expect(
            humanPlayer.isCardIndexNewlyDrawn(i),
            true,
            reason:
                'Card at index $i should remain highlighted during meld phase',
          );
        }

        // Player discards to end turn - this should advance to next player
        final cardToDiscard = humanPlayer.currentHand.first;
        expect(controller.discardCard(cardToDiscard), true);

        // Verify turn advanced to bot player
        expect(controller.gameState.currentPlayer.id, '2');
        expect(controller.gameState.currentPlayer.type, PlayerType.bot);

        // IMPORTANT: Human player should still have their newly drawn cards highlighted
        // because clearing only happens at the START of the new current player's turn
        for (
          int i = handSize - expectedNewCardCount - 1;
          i < handSize - 1;
          i++
        ) {
          // -1 because we discarded
          expect(
            humanPlayer.isCardIndexNewlyDrawn(i),
            true,
            reason:
                'Human card at index $i should still be highlighted after their turn ended',
          );
        }

        // But the bot (current player) should have no newly drawn cards highlighted yet
        expect(
          botPlayer1.newlyDrawnCardIndices.isEmpty,
          true,
          reason: 'Bot should have no highlighted cards at start of turn',
        );
      },
    );

    test(
      'should clear newly drawn cards when it becomes that player\'s turn again',
      () {
        // Create a 2-player game to make turns cycle faster
        final humanPlayer = Player(
          id: '1',
          name: 'Human',
          type: PlayerType.human,
        );
        final botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

        final controller = GameController(players: [humanPlayer, botPlayer]);
        controller.initializeGame();

        // Human draws cards and gets highlighting
        expect(controller.drawFromDeck(), true);
        final handSize = humanPlayer.currentHand.length;

        // Verify highlighting exists
        for (
          int i = handSize - GameState.requiredDrawCount;
          i < handSize;
          i++
        ) {
          expect(humanPlayer.isCardIndexNewlyDrawn(i), true);
        }

        // Human discards, bot's turn starts
        final humanCard = humanPlayer.currentHand.first;
        expect(controller.discardCard(humanCard), true);
        expect(controller.gameState.currentPlayer.id, '2'); // Bot's turn

        // Human should still have highlighting
        final newHandSize = humanPlayer.currentHand.length; // -1 from discard
        for (
          int i = newHandSize - GameState.requiredDrawCount;
          i < newHandSize;
          i++
        ) {
          expect(
            humanPlayer.isCardIndexNewlyDrawn(i),
            true,
            reason: 'Human should still have highlighting during bot\'s turn',
          );
        }

        // Bot draws and discards to return turn to human
        expect(controller.drawFromDeck(), true);
        final botCard = botPlayer.currentHand.first;
        expect(controller.discardCard(botCard), true);
        expect(controller.gameState.currentPlayer.id, '1'); // Back to human

        // NOW human's newly drawn cards should be cleared (start of their new turn)
        for (int i = 0; i < humanPlayer.currentHand.length; i++) {
          expect(
            humanPlayer.isCardIndexNewlyDrawn(i),
            false,
            reason:
                'All human cards should have highlighting cleared at start of new turn',
          );
        }
      },
    );

    test('should handle highlighting correctly in 3+ player games', () {
      // Create a 3-player game
      final humanPlayer = Player(
        id: '1',
        name: 'Human',
        type: PlayerType.human,
      );
      final botPlayer1 = Player(id: '2', name: 'Bot 1', type: PlayerType.bot);
      final botPlayer2 = Player(id: '3', name: 'Bot 2', type: PlayerType.bot);

      final controller = GameController(
        players: [humanPlayer, botPlayer1, botPlayer2],
      );
      controller.initializeGame();

      // Human draws and discards
      expect(controller.drawFromDeck(), true);
      final humanHandSize = humanPlayer.currentHand.length;
      final humanCard = humanPlayer.currentHand.first;
      expect(controller.discardCard(humanCard), true);

      // Bot 1's turn - human should still have highlighting
      expect(controller.gameState.currentPlayer.id, '2');
      for (
        int i = humanHandSize - GameState.requiredDrawCount - 1;
        i < humanHandSize - 1;
        i++
      ) {
        expect(
          humanPlayer.isCardIndexNewlyDrawn(i),
          true,
          reason: 'Human should keep highlighting during bot 1 turn',
        );
      }

      // Bot 1 draws and discards
      expect(controller.drawFromDeck(), true);
      final bot1Card = botPlayer1.currentHand.first;
      expect(controller.discardCard(bot1Card), true);

      // Bot 2's turn - human should STILL have highlighting
      expect(controller.gameState.currentPlayer.id, '3');
      for (
        int i = humanHandSize - GameState.requiredDrawCount - 1;
        i < humanHandSize - 1;
        i++
      ) {
        expect(
          humanPlayer.isCardIndexNewlyDrawn(i),
          true,
          reason: 'Human should keep highlighting during bot 2 turn',
        );
      }

      // Bot 2 draws and discards to return to human
      expect(controller.drawFromDeck(), true);
      final bot2Card = botPlayer2.currentHand.first;
      expect(controller.discardCard(bot2Card), true);

      // Back to human - NOW highlighting should be cleared
      expect(controller.gameState.currentPlayer.id, '1');
      for (int i = 0; i < humanPlayer.currentHand.length; i++) {
        expect(
          humanPlayer.isCardIndexNewlyDrawn(i),
          false,
          reason:
              'Human highlighting should be cleared when their turn starts again',
        );
      }
    });
  });
}
