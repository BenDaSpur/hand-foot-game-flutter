@Tags(['competitive_planner'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_config.dart';
import 'package:hand_foot_game_flutter/ai/bot_discard_analyzer.dart';
import 'package:hand_foot_game_flutter/ai/bot_game_context.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/ai/planner/competitive_policy.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

/// Policy tests for the competitive planner, including reconstructed
/// snapshots from production seeds 966057 / 938454 / 971981 / 880086.
void main() {
  group('Competitive planner policy', () {
    late EnhancedBotAI botAI;
    late GameController controller;
    late Player human;
    late Player bot;

    setUp(() {
      botAI = EnhancedBotAI(seed: 20260821);
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bot = Player(id: 'bot', name: 'Adaptive', type: PlayerType.bot);
      controller = GameController(players: [human, bot], seed: 20260821);
      controller.initializeGame();
      botAI.assignPersonality(bot.id, BotPersonality.adaptive);
      controller.gameState.currentPlayerIndex = 1;
    });

    test('botAiVersion is hand-pile-empty', () {
      expect(BotConfig.botAiVersion, '2026.08-hand-pile-empty');
      expect(BotConfig.goOutThisTurnMaxHand, 5);
      expect(CompetitivePolicy.latePlayDownHandSize, 12);
    }, tags: ['competitive_planner']);

    test(
      'takes when eligible and not actually going out this turn',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;
        bot.foot
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
          ]);
        bot.melds.addAll([
          _book(CardRank.ace, dirty: false),
          _book(CardRank.queen, dirty: true),
        ]);

        _setPile(controller, size: 50, top: CardRank.king);
        controller.gameState.turnPhase = TurnPhase.draw;
        controller.gameState.hasDrawnFromDeck = false;
        controller.gameState.discardPileFrozen = false;

        expect(controller.gameState.canUnlockDiscard(), isTrue);
        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'drawFromDiscard');
        expect(decision.analyticsContext?['couldUnlock'], isTrue);
        expect(decision.analyticsContext?['keyCount'], 2);
      },
      tags: ['competitive_planner'],
    );

    test(
      'takes pile when the current hand is fully meldable before the draw',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;
        bot.foot
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          ]);
        bot.melds.addAll([
          _book(CardRank.ace, dirty: false),
          _book(CardRank.queen, dirty: true),
        ]);

        _setPile(controller, size: 40, top: CardRank.king);
        controller.gameState.turnPhase = TurnPhase.draw;
        controller.gameState.hasDrawnFromDeck = false;
        controller.gameState.discardPileFrozen = false;

        expect(controller.gameState.canUnlockDiscard(), isTrue);
        expect(
          CompetitivePolicy.canEmptyThisTurn(
            bot,
            context: BotGameContext(controller.gameState, controller),
            meldAnalyzer: botAI.meldAnalyzer,
          ),
          isFalse,
        );
        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'drawFromDiscard');
        expect(decision.analyticsContext?['couldUnlock'], isTrue);
      },
      tags: ['competitive_planner'],
    );

    test(
      'keeps drawFromDiscard when one leftover card cannot finish before the draw',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;
        bot.foot
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
          ]);
        bot.melds.addAll([
          _book(CardRank.ace, dirty: false),
          _book(CardRank.queen, dirty: true),
        ]);

        _setPile(controller, size: 40, top: CardRank.king);
        controller.gameState.turnPhase = TurnPhase.draw;
        controller.gameState.hasDrawnFromDeck = false;
        controller.gameState.discardPileFrozen = false;

        expect(
          CompetitivePolicy.canEmptyThisTurn(
            bot,
            context: BotGameContext(controller.gameState, controller),
            meldAnalyzer: botAI.meldAnalyzer,
          ),
          isFalse,
        );
        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'drawFromDiscard');
        expect(decision.analyticsContext?['couldUnlock'], isTrue);
      },
      tags: ['competitive_planner'],
    );

    test('keeps one buried 3 as a useful safe discard', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;
      bot.foot
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
        ]);
      bot.melds.addAll([
        _book(CardRank.ace, dirty: false),
        _book(CardRank.queen, dirty: true),
      ]);

      _setPile(controller, size: 20, top: CardRank.king);
      _replaceUnderTopWithThrees(controller, 1);
      controller.gameState.turnPhase = TurnPhase.draw;
      controller.gameState.hasDrawnFromDeck = false;
      controller.gameState.discardPileFrozen = false;

      expect(CompetitivePolicy.pickupThreeCount(controller.gameState), 1);
      expect(
        CompetitivePolicy.shouldSkipUnlockForThrees(bot, controller.gameState),
        isFalse,
      );
      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, 'drawFromDiscard');
      expect(decision.analyticsContext?['pickupThrees'], 1);
    }, tags: ['competitive_planner']);

    test(
      'skips a pickup that would add three 3s and extra dump turns',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;
        bot.foot
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
          ]);
        bot.melds.addAll([
          _book(CardRank.ace, dirty: false),
          _book(CardRank.queen, dirty: true),
        ]);

        _setPile(controller, size: 16, top: CardRank.king);
        _replaceUnderTopWithThrees(controller, 3);
        controller.gameState.turnPhase = TurnPhase.draw;
        controller.gameState.hasDrawnFromDeck = false;
        controller.gameState.discardPileFrozen = false;

        expect(CompetitivePolicy.pickupThreeCount(controller.gameState), 3);
        expect(CompetitivePolicy.threeDumpTurns(bot, controller.gameState), 3);
        expect(
          CompetitivePolicy.shouldSkipUnlockForThrees(
            bot,
            controller.gameState,
          ),
          isTrue,
        );
        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'drawFromDeck');
        expect(decision.analyticsContext?['skipReason'], 'toxicThrees');
        expect(decision.analyticsContext?['pickupThrees'], 3);
        expect(decision.analyticsContext?['threeDumpTurns'], 3);
      },
      tags: ['competitive_planner'],
    );

    test(
      'skips two buried 3s when still on the hand pile near foot',
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

        _setPile(controller, size: 16, top: CardRank.king);
        _replaceUnderTopWithThrees(controller, 2);
        controller.gameState.turnPhase = TurnPhase.draw;
        controller.gameState.hasDrawnFromDeck = false;
        controller.gameState.discardPileFrozen = false;

        expect(
          bot.currentHand.length <= BotConfig.emergencyTransitionThreshold,
          isTrue,
        );
        expect(
          CompetitivePolicy.shouldSkipUnlockForThrees(
            bot,
            controller.gameState,
          ),
          isTrue,
        );
        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'drawFromDeck');
        expect(decision.analyticsContext?['skipReason'], 'toxicThrees');
      },
      tags: ['competitive_planner'],
    );

    test(
      'discard retains a live-top pair over an equivalent non-live pair',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = false;
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          ]);
        _setPile(controller, size: 8, top: CardRank.king);
        controller.gameState.turnPhase = TurnPhase.discard;
        controller.gameState.hasDrawnFromDeck = true;
        controller.gameState.discardPileFrozen = false;

        final liveKeys = CompetitivePolicy.liveKeyRanks(controller.gameState);
        expect(liveKeys.contains(CardRank.king), isTrue);

        final discarded = BotDiscardAnalyzer().chooseCardToDiscard(
          bot,
          controller.gameState,
          extraProtectedRanks: liveKeys,
        );
        expect(discarded.rank, CardRank.queen);

        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'discard');
        expect((decision.data as PlayingCard).rank, isNot(CardRank.king));
      },
      tags: ['competitive_planner'],
    );

    test('plays down as soon as a legal combo exists', () {
      bot.hasPlayedDown = false;
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
        ]);

      controller.gameState.round = 1;
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;
      controller.gameState.discardPile.clear();

      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, anyOf('createMeld', 'createMultipleMelds'));
    }, tags: ['competitive_planner']);

    test(
      'holds the live top pair instead of melding it away',
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
            const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
          ]);
        bot.melds.add(_book(CardRank.ace, dirty: false));

        _setPile(controller, size: 12, top: CardRank.king);
        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;

        expect(
          CompetitivePolicy.shouldEmptyHandPile(bot, controller.gameState),
          isFalse,
        );
        final decision = botAI.makeDecision(bot, controller);
        if (decision.action == 'createMeld') {
          final meld = decision.data as List<PlayingCard>;
          final kings = meld.where((c) => c.rank == CardRank.king).length;
          expect(kings, lessThan(2));
        } else if (decision.action == 'addToMeld') {
          final card =
              (decision.data as Map<String, dynamic>)['card'] as PlayingCard;
          expect(card.rank, isNot(CardRank.king));
        } else {
          expect(decision.action, 'noMeld');
        }
      },
      tags: ['competitive_planner'],
    );

    test(
      'never poisons the only clean-book lane with a wild',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;
        bot.foot
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
            const PlayingCard(suit: Suit.spades, rank: CardRank.five),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
          ]);
        bot.melds.addAll([
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
            const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
            const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          ])!,
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.two),
          ])!,
        ]);

        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;
        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'addToMeld');
        final data = decision.data as Map<String, dynamic>;
        final card = data['card'] as PlayingCard;
        final meldIndex = data['meldIndex'] as int;
        if (card.isWild) {
          expect(bot.melds[meldIndex].cards.any((c) => c.isWild), isTrue);
        }
      },
      tags: ['competitive_planner'],
    );

    test(
      'plays down a round-2 90-point combo at 13 cards',
      () {
        bot.hasPlayedDown = false;
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
            const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.five),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
            const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
          ]);
        human.hasPlayedDown = true;
        controller.gameState.round = 2;
        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;
        _setPile(controller, size: 18, top: CardRank.jack);

        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, anyOf('createMeld', 'createMultipleMelds'));
      },
      tags: ['competitive_planner'],
    );

    test(
      'bookless 4-card hand pile spends the live pair to empty toward foot',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = false;
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
          ]);
        human.hasPlayedDown = true;
        human.hasPickedUpFoot = true;
        _setPile(controller, size: 38, top: CardRank.king);
        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;

        expect(
          CompetitivePolicy.shouldEmptyHandPile(bot, controller.gameState),
          isTrue,
        );
        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'createMeld');
        final meld = decision.data as List<PlayingCard>;
        expect(meld.where((c) => c.rank == CardRank.king).length, 3);
      },
      tags: ['competitive_planner'],
    );

    test(
      'bursts two disjoint melds on a large foot hand',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;
        bot.foot
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.four),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
            const PlayingCard(suit: Suit.spades, rank: CardRank.five),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
            const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          ]);
        bot.melds.addAll([
          _book(CardRank.ace, dirty: false),
          _book(CardRank.king, dirty: true),
        ]);
        _setPile(controller, size: 8, top: CardRank.two);
        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;
        controller.gameState.discardPileFrozen = true;

        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'createMultipleMelds');
        final melds = decision.data as List<List<PlayingCard>>;
        expect(melds.length, greaterThanOrEqualTo(2));
      },
      tags: ['competitive_planner'],
    );

    test(
      'conservative with a live pair still takes a 12-card pile',
      () {
        botAI.assignPersonality(bot.id, BotPersonality.conservative);
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;
        bot.foot
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
          ]);
        bot.melds.addAll([
          _book(CardRank.ace, dirty: false),
          _book(CardRank.king, dirty: true),
        ]);
        _setPile(controller, size: 12, top: CardRank.queen);
        controller.gameState.turnPhase = TurnPhase.draw;
        controller.gameState.hasDrawnFromDeck = false;
        controller.gameState.discardPileFrozen = false;

        expect(controller.gameState.canUnlockDiscard(), isTrue);
        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'drawFromDiscard');
      },
      tags: ['competitive_planner'],
    );

    test(
      'bookless leftover of 7 empties even when the pile is thin',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = false;
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
            const PlayingCard(suit: Suit.spades, rank: CardRank.three),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
            const PlayingCard(suit: Suit.spades, rank: CardRank.six),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          ]);
        bot.melds.addAll([
          _sizedMeld(CardRank.ten, size: 4, dirty: true),
          _sizedMeld(CardRank.king, size: 4, dirty: true),
          _sizedMeld(CardRank.jack, size: 5, dirty: true),
          _sizedMeld(CardRank.eight, size: 4, dirty: true),
          _sizedMeld(CardRank.ace, size: 4, dirty: true),
        ]);
        _setPile(controller, size: 4, top: CardRank.queen);
        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;

        expect(bot.bookCount, 0);
        expect(
          CompetitivePolicy.shouldEmptyHandPile(bot, controller.gameState),
          isTrue,
        );
        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'noMeld');
        expect(decision.analyticsContext?['emptyHandPile'], isTrue);
        expect(decision.analyticsContext?['leftoverUnmeldable'], isTrue);
        expect(decision.analyticsContext?['liveTop'], 'queen');
        expect(
          decision.analyticsContext?['candidateKinds'],
          contains('noMeld'),
        );
        expect(decision.analyticsContext?['humanCanUnlock'], isA<bool>());
      },
      tags: ['competitive_planner'],
    );

    test(
      'on foot, takes a huge farm even with four buried 3s',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;
        bot.foot
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
            const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          ]);
        bot.melds.add(_book(CardRank.ten, dirty: false));
        _setPile(controller, size: 27, top: CardRank.seven);
        _replaceUnderTopWithThrees(controller, 4);
        controller.gameState.turnPhase = TurnPhase.draw;
        controller.gameState.hasDrawnFromDeck = false;
        controller.gameState.discardPileFrozen = false;

        expect(controller.gameState.canUnlockDiscard(), isTrue);
        expect(
          CompetitivePolicy.shouldSkipUnlockForThrees(
            bot,
            controller.gameState,
          ),
          isFalse,
        );
        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'drawFromDiscard');
      },
      tags: ['competitive_planner'],
    );

    test(
      'greedy play-down fires below 12 cards once the human is already down',
      () {
        bot.hasPlayedDown = false;
        bot.hasPickedUpFoot = false;
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
            const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.five),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
          ]);
        expect(bot.currentHand.length, 11);
        human.hasPlayedDown = false;
        _setPile(controller, size: 4, top: CardRank.nine);
        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;
        controller.gameState.round = 2;

        expect(
          CompetitivePolicy.shouldSearchGreedyPlayDown(
            bot,
            controller.gameState,
          ),
          isFalse,
        );
        human.hasPlayedDown = true;
        expect(
          CompetitivePolicy.shouldSearchGreedyPlayDown(
            bot,
            controller.gameState,
          ),
          isTrue,
        );
        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, anyOf('createMeld', 'createMultipleMelds'));
      },
      tags: ['competitive_planner'],
    );

    test(
      'freezes a contestable pile with a 3 instead of feeding a five',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = false;
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
            const PlayingCard(suit: Suit.spades, rank: CardRank.five),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
          ]);
        bot.melds.add(_book(CardRank.ten, dirty: true));
        _setPile(controller, size: 18, top: CardRank.queen);
        controller.gameState.turnPhase = TurnPhase.discard;
        controller.gameState.hasDrawnFromDeck = true;
        controller.gameState.discardPileFrozen = false;
        human.hasPlayedDown = true;

        final discarded = BotDiscardAnalyzer().chooseCardToDiscard(
          bot,
          controller.gameState,
        );
        expect(discarded.rank, CardRank.three);

        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'discard');
        expect((decision.data as PlayingCard).rank, CardRank.three);
        expect(decision.analyticsContext?['discardedRank'], 'three');
        expect(decision.analyticsContext?['liveTop'], 'queen');
        expect(decision.analyticsContext?['humanCanUnlock'], isTrue);
      },
      tags: ['competitive_planner'],
    );

    test(
      'does not start meld #5 on a bookless hand pile when a 6-card add exists',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = false;
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
            const PlayingCard(suit: Suit.spades, rank: CardRank.four),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.five),
          ]);
        bot.melds.addAll([
          _sizedMeld(CardRank.ten, size: 6, dirty: true),
          _sizedMeld(CardRank.king, size: 4, dirty: true),
          _sizedMeld(CardRank.jack, size: 4, dirty: true),
          _sizedMeld(CardRank.ace, size: 3, dirty: true),
        ]);
        expect(bot.bookCount, 0);
        expect(bot.melds.length, 4);
        _setPile(controller, size: 12, top: CardRank.queen);
        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;

        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'addToMeld');
        final data = decision.data as Map<String, dynamic>;
        expect(data['meldIndex'], 0);
        expect((data['card'] as PlayingCard).rank, CardRank.ten);
      },
      tags: ['competitive_planner'],
    );
  });

  group('Production seed snapshots', () {
    test(
      'seed 966057: 8-card foot with 2 kings takes pile 50',
      () {
        final botAI = EnhancedBotAI(seed: 966057);
        final human = Player(id: '1', name: 'You', type: PlayerType.human);
        final bot = Player(id: '2', name: 'Adaptive', type: PlayerType.bot);
        final controller = GameController(players: [human, bot], seed: 966057);
        controller.initializeGame();
        botAI.assignPersonality(bot.id, BotPersonality.adaptive);
        controller.gameState.currentPlayerIndex = 1;

        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;
        bot.foot
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.six),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.three),
          ]);
        bot.melds.add(_book(CardRank.ace, dirty: true));

        _setPile(
          controller,
          size: 50,
          top: CardRank.king,
          topSuit: Suit.hearts,
        );
        controller.gameState.turnPhase = TurnPhase.draw;
        controller.gameState.hasDrawnFromDeck = false;
        controller.gameState.discardPileFrozen = false;

        expect(controller.gameState.canUnlockDiscard(), isTrue);
        expect(botAI.makeDecision(bot, controller).action, 'drawFromDiscard');
        expect(controller.drawFromDiscardPile(), isTrue);
        expect(controller.gameState.discardPile.length, 44);
      },
      tags: ['competitive_planner'],
    );

    test(
      'seed 971981: conservative 8-card foot takes pile 51',
      () {
        final botAI = EnhancedBotAI(seed: 971981);
        final human = Player(id: '1', name: 'You', type: PlayerType.human);
        final bot = Player(id: '3', name: 'Carl', type: PlayerType.bot);
        final controller = GameController(players: [human, bot], seed: 971981);
        controller.initializeGame();
        botAI.assignPersonality(bot.id, BotPersonality.conservative);
        controller.gameState.currentPlayerIndex = 1;

        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;
        bot.foot
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
            const PlayingCard(suit: Suit.spades, rank: CardRank.five),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.eight),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          ]);
        bot.melds.addAll([
          _book(CardRank.ace, dirty: false),
          _book(CardRank.king, dirty: true),
          _book(CardRank.jack, dirty: true),
        ]);

        _setPile(
          controller,
          size: 51,
          top: CardRank.eight,
          topSuit: Suit.hearts,
        );
        controller.gameState.turnPhase = TurnPhase.draw;
        controller.gameState.hasDrawnFromDeck = false;
        controller.gameState.discardPileFrozen = false;

        expect(controller.gameState.canUnlockDiscard(), isTrue);
        expect(botAI.makeDecision(bot, controller).action, 'drawFromDiscard');
        expect(controller.drawFromDiscardPile(), isTrue);
        expect(controller.gameState.discardPile.length, 45);
      },
      tags: ['competitive_planner'],
    );

    test(
      'seed 938454: 11-card foot with 3 nines takes pile 34',
      () {
        final botAI = EnhancedBotAI(seed: 938454);
        final human = Player(id: '1', name: 'You', type: PlayerType.human);
        final bot = Player(id: '2', name: 'Alex', type: PlayerType.bot);
        final controller = GameController(players: [human, bot], seed: 938454);
        controller.initializeGame();
        botAI.assignPersonality(bot.id, BotPersonality.adaptive);
        controller.gameState.currentPlayerIndex = 1;

        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;
        bot.foot
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          ]);
        bot.melds.add(_book(CardRank.ace, dirty: true));

        _setPile(
          controller,
          size: 34,
          top: CardRank.nine,
          topSuit: Suit.spades,
        );
        controller.gameState.turnPhase = TurnPhase.draw;
        controller.gameState.hasDrawnFromDeck = false;
        controller.gameState.discardPileFrozen = false;

        expect(controller.gameState.canUnlockDiscard(), isTrue);
        expect(botAI.makeDecision(bot, controller).action, 'drawFromDiscard');
        expect(controller.drawFromDiscardPile(), isTrue);
        expect(controller.gameState.discardPile.length, 28);
      },
      tags: ['competitive_planner'],
    );

    test('seed 880086: 5-card hand pile takes pile 35', () {
      final botAI = EnhancedBotAI(seed: 880086);
      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final bot = Player(id: '2', name: 'Alex', type: PlayerType.bot);
      final controller = GameController(players: [human, bot], seed: 880086);
      controller.initializeGame();
      botAI.assignPersonality(bot.id, BotPersonality.adaptive);
      controller.gameState.currentPlayerIndex = 1;

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
        ]);
      bot.melds.add(_book(CardRank.ace, dirty: true));

      _setPile(controller, size: 35, top: CardRank.queen);
      controller.gameState.turnPhase = TurnPhase.draw;
      controller.gameState.hasDrawnFromDeck = false;
      controller.gameState.discardPileFrozen = false;

      expect(controller.gameState.canUnlockDiscard(), isTrue);
      expect(botAI.makeDecision(bot, controller).action, 'drawFromDiscard');
      expect(controller.drawFromDiscardPile(), isTrue);
      expect(controller.gameState.discardPile.length, 29);
    }, tags: ['competitive_planner']);

    test(
      'seed 194022: bookless 7-card leftover on pile 29 is leftoverUnmeldable',
      () {
        final botAI = EnhancedBotAI(seed: 194022);
        final human = Player(id: '1', name: 'You', type: PlayerType.human);
        final bot = Player(id: '2', name: 'Adaptive', type: PlayerType.bot);
        final controller = GameController(players: [human, bot], seed: 194022);
        controller.initializeGame();
        botAI.assignPersonality(bot.id, BotPersonality.adaptive);
        controller.gameState.currentPlayerIndex = 1;

        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = false;
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
            const PlayingCard(suit: Suit.spades, rank: CardRank.four),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.six),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
            const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          ]);
        bot.melds.addAll([
          _sizedMeld(CardRank.ten, size: 6, dirty: true),
          _sizedMeld(CardRank.king, size: 4, dirty: true),
          _sizedMeld(CardRank.jack, size: 5, dirty: true),
          _sizedMeld(CardRank.eight, size: 4, dirty: true),
          _sizedMeld(CardRank.ace, size: 4, dirty: true),
        ]);
        _setPile(controller, size: 29, top: CardRank.seven);
        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;

        expect(bot.bookCount, 0);
        expect(
          CompetitivePolicy.shouldEmptyHandPile(bot, controller.gameState),
          isTrue,
        );
        final decision = botAI.makeDecision(bot, controller);
        expect(decision.analyticsContext?['emptyHandPile'], isTrue);
        expect(decision.analyticsContext?['leftoverUnmeldable'], isTrue);
        expect(decision.analyticsContext?['liveTop'], 'seven');
      },
      tags: ['competitive_planner'],
    );

    test(
      'seed 956319: 1-card leftover empties the hand pile',
      () {
        final botAI = EnhancedBotAI(seed: 956319);
        final human = Player(id: '1', name: 'You', type: PlayerType.human);
        final bot = Player(id: '2', name: 'BookBuilder', type: PlayerType.bot);
        final controller = GameController(players: [human, bot], seed: 956319);
        controller.initializeGame();
        botAI.assignPersonality(bot.id, BotPersonality.bookBuilder);
        controller.gameState.currentPlayerIndex = 1;

        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = false;
        bot.hand
          ..clear()
          ..addAll([const PlayingCard(suit: Suit.hearts, rank: CardRank.jack)]);
        bot.melds.addAll([
          _sizedMeld(CardRank.ace, size: 4, dirty: true),
          _sizedMeld(CardRank.king, size: 3, dirty: true),
        ]);
        _setPile(controller, size: 17, top: CardRank.seven);
        controller.gameState.turnPhase = TurnPhase.discard;
        controller.gameState.hasDrawnFromDeck = true;
        controller.gameState.discardPileFrozen = false;

        expect(
          CompetitivePolicy.shouldEmptyHandPile(bot, controller.gameState),
          isTrue,
        );
        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'discard');
        expect((decision.data as PlayingCard).rank, CardRank.jack);
        expect(decision.analyticsContext?['emptyHandPile'], isTrue);
        expect(decision.analyticsContext?['discardedRank'], 'jack');
      },
      tags: ['competitive_planner'],
    );
  });
}

