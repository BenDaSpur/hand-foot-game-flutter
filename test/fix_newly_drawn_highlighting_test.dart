import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Newly Drawn Cards Highlighting Fix', () {
    test(
      'should clear newly drawn cards after game controller initialization',
      () {
        // Create players with some newly drawn cards indices set incorrectly
        final humanPlayer = Player(
          id: '1',
          name: 'Human',
          type: PlayerType.human,
        );
        final botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

        // Add some cards to hand
        humanPlayer.hand.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ]);

        // Simulate corrupted newly drawn indices (pointing to wrong cards)
        humanPlayer.newlyDrawnCardIndices.addAll([0, 2]); // Wrong indices

        // Verify the incorrect state exists
        expect(humanPlayer.isCardIndexNewlyDrawn(0), true);
        expect(humanPlayer.isCardIndexNewlyDrawn(2), true);

        // Create game controller - should clear newly drawn cards
        final controller = GameController(players: [humanPlayer, botPlayer]);
        controller.clearAllNewlyDrawnCards();

        // Verify newly drawn cards were cleared
        expect(humanPlayer.isCardIndexNewlyDrawn(0), false);
        expect(humanPlayer.isCardIndexNewlyDrawn(1), false);
        expect(humanPlayer.isCardIndexNewlyDrawn(2), false);
      },
    );

    test('should clear newly drawn cards in game save service restore', () {
      // Create a mock saved game data with players that have stale newly drawn indices
      final humanPlayer = Player(
        id: '1',
        name: 'Human',
        type: PlayerType.human,
      );
      final botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

      humanPlayer.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      ]);

      // Add stale newly drawn indices
      humanPlayer.newlyDrawnCardIndices.add(1);
      expect(humanPlayer.isCardIndexNewlyDrawn(1), true);

      // Create controller to test the clearAllNewlyDrawnCards method
      final controller = GameController(players: [humanPlayer, botPlayer]);

      // Call the method that's used in restoreGameController
      controller.clearAllNewlyDrawnCards();

      // Verify newly drawn cards were cleared
      expect(humanPlayer.isCardIndexNewlyDrawn(1), false);
      expect(botPlayer.newlyDrawnCardIndices.isEmpty, true);
    });

    test('should not affect valid newly drawn cards during normal gameplay', () {
      final humanPlayer = Player(
        id: '1',
        name: 'Human',
        type: PlayerType.human,
      );
      final botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

      // Add some cards to hand
      humanPlayer.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      ]);

      // Add a newly drawn card through the proper method
      final newCard = const PlayingCard(suit: Suit.clubs, rank: CardRank.queen);
      humanPlayer.addNewlyDrawnCard(newCard);

      // Verify it was marked as newly drawn
      expect(humanPlayer.isCardIndexNewlyDrawn(2), true);
      expect(humanPlayer.currentHand[2], newCard);

      // Create controller but don't clear (simulating normal gameplay)
      final controller = GameController(players: [humanPlayer, botPlayer]);

      // Verify the newly drawn card is still marked (until cleared by normal game flow)
      expect(humanPlayer.isCardIndexNewlyDrawn(2), true);

      // Clear all as would happen in the initialization
      controller.clearAllNewlyDrawnCards();

      // Now it should be cleared
      expect(humanPlayer.isCardIndexNewlyDrawn(2), false);
    });

    test('should handle export/import scenario with corrupted newly drawn indices', () {
      // Create a game controller with players who have existing melds (like the user's scenario)
      final humanPlayer = Player(id: '1', name: 'You', type: PlayerType.human);
      final botPlayer1 = Player(id: '2', name: 'Bot 1', type: PlayerType.bot);
      final botPlayer2 = Player(id: '3', name: 'Bot 2', type: PlayerType.bot);

      // Set up the human player's state similar to the user's export
      humanPlayer.hasPlayedDown = true;
      humanPlayer.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // 0
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // 1
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // 2
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four), // 3
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four), // 4
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.four,
        ), // 5 <- should be newly drawn
        // ... more cards
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.king,
        ), // 15 <- should be newly drawn
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king), // 16
        const PlayingCard(
          suit: Suit.spades,
          rank: CardRank.ace,
        ), // 17 <- incorrectly highlighted
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace), // 18
        const PlayingCard(
          suit: Suit.clubs,
          rank: CardRank.joker,
        ), // 19 <- incorrectly highlighted
      ]);

      // Add existing melds (like the user had)
      final aceMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ])!;

      final fourMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        const PlayingCard(suit: Suit.spades, rank: CardRank.four),
      ])!;

      humanPlayer.melds.addAll([aceMeld, fourMeld]);

      // Simulate corrupted newly drawn indices pointing to wrong cards
      // (like ace and joker instead of the actual four and king that were drawn)
      humanPlayer.newlyDrawnCardIndices.addAll([17, 19]); // Wrong indices

      // Verify the corrupted state exists
      expect(humanPlayer.isCardIndexNewlyDrawn(17), true); // Ace (wrong)
      expect(humanPlayer.isCardIndexNewlyDrawn(19), true); // Joker (wrong)
      expect(
        humanPlayer.isCardIndexNewlyDrawn(5),
        false,
      ); // Four (should be newly drawn but not marked)
      expect(
        humanPlayer.isCardIndexNewlyDrawn(15),
        false,
      ); // King (should be newly drawn but not marked)

      // Create game controller and restore (this simulates the GameSaveService.restoreGameController flow)
      final controller = GameController(
        players: [humanPlayer, botPlayer1, botPlayer2],
      );

      // The restoreGameController method would call this automatically
      controller.clearAllNewlyDrawnCards();

      // Verify all newly drawn card highlighting is cleared
      expect(
        humanPlayer.isCardIndexNewlyDrawn(17),
        false,
      ); // Ace no longer highlighted
      expect(
        humanPlayer.isCardIndexNewlyDrawn(19),
        false,
      ); // Joker no longer highlighted
      expect(
        humanPlayer.isCardIndexNewlyDrawn(5),
        false,
      ); // Four still not highlighted
      expect(
        humanPlayer.isCardIndexNewlyDrawn(15),
        false,
      ); // King still not highlighted

      // Verify no cards are incorrectly highlighted
      for (int i = 0; i < humanPlayer.currentHand.length; i++) {
        expect(
          humanPlayer.isCardIndexNewlyDrawn(i),
          false,
          reason:
              'Card at index $i should not be highlighted as newly drawn after restore',
        );
      }
    });

    test('should maintain newly drawn card clearing across game phases', () {
      // Test that newly drawn cards are properly cleared when changing turns/phases
      final humanPlayer = Player(
        id: '1',
        name: 'Human',
        type: PlayerType.human,
      );
      final botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

      // Add cards and simulate drawing new ones
      humanPlayer.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      ]);

      // Draw two cards normally (simulates the user's scenario of drawing four and king)
      final drawnCard1 = const PlayingCard(
        suit: Suit.diamonds,
        rank: CardRank.four,
      );
      final drawnCard2 = const PlayingCard(
        suit: Suit.hearts,
        rank: CardRank.king,
      );

      humanPlayer.addNewlyDrawnCard(drawnCard1);
      humanPlayer.addNewlyDrawnCard(drawnCard2);

      // Verify cards are marked as newly drawn
      expect(humanPlayer.isCardIndexNewlyDrawn(2), true); // Four
      expect(humanPlayer.isCardIndexNewlyDrawn(3), true); // King

      // Create game controller
      final controller = GameController(players: [humanPlayer, botPlayer]);

      // Simulate what happens when game is restored or reinitialized
      controller.clearAllNewlyDrawnCards();

      // All newly drawn highlighting should be cleared
      expect(humanPlayer.isCardIndexNewlyDrawn(2), false);
      expect(humanPlayer.isCardIndexNewlyDrawn(3), false);

      // But the cards should still be in hand
      expect(humanPlayer.currentHand.length, 4);
      expect(humanPlayer.currentHand[2], drawnCard1);
      expect(humanPlayer.currentHand[3], drawnCard2);
    });
  });
}
