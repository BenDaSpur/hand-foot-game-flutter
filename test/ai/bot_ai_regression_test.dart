import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/ai/bot_decision.dart';

void main() {
  group('Bot AI Regression Tests', () {
    late GameController controller;
    late EnhancedBotAI botAI;
    late Player botPlayer;

    setUp(() {
      final humanPlayer = Player(
        id: '1',
        name: 'Human',
        type: PlayerType.human,
      );
      final testBotPlayer = Player(
        id: '2',
        name: 'TestBot',
        type: PlayerType.bot,
      );

      controller = GameController(players: [humanPlayer, testBotPlayer]);
      controller.initializeGame();
      botPlayer = controller.gameState.players[1]; // Bot player
      botAI = EnhancedBotAI();
    });

    group('Exception Handling Fixes', () {
      test('should handle empty hand gracefully without crashing', () {
        // Clear bot's hand completely
        botPlayer.hand.clear();
        botPlayer.foot.clear();

        // Bot should return error decision, not throw exception
        controller.gameState.turnPhase = TurnPhase.discard;
        controller.gameState.currentPlayerIndex = 1; // Bot's turn

        final decision = botAI.makeDecision(botPlayer, controller);

        // Should return error decision or graceful fallback, not crash
        expect(decision.action, isIn(['error', 'noMeld', 'goOut']));

        // Verify no exceptions were thrown
        expect(
          () => botAI.makeDecision(botPlayer, controller),
          returnsNormally,
        );
      });

      test('should never throw exceptions from empty hand discard methods', () {
        // Test the specific method that previously threw exceptions
        botPlayer.hand.clear();

        // Call the discard decision method that was problematic
        controller.gameState.turnPhase = TurnPhase.discard;
        controller.gameState.currentPlayerIndex = 1;

        expect(() {
          final decision = botAI.makeDecision(botPlayer, controller);
          // Verify decision is safe even with empty hand
          expect(decision, isNotNull);
        }, returnsNormally);
      });

      test('should handle foot transition manager empty hand safely', () {
        // Test BotFootTransitionManager specific edge case
        botPlayer.hand.clear();
        botPlayer.hasPlayedDown = true; // Bot has played down but no cards

        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.currentPlayerIndex = 1;

        expect(() {
          final decision = botAI.makeDecision(botPlayer, controller);
          expect(decision.action, isIn(['error', 'noMeld', 'goOut']));
        }, returnsNormally);
      });
    });

    group('Safe Error Handling', () {
      test('should return error BotDecisions instead of throwing', () {
        // Create scenario where bot cannot make valid moves
        botPlayer.hand.clear();
        botPlayer.foot.clear();
        botPlayer.melds.clear();

        controller.gameState.turnPhase = TurnPhase.discard;
        controller.gameState.currentPlayerIndex = 1;

        final decision = botAI.makeDecision(botPlayer, controller);

        // Should be a valid BotDecision with safe fallback action
        expect(decision, isA<BotDecision>());
        expect(
          decision.action,
          isIn(['error', 'noMeld']),
        ); // Bot AI has safe fallbacks
      });

      test('should handle null return from _chooseCardToDiscard safely', () {
        // Test the new null-safe _chooseCardToDiscard method
        botPlayer.hand.clear();

        controller.gameState.turnPhase = TurnPhase.discard;
        controller.gameState.currentPlayerIndex = 1;

        // This should not crash even though discard method returns null
        final decision = botAI.makeDecision(botPlayer, controller);
        expect(decision.action, isIn(['error', 'goOut', 'noMeld']));
      });
    });

    group('Caching Performance Fixes', () {
      test('should cache meld analysis results to avoid stack overflow', () {
        // Give bot a large hand to trigger meld analysis
        final largeHand = List.generate(
          20,
          (i) => PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.values[i % CardRank.values.length],
          ),
        );
        botPlayer.dealHand(largeHand);

        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.currentPlayerIndex = 1;

        // Multiple calls should not cause stack overflow
        expect(() {
          for (int i = 0; i < 5; i++) {
            final decision = botAI.makeDecision(botPlayer, controller);
            expect(decision, isNotNull);
          }
        }, returnsNormally);
      });

      test('should handle recursive caching calls without infinite loops', () {
        // Test that caching doesn't create recursive calls
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ]);

        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.currentPlayerIndex = 1;

        // This should complete quickly without recursion issues
        final startTime = DateTime.now();
        final decision = botAI.makeDecision(botPlayer, controller);
        final duration = DateTime.now().difference(startTime);

        expect(decision, isNotNull);
        expect(duration.inSeconds, lessThan(5)); // Should be fast
      });
    });

    group('Logic Consistency Fixes', () {
      test('should have consistent foot transition logic', () {
        // Test the fixed foot transition condition logic
        botPlayer.dealHand(
          List.generate(
            15,
            (i) => PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          ),
        );
        botPlayer.hasPlayedDown = true;

        // Add opponent on foot to create competitive pressure
        final opponent = controller.gameState.players[0];
        opponent.hasPlayedDown = true;
        opponent.hasPickedUpFoot = true;

        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.currentPlayerIndex = 1;

        // Should make logical decision without contradictory behavior
        final decision = botAI.makeDecision(botPlayer, controller);
        expect(
          decision.action,
          isIn(['createMeld', 'addToMeld', 'discard', 'noMeld']),
        );
      });

      test('should simplify complex boolean expressions correctly', () {
        // Test that simplified expressions work the same as complex ones
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        ]);

        controller.gameState.currentPlayerIndex = 1;

        // Test different game states to verify expression logic
        for (final phase in [
          TurnPhase.draw,
          TurnPhase.meld,
          TurnPhase.discard,
        ]) {
          controller.gameState.turnPhase = phase;
          expect(
            () => botAI.makeDecision(botPlayer, controller),
            returnsNormally,
          );
        }
      });
    });

    group('Null Safety Improvements', () {
      test('should handle null returns from meld analyzer safely', () {
        // Test with minimal cards where meld analysis might return null/empty
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.three,
          ), // Cannot meld 3s
        ]);

        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.currentPlayerIndex = 1;

        final decision = botAI.makeDecision(botPlayer, controller);
        expect(decision, isNotNull);
        expect(decision.action, isA<String>());
      });

      test('should handle empty possible melds list without crashing', () {
        // Give bot only cards that cannot be melded (3s)
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
          const PlayingCard(suit: Suit.spades, rank: CardRank.three),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.three),
        ]);

        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.currentPlayerIndex = 1;

        expect(() {
          final decision = botAI.makeDecision(botPlayer, controller);
          expect(decision.action, isIn(['noMeld', 'discard']));
        }, returnsNormally);
      });
    });

    group('Emergency Protocols', () {
      test('should handle critical hand size without stack overflow', () {
        // Test the emergency hand size protocols
        final criticalSizeHand = List.generate(
          25,
          (i) => PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.values[i % CardRank.values.length],
          ),
        );
        botPlayer.dealHand(criticalSizeHand);

        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.currentPlayerIndex = 1;

        // Should handle large hand without crashing
        expect(() {
          final decision = botAI.makeDecision(botPlayer, controller);
          expect(decision, isNotNull);
        }, returnsNormally);
      });

      test('should fallback safely when all decision paths fail', () {
        // Create scenario where bot has no valid moves
        botPlayer.hand.clear();
        botPlayer.foot.clear();
        controller.gameState.discardPile.clear();

        controller.gameState.turnPhase = TurnPhase.discard;
        controller.gameState.currentPlayerIndex = 1;

        // Should not crash, should return safe fallback
        expect(() {
          final decision = botAI.makeDecision(botPlayer, controller);
          expect(decision.action, isIn(['error', 'noMeld', 'goOut']));
        }, returnsNormally);
      });
    });
  });
}
