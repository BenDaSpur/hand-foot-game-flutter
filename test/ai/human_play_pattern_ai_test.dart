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

    test(
      'accumulates hand instead of incremental melds in 8-14 card window',
      () {
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
          ])!,
        );

        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;

        final decision = botAI.makeDecision(bot, controller);

        expect(
          decision.action,
          'noMeld',
          reason:
              'Human-style bots should hold 8-14 cards before burst-melding',
        );
      },
    );

    test(
      'holds accumulation through 14-card boundary with high meld potential',
      () {
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
          ])!,
        );

        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.meld;
        controller.gameState.hasDrawnFromDeck = true;

        final decision = botAI.makeDecision(bot, controller);

        expect(
          decision.action,
          'noMeld',
          reason:
              '14-card boundary should still accumulate before burst threshold',
        );
        expect(bot.currentHand.length, 14);
      },
    );

    test('prefers low-rank discard on large hands even with duplicates', () {
      final bot = Player(id: 'bot1', name: 'Bot1', type: PlayerType.bot);
      bot.hasPlayedDown = true;
      bot.hand.addAll([
        ...List.generate(
          4,
          (_) => const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        ),
        ...List.generate(
          3,
          (_) => const PlayingCard(suit: Suit.spades, rank: CardRank.five),
        ),
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
      'draws from deck during accumulation instead of unlocking discard pile',
      () {
        final bot = controller.gameState.players.firstWhere(
          (p) => p.id == 'bot1',
        );
        bot.hasPlayedDown = true;
        bot.hand.clear();
        bot.hand.addAll(
          List.generate(
            10,
            (i) => PlayingCard(
              suit: Suit.values[i % 4],
              rank: CardRank.values[(i % 9) + 4],
            ),
          ),
        );

        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.draw;
        controller.gameState.discardPile.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ]);

        final decision = botAI.makeDecision(bot, controller);

        expect(decision.action, 'drawFromDeck');
      },
    );
  });
}
