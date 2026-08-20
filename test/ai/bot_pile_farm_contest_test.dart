@Tags(['pile_farm_contest'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_config.dart';
import 'package:hand_foot_game_flutter/ai/bot_end_game_manager.dart';
import 'package:hand_foot_game_flutter/ai/bot_meld_analyzer.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Pile-farm contest AI (2026.08-human-counter)', () {
    late EnhancedBotAI botAI;
    late GameController controller;
    late Player human;
    late Player bot;

    setUp(() {
      botAI = EnhancedBotAI(seed: 822703);
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bot = Player(id: 'bot', name: 'Conservative', type: PlayerType.bot);
      controller = GameController(players: [human, bot], seed: 822703);
      controller.initializeGame();
      botAI.assignPersonality(bot.id, BotPersonality.conservative);
      controller.gameState.currentPlayerIndex = 1;
    });

    test('botAiVersion bumped for human-counter', () {
      expect(BotConfig.botAiVersion, '2026.08-human-counter');
    });

    test(
      'hard-takes discard pile at postPlayDownHardTakePileSize after play-down',
      () {
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
            const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          ]);

        // Hard-take-sized unlockable pile topped with King
        controller.gameState.discardPile
          ..clear()
          ..addAll(
            List.generate(
              BotConfig.postPlayDownHardTakePileSize - 1,
              (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ace),
            ),
          )
          ..add(const PlayingCard(suit: Suit.clubs, rank: CardRank.king));

        expect(
          controller.gameState.discardPile.length,
          BotConfig.postPlayDownHardTakePileSize,
        );
        expect(controller.gameState.canUnlockDiscard(), isTrue);

        controller.gameState.turnPhase = TurnPhase.draw;
        controller.gameState.hasDrawnFromDeck = false;
        controller.gameState.discardPileFrozen = false;

        final decision = botAI.makeDecision(bot, controller);
        expect(
          decision.action,
          'drawFromDiscard',
          reason:
              'post-play-down pile >= hard-take size must unlock when eligible',
        );
      },
    );

    test('forces late-round play-down at hand >= 18 when behind', () {
      bot.hasPlayedDown = false;
      bot.hasPickedUpFoot = false;
      human.score = 5000;
      bot.score = 2500; // gap >= 2000
      controller.gameState.round = 3;

      // 18 cards with enough point value for round-3 play-down (120)
      bot.hand
        ..clear()
        ..addAll([
          // Ace meld ~60
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          // King meld ~30
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          // Queen meld ~30
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          // Filler
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.six),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.eight),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
        ]);
      expect(
        bot.currentHand.length,
        greaterThanOrEqualTo(BotConfig.lateRoundForcePlayDownHandSize),
      );

      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;

      final decision = botAI.makeDecision(bot, controller);
      expect(
        decision.action,
        anyOf('createMeld', 'createMultipleMelds'),
        reason: 'R3+ with hand>=18 or large deficit must force play-down',
      );
    });

    test(
      'does not strategic-hold on foot with ≤3 cards when missing books',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;
        bot.hand.clear();
        bot.foot
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.four),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          ]);
        // Dirty book only — missing clean
        bot.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
          ])!,
        );

        expect(bot.canGoOutWithBooks, isFalse);
        expect(bot.currentHand.length, 3);

        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;

        final decision = botAI.makeDecision(bot, controller);
        // Creating the 4s meld would empty the foot without go-out — refuse
        // emptying. Meld phase must not emit discard (phase violation).
        expect(decision.action, 'noMeld');
        expect(
          BotEndGameManager.isSafeCreateMeld(bot, [
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.four),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          ]),
          isFalse,
        );

        controller.gameState.turnPhase = TurnPhase.discard;
        final discardDecision = botAI.makeDecision(bot, controller);
        expect(discardDecision.action, 'discard');
      },
    );

    test('melds toward missing clean book when safe with small foot hand', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;
      bot.hand.clear();
      bot.foot
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.four),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
        ]);
      bot.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        ])!,
      );

      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;

      final decision = botAI.makeDecision(bot, controller);
      expect(
        decision.action,
        anyOf('createMeld', 'addToMeld', 'createMultipleMelds'),
      );
    });

    test('preferCleanBooks ranks natural 7+ melds first in maximal dump', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          // Clean book of 7s
          const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
          // Dirty-capable 5s + wild
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
          // Another small natural
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
        ]);

      final analyzer = BotMeldAnalyzer();
      final melds = analyzer.findMaximalMeldCombination(
        bot,
        controller,
        preferCleanBooks: true,
      );
      expect(melds, isNotEmpty);
      final first = melds.first;
      expect(first.length, greaterThanOrEqualTo(BotConfig.bookSize));
      expect(first.any((c) => c.isWild), isFalse);
      expect(first.every((c) => c.rank == CardRank.seven), isTrue);
    });

    test('ends turn instead of emptying foot without go-out books', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;
      bot.hand.clear();
      bot.foot
        ..clear()
        ..add(const PlayingCard(suit: Suit.hearts, rank: CardRank.nine));
      bot.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        ])!,
      );

      expect(BotEndGameManager.wouldEmptyFootWithoutGoOut(bot), isTrue);

      controller.gameState.turnPhase = TurnPhase.discard;
      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, 'endTurn');
    });
  });
}
