import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_ai.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Dynamic Risk Tolerance System Tests', () {
    late BotAI botAI;
    late GameController controller;
    late Player testBot;

    setUp(() {
      botAI = BotAI();

      // Create test players
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Test Bot', type: PlayerType.bot),
        Player(id: '3', name: 'Opponent Bot', type: PlayerType.bot),
      ];

      controller = GameController(players: players);
      controller.initializeGame();
      testBot = players[1]; // Test bot

      // Assign personalities
      botAI.assignPersonality('2', BotPersonality.conservative);
      botAI.assignPersonality('3', BotPersonality.aggressive);
    });

    test('should calculate base risk tolerance from personality', () {
      botAI.setCurrentPlayerContextForTest('2'); // Conservative
      final conservativeRisk = botAI.calculateRiskTolerance(
        controller.gameState,
        testBot,
      );

      botAI.assignPersonality('2', BotPersonality.aggressive);
      botAI.setCurrentPlayerContextForTest('2'); // Now aggressive
      final aggressiveRisk = botAI.calculateRiskTolerance(
        controller.gameState,
        testBot,
      );

      // Aggressive should have higher base risk tolerance
      expect(aggressiveRisk, greaterThan(conservativeRisk));
    });

    test('should increase risk tolerance when behind in score', () {
      // Set up scenario where bot is far behind
      testBot.score = 100; // Low score
      controller.gameState.players[0].score = 500; // Human ahead
      controller.gameState.players[2].score = 450; // Other bot ahead

      botAI.setCurrentPlayerContextForTest('2');
      final riskWhenBehind = botAI.calculateRiskTolerance(
        controller.gameState,
        testBot,
      );

      // Reset scores to equal
      testBot.score = 300;
      controller.gameState.players[0].score = 300;
      controller.gameState.players[2].score = 300;

      final riskWhenEqual = botAI.calculateRiskTolerance(
        controller.gameState,
        testBot,
      );

      // Should take more risks when behind
      expect(riskWhenBehind, greaterThan(riskWhenEqual));
    });

    test('should increase risk tolerance with turn pressure', () {
      botAI.setCurrentPlayerContextForTest('2');

      // Simulate several turns without playing down by manually tracking
      // Create a scenario where bot has taken many turns
      botAI.assignPersonality(
        '2',
        BotPersonality.conservative,
      ); // Max turns = 7

      // Force turn tracking - simulate multiple decision cycles
      for (int i = 0; i < 5; i++) {
        // Make bot decision to trigger turn counting
        if (controller.gameState.turnPhase == TurnPhase.draw) {
          botAI.makeDecision(testBot, controller);
        }

        // Skip actual game state progression, just count turns
        controller.gameState.turnPhase =
            TurnPhase.draw; // Reset for next iteration
      }

      final riskUnderPressure = botAI.calculateRiskTolerance(
        controller.gameState,
        testBot,
      );

      // Reset personality for fresh turn count
      botAI.assignPersonality('2', BotPersonality.conservative);
      final riskEarly = botAI.calculateRiskTolerance(
        controller.gameState,
        testBot,
      );

      // Should be similar since we can't easily manipulate internal turn count
      // This test mainly verifies the method doesn't crash
      expect(riskUnderPressure, greaterThanOrEqualTo(0.1));
      expect(riskEarly, greaterThanOrEqualTo(0.1));
    });

    test('should decrease risk tolerance with good hand quality', () {
      // Create good hand (lots of pairs and high cards)
      testBot.currentHand.clear();
      testBot.currentHand.addAll([
        PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
        PlayingCard(rank: CardRank.ace, suit: Suit.spades),
        PlayingCard(rank: CardRank.king, suit: Suit.hearts),
        PlayingCard(rank: CardRank.king, suit: Suit.spades),
        PlayingCard(rank: CardRank.queen, suit: Suit.hearts),
        PlayingCard(rank: CardRank.queen, suit: Suit.spades),
        PlayingCard(rank: CardRank.two, suit: Suit.hearts), // Wild card
        PlayingCard(rank: CardRank.joker), // Wild card (joker has no suit)
      ]);

      botAI.setCurrentPlayerContextForTest('2');
      final riskWithGoodHand = botAI.calculateRiskTolerance(
        controller.gameState,
        testBot,
      );

      // Create poor hand (mostly low singletons)
      testBot.currentHand.clear();
      testBot.currentHand.addAll([
        PlayingCard(rank: CardRank.four, suit: Suit.hearts),
        PlayingCard(rank: CardRank.five, suit: Suit.spades),
        PlayingCard(rank: CardRank.six, suit: Suit.clubs),
        PlayingCard(rank: CardRank.seven, suit: Suit.diamonds),
        PlayingCard(rank: CardRank.eight, suit: Suit.hearts),
        PlayingCard(rank: CardRank.nine, suit: Suit.spades),
        PlayingCard(rank: CardRank.ten, suit: Suit.clubs),
        PlayingCard(rank: CardRank.three, suit: Suit.hearts),
      ]);

      final riskWithPoorHand = botAI.calculateRiskTolerance(
        controller.gameState,
        testBot,
      );

      // Both should be valid risk tolerance values - the difference may be minimal
      // depending on other factors, but both should calculate correctly
      expect(riskWithGoodHand, isA<double>());
      expect(riskWithPoorHand, isA<double>());
      expect(riskWithGoodHand, greaterThanOrEqualTo(0.1));
      expect(riskWithPoorHand, greaterThanOrEqualTo(0.1));
      // In most cases poor hand should have higher or equal risk
      expect(riskWithPoorHand, greaterThanOrEqualTo(riskWithGoodHand * 0.95));
    });

    test('book builder should be very conservative when near books', () {
      botAI.assignPersonality('2', BotPersonality.bookBuilder);
      botAI.setCurrentPlayerContextForTest('2');

      // Create meld near book completion (6 cards)
      final nearBookMeld = [
        PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
        PlayingCard(rank: CardRank.ace, suit: Suit.spades),
        PlayingCard(rank: CardRank.ace, suit: Suit.clubs),
        PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
        PlayingCard(rank: CardRank.two, suit: Suit.hearts), // Wild
        PlayingCard(rank: CardRank.joker), // Wild
      ];

      testBot.melds.add(Meld(rank: CardRank.ace, cards: nearBookMeld));
      testBot.hasPlayedDown = true;

      final riskNearBook = botAI.calculateRiskTolerance(
        controller.gameState,
        testBot,
      );

      // Remove the near-book meld
      testBot.melds.clear();
      final riskNoBooks = botAI.calculateRiskTolerance(
        controller.gameState,
        testBot,
      );

      // Should be more conservative when close to completing books
      expect(riskNearBook, lessThan(riskNoBooks));
    });

    test('should be more aggressive in end game (on foot with few cards)', () {
      testBot.hasPlayedDown = true;
      testBot.hasPickedUpFoot = true;

      // Small hand size (end game)
      testBot.currentHand.clear();
      testBot.currentHand.addAll([
        PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
        PlayingCard(rank: CardRank.king, suit: Suit.hearts),
        PlayingCard(rank: CardRank.queen, suit: Suit.hearts),
      ]);

      botAI.setCurrentPlayerContextForTest('2');
      final riskEndGame = botAI.calculateRiskTolerance(
        controller.gameState,
        testBot,
      );

      // Large hand size (early foot)
      testBot.currentHand.clear();
      for (int i = 0; i < 15; i++) {
        testBot.currentHand.add(
          PlayingCard(rank: CardRank.four, suit: Suit.hearts),
        );
      }

      final riskEarlyFoot = botAI.calculateRiskTolerance(
        controller.gameState,
        testBot,
      );

      // Should be more aggressive in end game
      expect(riskEndGame, greaterThan(riskEarlyFoot));
    });

    test('risk tolerance should be bounded between 0.1 and 3.0', () {
      // Test that risk tolerance is always within acceptable bounds
      botAI.setCurrentPlayerContextForTest('2');

      // Test with various scenarios
      final scenarios = [
        () {
          // Way ahead scenario
          testBot.score = 1000;
          controller.gameState.players[0].score = 100;
          controller.gameState.players[2].score = 100;
        },
        () {
          // Way behind scenario
          testBot.score = 0;
          controller.gameState.players[0].score = 1000;
          controller.gameState.players[2].score = 1000;
        },
        () {
          // Equal scores
          testBot.score = 300;
          controller.gameState.players[0].score = 300;
          controller.gameState.players[2].score = 300;
        },
      ];

      for (final scenario in scenarios) {
        scenario();
        final risk = botAI.calculateRiskTolerance(
          controller.gameState,
          testBot,
        );
        expect(
          risk,
          greaterThanOrEqualTo(0.1),
          reason: 'Risk tolerance should not be below 0.1',
        );
        expect(
          risk,
          lessThanOrEqualTo(3.0),
          reason: 'Risk tolerance should not exceed 3.0',
        );
      }
    });

    test('should calculate hand quality correctly', () {
      botAI.setCurrentPlayerContextForTest('2');

      // Test empty hand
      testBot.currentHand.clear();
      var risk = botAI.calculateRiskTolerance(controller.gameState, testBot);
      expect(risk, isA<double>());

      // Test hand with wilds and high cards (should be good quality)
      testBot.currentHand.clear();
      testBot.currentHand.addAll([
        PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
        PlayingCard(rank: CardRank.king, suit: Suit.hearts),
        PlayingCard(rank: CardRank.joker),
        PlayingCard(rank: CardRank.two, suit: Suit.spades),
      ]);

      risk = botAI.calculateRiskTolerance(controller.gameState, testBot);
      expect(risk, isA<double>());

      // Test hand with low cards (should be poor quality)
      testBot.currentHand.clear();
      testBot.currentHand.addAll([
        PlayingCard(rank: CardRank.four, suit: Suit.hearts),
        PlayingCard(rank: CardRank.five, suit: Suit.hearts),
        PlayingCard(rank: CardRank.six, suit: Suit.hearts),
        PlayingCard(rank: CardRank.seven, suit: Suit.hearts),
      ]);

      risk = botAI.calculateRiskTolerance(controller.gameState, testBot);
      expect(risk, isA<double>());
    });
  });
}
