import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/round_score_breakdown.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';

void main() {
  group('RoundScoreBreakdown', () {
    test('should create correct breakdown from player state', () {
      final player = Player(
        id: '1',
        name: 'Test Player',
        type: PlayerType.human,
        score: 0,
      );

      // Add some cards to create a meld with points
      final cards = [
        const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.king, suit: Suit.spades),
        const PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
        const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
        const PlayingCard(
          rank: CardRank.king,
          suit: Suit.hearts,
        ), // Different King
        const PlayingCard(rank: CardRank.two, suit: Suit.hearts), // Wild card
        const PlayingCard(rank: CardRank.two, suit: Suit.spades), // Wild card
      ];

      // Add cards to hand first
      player.hand.addAll(cards);

      // Create a 7-card meld (dirty book with wilds)
      final success = player.createMeld(cards);
      expect(success, isTrue);
      expect(player.melds.length, 1);
      expect(player.melds[0].isBook, isTrue);
      expect(player.melds[0].isDirty, isTrue);

      // Add some penalty cards to hand
      player.hand.addAll([
        const PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.three, suit: Suit.diamonds), // Black 3
      ]);

      // Record round score breakdown
      player.recordRoundScoreBreakdown(round: 1, wentOut: true);

      expect(player.roundScoreHistory.length, 1);
      final breakdown = player.roundScoreHistory[0];

      expect(breakdown.round, 1);
      expect(breakdown.dirtyBooks, 1);
      expect(breakdown.cleanBooks, 0);
      expect(breakdown.dirtyBookPoints, 300);
      expect(breakdown.goingOutBonus, 100);
      // Black 3 = 100, Ace = 20, but penalty points should include both hand and foot
      // Since this player hasn't picked up foot yet, only hand cards count
      final expectedPenalty = player.calculateAllUnplayedCardsValue();
      expect(breakdown.penaltyPoints, expectedPenalty);

      // Card points should be meld value minus book bonuses
      final expectedCardPoints =
          player.calculateMeldValue() - 300; // meld value - dirty book bonus
      expect(breakdown.cardPoints, expectedCardPoints);

      final expectedTotal =
          breakdown.cardPoints +
          breakdown.dirtyBookPoints +
          breakdown.goingOutBonus -
          breakdown.penaltyPoints;
      expect(breakdown.totalRoundScore, expectedTotal);
    });

    test('should serialize and deserialize correctly', () {
      const breakdown = RoundScoreBreakdown(
        round: 2,
        cardPoints: 150,
        cleanBooks: 1,
        dirtyBooks: 1,
        penaltyPoints: 50,
        goingOutBonus: 100,
        totalRoundScore: 800, // 150 + 500 + 300 + 100 - 50
      );

      // Test JSON serialization
      final json = breakdown.toJson();
      final fromJson = RoundScoreBreakdown.fromJson(json);
      expect(fromJson.round, breakdown.round);
      expect(fromJson.cardPoints, breakdown.cardPoints);
      expect(fromJson.cleanBooks, breakdown.cleanBooks);
      expect(fromJson.dirtyBooks, breakdown.dirtyBooks);
      expect(fromJson.penaltyPoints, breakdown.penaltyPoints);
      expect(fromJson.goingOutBonus, breakdown.goingOutBonus);
      expect(fromJson.totalRoundScore, breakdown.totalRoundScore);

      // Test compact JSON serialization
      final compactJson = breakdown.toCompactJson();
      final fromCompactJson = RoundScoreBreakdown.fromCompactJson(compactJson);
      expect(fromCompactJson.round, breakdown.round);
      expect(fromCompactJson.cardPoints, breakdown.cardPoints);
      expect(fromCompactJson.cleanBooks, breakdown.cleanBooks);
      expect(fromCompactJson.dirtyBooks, breakdown.dirtyBooks);
      expect(fromCompactJson.penaltyPoints, breakdown.penaltyPoints);
      expect(fromCompactJson.goingOutBonus, breakdown.goingOutBonus);
      expect(fromCompactJson.totalRoundScore, breakdown.totalRoundScore);
    });

    test('should calculate derived properties correctly', () {
      const breakdown = RoundScoreBreakdown(
        round: 1,
        cardPoints: 100,
        cleanBooks: 2,
        dirtyBooks: 1,
        penaltyPoints: 30,
        goingOutBonus: 100,
        totalRoundScore: 1470, // 100 + 1000 + 300 + 100 - 30
      );

      expect(breakdown.cleanBookPoints, 1000); // 2 * 500
      expect(breakdown.dirtyBookPoints, 300); // 1 * 300
      expect(breakdown.totalBookPoints, 1300); // 1000 + 300
      expect(breakdown.positivePoints, 1500); // 100 + 1300 + 100
    });
  });
}
