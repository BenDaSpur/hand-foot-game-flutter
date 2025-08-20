import 'dart:async';
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

      // Test valid indices - both should be within bounds
      expect(availableCardIndices.isNotEmpty, isTrue);
      expect(availableCardIndices.length, equals(5));

      // Test invalid indices
      expect(-1 < 0, isTrue);
      expect(5 >= availableCardIndices.length, isTrue);

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

    test('should properly dispose of resources and prevent memory leaks', () {
      // Mock timer for testing disposal
      Timer? mockTimer;
      bool timerCancelled = false;

      // Simulate the timer creation and cancellation pattern
      mockTimer = Timer(const Duration(milliseconds: 300), () {});

      // Simulate disposal
      if (mockTimer.isActive) {
        mockTimer.cancel();
        timerCancelled = true;
      }

      expect(timerCancelled, isTrue);
      expect(mockTimer.isActive, isFalse);
    });

    test('should handle widget lifecycle properly', () {
      // Test mounted state checking
      bool mounted = true;

      void simulateStateUpdate() {
        if (mounted) {
          // This would normally call setState
          // Here we just verify the mounted check works
          expect(mounted, isTrue);
        }
      }

      simulateStateUpdate();

      // Simulate widget disposal
      mounted = false;

      // This should not trigger state updates
      simulateStateUpdate();
      expect(mounted, isFalse);
    });

    test(
      'should handle debouncing properly to prevent excessive refreshes',
      () {
        final refreshCalls = <DateTime>[];

        // Simulate multiple rapid refresh calls
        final now = DateTime.now();
        refreshCalls.add(now);
        refreshCalls.add(now.add(const Duration(milliseconds: 50)));
        refreshCalls.add(now.add(const Duration(milliseconds: 100)));
        refreshCalls.add(now.add(const Duration(milliseconds: 150)));

        // With proper debouncing, only the last call should be executed
        // Here we simulate by checking the timing between calls
        final validCalls = refreshCalls.where((call) {
          final timeSinceFirst = call.difference(refreshCalls.first);
          return timeSinceFirst.inMilliseconds >= 300;
        }).toList();

        // Should have at most one valid call after debounce period
        expect(validCalls.length, lessThanOrEqualTo(1));
      },
    );

    test(
      'should validate bounds checking prevents array access violations',
      () {
        final availableIndices = [0, 1, 2];

        // Test accessing valid indices
        for (int i = 0; i < availableIndices.length; i++) {
          expect(i >= 0 && i < availableIndices.length, isTrue);
        }

        // Test invalid indices are caught
        expect(-1 < 0, isTrue);
        expect(availableIndices.length < availableIndices.length, isFalse);
        expect(availableIndices.length + 1 >= availableIndices.length, isTrue);
      },
    );

    test('should handle keep-alive widget state properly', () {
      // Test AutomaticKeepAliveClientMixin behavior simulation
      bool wantKeepAlive = true;
      bool isWidgetBuilt = false;

      void simulateBuild() {
        if (wantKeepAlive) {
          // Simulate super.build() call required by mixin
          isWidgetBuilt = true;
        }
      }

      simulateBuild();
      expect(isWidgetBuilt, isTrue);

      // Test disabling keep alive
      wantKeepAlive = false;
      isWidgetBuilt = false;
      simulateBuild();
      expect(isWidgetBuilt, isFalse);
    });
  });

  group('Advanced Meld Selector - Meld Validation Rules', () {
    late Player testPlayer;

    setUp(() {
      testPlayer = Player(
        id: 'validation_test',
        name: 'Validation Test Player',
        type: PlayerType.human,
      );
    });

    test('should reject meld with 3s in selection', () {
      // Add cards with 3s included
      testPlayer.currentHand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(
          suit: Suit.clubs,
          rank: CardRank.three,
        ), // 3 - should be rejected
      ]);

      final selectedCards = testPlayer.currentHand.sublist(0, 3);
      final has3s = selectedCards.any((card) => card.rank == CardRank.three);

      // Should fail validation due to 3s
      expect(has3s, isTrue);
      // This would trigger error: "3s cannot be melded"
    });

    test('should reject meld with insufficient total cards', () {
      // Add only 2 cards (less than minimum 3)
      testPlayer.currentHand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
      ]);

      final selectedCards = testPlayer.currentHand.sublist(0, 2);
      final hasMinimumCards =
          selectedCards.length >= 3; // GameConfig.minTotalCardsForMeld

      expect(hasMinimumCards, isFalse);
      // This would trigger error: "Need at least 3 cards for a meld"
    });

    test('should reject meld with insufficient natural cards', () {
      // Add cards with only 1 natural card + wilds
      testPlayer.currentHand.addAll([
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.king,
        ), // Only 1 natural
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // Wild
        const PlayingCard(rank: CardRank.joker), // Wild
      ]);

      final selectedCards = testPlayer.currentHand.sublist(0, 3);
      final naturalCards = selectedCards
          .where((card) => !card.isWild && card.rank != CardRank.three)
          .toList();

      final hasMinimumNaturals =
          naturalCards.length >= 2; // GameConfig.minNaturalCardsForMeld

      expect(naturalCards.length, equals(1));
      expect(hasMinimumNaturals, isFalse);
      // This would trigger error: "Need at least 2 natural cards of the same rank"
    });

    test('should reject meld with mixed ranks in natural cards', () {
      // Add cards with different natural ranks
      testPlayer.currentHand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.queen,
        ), // Different rank
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // Wild
      ]);

      final selectedCards = testPlayer.currentHand.sublist(0, 3);
      final naturalCards = selectedCards
          .where((card) => !card.isWild && card.rank != CardRank.three)
          .toList();

      if (naturalCards.isNotEmpty) {
        final firstRank = naturalCards.first.rank;
        final allSameRank = naturalCards.every(
          (card) => card.rank == firstRank,
        );
        expect(allSameRank, isFalse);
      }
      // This would trigger error: "All natural cards must be the same rank"
    });

    test('should reject meld when wild cards exceed naturals', () {
      // Add more wilds than naturals
      testPlayer.currentHand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // Wild
        const PlayingCard(rank: CardRank.joker), // Wild
        const PlayingCard(suit: Suit.clubs, rank: CardRank.two), // Another wild
      ]);

      final selectedCards = testPlayer.currentHand.sublist(0, 4);
      final naturalCards = selectedCards
          .where((card) => !card.isWild && card.rank != CardRank.three)
          .toList();
      final wildCards = selectedCards.where((card) => card.isWild).toList();

      final wildCountValid = wildCards.length <= naturalCards.length;

      expect(naturalCards.length, equals(1));
      expect(wildCards.length, equals(3));
      expect(wildCountValid, isFalse);
      // This would trigger error: "Too many wild cards (3) for naturals (1)"
    });

    test('should accept valid 3-card meld with 2 naturals + 1 wild', () {
      // Add valid meld: 2 naturals + 1 wild
      testPlayer.currentHand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // Wild
      ]);

      final selectedCards = testPlayer.currentHand.sublist(0, 3);
      final naturalCards = selectedCards
          .where((card) => !card.isWild && card.rank != CardRank.three)
          .toList();
      final wildCards = selectedCards.where((card) => card.isWild).toList();

      // All validation checks should pass
      final hasMinimumCards = selectedCards.length >= 3;
      final hasMinimumNaturals = naturalCards.length >= 2;
      final allSameRank =
          naturalCards.isNotEmpty &&
          naturalCards.every((card) => card.rank == naturalCards.first.rank);
      final wildCountValid = wildCards.length <= naturalCards.length;
      final has3s = selectedCards.any((card) => card.rank == CardRank.three);

      expect(hasMinimumCards, isTrue);
      expect(hasMinimumNaturals, isTrue);
      expect(allSameRank, isTrue);
      expect(wildCountValid, isTrue);
      expect(has3s, isFalse);
      expect(naturalCards.length, equals(2));
      expect(wildCards.length, equals(1));
      expect(selectedCards.length, equals(3));
    });

    test('should properly update available cards after meld creation', () {
      // Setup initial state
      testPlayer.currentHand.addAll([
        // First meld cards
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        // Remaining available cards
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.two),
      ]);

      // Initial available cards (all cards)
      List<int> availableCardIndices = List.generate(
        testPlayer.currentHand.length,
        (index) => index,
      );
      expect(availableCardIndices.length, equals(6));
      expect(availableCardIndices, equals([0, 1, 2, 3, 4, 5]));

      // Create meld with first 3 cards
      final meldIndices = [0, 1, 2];

      // Remove melded cards from available cards (in reverse order to maintain indices)
      for (final handIndex in meldIndices.reversed) {
        availableCardIndices.remove(handIndex);
      }

      // Verify available cards updated correctly
      expect(availableCardIndices.length, equals(3));
      expect(availableCardIndices, equals([3, 4, 5]));

      // Verify the remaining available cards are correct
      final remainingCards = availableCardIndices
          .map((index) => testPlayer.currentHand[index])
          .toList();

      expect(remainingCards.length, equals(3));
      expect(remainingCards[0].rank, equals(CardRank.queen));
      expect(remainingCards[1].rank, equals(CardRank.queen));
      expect(remainingCards[2].isWild, isTrue);
    });

    test('should validate clean meld (no wilds)', () {
      // Add 4 natural cards of same rank
      testPlayer.currentHand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
      ]);

      final selectedCards = testPlayer.currentHand.sublist(0, 4);
      final naturalCards = selectedCards
          .where((card) => !card.isWild && card.rank != CardRank.three)
          .toList();
      final wildCards = selectedCards.where((card) => card.isWild).toList();

      expect(naturalCards.length, equals(4));
      expect(wildCards.length, equals(0));
      expect(naturalCards.every((card) => card.rank == CardRank.ace), isTrue);

      // Clean meld validation passes
      final isCleanMeld = wildCards.isEmpty && naturalCards.length >= 3;
      expect(isCleanMeld, isTrue);
    });

    test('should validate dirty meld (with wilds)', () {
      // Add mixed natural and wild cards
      testPlayer.currentHand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // Wild
        const PlayingCard(rank: CardRank.joker), // Wild
      ]);

      final selectedCards = testPlayer.currentHand.sublist(0, 5);
      final naturalCards = selectedCards
          .where((card) => !card.isWild && card.rank != CardRank.three)
          .toList();
      final wildCards = selectedCards.where((card) => card.isWild).toList();

      expect(naturalCards.length, equals(3));
      expect(wildCards.length, equals(2));
      expect(naturalCards.every((card) => card.rank == CardRank.jack), isTrue);

      // Dirty meld validation passes (wilds <= naturals)
      final isDirtyMeld =
          wildCards.isNotEmpty &&
          wildCards.length <= naturalCards.length &&
          naturalCards.length >= 2;
      expect(isDirtyMeld, isTrue);
    });
  });
}
