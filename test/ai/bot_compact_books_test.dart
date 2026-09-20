@Tags(['compact_books'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_config.dart';
import 'package:hand_foot_game_flutter/ai/bot_discard_analyzer.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

/// Planner regressions from 2026.09 Firestore review (sessions
/// 17899333117151715 / 17897480002110211).
void main() {
  group('Compact books planner (2026.09)', () {
    late EnhancedBotAI botAI;
    late BotDiscardAnalyzer discardAnalyzer;
    late GameController controller;
    late Player human;
    late Player bot;

    setUp(() {
      botAI = EnhancedBotAI(seed: 178546);
      discardAnalyzer = BotDiscardAnalyzer();
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bot = Player(id: 'bot', name: 'Adaptive', type: PlayerType.bot);
      controller = GameController(players: [human, bot], seed: 178546);
      controller.initializeGame();
      botAI.assignPersonality(bot.id, BotPersonality.adaptive);
      controller.gameState.currentPlayerIndex = 1;
    });

    test('botAiVersion is compact-books', () {
      expect(BotConfig.botAiVersion, '2026.09-compact-books');
    });

    test(
      'does not open a fifth leftover rank after four piles including books',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = false;
        bot.melds.addAll([
          _sizedMeld(CardRank.ace, size: 7, dirty: false),
          _sizedMeld(CardRank.queen, size: 7, dirty: true),
          _sizedMeld(CardRank.seven, size: 4, dirty: true),
          _sizedMeld(CardRank.five, size: 3, dirty: true),
        ]);
        expect(bot.melds.length, BotConfig.handPileNewMeldCap);
        expect(bot.hasCleanBook, isTrue);
        expect(bot.hasDirtyBook, isTrue);

        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          ]);

        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;
        _setPile(controller, size: 12, top: CardRank.jack);

        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, isNot(equals('createMeld')));
        expect(decision.action, isNot(equals('createMultipleMelds')));
        expect(decision.action, 'addToMeld');
        final data = decision.data as Map<String, dynamic>;
        expect((data['card'] as PlayingCard).rank, CardRank.queen);
      },
    );

    test('holds live-top fours at pile size 4 before play-down', () {
      bot.hasPlayedDown = false;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.four),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
        ]);
      _setPile(controller, size: 4, top: CardRank.four);
      controller.gameState.discardPileFrozen = false;
      controller.gameState.turnPhase = TurnPhase.discard;
      controller.gameState.hasDrawnFromDeck = true;

      final scored = discardAnalyzer.chooseCardToDiscard(
        bot,
        controller.gameState,
      );
      expect(scored.rank, CardRank.nine);

      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, 'discard');
      expect((decision.data as PlayingCard).rank, CardRank.nine);
    });

    test('does not dump leftover 5/7 pairs onto a contestable pile', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.melds.addAll([
        _sizedMeld(CardRank.ace, size: 4, dirty: true),
        _sizedMeld(CardRank.queen, size: 3, dirty: true),
      ]);
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
        ]);
      _setPile(controller, size: 12, top: CardRank.jack);
      controller.gameState.discardPileFrozen = false;
      controller.gameState.turnPhase = TurnPhase.discard;
      controller.gameState.hasDrawnFromDeck = true;

      final decision = botAI.makeDecision(bot, controller);
      expect(decision.action, 'discard');
      expect((decision.data as PlayingCard).rank, CardRank.nine);
    });

    test(
      'plays down a 32-card late-round hand that only packs as many small ranks',
      () {
        // Session 17897480002110211 (seed 455125): aggressive sat on 32
        // cards in round 4. Requirement 150 needs more than five 3-card
        // piles of mixed 5/10-point ranks.
        controller.gameState.round = 4;
        expect(controller.gameState.playDownRequirement, 150);

        bot.hasPlayedDown = false;
        bot.hasPickedUpFoot = false;
        bot.hand
          ..clear()
          ..addAll(
            _fourOfEach([
              CardRank.four,
              CardRank.five,
              CardRank.six,
              CardRank.seven,
              CardRank.eight,
              CardRank.nine,
              CardRank.ten,
              CardRank.jack,
            ]),
          );
        expect(bot.currentHand.length, 32);

        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;
        _setPile(controller, size: 8, top: CardRank.three);

        final greedy = botAI.meldAnalyzer.findGreedyPlayDownCombination(
          bot,
          controller,
          controller.gameState.playDownRequirement,
        );
        expect(greedy, isNotEmpty);
        expect(
          botAI.meldAnalyzer.calculateTotalMeldValue(greedy),
          greaterThanOrEqualTo(150),
        );
        expect(
          greedy.length,
          lessThan(8),
          reason: 'stop packing once the 150-point requirement is met',
        );

        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, anyOf('createMeld', 'createMultipleMelds'));
        if (decision.action == 'createMultipleMelds') {
          expect((decision.data as List).length, lessThan(8));
        }
      },
    );

    test(
      'same-rank extra cards at the pile cap still add instead of opening a fifth rank',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = false;
        bot.melds.addAll([
          _sizedMeld(CardRank.ace, size: 7, dirty: false),
          _sizedMeld(CardRank.queen, size: 5, dirty: true),
          _sizedMeld(CardRank.seven, size: 4, dirty: true),
          _sizedMeld(CardRank.five, size: 3, dirty: true),
        ]);
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
          ]);

        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;
        _setPile(controller, size: 12, top: CardRank.jack);

        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, anyOf('addToMeld', 'createMeld'));
        if (decision.action == 'addToMeld') {
          final data = decision.data as Map<String, dynamic>;
          expect((data['card'] as PlayingCard).rank, CardRank.queen);
        } else {
          final cards = decision.data as List<PlayingCard>;
          expect(cards.every((card) => card.rank == CardRank.queen), isTrue);
        }
      },
    );

    test(
      'freezes the pile with a wild when the human can unlock and the bot cannot',
      () {
        human.hasPlayedDown = true;
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = false;
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
            const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
          ]);
        _setPile(controller, size: 14, top: CardRank.king);
        controller.gameState.discardPileFrozen = false;
        controller.gameState.turnPhase = TurnPhase.discard;
        controller.gameState.hasDrawnFromDeck = true;

        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'discard');
        expect((decision.data as PlayingCard).isWild, isTrue);
      },
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

List<PlayingCard> _fourOfEach(List<CardRank> ranks) {
  final cards = <PlayingCard>[];
  for (final rank in ranks) {
    for (final suit in Suit.values) {
      cards.add(PlayingCard(suit: suit, rank: rank));
    }
  }
  return cards;
}
