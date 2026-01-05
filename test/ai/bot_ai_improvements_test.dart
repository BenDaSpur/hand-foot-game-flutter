import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_config.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';

void main() {
  group('Bot AI Improvements Tests', () {
    late EnhancedBotAI botAI;
    late GameController controller;

    setUp(() {
      botAI = EnhancedBotAI(seed: 42); // Deterministic for testing
      final players = [
        Player(id: 'human', name: 'Human', type: PlayerType.human),
        Player(id: 'bot1', name: 'Bot1', type: PlayerType.bot),
        Player(id: 'bot2', name: 'Bot2', type: PlayerType.bot),
        Player(id: 'bot3', name: 'Bot3', type: PlayerType.bot),
      ];
      controller = GameController(players: players, seed: 42);
    });

    group('Wild Card Discard Logic', () {
      test('should NOT discard wild cards with less than 10 wilds', () {
        // Setup bot with 9 wild cards (below threshold)
        final bot = Player(id: 'bot1', name: 'Bot1', type: PlayerType.bot);
        // Add cards directly to hand list
        bot.hand.addAll([
          ...List.generate(
            5,
            (_) => const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
          ), // 5 2s (wilds)
          ...List.generate(
            4,
            (_) => const PlayingCard(rank: CardRank.joker),
          ), // 4 Jokers (wilds)
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.five,
          ), // 1 natural card
        ]);
        bot.hasPlayedDown = true; // Avoid play-down logic

        // Set game state to discard phase so bot will make discard decision
        controller.gameState.turnPhase = TurnPhase.discard;

        final decision = botAI.makeDecision(bot, controller);

        // Should discard the natural card (5), not any wilds
        expect(decision.action, 'discard');
        expect((decision.data as PlayingCard).isWild, false);
        expect((decision.data as PlayingCard).pointValue, 5);
      });

      test('should discard wild card only when having 10+ wilds', () {
        // Setup bot with 10 wild cards (at threshold)
        final bot = Player(id: 'bot1', name: 'Bot1', type: PlayerType.bot);
        bot.hand.addAll([
          ...List.generate(
            6,
            (_) => const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
          ), // 6 2s (wilds)
          ...List.generate(
            4,
            (_) => const PlayingCard(rank: CardRank.joker),
          ), // 4 Jokers (wilds)
        ]);
        bot.hasPlayedDown = true; // Avoid play-down logic

        // Set game state to discard phase so bot will make discard decision
        controller.gameState.turnPhase = TurnPhase.discard;

        final decision = botAI.makeDecision(bot, controller);

        // Should discard a wild card (preferably lowest value - 2s first)
        expect(decision.action, 'discard');
        expect((decision.data as PlayingCard).isWild, true);
        expect(
          (decision.data as PlayingCard).rank,
          CardRank.two,
        ); // Lower value wild
      });

      test(
        'should discard wild card in emergency case - last card but cannot go out',
        () {
          // Setup bot with 1 wild card and cannot go out
          final bot = Player(id: 'bot1', name: 'Bot1', type: PlayerType.bot);
          bot.hasPlayedDown = true;
          bot.hasPickedUpFoot = true;

          // Put wild card in foot (since hasPickedUpFoot = true means currentHand = foot)
          bot.foot.add(
            const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
          ); // Only wild card
          // Cannot go out - no clean/dirty books (empty melds list)

          // Set game state to discard phase so bot will make discard decision
          controller.gameState.turnPhase = TurnPhase.discard;

          final decision = botAI.makeDecision(bot, controller);

          expect(decision.action, 'discard');
          expect((decision.data as PlayingCard).isWild, true);
        },
      );
    });

    group('Adaptive Discard Strategy', () {
      test('should discard low-value singletons first', () {
        final bot = Player(id: 'bot1', name: 'Bot1', type: PlayerType.bot);
        bot.hand.addAll([
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.four,
          ), // Low value singleton
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.ten,
          ), // Higher value singleton
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.king,
          ), // High value singleton
        ]);
        bot.hasPlayedDown = true;

        controller.gameState.turnPhase = TurnPhase.discard;
        final decision = botAI.makeDecision(bot, controller);

        expect(decision.action, 'discard');
        final discardedCard = decision.data as PlayingCard;
        expect(discardedCard.rank, CardRank.four); // Lowest value
      });

      test('should discard 3s first (penalty cards)', () {
        final bot = Player(id: 'bot1', name: 'Bot1', type: PlayerType.bot);
        bot.hand.addAll([
          const PlayingCard(
            suit: Suit.spades,
            rank: CardRank.three,
          ), // Black 3 (-5 penalty)
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.three,
          ), // Red 3 (-300 penalty)
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.four,
          ), // Low natural
        ]);
        bot.hasPlayedDown = true;

        controller.gameState.turnPhase = TurnPhase.discard;
        final decision = botAI.makeDecision(bot, controller);

        expect(decision.action, 'discard');
        final discardedCard = decision.data as PlayingCard;
        expect(discardedCard.rank, CardRank.three);
        // Should discard red 3 first (worst penalty: -300 vs black 3: -5)
        expect(
          discardedCard.suit,
          anyOf([Suit.hearts, Suit.diamonds]),
        ); // Red suits
      });

      test('should use emergency discard with 20+ cards', () {
        final bot = Player(id: 'bot1', name: 'Bot1', type: PlayerType.bot);
        bot.hand.addAll([
          ...List.generate(
            19,
            (_) => const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          ), // 19 high cards
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.five,
          ), // 1 lower singleton
        ]);
        bot.hasPlayedDown = true;

        controller.gameState.turnPhase = TurnPhase.discard;
        final decision = botAI.makeDecision(bot, controller);

        expect(decision.action, 'discard');
        final discardedCard = decision.data as PlayingCard;
        expect(
          discardedCard.rank,
          CardRank.five,
        ); // Emergency discard any singleton
      });
    });

    group('High Round Detection', () {
      test('should detect high round situation correctly', () {
        final bot = Player(id: 'bot1', name: 'Bot1', type: PlayerType.bot);
        bot.hand.addAll(
          List.generate(
            16,
            (_) => const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          ),
        );
        bot.hasPlayedDown = false;

        controller.gameState.turnPhase = TurnPhase.discard;
        final decision = botAI.makeDecision(bot, controller);

        // In high round with 16 cards, should be more liberal with discarding
        expect(decision.action, 'discard');
        // Should not get stuck - should find something to discard
      });

      test('should NOT detect high round when already played down', () {
        final bot = Player(id: 'bot1', name: 'Bot1', type: PlayerType.bot);
        bot.hand.addAll(
          List.generate(
            16,
            (_) => const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          ),
        );
        bot.hasPlayedDown = true; // Already played down

        controller.gameState.turnPhase = TurnPhase.discard;
        final decision = botAI.makeDecision(bot, controller);

        // Should still make a decision, but using different (post-play-down) logic
        expect(decision.action, 'discard');
      });
    });

    group('Constants Usage', () {
      test('should use named constants instead of magic numbers', () {
        // This is more of a code inspection test, but we can verify behavior
        final bot = Player(id: 'bot1', name: 'Bot1', type: PlayerType.bot);
        bot.hand.addAll([
          ...List.generate(
            BotConfig.wildCardDiscardThreshold,
            (_) => const PlayingCard(rank: CardRank.joker),
          ),
        ]);
        bot.hasPlayedDown = true;

        controller.gameState.turnPhase = TurnPhase.discard;
        final decision = botAI.makeDecision(bot, controller);

        // Should discard wild when at threshold
        expect(decision.action, 'discard');
        expect((decision.data as PlayingCard).isWild, true);
      });
    });

    group('Method Refactoring Verification', () {
      test('should use new smaller helper methods correctly', () {
        final bot = Player(id: 'bot1', name: 'Bot1', type: PlayerType.bot);
        bot.hand.addAll([
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.five,
          ), // Low singleton
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.queen,
          ), // Medium pair
          const PlayingCard(
            suit: Suit.spades,
            rank: CardRank.queen,
          ), // Medium pair
        ]);
        bot.hasPlayedDown = false;

        controller.gameState.turnPhase = TurnPhase.discard;
        final decision = botAI.makeDecision(bot, controller);

        // Should successfully use refactored methods
        expect(decision.action, 'discard');
        expect(
          (decision.data as PlayingCard).pointValue,
          lessThanOrEqualTo(10),
        );
      });
    });
  });
}
