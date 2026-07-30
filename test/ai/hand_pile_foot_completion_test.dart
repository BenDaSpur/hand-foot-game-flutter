@Tags(['hand_pile_foot_completion'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_game_context.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/config/solo_game_settings.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Hand pile foot completion', () {
    late EnhancedBotAI botAI;
    late GameController gameController;
    late Player human;
    late Player bot;

    setUp(() {
      botAI = EnhancedBotAI(seed: 398170);
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bot = Player(id: 'bot', name: 'Bot', type: PlayerType.bot);
      gameController = GameController(players: [human, bot], seed: 398170);
      gameController.initializeGame();
      botAI.assignPersonality(bot.id, BotPersonality.conservative);
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      gameController.gameState.currentPlayerIndex = 1;
      gameController.gameState.turnPhase = TurnPhase.meld;
      gameController.gameState.hasDrawnFromDeck = true;
    });

    BotGameContext context() =>
        BotGameContext(gameController.gameState, gameController);

    test(
      'shouldCompleteHandPileForFoot at critical 4 but not soft 5 without books',
      () {
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.five),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
          ]);

        expect(botAI.shouldCompleteHandPileForFoot(bot, context()), isTrue);

        bot.hand.add(
          const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
        );
        // Soft window (5) with 0 books and no clear-all — stay on normal meld scoring
        expect(botAI.shouldCompleteHandPileForFoot(bot, context()), isFalse);

        bot.hand.add(const PlayingCard(suit: Suit.spades, rank: CardRank.nine));
        expect(botAI.shouldCompleteHandPileForFoot(bot, context()), isFalse);
      },
    );

    test('shouldCompleteHandPileForFoot at 5 when bot already has a book', () {
      bot.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        ])!,
      );
      expect(bot.bookCount, 1);

      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
        ]);

      expect(botAI.shouldCompleteHandPileForFoot(bot, context()), isTrue);
    });

    test('shouldCompleteHandPileForFoot at 5 when clear-all path exists', () {
      // Five of a kind can be melded in one action — clear-all gates soft window.
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
        ]);

      expect(botAI.shouldCompleteHandPileForFoot(bot, context()), isTrue);
    });

    test(
      'uses createMultipleMelds to clear hand with two melds plus discard',
      () {
        human.hasPickedUpFoot = true;
        // Soft / opponent-pressure completion requires a book or clear-all path
        bot.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
          ])!,
        );
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
            const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.eight),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
            const PlayingCard(suit: Suit.spades, rank: CardRank.eight),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          ]);

        final decision = botAI.makeCompleteHandPileForFootDecision(
          bot,
          context(),
        );

        expect(decision, isNotNull);
        expect(decision!.action, 'createMultipleMelds');
      },
    );

    test(
      'does not strategically hold during hand-pile foot completion window',
      () {
        human.hasPickedUpFoot = true;
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.four),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.six),
          ]);
        bot.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          ])!,
        );

        expect(botAI.shouldCompleteHandPileForFoot(bot, context()), isTrue);

        final decision = botAI.makeDecision(bot, gameController);

        expect(decision.action, isNot('noMeld'));
      },
    );

    test(
      'makeCompleteHandPileForFootDecision defers discard when no melds in meld phase',
      () {
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.six),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          ]);
        bot.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          ])!,
        );

        final decision = botAI.makeCompleteHandPileForFootDecision(
          bot,
          context(),
        );

        expect(decision?.action, 'noMeld');

        gameController.gameState.turnPhase = TurnPhase.discard;
        final discardDecision = botAI.makeDecision(bot, gameController);
        expect(discardDecision.action, 'discard');
      },
    );

    test(
      'conservative bot does not hold at 8 cards with melds but zero books',
      () {
        bot.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
            const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          ])!,
        );
        bot.hand
          ..clear()
          ..addAll(
            List<PlayingCard>.generate(
              8,
              (i) => PlayingCard(
                suit: Suit.values[i % 4],
                rank: CardRank.values[(i % 10) + 2],
              ),
            ),
          );

        final decision = botAI.makeDecision(bot, gameController);

        expect(decision.action, isNot('noMeld'));
      },
    );
  });

  group('Final turn scoring', () {
    late EnhancedBotAI botAI;
    late GameController gameController;
    late Player human;
    late Player bot;

    setUp(() {
      botAI = EnhancedBotAI(seed: 12345);
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bot = Player(id: 'bot', name: 'Bot', type: PlayerType.bot);
      gameController = GameController(
        players: [human, bot],
        seed: 12345,
        soloSettings: SoloGameSettings.defaults,
      );
      gameController.initializeGame();
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;
      gameController.gameState.currentPlayerIndex = 1;
      gameController.gameState.turnPhase = TurnPhase.meld;
      gameController.gameState.hasDrawnFromDeck = true;
      gameController.gameState.finalTurnPhaseActive = true;
      gameController.gameState.playersAwaitingFinalTurn.add(1);
      gameController.gameState.playerWhoWentOutIndex = 0;
    });

    BotGameContext context() =>
        BotGameContext(gameController.gameState, gameController);

    test('final turn melds addToMeld instead of holding', () {
      bot.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ])!,
      );
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
        ]);

      final decision = botAI.makeFinalTurnScoringDecision(bot, context());

      expect(decision.action, isIn(['addToMeld', 'createMeld']));
    });

    test(
      'makeDecision routes to final turn scoring when awaiting final turn',
      () {
        bot.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
            const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
          ])!,
        );
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
          ]);

        final decision = botAI.makeDecision(bot, gameController);

        expect(decision.action, isIn(['addToMeld', 'createMeld', 'noMeld']));
        expect(decision.action, isNot('drawFromDeck'));
      },
    );

    test('final turn draw phase draws from deck', () {
      gameController.gameState.turnPhase = TurnPhase.draw;
      gameController.gameState.hasDrawnFromDeck = false;
      bot.hand
        ..clear()
        ..add(const PlayingCard(suit: Suit.hearts, rank: CardRank.five));

      final decision = botAI.makeFinalTurnScoringDecision(bot, context());
      expect(decision.action, 'drawFromDeck');

      final routeDecision = botAI.makeDecision(bot, gameController);
      expect(routeDecision.action, 'drawFromDeck');
    });

    test('final turn discard phase discards without drawing', () {
      gameController.gameState.turnPhase = TurnPhase.discard;
      gameController.gameState.hasDrawnFromDeck = true;
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.six),
        ]);

      final decision = botAI.makeFinalTurnScoringDecision(bot, context());
      expect(decision.action, 'discard');

      final routeDecision = botAI.makeDecision(bot, gameController);
      expect(routeDecision.action, 'discard');
      expect(routeDecision.action, isNot('drawFromDeck'));
    });
  });
}
