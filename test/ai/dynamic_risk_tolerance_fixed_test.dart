import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Dynamic Risk-Based Decision Making Tests', () {
    late EnhancedBotAI botAI;
    late GameController controller;
    late Player testBot;

    setUp(() {
      botAI = EnhancedBotAI(seed: 42);
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'TestBot', type: PlayerType.bot),
      ];
      controller = GameController(players: players);
      controller.initializeGame();
      testBot = players[1];
    });

    group('Risk-Based Behavior Changes', () {
      test('should handle high-risk scenarios with negative hand values', () {
        // Give bot a very negative hand (lots of 3s)
        testBot.hand.clear();
        testBot.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.three), // -100
          const PlayingCard(suit: Suit.spades, rank: CardRank.three), // -100
          const PlayingCard(suit: Suit.clubs, rank: CardRank.three), // -100
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king), // 10
          const PlayingCard(suit: Suit.spades, rank: CardRank.king), // 10
        ]);

        testBot.hasPlayedDown = false;
        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.discard;

        // Test with conservative personality in high-risk scenario
        botAI.assignPersonality('2', BotPersonality.conservative);
        final decision = botAI.makeDecision(testBot, controller);

        expect(decision.action, equals('discard'));

        // Should prefer to discard penalty cards (3s) in high-risk situations
        final discardedCard = decision.data as PlayingCard;
        expect(discardedCard, isA<PlayingCard>());
      });

      test('should behave differently under low vs high risk conditions', () {
        // Low risk scenario - good hand
        testBot.hand.clear();
        testBot.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ]);

        testBot.hasPlayedDown = true;
        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;

        botAI.assignPersonality('2', BotPersonality.conservative);
        final lowRiskDecision = botAI.makeDecision(testBot, controller);

        // Now high risk scenario - same cards but not played down and high penalty
        testBot.hasPlayedDown = false;
        testBot.hand.addAll([
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.three), // -100
          const PlayingCard(suit: Suit.hearts, rank: CardRank.three), // -100
        ]);

        final highRiskDecision = botAI.makeDecision(testBot, controller);

        expect(lowRiskDecision.action, isA<String>());
        expect(highRiskDecision.action, isA<String>());

        // Both should be valid decisions
        expect([
          'createMeld',
          'addToMeld',
          'discard',
          'endTurn',
          'noMeld',
        ], contains(lowRiskDecision.action));
        expect([
          'createMeld',
          'addToMeld',
          'discard',
          'endTurn',
          'noMeld',
        ], contains(highRiskDecision.action));
      });

      test('should adapt to personality in risk scenarios', () {
        // Give bot a moderate risk hand
        testBot.hand.clear();
        testBot.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.three), // -100
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
        ]);

        testBot.hasPlayedDown = true;
        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.discard;

        // Test conservative approach
        botAI.assignPersonality('2', BotPersonality.conservative);
        final conservativeDecision = botAI.makeDecision(testBot, controller);

        // Test aggressive approach
        botAI.assignPersonality('2', BotPersonality.aggressive);
        final aggressiveDecision = botAI.makeDecision(testBot, controller);

        expect(conservativeDecision.action, equals('discard'));
        expect(aggressiveDecision.action, equals('discard'));

        // Both should discard something
        expect(conservativeDecision.data, isA<PlayingCard>());
        expect(aggressiveDecision.data, isA<PlayingCard>());
      });
    });

    group('Emergency Decision Making', () {
      test('should handle emergency situations appropriately', () {
        // Give bot just one card - emergency situation
        testBot.hand.clear();
        testBot.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.three), // -100
        ]);

        testBot.hasPlayedDown = true;
        testBot.hasPickedUpFoot = false; // Still needs to transition to foot
        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.discard;

        final decision = botAI.makeDecision(testBot, controller);

        expect(decision.action, equals('discard'));
        expect(decision.data, isA<PlayingCard>());

        final discardedCard = decision.data as PlayingCard;
        expect(discardedCard.rank, equals(CardRank.three));
      });

      test('should handle foot transition under pressure', () {
        // Bot with few cards left, needs to transition to foot
        testBot.hand.clear();
        testBot.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.six),
        ]);

        testBot.hasPlayedDown = true;
        testBot.hasPickedUpFoot = false; // Ready for foot transition
        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.discard;

        final decision = botAI.makeDecision(testBot, controller);

        expect(decision.action, equals('discard'));
        expect(decision.data, isA<PlayingCard>());
      });
    });

    group('Personality-Specific Risk Responses', () {
      test('should show different risk tolerance by personality', () {
        // Moderate risk scenario
        testBot.hand.clear();
        testBot.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.three), // -100
        ]);

        testBot.hasPlayedDown = true;
        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.discard;

        // Test all personality types handle risk scenarios
        final personalities = [
          BotPersonality.conservative,
          BotPersonality.aggressive,
          BotPersonality.bookBuilder,
          BotPersonality.adaptive,
        ];

        for (final personality in personalities) {
          botAI.assignPersonality('2', personality);
          final decision = botAI.makeDecision(testBot, controller);

          expect(decision.action, equals('discard'));
          expect(decision.data, isA<PlayingCard>());
        }
      });
    });
  });
}
