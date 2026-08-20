@Tags(['unlock_churn'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_config.dart';
import 'package:hand_foot_game_flutter/ai/bot_meld_analyzer.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Unlock-churn AI (2026.08-unlock-churn)', () {
    late EnhancedBotAI botAI;
    late GameController controller;
    late Player human;
    late Player bot;

    setUp(() {
      botAI = EnhancedBotAI(seed: 202608);
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bot = Player(id: 'bot', name: 'Adaptive', type: PlayerType.bot);
      controller = GameController(players: [human, bot], seed: 202608);
      controller.initializeGame();
      botAI.assignPersonality(bot.id, BotPersonality.adaptive);
      controller.gameState.currentPlayerIndex = 1;
    });

    test('botAiVersion is competitive-planner', () {
      expect(BotConfig.botAiVersion, '2026.08-competitive-planner');
      expect(BotConfig.postPlayDownHardTakePileSize, 6);
      expect(BotConfig.preserveUnlockKeysMeldPileSize, 5);
    });

    test('hard-takes unlockable pile at size 6 after play-down', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
        ]);

      controller.gameState.discardPile
        ..clear()
        ..addAll(
          List.generate(
            BotConfig.postPlayDownHardTakePileSize - 1,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ace),
          ),
        )
        ..add(const PlayingCard(suit: Suit.clubs, rank: CardRank.king));

      controller.gameState.turnPhase = TurnPhase.draw;
      controller.gameState.hasDrawnFromDeck = false;
      controller.gameState.discardPileFrozen = false;

      expect(controller.gameState.canUnlockDiscard(), isTrue);
      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, 'drawFromDiscard');
    });

    test('hard-takes when holding unlock keys at pile size 5', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
        ]);

      controller.gameState.discardPile
        ..clear()
        ..addAll(
          List.generate(
            BotConfig.preserveUnlockKeysMeldPileSize - 1,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ten),
          ),
        )
        ..add(const PlayingCard(suit: Suit.clubs, rank: CardRank.king));

      expect(
        controller.gameState.discardPile.length,
        BotConfig.preserveUnlockKeysMeldPileSize,
      );

      controller.gameState.turnPhase = TurnPhase.draw;
      controller.gameState.hasDrawnFromDeck = false;
      controller.gameState.discardPileFrozen = false;

      expect(controller.gameState.canUnlockDiscard(), isTrue);
      final decision = botAI.makeDecision(bot, controller);
      expect(
        decision.action,
        'drawFromDiscard',
        reason: 'keys + pile ≥5 must hard-take when eligible',
      );
    });

    test('aggressive hard-takes mid-size unlockable pile', () {
      botAI.assignPersonality(bot.id, BotPersonality.aggressive);
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
        ]);

      controller.gameState.discardPile
        ..clear()
        ..addAll(
          List.generate(
            5,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ten),
          ),
        )
        ..add(const PlayingCard(suit: Suit.clubs, rank: CardRank.queen));

      controller.gameState.turnPhase = TurnPhase.draw;
      controller.gameState.hasDrawnFromDeck = false;
      controller.gameState.discardPileFrozen = false;

      expect(controller.gameState.canUnlockDiscard(), isTrue);
      final decision = botAI.makeDecision(bot, controller);
      expect(
        decision.action,
        'drawFromDiscard',
        reason: 'aggressive must contest mid piles (analytics: 0 unlocks)',
      );
    });

    test(
      'same-turn play-down when contestable pile has keys and full points',
      () {
        bot.hasPlayedDown = false;
        bot.hasPickedUpFoot = false;
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
            const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          ]);

        controller.gameState.round = 1;
        // Contestable mid-pile (5) with unlock keys — below old pile-farm 12.
        controller.gameState.discardPile
          ..clear()
          ..addAll(
            List.generate(
              BotConfig.preserveUnlockKeysMeldPileSize - 1,
              (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ten),
            ),
          )
          ..add(const PlayingCard(suit: Suit.clubs, rank: CardRank.king));

        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;

        final decision = botAI.makeDecision(bot, controller);
        expect(
          decision.action,
          anyOf('createMeld', 'createMultipleMelds'),
          reason:
              'keys + pile ≥5 + full points must skip patience for play-down',
        );
        // Contestable pressure also prefers key-preserving play-down combos.
        final played = decision.action == 'createMultipleMelds'
            ? (decision.data as List<List<PlayingCard>>).expand((m) => m)
            : (decision.data as List<PlayingCard>);
        final kingsUsed = played
            .where((c) => !c.isWild && c.rank == CardRank.king)
            .length;
        expect(
          kingsUsed,
          lessThan(2),
          reason: 'contestable play-down should preserve king unlock keys',
        );
      },
    );

    test('force-spends unlock keys when pile top is a three', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          // Only king meld possible — would be held if top were unlockable
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        ]);
      bot.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        ])!,
      );

      controller.gameState.discardPile
        ..clear()
        ..addAll(
          List.generate(
            6,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ten),
          ),
        )
        ..add(const PlayingCard(suit: Suit.clubs, rank: CardRank.three));

      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;

      // Filter alone would hold if top were a king; with a three, AI must meld.
      final kingsOnly = [
        [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ],
      ];
      // Sanity: three top means filter does not hold
      expect(
        BotMeldAnalyzer.filterUnlockKeyMeldCandidates(
          bot,
          controller.gameState,
          kingsOnly,
        ),
        isNotEmpty,
      );

      final decision = botAI.makeDecision(bot, controller);
      expect(
        decision.action,
        'createMeld',
        reason: 'three-top must force-spend keys via king meld, not stall',
      );
      final meld = decision.data as List<PlayingCard>;
      expect(
        meld.every((c) => c.rank == CardRank.king),
        isTrue,
        reason: 'forced spend should meld the king unlock keys',
      );
    });

    test('aggressive personality raises book completion priority', () {
      final constants = PersonalityConstants.forPersonality(
        BotPersonality.aggressive,
      );
      expect(constants.bookCompletionPriority, greaterThanOrEqualTo(160));
      expect(constants.highValuePairBreakChance, lessThanOrEqualTo(0.5));
    });
  });
}
