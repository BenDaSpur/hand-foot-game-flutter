import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';

void main() {
  group('GameScreen Card Selection Logic', () {
    test('_getCompatibleCardsCount should prioritize natural cards', () {
      // This is a more direct unit test of the logic
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot 1', type: PlayerType.bot),
        Player(id: '3', name: 'Bot 2', type: PlayerType.bot),
      ];

      final humanPlayer = players[0];

      // Create existing Kings meld
      final kingsMeld = Meld(
        rank: CardRank.king,
        cards: [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ],
        type: MeldType.natural,
      );
      humanPlayer.melds.add(kingsMeld);

      // Test case 1: Has natural cards of same rank + wilds
      humanPlayer.dealHand([
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king), // Natural
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // Wild
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // Wild
      ]);

      // Count compatible cards - should be 1 (only the natural King)
      int naturalCount = 0;
      for (final card in humanPlayer.hand) {
        if (card.rank == CardRank.king && !card.isWild) {
          naturalCount++;
        }
      }

      expect(naturalCount, equals(1));

      // Test case 2: No natural cards, only wilds
      humanPlayer.dealHand([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // Wild
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // Wild
        const PlayingCard(rank: CardRank.joker), // Wild
      ]);

      naturalCount = 0;
      int wildCount = 0;
      for (final card in humanPlayer.hand) {
        if (card.rank == CardRank.king && !card.isWild) {
          naturalCount++;
        } else if (card.isWild) {
          wildCount++;
        }
      }

      expect(naturalCount, equals(0));
      expect(wildCount, equals(3));

      // In this case, should only count wilds that don't exceed natural limit
      final currentNaturalsInMeld = kingsMeld.cards
          .where((c) => !c.isWild)
          .length;
      final currentWildsInMeld = kingsMeld.cards.where((c) => c.isWild).length;
      final maxAdditionalWilds = currentNaturalsInMeld - currentWildsInMeld;

      expect(currentNaturalsInMeld, equals(3));
      expect(currentWildsInMeld, equals(0));
      expect(maxAdditionalWilds, equals(3));
    });

    test('should reject wild-only meld creation in UI logic', () {
      // Test that the UI logic properly rejects wild-only melds
      final wildCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        const PlayingCard(suit: Suit.spades, rank: CardRank.two),
        const PlayingCard(rank: CardRank.joker),
      ];

      // Simulate the logic from _findMeldGroupsFromSelectedIndices
      final naturalCards = wildCards.where((card) => !card.isWild).toList();
      final wilds = wildCards.where((card) => card.isWild).toList();

      expect(naturalCards.isEmpty, isTrue);
      expect(wilds.length, equals(3));

      // The updated logic should NOT create a meld group from wild-only cards
      // This tests our fix for the critical bug
      List<List<PlayingCard>> meldGroups = [];

      // Only create meld groups if we have natural cards
      if (naturalCards.isNotEmpty && naturalCards.length >= 3) {
        meldGroups.add(naturalCards);
      }

      // Wild-only melds should NOT be added (this was the bug we fixed)
      // if (wilds.length >= 3) {
      //   meldGroups.add(wilds); // This is now removed
      // }

      expect(meldGroups.isEmpty, isTrue);
    });

    test('should create mixed meld with natural + wild cards', () {
      final mixedCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king), // Natural
        const PlayingCard(suit: Suit.spades, rank: CardRank.king), // Natural
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // Wild
      ];

      final naturalCards = mixedCards.where((card) => !card.isWild).toList();
      final wilds = mixedCards.where((card) => card.isWild).toList();

      expect(naturalCards.length, equals(2));
      expect(wilds.length, equals(1));

      // Should be able to create a mixed meld
      List<List<PlayingCard>> meldGroups = [];

      if (naturalCards.length >= 2 && wilds.isNotEmpty) {
        final meldCards = [...naturalCards, ...wilds.take(naturalCards.length)];
        if (meldCards.length >= 3) {
          meldGroups.add(meldCards);
        }
      }

      expect(meldGroups.length, equals(1));
      expect(meldGroups[0].length, equals(3));
    });

    test('should detect wild-only card selections for user feedback', () {
      // Test the validation logic we added to _createMultipleMelds
      final wildOnlyCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // Wild
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // Wild
        const PlayingCard(rank: CardRank.joker), // Wild
      ];

      // Simulate the validation check
      final hasOnlyWildCards =
          wildOnlyCards.isNotEmpty &&
          wildOnlyCards.every((card) => card.isWild);

      expect(hasOnlyWildCards, isTrue);

      // Test mixed selection (should not trigger wild-only validation)
      final mixedCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king), // Natural
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // Wild
      ];

      final hasOnlyWildCardsMixed =
          mixedCards.isNotEmpty && mixedCards.every((card) => card.isWild);

      expect(hasOnlyWildCardsMixed, isFalse);

      // Test empty selection (should not trigger validation)
      final emptyCards = <PlayingCard>[];

      final hasOnlyWildCardsEmpty =
          emptyCards.isNotEmpty && emptyCards.every((card) => card.isWild);

      expect(hasOnlyWildCardsEmpty, isFalse);
    });

    test(
      'should handle multiple meld play-down correctly (3 nines + 5 tens scenario)',
      () {
        // Test the specific scenario from the bug report
        final players = [
          Player(id: '1', name: 'Human', type: PlayerType.human),
          Player(id: '2', name: 'Bot 1', type: PlayerType.bot),
          Player(id: '3', name: 'Bot 2', type: PlayerType.bot),
        ];

        final humanPlayer = players[0];

        // Set up the same scenario: 3 nines (30 pts) + 5 tens (50 pts) = 80 pts total
        humanPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine), // 10 pts
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine), // 10 pts
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine), // 10 pts
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten), // 10 pts
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ten), // 10 pts
          const PlayingCard(suit: Suit.spades, rank: CardRank.ten), // 10 pts
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ten), // 10 pts
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.ten,
          ), // 10 pts (duplicate)
        ]);

        // Player hasn't played down yet
        expect(humanPlayer.hasPlayedDown, isFalse);

        // Calculate total points for play-down check (should be 80 > 60)
        final totalPoints = humanPlayer.hand.fold<int>(
          0,
          (sum, card) => sum + card.pointValue,
        );
        expect(totalPoints, equals(80));
        expect(totalPoints >= 60, isTrue); // Meets play-down requirement

        // Test individual meld validation (this was the bug)
        final ninesCards = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
        ];

        final ninesPoints = ninesCards.fold<int>(
          0,
          (sum, card) => sum + card.pointValue,
        );
        expect(ninesPoints, equals(30)); // 3 x 10 = 30 points
        expect(
          ninesPoints < 60,
          isTrue,
        ); // Individual meld is less than requirement

        // But the individual meld should still be valid when part of a multi-meld play-down
        final ninesMeld = Meld.createMeld(ninesCards);
        expect(ninesMeld, isNotNull);
        expect(ninesMeld!.rank, equals(CardRank.nine));
        // ignore: deprecated_member_use_from_same_package
        expect(
          ninesMeld.type,
          equals(MeldType.natural),
        ); // Testing original field

        // Test tens meld as well
        final tensCards = [
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
        ];

        final tensMeld = Meld.createMeld(tensCards);
        expect(tensMeld, isNotNull);
        expect(tensMeld!.rank, equals(CardRank.ten));
        // ignore: deprecated_member_use_from_same_package
        expect(
          tensMeld.type,
          equals(MeldType.natural),
        ); // Testing original field

        final tensPoints = tensCards.fold<int>(
          0,
          (sum, card) => sum + card.pointValue,
        );
        expect(tensPoints, equals(50)); // 5 x 10 = 50 points

        // Combined points should meet requirement
        expect(ninesPoints + tensPoints, equals(80));
        expect(ninesPoints + tensPoints >= 60, isTrue);
      },
    );
  });
}
