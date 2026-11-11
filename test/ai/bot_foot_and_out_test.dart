@Tags(['foot_and_out'])
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

/// Regressions from finished games on 2026.10-playdown-books.
///
/// Shapes, not full replays: seed 115743 (round 6, never down), seed 467340
/// (down, 0 books, 12 cards, no foot), seed 441021 (down, 0 books, 1 card,
/// no foot).
void main() {
  group('Foot and out AI (2026.11-foot-and-out)', () {
    late EnhancedBotAI botAI;
    late BotDiscardAnalyzer discardAnalyzer;
    late GameController controller;
    late Player human;
    late Player bot;

    setUp(() {
      botAI = EnhancedBotAI(seed: 115743);
      discardAnalyzer = BotDiscardAnalyzer();
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bot = Player(id: 'bot', name: 'Adaptive', type: PlayerType.bot);
      controller = GameController(players: [human, bot], seed: 115743);
      controller.initializeGame();
      botAI.assignPersonality(bot.id, BotPersonality.adaptive);
      controller.gameState.currentPlayerIndex = 1;
    });

    test('botAiVersion is foot-and-out', () {
      expect(BotConfig.botAiVersion, '2026.11-foot-and-out');
    });

    test('seed 115743 shape: round 4+ searches a legal play-down '
        'before the hand is huge', () {
      controller.gameState.round = 4;
      expect(
        controller.gameState.playDownRequirement,
        BotConfig.lateRoundWidePlayDownRequirement,
      );
      bot.hasPlayedDown = false;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll(_nOf(CardRank.ace, 8));
      expect(
        bot.currentHand.length,
        lessThan(CompetitivePolicy.latePlayDownHandSize),
      );
      _setPile(controller, size: 4, top: CardRank.three);
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;

      expect(
        CompetitivePolicy.shouldSearchGreedyPlayDown(bot, controller.gameState),
        isTrue,
      );
      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, anyOf('createMeld', 'createMultipleMelds'));
    });

    test('seed 467340 shape: played-down bookless hand does not open '
        'another short rank', () {
      controller.gameState.round = 5;
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.melds.addAll([
        _sizedMeld(CardRank.ace, size: 3, dirty: false),
        _sizedMeld(CardRank.king, size: 3, dirty: true),
        _sizedMeld(CardRank.queen, size: 3, dirty: true),
        _sizedMeld(CardRank.jack, size: 3, dirty: true),
        _sizedMeld(CardRank.ten, size: 3, dirty: true),
      ]);
      expect(bot.bookCount, 0);
      bot.hand
        ..clear()
        ..addAll([
          ..._nOf(CardRank.nine, 3),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.four),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.six),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          const PlayingCard(suit: Suit.spades, rank: CardRank.eight),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.three),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.three),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        ]);
      expect(bot.currentHand.length, 12);
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;
      _setPile(controller, size: 8, top: CardRank.four);

      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, 'noMeld');
    });

    test(
      'seed 441021 shape: last hand-pile card is discarded toward the foot',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = false;
        bot.melds.addAll([
          _sizedMeld(CardRank.ace, size: 4, dirty: true),
          _sizedMeld(CardRank.king, size: 4, dirty: true),
          _sizedMeld(CardRank.queen, size: 3, dirty: true),
          _sizedMeld(CardRank.jack, size: 3, dirty: false),
        ]);
        expect(bot.bookCount, 0);
        bot.hand
          ..clear()
          ..add(const PlayingCard(suit: Suit.hearts, rank: CardRank.five));
        controller.gameState.turnPhase = TurnPhase.discard;
        controller.gameState.hasDrawnFromDeck = true;
        _setPile(controller, size: 6, top: CardRank.nine);

        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'discard');
        expect((decision.data as PlayingCard).rank, CardRank.five);
      },
    );

    test(
      'on foot with clean and dirty books discards instead of opening a rank',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;
        bot.melds.addAll([
          _sizedMeld(CardRank.ace, size: 7, dirty: false),
          _sizedMeld(CardRank.king, size: 7, dirty: true),
        ]);
        expect(bot.canGoOutWithBooks, isTrue);
        bot.foot
          ..clear()
          ..addAll([
            ..._nOf(CardRank.queen, 3),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.five),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
          ]);
        expect(bot.currentHand.length, 6);
        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;
        _setPile(controller, size: 4, top: CardRank.three);

        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'noMeld');
      },
    );

    test('played-down discard prefers a singleton 4 over a singleton king', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
          const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ]);
      _setPile(controller, size: 3, top: CardRank.two);
      controller.gameState.discardPileFrozen = true;
      controller.gameState.turnPhase = TurnPhase.discard;
      controller.gameState.hasDrawnFromDeck = true;

      final discarded = discardAnalyzer.chooseCardToDiscard(
        bot,
        controller.gameState,
      );
      expect(discarded.rank, CardRank.four);
    });

    test('after play-down a wild freeze beats a singleton 4 when the human '
        'can take the pile', () {
      human.hasPlayedDown = true;
      human.melds.add(_sizedMeld(CardRank.king, size: 3, dirty: false));
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        ]);
      _setPile(controller, size: 10, top: CardRank.king);
      controller.gameState.discardPileFrozen = false;
      controller.gameState.turnPhase = TurnPhase.discard;
      controller.gameState.hasDrawnFromDeck = true;

      expect(
        CompetitivePolicy.humanLikelyCanUnlock(controller.gameState, bot.id),
        isTrue,
      );
      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, 'discard');
      expect((decision.data as PlayingCard).isWild, isTrue);
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
  return Meld.createMeld(cards)!;
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