void _setPile(
  GameController controller, {
  required int size,
  required CardRank top,
  Suit topSuit = Suit.clubs,
}) {
  controller.gameState.discardPile
    ..clear()
    ..addAll(
      List.generate(
        size - 1,
        (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ace),
      ),
    )
    ..add(PlayingCard(suit: topSuit, rank: top));
}

void _replaceUnderTopWithThrees(GameController controller, int count) {
  final pile = controller.gameState.discardPile;
  for (var i = 1; i <= count && i < pile.length; i++) {
    pile[pile.length - 1 - i] = PlayingCard(
      suit: i.isOdd ? Suit.clubs : Suit.hearts,
      rank: CardRank.three,
    );
  }
}

Meld _book(CardRank rank, {required bool dirty}) {
  return _sizedMeld(rank, size: 7, dirty: dirty);
}

Meld _sizedMeld(CardRank rank, {required int size, required bool dirty}) {
  final cards = <PlayingCard>[];
  final naturalCount = dirty ? size - 1 : size;
  for (var i = 0; i < naturalCount; i++) {
    cards.add(PlayingCard(suit: Suit.values[i % 4], rank: rank));
  }
  if (dirty) {
    cards.add(const PlayingCard(suit: Suit.clubs, rank: CardRank.two));
  }
  return Meld.createMeld(cards)!;
}
