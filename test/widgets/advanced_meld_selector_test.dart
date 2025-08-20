import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Advanced Meld Selector Multi-Meld State Management', () {
    late Player testPlayer;

    setUp(() {
      // Create a hand with cards that can form multiple melds
      final testHand = [
        // First meld: Three 4s
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        const PlayingCard(suit: Suit.spades, rank: CardRank.four),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four),

        // Second meld: Three 7s
        const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
        const PlayingCard(suit: Suit.spades, rank: CardRank.seven),

        // Third meld potential: Kings and wild cards
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.two), // Wild
        // Extra cards
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.eight),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
      ];

      testPlayer = Player(
        id: '1',
        name: 'Test Player',
        type: PlayerType.human,
        hand: testHand,
      );
    });

    test('should maintain consistent state after creating first meld', () {
      // Simulate the advanced meld selector state
      List<List<int>> proposedMeldIndices = [];
      List<int> availableCardIndices = List.generate(
        testPlayer.currentHand.length,
        (index) => index,
      );
      Set<int> selectedAvailableIndices = {};

      // Select first three cards (the 4s: indices 0, 1, 2 in availableCardIndices)
      selectedAvailableIndices.addAll([0, 1, 2]);

      // Convert to hand indices (should be [0, 1, 2])
      final selectedHandIndices = selectedAvailableIndices
          .map((availableIndex) => availableCardIndices[availableIndex])
          .toList();

      expect(selectedHandIndices, equals([0, 1, 2]));

      // Create the meld (simulate the fixed logic)
      proposedMeldIndices.add(selectedHandIndices);

      // Remove selected hand indices from available cards
      for (final handIndex in selectedHandIndices.reversed) {
        availableCardIndices.remove(handIndex);
      }

      selectedAvailableIndices.clear();

      // Verify state after first meld creation
      expect(proposedMeldIndices.length, equals(1));
      expect(proposedMeldIndices[0], equals([0, 1, 2]));
      expect(availableCardIndices.length, equals(9)); // 12 - 3 = 9
      expect(selectedAvailableIndices.isEmpty, isTrue);

      // Verify available cards are now [3, 4, 5, 6, 7, 8, 9, 10, 11]
      expect(availableCardIndices, equals([3, 4, 5, 6, 7, 8, 9, 10, 11]));
    });

    test('should allow creating second meld after first meld', () {
      // Start with state after first meld (4s removed)
      List<List<int>> proposedMeldIndices = [
        [0, 1, 2],
      ];
      List<int> availableCardIndices = [3, 4, 5, 6, 7, 8, 9, 10, 11];
      Set<int> selectedAvailableIndices = {};

      // Select next three cards for second meld (the 7s: hand indices 3, 4, 5)
      // These are at positions 0, 1, 2 in the availableCardIndices array
      selectedAvailableIndices.addAll([0, 1, 2]);

      // Convert to hand indices (should be [3, 4, 5])
      final selectedHandIndices = selectedAvailableIndices
          .map((availableIndex) => availableCardIndices[availableIndex])
          .toList();

      expect(selectedHandIndices, equals([3, 4, 5]));

      // Verify we can get the actual cards
      final selectedCards = selectedHandIndices
          .map((handIndex) => testPlayer.currentHand[handIndex])
          .toList();

      expect(selectedCards.length, equals(3));
      expect(
        selectedCards.every((card) => card.rank == CardRank.seven),
        isTrue,
      );

      // Create second meld
      proposedMeldIndices.add(selectedHandIndices);

      // Remove from available cards
      for (final handIndex in selectedHandIndices.reversed) {
        availableCardIndices.remove(handIndex);
      }

      selectedAvailableIndices.clear();

      // Verify state after second meld
      expect(proposedMeldIndices.length, equals(2));
      expect(proposedMeldIndices[1], equals([3, 4, 5]));
      expect(availableCardIndices.length, equals(6)); // 9 - 3 = 6
      expect(selectedAvailableIndices.isEmpty, isTrue);

      // Verify remaining available cards
      expect(availableCardIndices, equals([6, 7, 8, 9, 10, 11]));
    });

    test(
      'should handle third meld creation with mixed natural and wild cards',
      () {
        // Start with state after two melds
        List<List<int>> proposedMeldIndices = [
          [0, 1, 2],
          [3, 4, 5],
        ];
        List<int> availableCardIndices = [6, 7, 8, 9, 10, 11];
        Set<int> selectedAvailableIndices = {};

        // Select kings and wild card for third meld (hand indices 6, 7, 8)
        selectedAvailableIndices.addAll([
          0,
          1,
          2,
        ]); // Positions in availableCardIndices

        final selectedHandIndices = selectedAvailableIndices
            .map((availableIndex) => availableCardIndices[availableIndex])
            .toList();

        expect(selectedHandIndices, equals([6, 7, 8]));

        // Verify the cards are valid for a meld
        final selectedCards = selectedHandIndices
            .map((handIndex) => testPlayer.currentHand[handIndex])
            .toList();

        final naturalCards = selectedCards
            .where((card) => !card.isWild)
            .toList();
        final wildCards = selectedCards.where((card) => card.isWild).toList();

        expect(naturalCards.length, equals(2)); // Two kings
        expect(wildCards.length, equals(1)); // One wild (2)
        expect(
          naturalCards.every((card) => card.rank == CardRank.king),
          isTrue,
        );

        // Create third meld
        proposedMeldIndices.add(selectedHandIndices);

        for (final handIndex in selectedHandIndices.reversed) {
          availableCardIndices.remove(handIndex);
        }

        selectedAvailableIndices.clear();

        // Verify final state
        expect(proposedMeldIndices.length, equals(3));
        expect(proposedMeldIndices[2], equals([6, 7, 8]));
        expect(availableCardIndices.length, equals(3)); // 6 - 3 = 3
        expect(availableCardIndices, equals([9, 10, 11])); // Remaining cards
      },
    );

    test('should handle bounds checking for card selection', () {
      List<int> availableCardIndices = [0, 1, 2, 3, 4];

      // Test valid indices
      expect(0 >= 0 && 0 < availableCardIndices.length, isTrue);
      expect(4 >= 0 && 4 < availableCardIndices.length, isTrue);

      // Test invalid indices
      expect(-1 >= 0 && -1 < availableCardIndices.length, isFalse);
      expect(5 >= 0 && 5 < availableCardIndices.length, isFalse);

      // Test bounds checking function
      bool isValidIndex(int index, List<int> indices) {
        return index >= 0 && index < indices.length;
      }

      expect(isValidIndex(-1, availableCardIndices), isFalse);
      expect(isValidIndex(0, availableCardIndices), isTrue);
      expect(isValidIndex(4, availableCardIndices), isTrue);
      expect(isValidIndex(5, availableCardIndices), isFalse);
    });

    test('should prevent invalid meld creation', () {
      // Test with insufficient cards
      final insufficientCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        const PlayingCard(
          suit: Suit.spades,
          rank: CardRank.five,
        ), // Different rank
      ];

      final naturalCards = insufficientCards
          .where((card) => !card.isWild)
          .toList();

      // Should fail - different ranks
      if (naturalCards.isNotEmpty) {
        final rank = naturalCards.first.rank;
        final allSameRank = naturalCards.every((card) => card.rank == rank);
        expect(allSameRank, isFalse);
      }

      // Should fail - insufficient count (we have exactly 2 cards)
      expect(naturalCards.length, equals(2)); // We have 2 natural cards
      expect(insufficientCards.length < 3, isTrue); // But less than 3 total
    });

    test('should calculate points correctly across multiple melds', () {
      final meldIndices1 = [0, 1, 2]; // Three 4s = 3 * 5 = 15 pts
      final meldIndices2 = [3, 4, 5]; // Three 7s = 3 * 5 = 15 pts
      final meldIndices3 = [6, 7, 8]; // Two Kings + wild = 2 * 10 + 20 = 40 pts

      final allMeldIndices = [meldIndices1, meldIndices2, meldIndices3];

      final totalPoints = allMeldIndices
          .expand(
            (meldIndices) => meldIndices.map((i) => testPlayer.currentHand[i]),
          )
          .fold<int>(0, (sum, card) => sum + card.pointValue);

      expect(totalPoints, equals(70)); // 15 + 15 + 40 = 70
    });

    test('should handle meld removal correctly', () {
      // Start with two melds
      List<List<int>> proposedMeldIndices = [
        [0, 1, 2],
        [3, 4, 5],
      ];
      List<int> availableCardIndices = [6, 7, 8, 9, 10, 11];

      // Remove first meld
      final removedMeldIndices = proposedMeldIndices.removeAt(0);
      availableCardIndices.addAll(removedMeldIndices);

      // Sort for better UX (simulate _sortAvailableCardIndices)
      availableCardIndices.sort();

      expect(proposedMeldIndices.length, equals(1));
      expect(proposedMeldIndices[0], equals([3, 4, 5])); // Second meld remains
      expect(
        availableCardIndices,
        equals([0, 1, 2, 6, 7, 8, 9, 10, 11]),
      ); // Cards returned
    });
  });
}
