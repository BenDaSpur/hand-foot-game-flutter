import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/ai/bot_decision.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('EnhancedBotAI Core Tests', () {
    late EnhancedBotAI botAI;
    late GameController gameController;
    late Player botPlayer;

    setUp(() {
      botAI = EnhancedBotAI(seed: 42); // Deterministic for testing

      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      gameController = GameController(players: players);
      gameController.initializeGame();
      botPlayer = players[1];
    });

    group('Decision Making Flow', () {
      test('should make valid decisions for each turn phase', () {
        // Test draw phase
        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.draw;

        final drawDecision = botAI.makeDecision(botPlayer, gameController);
        expect(drawDecision, isA<BotDecision>());
        expect(drawDecision.action, anyOf(['drawFromDeck', 'drawFromDiscard']));

        // Simulate drawing
        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        final meldDecision = botAI.makeDecision(botPlayer, gameController);
        expect(meldDecision, isA<BotDecision>());
        expect(
          meldDecision.action,
          anyOf([
            'createMeld',
            'createMultipleMelds',
            'addToMeld',
            'discard',
            'endTurn',
            'noMeld', // Bot might decide not to meld
          ]),
        );
      });

      test('should handle discard phase correctly', () {
        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.discard;

        // Give bot some cards to discard
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.six),
        ]);

        final decision = botAI.makeDecision(botPlayer, gameController);
        expect(decision.action, equals('discard'));
        expect(decision.data, isA<PlayingCard>());
      });
    });

    group('Strategic Constants', () {
      test('should have appropriate strategic constants', () {
        expect(
          EnhancedBotAI.maxTurnsBeforeForcePlayDown,
          equals(4),
        ); // EMERGENCY FIX - reduced further to prevent catastrophic accumulation
        expect(
          EnhancedBotAI.strongPlayDownBuffer,
          equals(5),
        ); // Reduced further for more aggressive play-downs
        expect(EnhancedBotAI.wildCardDiscardThreshold, equals(8));
        expect(EnhancedBotAI.emergencyRiskTolerance, equals(1.8));
        expect(EnhancedBotAI.maxEmergencyRiskTolerance, equals(6.0));
        expect(EnhancedBotAI.emergencyHandSizeThreshold, equals(15));
        expect(EnhancedBotAI.criticalHandSizeThreshold, equals(18));
        expect(EnhancedBotAI.playDownEmergencyThreshold, equals(14));
        expect(EnhancedBotAI.minTurnsForEmergency, equals(4));
      });
    });

    group('Edge Cases', () {
      test('should handle empty hand gracefully', () {
        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase =
            TurnPhase.meld; // Use meld phase instead of discard for empty hand
        botPlayer.hand.clear();

        final decision = botAI.makeDecision(botPlayer, gameController);
        expect(decision.action, anyOf(['endTurn', 'noMeld']));
      });

      test('should handle invalid player index', () {
        gameController.gameState.currentPlayerIndex = 999; // Invalid index
        gameController.gameState.turnPhase = TurnPhase.meld;

        final decision = botAI.makeDecision(botPlayer, gameController);
        expect(decision, isA<BotDecision>());
      });
    });

    group('Foot Phase Urgency Logic', () {
      test('should validate foot phase urgency constants', () {
        expect(EnhancedBotAI.footPhaseUrgencyThreshold, equals(5));
        expect(EnhancedBotAI.minimumDiscardPileSize, equals(2));
        expect(EnhancedBotAI.aggressiveDiscardMultiplier, equals(0.8));
        expect(EnhancedBotAI.competitiveDiscardMultiplier, equals(0.6));
        expect(EnhancedBotAI.defensiveDiscardMultiplier, equals(0.7));
      });

      test('should handle foot phase with few cards without crashing', () {
        // Setup bot in foot phase with few cards
        botPlayer.hasPickedUpFoot = true;
        botPlayer.hand.clear();
        // Add exactly the threshold number of cards
        for (int i = 0; i < EnhancedBotAI.footPhaseUrgencyThreshold; i++) {
          botPlayer.addCardToHand(
            PlayingCard(rank: CardRank.values[i % 13], suit: Suit.hearts),
          );
        }

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;

        final decision = botAI.makeDecision(botPlayer, gameController);
        // Should make some decision (not crash with exception)
        expect(decision, isA<BotDecision>());
        // Action should be valid
        expect(
          [
            'createMeld',
            'addToMeld',
            'noMeld',
            'discard',
            'endTurn',
          ].contains(decision.action),
          isTrue,
        );
      });
    });
  });
}
