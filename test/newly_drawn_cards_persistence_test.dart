import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/config/game_config.dart';

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
        final expectedNewCardCount = GameConfig.requiredDrawCount;

        // Count the highlighted cards instead of checking specific indices
        // since auto-sorting can put newly drawn cards anywhere
        int highlightedCount = 0;
        for (int i = 0; i < handSize; i++) {
          if (humanPlayer.isCardIndexNewlyDrawn(i)) {
            highlightedCount++;
          }
        }
        expect(
          highlightedCount,
          expectedNewCardCount,
          reason:
              'Should have exactly $expectedNewCardCount newly drawn cards highlighted',
        );

        // During meld phase, newly drawn cards should still be highlighted
        expect(controller.gameState.turnPhase.name, 'meld');
        highlightedCount = 0;
        for (int i = 0; i < handSize; i++) {
          if (humanPlayer.isCardIndexNewlyDrawn(i)) {
            highlightedCount++;
          }
        }
        expect(
          highlightedCount,
          expectedNewCardCount,
          reason:
              'Should still have $expectedNewCardCount cards highlighted during meld phase',
        );

        // Player discards to end turn - this should advance to next player
        // Choose a card that's NOT newly drawn to avoid removing highlighted cards
        // But if all cards are highlighted, just use the first non-highlighted or first card
        PlayingCard cardToDiscard = humanPlayer.currentHand.first;
        bool foundNonHighlighted = false;
        for (int i = 0; i < humanPlayer.currentHand.length; i++) {
          if (!humanPlayer.isCardIndexNewlyDrawn(i)) {
            cardToDiscard = humanPlayer.currentHand[i];
            foundNonHighlighted = true;
            break;
          }
        }

        // Store expected count based on whether we're discarding a highlighted card
        final expectedRemainingHighlighted = foundNonHighlighted
            ? expectedNewCardCount
            : expectedNewCardCount - 1;

        expect(controller.discardCard(cardToDiscard), true);

        // Verify turn advanced to bot player
        expect(controller.gameState.currentPlayer.id, '2');
        expect(controller.gameState.currentPlayer.type, PlayerType.bot);

        // IMPORTANT: Human player should still have their newly drawn cards highlighted
        // because clearing only happens at the START of the new current player's turn
        highlightedCount = 0;
        for (int i = 0; i < humanPlayer.currentHand.length; i++) {
          if (humanPlayer.isCardIndexNewlyDrawn(i)) {
            highlightedCount++;
          }
        }
        expect(
          highlightedCount,
          expectedRemainingHighlighted,
          reason:
              'Human should still have $expectedRemainingHighlighted cards highlighted after their turn ended',
        );

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
        int highlightedCount = 0;
        for (int i = 0; i < handSize; i++) {
          if (humanPlayer.isCardIndexNewlyDrawn(i)) {
            highlightedCount++;
          }
        }
        expect(
          highlightedCount,
          GameConfig.requiredDrawCount,
          reason:
              'Should have ${GameConfig.requiredDrawCount} cards highlighted',
        );

        // Human discards, bot's turn starts
        // Choose a card that's NOT newly drawn to avoid removing highlighted cards
        // But if all cards are highlighted, just use the first non-highlighted or first card
        PlayingCard humanCard = humanPlayer.currentHand.first;
        bool foundNonHighlighted = false;
        for (int i = 0; i < humanPlayer.currentHand.length; i++) {
          if (!humanPlayer.isCardIndexNewlyDrawn(i)) {
            humanCard = humanPlayer.currentHand[i];
            foundNonHighlighted = true;
            break;
          }
        }

        // Store expected count based on whether we're discarding a highlighted card
        final expectedRemainingHighlighted = foundNonHighlighted
            ? GameConfig.requiredDrawCount
            : GameConfig.requiredDrawCount - 1;

        expect(controller.discardCard(humanCard), true);
        expect(controller.gameState.currentPlayer.id, '2'); // Bot's turn

        // Human should still have highlighting
        final newHandSize = humanPlayer.currentHand.length; // -1 from discard
        highlightedCount = 0;
        for (int i = 0; i < newHandSize; i++) {
          if (humanPlayer.isCardIndexNewlyDrawn(i)) {
            highlightedCount++;
          }
        }
        expect(
          highlightedCount,
          expectedRemainingHighlighted,
          reason:
              'Human should still have $expectedRemainingHighlighted cards highlighted during bot\'s turn',
        );

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
      // Choose a card that's NOT newly drawn to avoid removing highlighted cards
      // But if all cards are highlighted, just use the first non-highlighted or first card
      PlayingCard humanCard = humanPlayer.currentHand.first;
      bool foundNonHighlighted = false;
      for (int i = 0; i < humanPlayer.currentHand.length; i++) {
        if (!humanPlayer.isCardIndexNewlyDrawn(i)) {
          humanCard = humanPlayer.currentHand[i];
          foundNonHighlighted = true;
          break;
        }
      }

      // Store expected count based on whether we're discarding a highlighted card
      final expectedRemainingHighlighted = foundNonHighlighted
          ? GameConfig.requiredDrawCount
          : GameConfig.requiredDrawCount - 1;

      expect(controller.discardCard(humanCard), true);

      // Bot 1's turn - human should still have highlighting
      expect(controller.gameState.currentPlayer.id, '2');
      int highlightedCount = 0;
      for (int i = 0; i < humanPlayer.currentHand.length; i++) {
        if (humanPlayer.isCardIndexNewlyDrawn(i)) {
          highlightedCount++;
        }
      }
      expect(
        highlightedCount,
        expectedRemainingHighlighted,
        reason:
            'Human should keep $expectedRemainingHighlighted cards highlighted during bot 1 turn',
      );

      // Bot 1 draws and discards
      expect(controller.drawFromDeck(), true);
      final bot1Card = botPlayer1.currentHand.first;
      expect(controller.discardCard(bot1Card), true);

      // Bot 2's turn - human should STILL have highlighting
      expect(controller.gameState.currentPlayer.id, '3');
      highlightedCount = 0;
      for (int i = 0; i < humanPlayer.currentHand.length; i++) {
        if (humanPlayer.isCardIndexNewlyDrawn(i)) {
          highlightedCount++;
        }
      }
      expect(
        highlightedCount,
        expectedRemainingHighlighted,
        reason:
            'Human should keep $expectedRemainingHighlighted cards highlighted during bot 2 turn',
      );

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
