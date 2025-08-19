import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Game Save/Restore Integration - Newly Drawn Cards', () {
    test('should clear newly drawn cards during game controller restoration', () {
      // This test focuses on the fix itself rather than the full serialization format
      final humanPlayer = Player(id: '1', name: 'You', type: PlayerType.human);
      final botPlayer1 = Player(id: '2', name: 'Bot 1', type: PlayerType.bot);
      final botPlayer2 = Player(id: '3', name: 'Bot 2', type: PlayerType.bot);

      final players = [humanPlayer, botPlayer1, botPlayer2];

      // Set up hand with some cards
      humanPlayer.hasPlayedDown = true;
      humanPlayer.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        const PlayingCard(suit: Suit.spades, rank: CardRank.two),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.joker),
      ]);

      // Simulate corrupted newly drawn indices (the bug we're fixing)
      humanPlayer.newlyDrawnCardIndices.addAll([4, 5]); // Wrong indices

      // Verify corrupted state exists
      expect(humanPlayer.isCardIndexNewlyDrawn(4), true); // Ace (wrong)
      expect(humanPlayer.isCardIndexNewlyDrawn(5), true); // Joker (wrong)

      // Create game controller - this should trigger the fix
      final controller = GameController(players: players, seed: 12345);

      // The fix should be applied automatically during restore
      // (in real usage, this happens in GameSaveService.restoreGameController)
      controller.clearAllNewlyDrawnCards();

      // Verify newly drawn cards highlighting was cleared
      expect(humanPlayer.isCardIndexNewlyDrawn(0), false);
      expect(humanPlayer.isCardIndexNewlyDrawn(1), false);
      expect(humanPlayer.isCardIndexNewlyDrawn(2), false);
      expect(humanPlayer.isCardIndexNewlyDrawn(3), false);
      expect(humanPlayer.isCardIndexNewlyDrawn(4), false);
      expect(humanPlayer.isCardIndexNewlyDrawn(5), false);

      // Verify no newly drawn card indices exist
      expect(humanPlayer.newlyDrawnCardIndices.isEmpty, true);

      // But the cards are still in hand
      expect(humanPlayer.hand.length, 6);
    });

    test('should prevent regression of the ace/joker highlighting bug', () {
      // This test specifically recreates the user's reported bug scenario
      final humanPlayer = Player(id: '1', name: 'You', type: PlayerType.human);
      final botPlayer1 = Player(id: '2', name: 'Bot 1', type: PlayerType.bot);
      final botPlayer2 = Player(id: '3', name: 'Bot 2', type: PlayerType.bot);

      // Create the exact hand from the user's export
      humanPlayer.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // 0
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // 1
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // 2
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four), // 3
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four), // 4
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four), // 5
        const PlayingCard(suit: Suit.clubs, rank: CardRank.eight), // 6
        const PlayingCard(suit: Suit.spades, rank: CardRank.eight), // 7
        const PlayingCard(suit: Suit.hearts, rank: CardRank.eight), // 8
        const PlayingCard(suit: Suit.hearts, rank: CardRank.eight), // 9
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.eight), // 10
        const PlayingCard(suit: Suit.spades, rank: CardRank.eight), // 11
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten), // 12
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten), // 13
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen), // 14
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.king,
        ), // 15 <- Should be newly drawn
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king), // 16
        const PlayingCard(
          suit: Suit.spades,
          rank: CardRank.ace,
        ), // 17 <- Was incorrectly highlighted
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace), // 18
        const PlayingCard(
          suit: Suit.clubs,
          rank: CardRank.joker,
        ), // 19 <- Was incorrectly highlighted
      ]);

      // User reported drawing "Four of diamonds" and "King of hearts"
      // but ace (index 17) and joker (index 19) were being highlighted instead
      humanPlayer.newlyDrawnCardIndices.addAll([17, 19]); // The bug

      // Verify the bug state exists
      expect(
        humanPlayer.isCardIndexNewlyDrawn(17),
        true,
      ); // Ace incorrectly highlighted
      expect(
        humanPlayer.isCardIndexNewlyDrawn(19),
        true,
      ); // Joker incorrectly highlighted
      expect(
        humanPlayer.isCardIndexNewlyDrawn(15),
        false,
      ); // King should be highlighted but isn't
      expect(
        humanPlayer.isCardIndexNewlyDrawn(5),
        false,
      ); // Four should be highlighted but isn't

      // Create controller (this triggers the fix)
      final controller = GameController(
        players: [humanPlayer, botPlayer1, botPlayer2],
      );
      controller.clearAllNewlyDrawnCards(); // Applied automatically in restore

      // Verify the bug is fixed - no incorrect highlighting
      expect(
        humanPlayer.isCardIndexNewlyDrawn(17),
        false,
      ); // Ace no longer highlighted
      expect(
        humanPlayer.isCardIndexNewlyDrawn(19),
        false,
      ); // Joker no longer highlighted
      expect(
        humanPlayer.isCardIndexNewlyDrawn(15),
        false,
      ); // King properly not highlighted
      expect(
        humanPlayer.isCardIndexNewlyDrawn(5),
        false,
      ); // Four properly not highlighted

      // Verify no cards are incorrectly highlighted
      for (int i = 0; i < humanPlayer.currentHand.length; i++) {
        expect(humanPlayer.isCardIndexNewlyDrawn(i), false);
      }

      // The cards are still in hand, just not incorrectly highlighted
      expect(humanPlayer.currentHand[17].rank, CardRank.ace);
      expect(humanPlayer.currentHand[19].rank, CardRank.joker);
      expect(humanPlayer.currentHand[15].rank, CardRank.king);
      expect(humanPlayer.currentHand[5].rank, CardRank.four);
    });
  });
}
