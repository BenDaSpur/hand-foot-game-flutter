@Tags(['playdown_books'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_config.dart';
import 'package:hand_foot_game_flutter/ai/bot_discard_analyzer.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/ai/planner/competitive_policy.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

/// Regressions from 2026.10-force-foot Firestore review:
/// session_17934670363126312 (seed 725028) and related deep-dives.
void main() {
  group('Play-down / books AI (2026.10-playdown-books)', () {
    late EnhancedBotAI botAI;
    late BotDiscardAnalyzer discardAnalyzer;
    late GameController controller;
    late Player human;
    late Player bot;

    setUp(() {
      botAI = EnhancedBotAI(seed: 725028);
      discardAnalyzer = BotDiscardAnalyzer();
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bot = Player(id: 'bot', name: 'Aggressive', type: PlayerType.bot);
      controller = GameController(players: [human, bot], seed: 725028);
      controller.initializeGame();
      botAI.assignPersonality(bot.id, BotPersonality.aggressive);
      controller.gameState.currentPlayerIndex = 1;
    });

    test('botAiVersion is playdown-books', () {
      expect(BotConfig.botAiVersion, '2026.10-playdown-books');
    });

    test('pre-play-down hand never discards wild when non-wilds exist '
        'even if humanCanUnlock freeze would otherwise apply', () {
      // Mirrors session_17934670363126312 R5/R6: large pre-down hand
      // with 2s, human able to unlock, bot unable — old path dumped wilds.
      bot.hasPlayedDown = false;
      bot.hasPickedUpFoot = false;
      human.hasPlayedDown = true;
      human.hasPickedUpFoot = true;
      human.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
        ]);

      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two),
          const PlayingCard(rank: CardRank.joker),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
          const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.four),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.eight),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
        ]);
      expect(bot.currentHand.length, greaterThanOrEqualTo(19));

      // Contestable unfrozen pile top the human can unlock (fives) and
      // the bot cannot (no five pair).
      controller.gameState.discardPile
        ..clear()
        ..addAll(
          List.generate(
            10,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ace),
          ),
        )
        ..add(const PlayingCard(suit: Suit.clubs, rank: CardRank.five));
      controller.gameState.discardPileFrozen = false;
      controller.gameState.turnPhase = TurnPhase.discard;
      controller.gameState.hasDrawnFromDeck = true;

      expect(
        CompetitivePolicy.humanLikelyCanUnlock(controller.gameState, bot.id),
        isTrue,
      );

      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, 'discard');
      final discarded = decision.data as PlayingCard;
      expect(
        discarded.isWild,
        isFalse,
        reason:
            'allowWildFreeze must stay off before play-down so 2s/jokers '
            'remain for 180–210pt dumps',
      );

      // Analyzer path with allowWildFreeze forced true must still protect
      // when the caller mirrors the planner's hasPlayedDown gate.
      final protected = discardAnalyzer.chooseCardToDiscard(
        bot,
        controller.gameState,
        allowWildFreeze: false,
      );
      expect(protected.isWild, isFalse);
    });

    test(
      'pre-play-down discard prefers singleton over high-value natural pair',
      () {
        bot.hasPlayedDown = false;
        bot.hasPickedUpFoot = false;
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.five),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
            const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.two),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
          ]);

        controller.gameState.discardPile
          ..clear()
          ..add(const PlayingCard(suit: Suit.hearts, rank: CardRank.three));
        controller.gameState.discardPileFrozen = false;
        controller.gameState.turnPhase = TurnPhase.discard;
        controller.gameState.hasDrawnFromDeck = true;

        final discarded = discardAnalyzer.chooseCardToDiscard(
          bot,
          controller.gameState,
        );
        expect(discarded.isWild, isFalse);
        expect(
          discarded.rank,
          isNot(anyOf(CardRank.king, CardRank.ace, CardRank.two)),
          reason: 'hold wilds and high pairs needed for late play-down',
        );
      },
    );

    test('finds a legal 210-point late-round play-down from a large hand', () {
      controller.gameState.round = 6;
      expect(controller.gameState.playDownRequirement, 210);

      bot.hasPlayedDown = false;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          ..._nOf(CardRank.ace, 3),
          ..._nOf(CardRank.king, 3),
          ..._nOf(CardRank.queen, 3),
          ..._nOf(CardRank.jack, 3),
          ..._nOf(CardRank.ten, 3),
          ..._nOf(CardRank.nine, 3),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two),
          const PlayingCard(rank: CardRank.joker),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
        ]);

      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;
      _setPile(controller, size: 6, top: CardRank.three);

      final requirement = controller.gameState.playDownRequirement;
      final combo = botAI.meldAnalyzer.findBestPlayDownCombination(
        bot,
        controller,
        requirement,
      );
      final greedy = combo.isNotEmpty
          ? combo
          : botAI.meldAnalyzer.findGreedyPlayDownCombination(
              bot,
              controller,
              requirement,
            );
      expect(greedy, isNotEmpty);
      expect(
        botAI.meldAnalyzer.calculateTotalMeldValue(greedy),
        greaterThanOrEqualTo(210),
      );

      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, anyOf('createMeld', 'createMultipleMelds'));
    });

    test('on foot with one clean book adds toward dirty book instead of '
        'opening a fifth leftover rank', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;
      bot.melds.addAll([
        _sizedMeld(CardRank.ace, size: 7, dirty: false),
        _sizedMeld(CardRank.queen, size: 5, dirty: true),
        _sizedMeld(CardRank.seven, size: 4, dirty: true),
        _sizedMeld(CardRank.five, size: 3, dirty: true),
      ]);
      expect(bot.hasCleanBook, isTrue);
      expect(bot.hasDirtyBook, isFalse);
      expect(bot.canGoOutWithBooks, isFalse);

      // currentHand reads foot once hasPickedUpFoot is true.
      bot.foot
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two),
        ]);
      expect(bot.currentHand.length, 6);

      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;
      _setPile(controller, size: 8, top: CardRank.three);

      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, anyOf('addToMeld', 'createMeld'));
      if (decision.action == 'addToMeld') {
        final data = decision.data as Map<String, dynamic>;
        expect(
          (data['card'] as PlayingCard).rank,
          anyOf(CardRank.queen, CardRank.two, CardRank.seven, CardRank.five),
        );
      } else {
        final meld = decision.data as List<PlayingCard>;
        // Only allow a dirty go-out lane open — not a clean nines pile.
        expect(meld.any((c) => c.isWild), isTrue);
      }
    });

    test('on foot with four dirty ranks may open a 3-card clean lane for '
        'the missing clean book', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;
      bot.melds.addAll([
        _sizedMeld(CardRank.queen, size: 5, dirty: true),
        _sizedMeld(CardRank.seven, size: 4, dirty: true),
        _sizedMeld(CardRank.five, size: 3, dirty: true),
        _sizedMeld(CardRank.four, size: 3, dirty: true),
      ]);
      expect(bot.hasCleanBook, isFalse);
      expect(bot.hasDirtyBook, isFalse);
      expect(bot.canGoOutWithBooks, isFalse);

      bot.foot
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        ]);

      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;
      _setPile(controller, size: 8, top: CardRank.three);

      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, anyOf('createMeld', 'addToMeld'));
      if (decision.action == 'createMeld') {
        final meld = decision.data as List<PlayingCard>;
        expect(
          meld.any((c) => c.isWild),
          isFalse,
          reason: 'missing clean book should open a natural kings lane',
        );
        expect(meld.every((c) => c.rank == CardRank.king || c.isWild), isTrue);
      }
    });

    test('on foot does not open a second short clean lane once one incomplete '
        'clean lane already exists', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;
      bot.melds.addAll([
        _sizedMeld(CardRank.queen, size: 5, dirty: true),
        _sizedMeld(CardRank.seven, size: 4, dirty: true),
        _sizedMeld(CardRank.five, size: 3, dirty: true),
        _sizedMeld(CardRank.four, size: 3, dirty: true),
        // Already-started clean lane for the missing clean book.
        _sizedMeld(CardRank.king, size: 3, dirty: false),
      ]);
      expect(bot.hasCleanBook, isFalse);
      expect(bot.melds.length, 5);

      bot.foot
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        ]);

      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;
      _setPile(controller, size: 8, top: CardRank.three);

      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, anyOf('addToMeld', 'noMeld'));
      if (decision.action == 'addToMeld') {
        final data = decision.data as Map<String, dynamic>;
        expect(
          (data['card'] as PlayingCard).rank,
          isNot(CardRank.ace),
          reason: 'should grow the existing kings clean lane, not open aces',
        );
      }
    });

    test('played-down bot does not skip huge farm unlock for buried 3s', () {
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
          const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
        ]);

      controller.gameState.discardPile
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.clubs, rank: CardRank.three),
          const PlayingCard(suit: Suit.spades, rank: CardRank.three),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
          ...List.generate(
            CompetitivePolicy.hugeFarmPileSize - 4,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ace),
          ),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ]);
      controller.gameState.discardPileFrozen = false;
      controller.gameState.turnPhase = TurnPhase.draw;
      controller.gameState.hasDrawnFromDeck = false;

      expect(
        controller.gameState.discardPile.length,
        greaterThanOrEqualTo(CompetitivePolicy.hugeFarmPileSize),
      );
      expect(
        CompetitivePolicy.shouldSkipUnlockForThrees(bot, controller.gameState),
        isFalse,
        reason: 'huge farms must stay contestable after play-down',
      );
      expect(controller.gameState.canUnlockDiscard(), isTrue);

      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, 'drawFromDiscard');
    });
  });
}

List<PlayingCard> _nOf(CardRank rank, int n) {
  return List.generate(
    n,
    (i) => PlayingCard(suit: Suit.values[i % Suit.values.length], rank: rank),
  );
}

Meld _sizedMeld(CardRank rank, {required int size, required bool dirty}) {
  final cards = <PlayingCard>[
    for (var i = 0; i < (dirty ? size - 1 : size); i++)
      PlayingCard(suit: Suit.values[i % Suit.values.length], rank: rank),
  ];
  if (dirty) {
    cards.add(const PlayingCard(suit: Suit.hearts, rank: CardRank.two));
  }
  return Meld(rank: rank, cards: cards);
}

void _setPile(
  GameController controller, {
  required int size,
  required CardRank top,
}) {
  controller.gameState.discardPile
    ..clear()
    ..addAll(
      List.generate(
        size - 1,
        (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ace),
      ),
    )
    ..add(PlayingCard(suit: Suit.clubs, rank: top));
  controller.gameState.discardPileFrozen =
      top == CardRank.two || top == CardRank.joker;
}
