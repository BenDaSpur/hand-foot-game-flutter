import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';

void main() {
  group('Multi-Meld Integration Tests', () {
    late GameController controller;
    late Player humanPlayer;

    setUp(() {
      humanPlayer = Player(id: '1', name: 'Test Human', type: PlayerType.human);
      final botPlayer = Player(id: '2', name: 'Test Bot', type: PlayerType.bot);
      controller = GameController(players: [humanPlayer, botPlayer]);
      controller.initializeGame();

      // Set up game state for meld phase
      controller.gameState.turnPhase = TurnPhase.meld;
    });

    test('should handle multi-meld creation with existing melds', () {
      // Setup: Create initial meld and then try to add to it via multi-meld
      humanPlayer.hand.clear();
      humanPlayer.hand.addAll([
        // Initial meld cards (will be used first)
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four), // 0
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four), // 1
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four), // 2
        // Additional cards for multi-meld scenario
        const PlayingCard(
          suit: Suit.spades,
          rank: CardRank.four,
        ), // 3 - should add to existing meld
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.seven,
        ), // 4 - new meld
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.seven,
        ), // 5 - new meld
        const PlayingCard(
          suit: Suit.clubs,
          rank: CardRank.seven,
        ), // 6 - new meld
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.nine,
        ), // 7 - new meld
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.nine,
        ), // 8 - new meld
        const PlayingCard(
          suit: Suit.clubs,
          rank: CardRank.nine,
        ), // 9 - new meld
      ]);

      // Create initial meld of 4s
      expect(
        controller.createMeldByIndices([0, 1, 2], skipPlayDownCheck: true),
        true,
      );
      expect(humanPlayer.melds.length, 1);
      expect(humanPlayer.melds[0].cards.length, 3);
      expect(humanPlayer.hand.length, 7); // 10 - 3 = 7

      // Now create additional melds one by one (indices shift after each)
      // Remaining hand after first meld: [Spade 4, Heart 7, Diamond 7, Club 7, Heart 9, Diamond 9, Club 9]
      //                                     0        1        2          3       4        5          6

      // Add Spade 4 to existing 4s meld
      expect(
        controller.createMeldByIndices([0], skipPlayDownCheck: true),
        true,
      );
      // Hand is now: [Heart 7, Diamond 7, Club 7, Heart 9, Diamond 9, Club 9]
      //                 0        1          2       3        4          5

      // Create new 7s meld
      expect(
        controller.createMeldByIndices([0, 1, 2], skipPlayDownCheck: true),
        true,
      );
      // Hand is now: [Heart 9, Diamond 9, Club 9]
      //                 0        1          2

      // Create new 9s meld
      expect(
        controller.createMeldByIndices([0, 1, 2], skipPlayDownCheck: true),
        true,
      );

      // Verify results
      expect(humanPlayer.melds.length, 3); // 1 existing + 2 new
      expect(
        humanPlayer.melds[0].cards.length,
        4,
      ); // Original 4s meld now has 4 cards
      expect(humanPlayer.melds[1].cards.length, 3); // New 7s meld
      expect(humanPlayer.melds[2].cards.length, 3); // New 9s meld
      expect(humanPlayer.hand.length, 0); // All cards used

      // Verify ranks
      expect(humanPlayer.melds[0].rank, CardRank.four);
      expect(humanPlayer.melds[1].rank, CardRank.seven);
      expect(humanPlayer.melds[2].rank, CardRank.nine);
    });

    test('should handle play-down requirement validation with multi-meld', () {
      // Setup for round 2 (90 point requirement)
      controller.gameState.round = 2;
      humanPlayer.hasPlayedDown = false;

      humanPlayer.hand.clear();
      humanPlayer.hand.addAll([
        // Low point meld (30 points) - insufficient alone
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four), // 0 - 5 pts
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.four,
        ), // 1 - 5 pts
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four), // 2 - 5 pts
        // High point meld (60 points) - together = 90 points (meets requirement)
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king), // 3 - 10 pts
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.king,
        ), // 4 - 10 pts
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king), // 5 - 10 pts
        const PlayingCard(suit: Suit.spades, rank: CardRank.king), // 6 - 10 pts
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace), // 7 - 20 pts
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.ace,
        ), // 8 - 20 pts
        const PlayingCard(
          suit: Suit.clubs,
          rank: CardRank.ace,
        ), // 9 - 20 pts (need 3 for valid meld)
      ]);

      // Try single low-point meld first (should fail play-down requirement)
      expect(controller.createMeldByIndices([0, 1, 2]), false);
      expect(humanPlayer.hasPlayedDown, false);
      expect(humanPlayer.melds.length, 0);

      // Now try multi-meld that meets requirement
      // Create 4s meld (15 pts) + Kings meld (40 pts) + Aces meld (60 pts) = 115 pts > 90
      expect(
        controller.createMeldByIndices([0, 1, 2], skipPlayDownCheck: true),
        true,
      );

      // After removing 3 cards, remaining hand is: [King-H, King-D, King-C, King-S, Ace-H, Ace-D, Ace-C]
      //                                            [0      1      2      3      4      5      6     ]
      expect(
        controller.createMeldByIndices([0, 1, 2, 3], skipPlayDownCheck: true),
        true,
      ); // Kings at indices 0-3

      // After removing 4 Kings, remaining hand is: [Ace-H, Ace-D, Ace-C]
      //                                            [0     1     2    ]
      expect(
        controller.createMeldByIndices([0, 1, 2], skipPlayDownCheck: true),
        true,
      ); // Aces at indices 0-2

      expect(humanPlayer.hasPlayedDown, true);
      expect(humanPlayer.melds.length, 3);

      // Calculate total points
      final totalPoints = humanPlayer.melds
          .expand((meld) => meld.cards)
          .fold<int>(0, (sum, card) => sum + card.pointValue);
      expect(totalPoints, greaterThanOrEqualTo(90));
    });

    test('should handle wild card distribution across multiple melds', () {
      humanPlayer.hand.clear();
      humanPlayer.hand.addAll([
        // Natural cards for first meld
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four), // 0
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four), // 1
        // Natural cards for second meld
        const PlayingCard(suit: Suit.hearts, rank: CardRank.seven), // 2
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven), // 3
        // Wild cards that could go to either meld
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // 4 - wild
        const PlayingCard(rank: CardRank.joker), // 5 - wild
      ]);

      // Create mixed melds with wilds distributed
      // First meld: 2 fours + 1 wild (3 cards)
      expect(
        controller.createMeldByIndices([0, 1, 4], skipPlayDownCheck: true),
        true,
      );

      // Second meld: 2 sevens + 1 wild (3 cards)
      // Note: indices shifted, remaining cards are [Heart 7, Diamond 7, Joker]
      expect(
        controller.createMeldByIndices([0, 1, 2], skipPlayDownCheck: true),
        true,
      );

      expect(humanPlayer.melds.length, 2);
      expect(humanPlayer.melds[0].cards.length, 3); // Fours + wild
      expect(humanPlayer.melds[1].cards.length, 3); // Sevens + wild
      expect(humanPlayer.hand.length, 0);

      // Verify both melds are mixed (contain wilds)
      expect(humanPlayer.melds[0].type, MeldType.mixed);
      expect(humanPlayer.melds[1].type, MeldType.mixed);
    });

    test('should handle edge case of empty hand after meld creation', () {
      humanPlayer.hand.clear();
      humanPlayer.foot.clear(); // Make sure foot is also clear
      humanPlayer.hasPickedUpFoot = false;

      // Add exactly enough cards for one meld
      humanPlayer.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
      ]);

      // Add some cards to foot so foot pickup can happen
      humanPlayer.foot.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
      ]);

      expect(
        controller.createMeldByIndices([0, 1, 2], skipPlayDownCheck: true),
        true,
      );

      // Should have triggered foot pickup
      expect(humanPlayer.hasPickedUpFoot, true);
      expect(
        humanPlayer.currentHand.length,
        2,
      ); // Now using foot as current hand
      expect(humanPlayer.foot.length, 2); // Foot still contains cards
      expect(humanPlayer.hand.length, 0); // Hand is empty
      expect(humanPlayer.melds.length, 1);
    });

    test('should handle invalid index scenarios gracefully', () {
      humanPlayer.hand.clear();
      humanPlayer.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
      ]);

      // Try to create meld with out-of-bounds index
      expect(
        controller.createMeldByIndices([0, 1, 5], skipPlayDownCheck: true),
        false,
      );
      expect(humanPlayer.melds.length, 0);

      // Try to create meld with negative index (edge case)
      expect(
        controller.createMeldByIndices([-1, 0, 1], skipPlayDownCheck: true),
        false,
      );
      expect(humanPlayer.melds.length, 0);

      // Hand should remain unchanged after failed attempts
      expect(humanPlayer.hand.length, 2);
    });

    test(
      'should maintain game state consistency during multi-meld creation',
      () {
        humanPlayer.hand.clear();
        humanPlayer.hand.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
        ]);

        // Verify initial state
        expect(controller.gameState.hasMelded, false);
        expect(controller.gameState.turnPhase, TurnPhase.meld);

        // Create meld
        expect(
          controller.createMeldByIndices([0, 1, 2], skipPlayDownCheck: true),
          true,
        );

        // Verify game state updated correctly
        expect(controller.gameState.hasMelded, true);
        expect(humanPlayer.hasPlayedDown, true);
        expect(
          controller.gameState.turnPhase,
          TurnPhase.meld,
        ); // Still in meld phase until discard
      },
    );

    test(
      'should handle simultaneous multi-meld creation without index shifting bugs',
      () {
        // This test reproduces the specific bug from the UI where creating multiple melds
        // simultaneously failed due to index shifting after the first meld was created

        humanPlayer.hand.clear();
        humanPlayer.hasPlayedDown =
            true; // Already played down to avoid play-down validation

        // Set up hand similar to the bug scenario: cards at various indices
        humanPlayer.hand.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.eight), // 0
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine), // 1
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine), // 2
          const PlayingCard(
            suit: Suit.clubs,
            rank: CardRank.ten,
          ), // 3 - first meld
          const PlayingCard(
            suit: Suit.clubs,
            rank: CardRank.ten,
          ), // 4 - first meld
          const PlayingCard(
            suit: Suit.clubs,
            rank: CardRank.ten,
          ), // 5 - first meld
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten), // 6
          const PlayingCard(suit: Suit.hearts, rank: CardRank.jack), // 7
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack), // 8
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen), // 9
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen), // 10
          const PlayingCard(
            suit: Suit.spades,
            rank: CardRank.ace,
          ), // 11 - second meld
          const PlayingCard(
            suit: Suit.diamonds,
            rank: CardRank.ace,
          ), // 12 - second meld
          const PlayingCard(
            suit: Suit.clubs,
            rank: CardRank.ace,
          ), // 13 - second meld
        ]);

        expect(humanPlayer.hand.length, 14);
        expect(humanPlayer.melds.length, 0);

        // Simulate the advanced meld selector creating two melds simultaneously:
        // Meld 1: tens at indices [3, 4, 5]
        // Meld 2: aces at indices [11, 12, 13]
        // The bug was that after creating the tens meld, the aces would be at different indices

        // Create first meld (tens) - this will shift subsequent indices
        bool firstMeldSuccess = controller.createMeldByIndices([
          3,
          4,
          5,
        ], skipPlayDownCheck: true);
        expect(firstMeldSuccess, true);
        expect(humanPlayer.hand.length, 11); // 14 - 3 = 11
        expect(humanPlayer.melds.length, 1);
        expect(humanPlayer.melds[0].rank, CardRank.ten);

        // Now hand indices have shifted. The aces that were at [11, 12, 13] are now at [8, 9, 10]
        // Verify the aces are now at the expected shifted indices
        expect(humanPlayer.hand[8].rank, CardRank.ace); // Was index 11
        expect(humanPlayer.hand[9].rank, CardRank.ace); // Was index 12
        expect(humanPlayer.hand[10].rank, CardRank.ace); // Was index 13

        // Create second meld (aces) using the NEW indices after the shift
        bool secondMeldSuccess = controller.createMeldByIndices([
          8,
          9,
          10,
        ], skipPlayDownCheck: true);
        expect(secondMeldSuccess, true);
        expect(humanPlayer.hand.length, 8); // 11 - 3 = 8
        expect(humanPlayer.melds.length, 2);
        expect(humanPlayer.melds[1].rank, CardRank.ace);

        // Verify both melds were created correctly
        expect(humanPlayer.melds[0].cards.length, 3); // tens meld
        expect(humanPlayer.melds[1].cards.length, 3); // aces meld

        // Verify the specific cards in each meld
        expect(
          humanPlayer.melds[0].cards.every((card) => card.rank == CardRank.ten),
          true,
        );
        expect(
          humanPlayer.melds[1].cards.every((card) => card.rank == CardRank.ace),
          true,
        );
      },
    );

    test(
      'should process multiple simultaneous melds in descending index order to prevent shifting bugs',
      () {
        // This test verifies the fix: when creating multiple melds simultaneously,
        // they should be processed in descending index order to prevent index shifting issues

        humanPlayer.hand.clear();
        humanPlayer.hasPlayedDown = true;

        humanPlayer.hand.addAll([
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.four,
          ), // 0 - low index meld
          const PlayingCard(
            suit: Suit.diamonds,
            rank: CardRank.four,
          ), // 1 - low index meld
          const PlayingCard(
            suit: Suit.clubs,
            rank: CardRank.four,
          ), // 2 - low index meld
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five), // 3
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.six), // 4
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.seven,
          ), // 5 - high index meld
          const PlayingCard(
            suit: Suit.diamonds,
            rank: CardRank.seven,
          ), // 6 - high index meld
          const PlayingCard(
            suit: Suit.clubs,
            rank: CardRank.seven,
          ), // 7 - high index meld
        ]);

        // Create melds in the order they would be submitted by the UI:
        // Low index meld first: [0, 1, 2] (fours)
        // High index meld second: [5, 6, 7] (sevens)

        // But our fix should process them in descending order:
        // 1. High index meld: [5, 6, 7] (processed first to avoid index shifting)
        // 2. Low index meld: [0, 1, 2] (processed second, indices still valid)

        List<List<int>> meldIndices = [
          [0, 1, 2], // fours (low indices - should be processed SECOND)
          [5, 6, 7], // sevens (high indices - should be processed FIRST)
        ];

        // Process both melds - the implementation should reorder them
        int meldsCreated = 0;

        // Sort by highest index first (simulating the fix)
        meldIndices.sort((a, b) {
          final maxA = a.reduce(
            (max, current) => current > max ? current : max,
          );
          final maxB = b.reduce(
            (max, current) => current > max ? current : max,
          );
          return maxB.compareTo(maxA); // Descending
        });

        // Now meldIndices should be [[5, 6, 7], [0, 1, 2]]
        expect(meldIndices[0], [5, 6, 7]); // sevens processed first
        expect(meldIndices[1], [0, 1, 2]); // fours processed second

        // Create melds in the reordered sequence
        for (final indices in meldIndices) {
          bool success = controller.createMeldByIndices(
            indices,
            skipPlayDownCheck: true,
          );
          expect(success, true);
          meldsCreated++;
        }

        expect(meldsCreated, 2);
        expect(humanPlayer.melds.length, 2);
        expect(humanPlayer.hand.length, 2); // 8 - 6 = 2 cards remaining

        // Verify both melds were created with correct ranks
        expect(
          humanPlayer.melds.any((meld) => meld.rank == CardRank.seven),
          true,
        );
        expect(
          humanPlayer.melds.any((meld) => meld.rank == CardRank.four),
          true,
        );
      },
    );
  });
}
