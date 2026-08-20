@Tags(['unlock_key_hold'])
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
  group('Unlock-key hold AI (2026.08-unlock-churn)', () {
    late EnhancedBotAI botAI;
    late GameController controller;
    late Player human;
    late Player bot;

    setUp(() {
      botAI = EnhancedBotAI(seed: 210011);
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bot = Player(id: 'bot', name: 'Conservative', type: PlayerType.bot);
      controller = GameController(players: [human, bot], seed: 210011);
      controller.initializeGame();
      botAI.assignPersonality(bot.id, BotPersonality.conservative);
      controller.gameState.currentPlayerIndex = 1;
    });

    test('botAiVersion bumped for unlock-churn', () {
      expect(BotConfig.botAiVersion, '2026.08-human-counter');
    });

    test('emergency hand size still hard-takes unlockable fat pile in draw', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      // Hand ≥ emergency threshold (15) with unlock keys for kings
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
          const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
        ]);
      expect(
        bot.currentHand.length,
        greaterThanOrEqualTo(BotConfig.emergencyHandSizeThreshold),
      );

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

      // Seed enough turns so early-game grace ends and emergency bypass activates
      for (var i = 0; i < 12; i++) {
        botAI.gameAnalyzer.incrementTurnCount(bot.id);
      }

      expect(controller.gameState.canUnlockDiscard(), isTrue);

      final decision = botAI.makeDecision(bot, controller);
      expect(
        decision.action,
        'drawFromDiscard',
        reason:
            'hand ≥15 must still contest unlockable hard-take pile (not force deck)',
      );
    });

    test(
      'missing unlock keys forces deck even when pile at hard-take size',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = false;
        bot.hand
          ..clear()
          ..addAll([
            // Only one king — cannot unlock
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
            const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
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

        expect(controller.gameState.canUnlockDiscard(), isFalse);

        final decision = botAI.makeDecision(bot, controller);
        expect(
          decision.action,
          'drawFromDeck',
          reason:
              'hard-take willingness must not override canUnlock eligibility',
        );
      },
    );

    test('meld phase holds unlock keys when pile is contestable', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          // Unlock keys for king top
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          // Alternative meld that would burn both kings if chosen with wilds —
          // and a queen meld that does not burn keys
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
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
            BotConfig.preserveUnlockKeysMeldPileSize,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ten),
          ),
        )
        ..add(const PlayingCard(suit: Suit.clubs, rank: CardRank.king));

      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;

      final possible = [
        [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        ],
        [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ],
      ];
      final filtered = BotMeldAnalyzer.filterUnlockKeyMeldCandidates(
        bot,
        controller.gameState,
        possible,
      );
      expect(filtered, hasLength(1));
      expect(filtered.first.every((c) => c.rank == CardRank.queen), isTrue);

      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, anyOf('createMeld', 'addToMeld', 'noMeld'));
      if (decision.action == 'createMeld') {
        final meld = decision.data as List<PlayingCard>;
        final kingsUsed = meld
            .where((c) => !c.isWild && c.rank == CardRank.king)
            .length;
        expect(
          kingsUsed,
          lessThan(2),
          reason: 'must not spend both king unlock keys on a new meld',
        );
      }
    });

    test(
      'draw phase never returns createMeld when pile needs play-down first',
      () {
        bot.hasPlayedDown = false;
        bot.hasPickedUpFoot = false;
        // Hold 2 kings matching top + enough for play-down later
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
            const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          ]);

        controller.gameState.discardPile
          ..clear()
          ..addAll(
            List.generate(
              BotConfig.pileFarmForcePlayDownPileSize - 1,
              (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ten),
            ),
          )
          ..add(const PlayingCard(suit: Suit.clubs, rank: CardRank.king));

        controller.gameState.turnPhase = TurnPhase.draw;
        controller.gameState.hasDrawnFromDeck = false;
        controller.gameState.discardPileFrozen = false;

        final decision = botAI.makeDecision(bot, controller);
        expect(
          decision.action,
          isNot(anyOf('createMeld', 'createMultipleMelds')),
          reason: 'draw phase must never emit meld actions',
        );
        expect(decision.action, 'drawFromDeck');
      },
    );

    test('forces play-down under pile-farm pressure with unlock keys', () {
      bot.hasPlayedDown = false;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          // Play-down: aces + queens (~60+ for round 1)
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          // Unlock keys for king top — keep after play-down
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.six),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.eight),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
        ]);

      controller.gameState.round = 1;
      controller.gameState.discardPile
        ..clear()
        ..addAll(
          List.generate(
            BotConfig.pileFarmForcePlayDownPileSize - 1,
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
            'fat pile + unlock keys must force play-down instead of waiting',
      );
    });
  });
}
