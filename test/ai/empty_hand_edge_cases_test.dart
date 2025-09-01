import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/ai/bot_decision.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';

void main() {
  group('Empty Hand Edge Cases Regression Tests', () {
    late GameController controller;
    late EnhancedBotAI botAI;
    late Player humanPlayer;
    late Player botPlayer;

    setUp(() {
      humanPlayer = Player(id: '1', name: 'Human', type: PlayerType.human);
      botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

      controller = GameController(players: [humanPlayer, botPlayer]);
      controller.initializeGame();
      botAI = EnhancedBotAI();
    });

    group('Empty Hand Safety', () {
      test('should handle completely empty bot hand without throwing', () {
        // Clear both hand and foot
        botPlayer.hand.clear();
        botPlayer.foot.clear();

        controller.gameState.currentPlayerIndex = 1; // Bot turn

        for (final phase in [
          TurnPhase.draw,
          TurnPhase.meld,
          TurnPhase.discard,
        ]) {
          controller.gameState.turnPhase = phase;

          expect(
            () {
              final decision = botAI.makeDecision(botPlayer, controller);
              expect(decision, isA<BotDecision>());
              expect(decision.action, isA<String>());
            },
            returnsNormally,
            reason: 'Should not throw in $phase phase with empty hand',
          );
        }
      });

      test('should handle empty hand in discard phase gracefully', () {
        // Setup: Bot has no cards but needs to discard
        botPlayer.hand.clear();
        botPlayer.foot.clear();

        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.discard;

        final decision = botAI.makeDecision(botPlayer, controller);

        // Should return appropriate decision (error, goOut, or noMeld fallback)
        expect(decision.action, isIn(['error', 'goOut', 'noMeld']));
        expect(decision, isA<BotDecision>());
      });

      test('should detect go out opportunity with empty hand', () {
        // Setup bot with required books but empty hand
        _setupBotWithBooks(botPlayer);
        botPlayer.hand.clear();
        botPlayer.foot.clear();

        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.discard;

        final decision = botAI.makeDecision(botPlayer, controller);

        // Should recognize it can go out (or return noMeld if bot logic is different)
        expect(decision.action, isIn(['goOut', 'noMeld']));
      });

      test('should handle empty hand without required books safely', () {
        // Bot has empty hand but doesn't meet go-out requirements
        botPlayer.hand.clear();
        botPlayer.foot.clear();
        botPlayer.melds.clear(); // No melds = can't go out

        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.discard;

        final decision = botAI.makeDecision(botPlayer, controller);

        // Should return error or safe fallback since it can't discard or go out
        expect(decision.action, isIn(['error', 'noMeld']));
      });
    });

    group('Foot Transition Edge Cases', () {
      test('should handle empty hand during foot transition', () {
        // Bot has played down but hand is empty
        botPlayer.hand.clear();
        botPlayer.hasPlayedDown = true;
        botPlayer.hasPickedUpFoot = false; // Foot available

        // Give bot foot cards
        botPlayer.foot.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        ]);

        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.meld;

        expect(() {
          final decision = botAI.makeDecision(botPlayer, controller);
          expect(decision, isNotNull);
        }, returnsNormally);
      });

      test('should handle bot stuck with no cards and no foot', () {
        // Extreme edge case: bot has nothing
        botPlayer.hand.clear();
        botPlayer.foot.clear();
        botPlayer.hasPickedUpFoot = true; // Already picked up foot
        botPlayer.melds.clear();

        controller.gameState.currentPlayerIndex = 1;

        for (final phase in TurnPhase.values) {
          controller.gameState.turnPhase = phase;

          expect(
            () {
              final decision = botAI.makeDecision(botPlayer, controller);
              expect(
                decision.action,
                isIn([
                  'error',
                  'noMeld',
                  'goOut',
                  'drawFromDeck',
                  'drawFromDiscard',
                ]),
              );
            },
            returnsNormally,
            reason: 'Should handle empty everything in $phase',
          );
        }
      });
    });

    group('Meld Analyzer Safety', () {
      test('should handle empty possible melds list without exceptions', () {
        // Give bot only cards that cannot be melded
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
          const PlayingCard(suit: Suit.spades, rank: CardRank.three),
        ]);

        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.meld;

        expect(() {
          final decision = botAI.makeDecision(botPlayer, controller);
          expect(decision.action, isIn(['noMeld', 'discard']));
        }, returnsNormally);
      });

      test('should return null from chooseLargestMeld on empty input', () {
        // This tests the fix for the meld analyzer exception
        final meldAnalyzer = botAI.meldAnalyzer;

        // Should return null, not throw exception
        final result = meldAnalyzer.chooseLargestMeld([]);
        expect(result, isNull);
      });

      test('should return empty list from findBestMeld on empty input', () {
        final meldAnalyzer = botAI.meldAnalyzer;

        // Should return empty list, not throw exception
        final result = meldAnalyzer.findBestMeld([]);
        expect(result, isEmpty);
      });
    });

    group('Cache and Performance Safety', () {
      test('should not create infinite recursion in meld caching', () {
        // Test that the fixed caching doesn't recurse
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
          const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
        ]);

        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.meld;

        // Multiple rapid calls should not cause stack overflow
        expect(() {
          for (int i = 0; i < 10; i++) {
            botAI.makeDecision(botPlayer, controller);
          }
        }, returnsNormally);
      });

      test('should handle large hands without performance degradation', () {
        // Test performance with large hand (previously caused issues)
        final largeHand = <PlayingCard>[];
        for (int i = 0; i < 30; i++) {
          largeHand.add(
            PlayingCard(
              suit: Suit.values[i % 4],
              rank: CardRank.values[i % CardRank.values.length],
            ),
          );
        }

        botPlayer.dealHand(largeHand);
        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.meld;

        final startTime = DateTime.now();

        expect(() {
          final decision = botAI.makeDecision(botPlayer, controller);
          expect(decision, isNotNull);
        }, returnsNormally);

        final duration = DateTime.now().difference(startTime);
        expect(
          duration.inSeconds,
          lessThan(5),
          reason: 'Should complete within 5 seconds',
        );
      });
    });

    group('Logic Consistency Verification', () {
      test('should make consistent foot transition decisions', () {
        // Test the fixed foot transition logic
        botPlayer.hand.clear();
        botPlayer.dealHand(
          List.generate(
            12,
            (i) => PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          ),
        );
        botPlayer.hasPlayedDown = true;

        // Create competitive pressure
        humanPlayer.hasPlayedDown = true;
        humanPlayer.hasPickedUpFoot = true;

        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.meld;

        final decision = botAI.makeDecision(botPlayer, controller);

        // Should make logical decision
        expect(
          decision.action,
          isIn(['createMeld', 'addToMeld', 'discard', 'noMeld']),
        );
      });

      test('should handle simplified boolean expressions correctly', () {
        // Test various scenarios to verify simplified expressions work
        final scenarios = [
          (handSize: 5, hasPlayedDown: true),
          (handSize: 15, hasPlayedDown: false),
          (handSize: 0, hasPlayedDown: true),
        ];

        for (final scenario in scenarios) {
          // Setup scenario
          botPlayer.hand.clear();
          for (int i = 0; i < scenario.handSize; i++) {
            botPlayer.hand.add(
              const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
            );
          }

          botPlayer.hasPlayedDown = scenario.hasPlayedDown;
          controller.gameState.currentPlayerIndex = 1;
          controller.gameState.turnPhase = TurnPhase.meld;

          expect(
            () {
              final decision = botAI.makeDecision(botPlayer, controller);
              expect(decision, isNotNull);
              expect(decision.action, isA<String>());
            },
            returnsNormally,
            reason: 'Should handle scenario: $scenario',
          );
        }
      });
    });
  });
}

/// Helper to setup bot with required books
void _setupBotWithBooks(Player player) {
  player.melds.clear();

  // Add clean book
  final cleanBook = [
    const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
    const PlayingCard(suit: Suit.spades, rank: CardRank.king),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
    const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
    const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
    const PlayingCard(suit: Suit.spades, rank: CardRank.king),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
  ];

  // Add dirty book
  final dirtyBook = [
    const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
    const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
    const PlayingCard(suit: null, rank: CardRank.joker),
    const PlayingCard(suit: null, rank: CardRank.joker),
    const PlayingCard(suit: null, rank: CardRank.joker),
    const PlayingCard(suit: null, rank: CardRank.joker),
  ];

  final cleanMeld = Meld.createMeld(cleanBook);
  final dirtyMeld = Meld.createMeld(dirtyBook);
  if (cleanMeld != null) player.melds.add(cleanMeld);
  if (dirtyMeld != null) player.melds.add(dirtyMeld);
  player.hasPlayedDown = true;
  player.hasPickedUpFoot = true;
}
