@Tags(['human_play_pattern_ai'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_config.dart';
import 'package:hand_foot_game_flutter/ai/bot_discard_analyzer.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Human play pattern AI', () {
    late EnhancedBotAI botAI;
    late GameController controller;
    late BotDiscardAnalyzer discardAnalyzer;

    setUp(() {
      botAI = EnhancedBotAI(seed: 99);
      discardAnalyzer = BotDiscardAnalyzer();
      controller = GameController(
        players: [
          Player(id: 'human', name: 'Human', type: PlayerType.human),
          Player(id: 'bot1', name: 'Bot1', type: PlayerType.bot),
          Player(id: 'bot2', name: 'Bot2', type: PlayerType.bot),
        ],
        seed: 99,
      );
    });

    test('melds in the old 8-14 accumulation window instead of holding', () {
      final bot = controller.gameState.players.firstWhere(
        (p) => p.id == 'bot1',
      );
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand.clear();
      bot.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        const PlayingCard(suit: Suit.spades, rank: CardRank.four),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        const PlayingCard(suit: Suit.spades, rank: CardRank.six),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
        const PlayingCard(suit: Suit.spades, rank: CardRank.eight),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
      ]);
      bot.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        ])!,
      );

      controller.gameState.currentPlayerIndex = 1;
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;

      final decision = botAI.makeDecision(bot, controller);

      expect(
        decision.action,
        anyOf('createMeld', 'addToMeld', 'createMultipleMelds'),
        reason:
            'Competitive planner melds book progress instead of holding 8-14',
      );
    });

    test('melds at the 14-card boundary instead of waiting to burst', () {
      final bot = controller.gameState.players.firstWhere(
        (p) => p.id == 'bot1',
      );
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand.clear();
      bot.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        const PlayingCard(suit: Suit.spades, rank: CardRank.four),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        const PlayingCard(suit: Suit.spades, rank: CardRank.five),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.six),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
        const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      ]);
      bot.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        ])!,
      );

      controller.gameState.currentPlayerIndex = 1;
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;

      final decision = botAI.makeDecision(bot, controller);

      expect(
        decision.action,
        anyOf('createMeld', 'addToMeld', 'createMultipleMelds'),
        reason: '14-card hands with meld potential should play, not hold',
      );
      expect(bot.currentHand.length, 14);
    });

    test('bursts at 15-card threshold with high meld potential', () {
      final bot = controller.gameState.players.firstWhere(
        (p) => p.id == 'bot1',
      );
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.hand.clear();
      bot.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        const PlayingCard(suit: Suit.spades, rank: CardRank.four),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        const PlayingCard(suit: Suit.spades, rank: CardRank.five),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.six),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
        const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
      ]);
      bot.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        ])!,
      );

      controller.gameState.currentPlayerIndex = 1;
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;

      final decision = botAI.makeDecision(bot, controller);

      expect(
        decision.action,
        anyOf('addToMeld', 'createMeld', 'createMultipleMelds'),
        reason: '15-card hand should meld instead of holding',
      );
      expect(bot.currentHand.length, 15);
    });

    test('prefers low-rank discard on large hands even with duplicates', () {
      final bot = Player(id: 'bot1', name: 'Bot1', type: PlayerType.bot);
      bot.hasPlayedDown = true;
      bot.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        const PlayingCard(suit: Suit.spades, rank: CardRank.four),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        const PlayingCard(suit: Suit.spades, rank: CardRank.five),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
        ...List.generate(
          8,
          (i) => PlayingCard(
            suit: Suit.values[i % 4],
            rank: CardRank.values[(i % 7) + 6],
          ),
        ),
      ]);

      final discard = discardAnalyzer.chooseCardToDiscard(
        bot,
        controller.gameState,
      );

      expect(
        discard.rank,
        anyOf(CardRank.four, CardRank.five),
        reason: 'Humans shed low ranks on ~16-card hands',
      );
      expect(
        bot.currentHand.length,
        greaterThanOrEqualTo(BotConfig.humanLargeHandDiscardThreshold),
      );
    });

    test(
      'takes an eligible keyed pile instead of accumulating from the deck',
      () {
        final bot = controller.gameState.players.firstWhere(
          (p) => p.id == 'bot1',
        );
        bot.hasPlayedDown = true;
        bot.hand.clear();
        bot.hand.addAll([
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

        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.draw;
        controller.gameState.hasDrawnFromDeck = false;
        controller.gameState.discardPileFrozen = false;
        controller.gameState.discardPile
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
            const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          ]);

        expect(controller.gameState.canUnlockDiscard(), isTrue);
        final decision = botAI.makeDecision(bot, controller);
        expect(decision.action, 'drawFromDiscard');
      },
    );
  });
}
