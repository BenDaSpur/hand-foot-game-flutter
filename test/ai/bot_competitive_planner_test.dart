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

    test('botAiVersion is competitive-planner', () {
      expect(BotConfig.botAiVersion, '2026.08-competitive-planner');
      expect(BotConfig.goOutThisTurnMaxHand, 5);
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

        _setPile(controller, size: 20, top: CardRank.king);
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
          ]);
        bot.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
            const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          ])!,
        );

        _setPile(controller, size: 12, top: CardRank.king);
        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;

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
  final cards = <PlayingCard>[
    PlayingCard(suit: Suit.hearts, rank: rank),
    PlayingCard(suit: Suit.spades, rank: rank),
    PlayingCard(suit: Suit.clubs, rank: rank),
    PlayingCard(suit: Suit.diamonds, rank: rank),
    PlayingCard(suit: Suit.hearts, rank: rank),
    PlayingCard(suit: Suit.spades, rank: rank),
    if (dirty)
      const PlayingCard(suit: Suit.clubs, rank: CardRank.two)
    else
      PlayingCard(suit: Suit.clubs, rank: rank),
  ];
  return Meld.createMeld(cards)!;
}
