import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/config/game_config.dart';

void main() {
  group('Newly Drawn Cards with Sorting', () {
    test(
      'should preserve newly drawn card highlighting after sorting by rank',
      () {
        // Create a player with specific cards in hand
        final humanPlayer = Player(
          id: '1',
          name: 'Human',
          type: PlayerType.human,
        );

        // Add initial cards and sort them (simulating game initialization)
        humanPlayer.hand.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
        ]);
        humanPlayer.sortHandByRank(); // Sort initial hand

        // Draw new cards that will automatically sort the hand
        final drawnCard1 = const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.two,
        ); // Wild card
        final drawnCard2 = const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.queen,
        ); // Regular card

        // Verify initial state before drawing
        expect(humanPlayer.isCardIndexNewlyDrawn(0), false);
        expect(humanPlayer.isCardIndexNewlyDrawn(1), false);
        expect(humanPlayer.isCardIndexNewlyDrawn(2), false);

        humanPlayer.addNewlyDrawnCard(drawnCard1); // Adds and auto-sorts
        humanPlayer.addNewlyDrawnCard(drawnCard2); // Adds and auto-sorts

        // After both cards are drawn, the hand should be automatically sorted:
        // Four(2), Queen(10), King(11), Ace(12), Two(13)

        // Verify the cards are in the expected positions after sorting
        expect(humanPlayer.currentHand[0].rank, CardRank.four); // Four first
        expect(humanPlayer.currentHand[1].rank, CardRank.queen); // Queen
        expect(humanPlayer.currentHand[2].rank, CardRank.king); // King
        expect(humanPlayer.currentHand[3].rank, CardRank.ace); // Ace
        expect(
          humanPlayer.currentHand[4].rank,
          CardRank.two,
        ); // Two moved to end (wild card)

        // IMPORTANT: The newly drawn cards should still be highlighted at their new positions
        expect(
          humanPlayer.isCardIndexNewlyDrawn(4),
          true,
          reason:
              'Two should still be highlighted at its new position (index 4)',
        );
        expect(
          humanPlayer.isCardIndexNewlyDrawn(1),
          true,
          reason:
              'Queen should still be highlighted at its new position (index 1)',
        );

        // The original cards should not be highlighted
        expect(
          humanPlayer.isCardIndexNewlyDrawn(0),
          false,
          reason: 'Four should not be highlighted (was not newly drawn)',
        );
        expect(
          humanPlayer.isCardIndexNewlyDrawn(2),
          false,
          reason: 'King should not be highlighted (was not newly drawn)',
        );
        expect(
          humanPlayer.isCardIndexNewlyDrawn(3),
          false,
          reason: 'Ace should not be highlighted (was not newly drawn)',
        );
      },
    );

    test('should handle duplicate cards correctly when sorting', () {
      final humanPlayer = Player(
        id: '1',
        name: 'Human',
        type: PlayerType.human,
      );

      // Add two identical cards initially
      humanPlayer.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king), // Index 0
        const PlayingCard(
          suit: Suit.spades,
          rank: CardRank.king,
        ), // Index 1 (same rank)
      ]);

      // Draw another king (identical to existing ones)
      final drawnCard = const PlayingCard(
        suit: Suit.clubs,
        rank: CardRank.king,
      );
      humanPlayer.addNewlyDrawnCard(drawnCard); // Index 2

      // Verify initial state
      expect(humanPlayer.isCardIndexNewlyDrawn(2), true); // Newly drawn king
      expect(humanPlayer.isCardIndexNewlyDrawn(0), false); // Original king
      expect(humanPlayer.isCardIndexNewlyDrawn(1), false); // Original king

      // Sort by rank - all kings should stay together but may reorder
      humanPlayer.sortHandByRank();

      // Verify we still have exactly one highlighted card
      int highlightedCount = 0;
      for (int i = 0; i < humanPlayer.currentHand.length; i++) {
        if (humanPlayer.isCardIndexNewlyDrawn(i)) {
          highlightedCount++;
        }
      }
      expect(
        highlightedCount,
        1,
        reason: 'Exactly one king should remain highlighted',
      );

      // All cards should still be kings
      for (final card in humanPlayer.currentHand) {
        expect(card.rank, CardRank.king);
      }
    });

    test('should work correctly with game controller draw and sort sequence', () {
      // This test simulates the actual game flow that was broken
      final humanPlayer = Player(
        id: '1',
        name: 'Human',
        type: PlayerType.human,
      );
      final botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

      final controller = GameController(players: [humanPlayer, botPlayer]);
      controller.initializeGame();

      // Get initial hand size (should be 11)
      final initialHandSize = humanPlayer.currentHand.length;
      expect(initialHandSize, 11);

      // Record the initial cards so we can distinguish them from newly drawn ones
      final initialCards = List<PlayingCard>.from(humanPlayer.currentHand);

      // Draw cards (this calls addNewlyDrawnCards internally)
      expect(controller.drawFromDeck(), true);

      // Manually sort (simulating what happens in the UI)
      humanPlayer.sortHandByRank();

      // After sorting, we should still have exactly the right number of highlighted cards
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
        GameConfig.requiredDrawCount,
        reason:
            'Should have exactly ${GameConfig.requiredDrawCount} highlighted cards after sorting',
      );

      // The highlighted cards should be different from the initial cards
      // (unless we drew duplicates, but that's unlikely with a full deck)
      for (final highlightedCard in highlightedCards) {
        // Count how many times this card appears in initial vs final hand
        final initialCount = initialCards
            .where((c) => c == highlightedCard)
            .length;
        final finalCount = humanPlayer.currentHand
            .where((c) => c == highlightedCard)
            .length;

        // If this card wasn't in the initial hand, it must be newly drawn
        // If it was in the initial hand, there should now be more copies
        expect(
          finalCount > initialCount || initialCount == 0,
          true,
          reason: 'Highlighted card should be newly drawn',
        );
      }
    });

    test(
      'should handle sorting by suit while preserving newly drawn highlighting',
      () {
        final humanPlayer = Player(
          id: '1',
          name: 'Human',
          type: PlayerType.human,
        );

        // Add initial cards with mixed suits
        humanPlayer.hand.addAll([
          const PlayingCard(suit: Suit.spades, rank: CardRank.king), // Index 0
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen), // Index 1
        ]);

        // Draw cards that will move when sorted by suit
        final drawnCard1 = const PlayingCard(
          suit: Suit.clubs,
          rank: CardRank.ace,
        ); // Will move
        final drawnCard2 = const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.two,
        ); // Will move

        humanPlayer.addNewlyDrawnCard(drawnCard1); // Index 2
        humanPlayer.addNewlyDrawnCard(drawnCard2); // Index 3

        // Sort by suit - this will rearrange cards
        humanPlayer.sortHandBySuit();

        // Find where the newly drawn cards ended up and verify they're still highlighted
        int highlightedCount = 0;
        for (int i = 0; i < humanPlayer.currentHand.length; i++) {
          if (humanPlayer.isCardIndexNewlyDrawn(i)) {
            highlightedCount++;
            final card = humanPlayer.currentHand[i];
            // Verify it's one of the cards we drew
            expect(
              [CardRank.ace, CardRank.two].contains(card.rank),
              true,
              reason: 'Highlighted card should be one we drew',
            );
          }
        }

        expect(
          highlightedCount,
          2,
          reason:
              'Should have exactly 2 highlighted cards after sorting by suit',
        );
      },
    );
  });
}
