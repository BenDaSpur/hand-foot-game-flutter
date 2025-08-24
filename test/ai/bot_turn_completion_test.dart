import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Bot Turn Completion Tests', () {
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

    group('Turn Ending Guarantees', () {
      test(
        'should always provide valid turn-ending decision in discard phase',
        () {
          // Give bot cards to discard
          botPlayer.hand.clear();
          botPlayer.dealHand([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
            const PlayingCard(suit: Suit.spades, rank: CardRank.six),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
          ]);

          botPlayer.hasPlayedDown = true;
          gameController.gameState.currentPlayerIndex = 1;
          gameController.gameState.turnPhase = TurnPhase.discard;

          final decision = botAI.makeDecision(botPlayer, gameController);

          expect(decision.action, equals('discard'));
          expect(decision.data, isA<PlayingCard>());

          final discardedCard = decision.data as PlayingCard;
          expect(botPlayer.currentHand, contains(discardedCard));
        },
      );

      test('should handle noMeld in meld phase gracefully', () {
        // Give bot cards that cannot form any meld
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.six),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
        ]);

        botPlayer.hasPlayedDown = true;
        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        final decision = botAI.makeDecision(botPlayer, gameController);

        // Should either create a meld or decide not to meld
        expect(
          decision.action,
          anyOf([
            'createMeld',
            'addToMeld',
            'noMeld',
            'discard', // Some managers might go straight to discard
          ]),
        );
      });

      test('should handle empty hand properly in discard phase', () {
        // Give bot no cards - should go out if possible
        botPlayer.hand.clear();
        botPlayer.foot.clear(); // Also clear foot since bot is on foot
        botPlayer.hasPlayedDown = true;
        botPlayer.hasPickedUpFoot = true;

        // Add required books for going out
        final cleanBook = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ];

        final dirtyBook = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: null, rank: CardRank.joker), // Wild
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // Wild
        ];

        // Add melds directly to avoid validation
        final cleanMeld = Meld.createMeld(cleanBook)!;
        final dirtyMeld = Meld.createMeld(dirtyBook)!;
        botPlayer.melds.add(cleanMeld);
        botPlayer.melds.add(dirtyMeld);

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.discard;

        final decision = botAI.makeDecision(botPlayer, gameController);

        // Should go out since they have required books and no cards
        expect(decision.action, equals('goOut'));
      });

      test('should handle empty hand without books in discard phase', () {
        // Give bot no cards and no books - should error
        botPlayer.hand.clear();
        botPlayer.foot.clear(); // Also clear foot since bot is on foot
        botPlayer.hasPlayedDown = true;
        botPlayer.hasPickedUpFoot = true;

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.discard;

        final decision = botAI.makeDecision(botPlayer, gameController);

        // Should return error since they can't go out without books
        expect(decision.action, equals('error'));
      });

      test('should never return invalid actions', () {
        final validActions = {
          'drawFromDeck',
          'drawFromDiscard',
          'createMeld',
          'addToMeld',
          'discard',
          'goOut',
          'noMeld',
          'endTurn',
          'error',
        };

        // Test various scenarios
        final scenarios = [
          // Draw phase
          () {
            gameController.gameState.turnPhase = TurnPhase.draw;
            gameController.gameState.currentPlayerIndex = 1;
          },
          // Meld phase
          () {
            gameController.gameState.turnPhase = TurnPhase.meld;
            gameController.gameState.currentPlayerIndex = 1;
            gameController.gameState.hasDrawnFromDeck = true;
          },
          // Discard phase
          () {
            gameController.gameState.turnPhase = TurnPhase.discard;
            gameController.gameState.currentPlayerIndex = 1;
          },
        ];

        for (final scenario in scenarios) {
          scenario();
          final decision = botAI.makeDecision(botPlayer, gameController);
          expect(
            validActions,
            contains(decision.action),
            reason:
                'Invalid action: ${decision.action} in phase: ${gameController.gameState.turnPhase}',
          );
        }
      });
    });

    group('Emergency Situations', () {
      test('should handle foot transition emergencies properly', () {
        // Bot with just 1 card, ready for foot transition
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.three,
          ), // -100 penalty
        ]);

        botPlayer.hasPlayedDown = true;
        botPlayer.hasPickedUpFoot = false; // Ready for foot transition

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.discard;

        final decision = botAI.makeDecision(botPlayer, gameController);

        // Should discard the penalty card to transition
        expect(decision.action, equals('discard'));
        expect(decision.data, isA<PlayingCard>());

        final discardedCard = decision.data as PlayingCard;
        expect(discardedCard.rank, equals(CardRank.three));
      });

      test('should handle end game scenarios with few cards', () {
        // Bot on foot with very few cards
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.six),
        ]);

        botPlayer.hasPlayedDown = true;
        botPlayer.hasPickedUpFoot = true; // On foot

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.discard;

        final decision = botAI.makeDecision(botPlayer, gameController);

        // Should make a valid decision (discard, addToMeld, or goOut)
        expect(decision.action, anyOf(['discard', 'addToMeld', 'goOut']));

        if (decision.action == 'discard') {
          expect(decision.data, isA<PlayingCard>());
        }
      });
    });

    group('Personality-Based Turn Completion', () {
      test('should complete turn regardless of personality', () {
        final personalities = [
          BotPersonality.conservative,
          BotPersonality.aggressive,
          BotPersonality.bookBuilder,
          BotPersonality.adaptive,
        ];

        for (final personality in personalities) {
          botAI.assignPersonality('2', personality);

          // Standard scenario
          botPlayer.hand.clear();
          botPlayer.dealHand([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
          ]);

          botPlayer.hasPlayedDown = true;
          gameController.gameState.currentPlayerIndex = 1;
          gameController.gameState.turnPhase = TurnPhase.discard;

          final decision = botAI.makeDecision(botPlayer, gameController);

          expect(
            decision.action,
            equals('discard'),
            reason: 'Personality $personality should discard to end turn',
          );
          expect(decision.data, isA<PlayingCard>());
        }
      });
    });
  });
}
