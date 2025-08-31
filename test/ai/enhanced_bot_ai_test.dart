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
          equals(8),
        ); // Updated for enhanced strategic patience
        expect(EnhancedBotAI.strongPlayDownBuffer, equals(15));
        expect(EnhancedBotAI.wildCardDiscardThreshold, equals(6));
        expect(EnhancedBotAI.emergencyRiskTolerance, equals(2.5));
        expect(EnhancedBotAI.maxEmergencyRiskTolerance, equals(6.0));
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
  });
}
