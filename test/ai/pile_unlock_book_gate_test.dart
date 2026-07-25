@Tags(['pile_unlock_book_gate'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_config.dart';
import 'package:hand_foot_game_flutter/ai/bot_game_context.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Pile unlock before accumulation', () {
    late EnhancedBotAI botAI;
    late GameController gameController;
    late Player human;
    late Player bot;

    setUp(() {
      botAI = EnhancedBotAI(seed: 424242);
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bot = Player(id: 'bot', name: 'Bot', type: PlayerType.bot);
      gameController = GameController(players: [human, bot], seed: 424242);
      gameController.initializeGame();
      botAI.assignPersonality(bot.id, BotPersonality.adaptive);
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      gameController.gameState.currentPlayerIndex = 1;
      gameController.gameState.turnPhase = TurnPhase.draw;
      gameController.gameState.hasDrawnFromDeck = false;
      gameController.gameState.discardPileFrozen = false;
    });

    test(
      'accumulation window does not skip drawFromDiscard when pile is unlockable',
      () {
        // Hand size 10 = inside human accumulation window (8–14)
        bot.hand
          ..clear()
          ..addAll([
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
        expect(bot.currentHand.length, BotConfig.humanAccumulationMinHand + 2);

        gameController.gameState.discardPile
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          ]);

        expect(gameController.gameState.canUnlockDiscard(), isTrue);

        final decision = botAI.makeDecision(bot, gameController);

        expect(
          decision.action,
          equals('drawFromDiscard'),
          reason:
              'unlockable valuable pile must beat accumulation deck short-circuit',
        );
      },
    );

    test(
      'accumulation window still draws from deck when pile is not unlockable',
      () {
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.five),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
            const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          ]);

        // Top card is a three — cannot unlock
        gameController.gameState.discardPile
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
          ]);

        expect(gameController.gameState.canUnlockDiscard(), isFalse);

        final decision = botAI.makeDecision(bot, gameController);
        expect(decision.action, equals('drawFromDeck'));
      },
    );
  });

  group('Book-gated hand-pile completion', () {
    late EnhancedBotAI botAI;
    late GameController gameController;
    late Player human;
    late Player bot;

    setUp(() {
      botAI = EnhancedBotAI(seed: 515151);
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bot = Player(id: 'bot', name: 'Bot', type: PlayerType.bot);
      gameController = GameController(players: [human, bot], seed: 515151);
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

    test('hand size 5 with 0 books and no clear-all skips completion mode', () {
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
        ]);
      bot.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        ])!,
      );
      expect(bot.bookCount, 0);

      expect(botAI.shouldCompleteHandPileForFoot(bot, context()), isFalse);
      expect(botAI.makeCompleteHandPileForFootDecision(bot, context()), isNull);
    });

    test('hand size 4 still rushes to foot without books', () {
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
        ]);

      expect(botAI.shouldCompleteHandPileForFoot(bot, context()), isTrue);
      expect(botAI.shouldRushHandToFoot(bot, context()), isTrue);
    });

    test('botAiVersion bumped for this analytics fix', () {
      expect(BotConfig.botAiVersion, '2026.07-go-out-race-clean-lane');
    });
  });
}
