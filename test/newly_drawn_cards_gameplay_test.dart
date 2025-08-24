import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Newly Drawn Cards During Gameplay', () {
    test(
      'should properly mark cards as newly drawn when drawing from deck during gameplay',
      () {
        // Create a fresh game (no saved game restore scenario)
        final players = [
          Player(id: '1', name: 'Human', type: PlayerType.human),
          Player(id: '2', name: 'Bot 1', type: PlayerType.bot),
        ];

        final controller = GameController(players: players);
        controller.initializeGame();

        // Verify initial state - no newly drawn cards should be highlighted after dealing
        final humanPlayer = players[0];
        expect(humanPlayer.currentHand.length, 11); // Initial hand size

        // No cards should be highlighted as newly drawn after initial deal
        for (int i = 0; i < humanPlayer.currentHand.length; i++) {
          expect(
            humanPlayer.isCardIndexNewlyDrawn(i),
            false,
            reason:
                'Initial dealt cards should not be highlighted as newly drawn',
          );
        }

        // Simulate drawing cards during gameplay (like the user's scenario)
        final success = controller.drawFromDeck();
        expect(success, true);

        // After drawing, the newly drawn cards should be highlighted
        final expectedHandSize = 11 + GameState.requiredDrawCount;
        expect(humanPlayer.currentHand.length, expectedHandSize);

        // With auto-sorting, newly drawn cards can be anywhere in the hand
        // Count the total highlighted cards instead of checking specific indices
        int highlightedCount = 0;
        for (int i = 0; i < expectedHandSize; i++) {
          if (humanPlayer.isCardIndexNewlyDrawn(i)) {
            highlightedCount++;
          }
        }

        expect(
          highlightedCount,
          GameState.requiredDrawCount,
          reason:
              'Should have exactly ${GameState.requiredDrawCount} cards highlighted as newly drawn',
        );
      },
    );

    test(
      'should maintain newly drawn highlighting after game controller creation but before clearing',
      () {
        // Create players and add some cards
        final humanPlayer = Player(
          id: '1',
          name: 'Human',
          type: PlayerType.human,
        );
        final botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

        // Add some initial cards
        humanPlayer.hand.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        ]);

        // Simulate properly drawn cards (using the correct method)
        final drawnCard1 = const PlayingCard(
          suit: Suit.clubs,
          rank: CardRank.joker,
        );
        final drawnCard2 = const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.eight,
        );
        humanPlayer.addNewlyDrawnCard(drawnCard1);
        humanPlayer.addNewlyDrawnCard(drawnCard2);

        // With auto-sorting, the cards will be reordered: Eight(7), King(11), Ace(12), Joker(14)
        // Find the highlighted cards instead of checking specific indices
        int highlightedCount = 0;
        final highlightedCards = <PlayingCard>[];
        for (int i = 0; i < humanPlayer.currentHand.length; i++) {
          if (humanPlayer.isCardIndexNewlyDrawn(i)) {
            highlightedCount++;
            highlightedCards.add(humanPlayer.currentHand[i]);
          }
        }

        expect(
          highlightedCount,
          2,
          reason: 'Should have 2 newly drawn cards highlighted',
        );
        expect(
          highlightedCards.any((c) => c.rank == CardRank.joker),
          true,
          reason: 'Joker should be highlighted',
        );
        expect(
          highlightedCards.any((c) => c.rank == CardRank.eight),
          true,
          reason: 'Eight should be highlighted',
        );

        // Creating a game controller should NOT clear these valid newly drawn cards
        // (This simulates the normal game flow, not a save/restore scenario)
        final controller = GameController(players: [humanPlayer, botPlayer]);

        // The newly drawn cards should still be marked
        highlightedCount = 0;
        for (int i = 0; i < humanPlayer.currentHand.length; i++) {
          if (humanPlayer.isCardIndexNewlyDrawn(i)) {
            highlightedCount++;
          }
        }
        expect(
          highlightedCount,
          2,
          reason:
              'Should still have 2 cards highlighted after controller creation',
        );

        // Only when we explicitly clear (like in save/restore scenarios) should they be cleared
        controller.clearAllNewlyDrawnCards();

        highlightedCount = 0;
        for (int i = 0; i < humanPlayer.currentHand.length; i++) {
          if (humanPlayer.isCardIndexNewlyDrawn(i)) {
            highlightedCount++;
          }
        }
        expect(
          highlightedCount,
          0,
          reason: 'All highlighting should be cleared after explicit clear',
        );
      },
    );
  });
}
