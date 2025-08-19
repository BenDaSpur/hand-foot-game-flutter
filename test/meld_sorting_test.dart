import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';

void main() {
  group('Meld Display Sorting', () {
    test('should sort melds with Aces at the end', () {
      final player = Player(id: '1', name: 'Test', type: PlayerType.human);

      // Create melds in random order to test sorting
      final aceMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ])!;

      final fourMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        const PlayingCard(suit: Suit.spades, rank: CardRank.four),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
      ])!;

      final kingMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ])!;

      final sevenMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
        const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
      ])!;

      // Add melds in random order: Ace, Four, King, Seven
      player.melds.addAll([aceMeld, fourMeld, kingMeld, sevenMeld]);

      // Create indexed melds and sort like the UI does
      final indexedMelds = player.melds.asMap().entries.toList();

      indexedMelds.sort((a, b) {
        // Special handling for Aces - put them at the end
        final aRank = a.value.rank;
        final bRank = b.value.rank;

        if (aRank == CardRank.ace && bRank != CardRank.ace) {
          return 1; // a (ace) comes after b
        }
        if (bRank == CardRank.ace && aRank != CardRank.ace) {
          return -1; // b (ace) comes after a
        }

        // For non-ace cards or both aces, use normal index comparison
        return aRank.index.compareTo(bRank.index);
      });

      // Verify the sorted order: Four, Seven, King, Ace (Aces at the end)
      expect(indexedMelds.length, 4);
      expect(indexedMelds[0].value.rank, CardRank.four);
      expect(indexedMelds[1].value.rank, CardRank.seven);
      expect(indexedMelds[2].value.rank, CardRank.king);
      expect(indexedMelds[3].value.rank, CardRank.ace); // Ace at the end!
    });

    test('should handle multiple ace melds correctly', () {
      final player = Player(id: '1', name: 'Test', type: PlayerType.human);

      // Create two different ace melds
      final aceMeld1 = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ])!;

      final aceMeld2 = Meld.createMeld([
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ])!;

      final tenMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
      ])!;

      // Add in order: ace, ten, ace
      player.melds.addAll([aceMeld1, tenMeld, aceMeld2]);

      // Sort like the UI does
      final indexedMelds = player.melds.asMap().entries.toList();

      indexedMelds.sort((a, b) {
        final aRank = a.value.rank;
        final bRank = b.value.rank;

        if (aRank == CardRank.ace && bRank != CardRank.ace) {
          return 1; // a (ace) comes after b
        }
        if (bRank == CardRank.ace && aRank != CardRank.ace) {
          return -1; // b (ace) comes after a
        }

        return aRank.index.compareTo(bRank.index);
      });

      // Should be: Ten, then the two Ace melds
      expect(indexedMelds.length, 3);
      expect(indexedMelds[0].value.rank, CardRank.ten);
      expect(indexedMelds[1].value.rank, CardRank.ace);
      expect(indexedMelds[2].value.rank, CardRank.ace);
    });

    test('should handle no ace melds correctly', () {
      final player = Player(id: '1', name: 'Test', type: PlayerType.human);

      final fourMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        const PlayingCard(suit: Suit.spades, rank: CardRank.four),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
      ])!;

      final kingMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ])!;

      final fiveMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        const PlayingCard(suit: Suit.spades, rank: CardRank.five),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
      ])!;

      // Add in order: Four, King, Five
      player.melds.addAll([fourMeld, kingMeld, fiveMeld]);

      // Sort like the UI does
      final indexedMelds = player.melds.asMap().entries.toList();

      indexedMelds.sort((a, b) {
        final aRank = a.value.rank;
        final bRank = b.value.rank;

        if (aRank == CardRank.ace && bRank != CardRank.ace) {
          return 1;
        }
        if (bRank == CardRank.ace && aRank != CardRank.ace) {
          return -1;
        }

        return aRank.index.compareTo(bRank.index);
      });

      // Should be sorted by normal index: Four, Five, King (no special ace handling needed)
      expect(indexedMelds.length, 3);
      expect(indexedMelds[0].value.rank, CardRank.four);
      expect(indexedMelds[1].value.rank, CardRank.five);
      expect(indexedMelds[2].value.rank, CardRank.king);
    });
  });
}
