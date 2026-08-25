@Tags(['human_counter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_config.dart';
import 'package:hand_foot_game_flutter/ai/bot_discard_analyzer.dart';
import 'package:hand_foot_game_flutter/ai/bot_game_context.dart';
import 'package:hand_foot_game_flutter/ai/bot_meld_analyzer.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

/// Regressions from completed + incomplete `2026.08-unlock-churn` games.
void main() {
  group('Human-counter AI (2026.08-human-counter)', () {
    late EnhancedBotAI botAI;
    late GameController controller;
    late Player human;
    late Player bot;
    late BotDiscardAnalyzer discardAnalyzer;

    setUp(() {
      botAI = EnhancedBotAI(seed: 20260820);
      discardAnalyzer = BotDiscardAnalyzer();
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bot = Player(id: 'bot', name: 'Adaptive', type: PlayerType.bot);
      controller = GameController(players: [human, bot], seed: 20260820);
      controller.initializeGame();
      botAI.assignPersonality(bot.id, BotPersonality.adaptive);
      controller.gameState.currentPlayerIndex = 1;
    });

    test('botAiVersion is hand-pile-empty', () {
      expect(BotConfig.botAiVersion, '2026.08-hand-pile-empty');
      expect(BotConfig.goOutThisTurnMaxHand, 5);
      expect(BotConfig.genericUnlockKeyHoldPenalty, 90);
      expect(BotConfig.booklessFarmForceFootMaxHand, 8);
    });

    test('foot with 8 cards and keys hard-takes a 30-card pile', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;
      bot.foot
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
          const PlayingCard(suit: Suit.spades, rank: CardRank.eight),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        ]);
      bot.melds.addAll([
        _book(CardRank.ace, dirty: false),
        _book(CardRank.king, dirty: true),
        _book(CardRank.queen, dirty: true),
      ]);

      controller.gameState.discardPile
        ..clear()
        ..addAll(
          List.generate(
            29,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ace),
          ),
        )
        ..add(const PlayingCard(suit: Suit.clubs, rank: CardRank.eight));

      controller.gameState.turnPhase = TurnPhase.draw;
      controller.gameState.hasDrawnFromDeck = false;
      controller.gameState.discardPileFrozen = false;
      human.hand.addAll(
        List.generate(
          20,
          (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.five),
        ),
      );

      expect(controller.gameState.canUnlockDiscard(), isTrue);
      expect(botAI.makeDecision(bot, controller).action, 'drawFromDiscard');
    });

    test('keeps last 4-pair and dumps a singleton seven', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.four),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        ]);

      controller.gameState.discardPile
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        ]);

      final discard = discardAnalyzer.chooseCardToDiscard(
        bot,
        controller.gameState,
      );
      expect(discard.rank, isNot(CardRank.four));
    });

    test('accumulation window still unlocks a size-6 keyed pile', () {
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
      bot.melds.add(_book(CardRank.ace, dirty: true));

      controller.gameState.discardPile
        ..clear()
        ..addAll(
          List.generate(
            5,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ace),
          ),
        )
        ..add(const PlayingCard(suit: Suit.clubs, rank: CardRank.king));

      controller.gameState.turnPhase = TurnPhase.draw;
      controller.gameState.hasDrawnFromDeck = false;
      controller.gameState.discardPileFrozen = false;

      expect(controller.gameState.canUnlockDiscard(), isTrue);
      expect(botAI.makeDecision(bot, controller).action, 'drawFromDiscard');
    });

    test('meld-phase decision does not skip the next keyed unlock', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ]);
      bot.melds.add(_book(CardRank.ace, dirty: true));

      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;
      botAI.makeDecision(bot, controller);

      controller.gameState.discardPile
        ..clear()
        ..addAll(
          List.generate(
            33,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ace),
          ),
        )
        ..add(const PlayingCard(suit: Suit.clubs, rank: CardRank.nine));
      controller.gameState.turnPhase = TurnPhase.draw;
      controller.gameState.hasDrawnFromDeck = false;
      controller.gameState.discardPileFrozen = false;

      expect(controller.gameState.canUnlockDiscard(), isTrue);
      expect(botAI.makeDecision(bot, controller).action, 'drawFromDiscard');
    });

    test('go-out-ready with 2 cards discards instead of holding', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;
      bot.foot
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
        ]);
      bot.melds.addAll([
        _book(CardRank.ace, dirty: false),
        _book(CardRank.king, dirty: true),
      ]);

      controller.gameState.turnPhase = TurnPhase.discard;
      controller.gameState.hasDrawnFromDeck = true;
      expect(botAI.makeDecision(bot, controller).action, 'discard');
    });

    test('bookless 2-card hand pile completes to foot when pile is fat', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
        ]);
      controller.gameState.discardPile
        ..clear()
        ..addAll(
          List.generate(
            38,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.four),
          ),
        );
      human.hasPlayedDown = true;
      human.hasPickedUpFoot = true;
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;

      expect(
        botAI.shouldCompleteHandPileForFoot(
          bot,
          BotGameContext(controller.gameState, controller),
        ),
        isTrue,
      );

      controller.gameState.turnPhase = TurnPhase.discard;
      expect(botAI.makeDecision(bot, controller).action, 'discard');
    });

    test('bookless 6-card hand pile completes to foot when pile is fat', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
        ]);
      controller.gameState.discardPile
        ..clear()
        ..addAll(
          List.generate(
            38,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.four),
          ),
        );
      human.hasPlayedDown = true;
      human.hasPickedUpFoot = false;
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;

      final context = BotGameContext(controller.gameState, controller);
      expect(botAI.shouldCompleteHandPileForFoot(bot, context), isTrue);
      expect(botAI.shouldRushHandToFoot(bot, context), isTrue);
    });

    test(
      'no live top keys still melds when only option spends last 4-8 pair',
      () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = false;
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.four),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          ]);
        controller.gameState.discardPile
          ..clear()
          ..addAll(
            List.generate(
              8,
              (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ten),
            ),
          )
          ..add(const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace));
        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;
        controller.gameState.discardPileFrozen = false;

        final foursOnly = [
          [
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.four),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          ],
        ];
        final filtered = BotMeldAnalyzer.filterUnlockKeyMeldCandidates(
          bot,
          controller.gameState,
          foursOnly,
        );
        expect(filtered, isNotEmpty);
        expect(filtered.first.every((c) => c.rank == CardRank.four), isTrue);

        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'createMeld');
        final meld = decision.data as List<PlayingCard>;
        expect(meld.every((c) => c.rank == CardRank.four), isTrue);
      },
    );

    test('bookless 5-card hand pile stays off foot when pile is small', () {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
        ]);
      controller.gameState.discardPile
        ..clear()
        ..add(const PlayingCard(suit: Suit.clubs, rank: CardRank.nine));
      human.hasPlayedDown = true;
      human.hasPickedUpFoot = false;
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;

      final context = BotGameContext(controller.gameState, controller);
      expect(botAI.shouldCompleteHandPileForFoot(bot, context), isFalse);
      expect(botAI.shouldRushHandToFoot(bot, context), isFalse);
    });
  });
}

Meld _book(CardRank rank, {required bool dirty}) {
  final cards = <PlayingCard>[
    PlayingCard(suit: Suit.hearts, rank: rank),
    PlayingCard(suit: Suit.spades, rank: rank),
    PlayingCard(suit: Suit.clubs, rank: rank),
    PlayingCard(suit: Suit.diamonds, rank: rank),
    PlayingCard(suit: Suit.hearts, rank: rank),
    PlayingCard(suit: Suit.spades, rank: rank),
    PlayingCard(suit: Suit.clubs, rank: dirty ? CardRank.two : rank),
  ];
  return Meld.createMeld(cards)!;
}
