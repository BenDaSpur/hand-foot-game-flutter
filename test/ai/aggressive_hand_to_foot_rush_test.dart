@Tags(['aggressive_hand_to_foot_rush'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_config.dart';
import 'package:hand_foot_game_flutter/ai/bot_game_context.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Aggressive hand-to-foot rush', () {
    late EnhancedBotAI botAI;
    late GameController gameController;
    late Player human;
    late Player bot;

    const unmeldedRanks = <CardRank>[
      CardRank.four,
      CardRank.five,
      CardRank.six,
      CardRank.seven,
      CardRank.eight,
      CardRank.nine,
      CardRank.ten,
      CardRank.jack,
      CardRank.queen,
      CardRank.ace,
    ];

    const unmeldedSuits = <Suit>[
      Suit.hearts,
      Suit.spades,
      Suit.clubs,
      Suit.diamonds,
    ];

    List<PlayingCard> unmeldedHand(int count) {
      return List<PlayingCard>.generate(
        count,
        (index) => PlayingCard(
          suit: unmeldedSuits[index % unmeldedSuits.length],
          rank: unmeldedRanks[index % unmeldedRanks.length],
        ),
      );
    }

    void setOpponentOnFoot({required int footCardCount}) {
      human.hasPickedUpFoot = true;
      human.dealFoot(unmeldedHand(footCardCount));
    }

    void configureBot({
      required BotPersonality personality,
      required int handSize,
      bool opponentOnFoot = false,
      int opponentFootCards = 7,
    }) {
      botAI.assignPersonality(bot.id, personality);
      bot.hand.clear();
      bot.melds.clear();
      bot.hand.addAll(unmeldedHand(handSize));
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      human.hasPickedUpFoot = false;
      human.foot.clear();
      if (opponentOnFoot) {
        setOpponentOnFoot(footCardCount: opponentFootCards);
      }
      gameController.gameState.currentPlayerIndex = 1;
      gameController.gameState.turnPhase = TurnPhase.meld;
      gameController.gameState.hasDrawnFromDeck = true;
    }

    BotGameContext context() =>
        BotGameContext(gameController.gameState, gameController);

    setUp(() {
      botAI = EnhancedBotAI(seed: 577904);
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bot = Player(id: 'bot', name: 'Bot', type: PlayerType.bot);
      gameController = GameController(players: [human, bot], seed: 577904);
      gameController.initializeGame();
    });

    group('shouldRushHandToFoot boundaries', () {
      test('critical hand size rushes at 4 but not 5', () {
        configureBot(
          personality: BotPersonality.conservative,
          handSize: BotConfig.handToFootCriticalHandSize,
        );
        expect(
          botAI.shouldRushHandToFoot(bot, context()),
          isTrue,
          reason:
              'critical threshold should rush at ${BotConfig.handToFootCriticalHandSize}',
        );

        configureBot(
          personality: BotPersonality.conservative,
          handSize: BotConfig.handToFootCriticalHandSize + 1,
        );
        expect(
          botAI.shouldRushHandToFoot(bot, context()),
          isFalse,
          reason:
              'critical threshold should not rush above ${BotConfig.handToFootCriticalHandSize}',
        );
      });

      test('opponent-on-foot pressure rushes at 8 but not 9', () {
        configureBot(
          personality: BotPersonality.conservative,
          handSize: BotConfig.handToFootRushOpponentOnFootThreshold,
          opponentOnFoot: true,
        );
        expect(
          botAI.shouldRushHandToFoot(bot, context()),
          isTrue,
          reason:
              'opponent foot pressure should rush at ${BotConfig.handToFootRushOpponentOnFootThreshold}',
        );

        configureBot(
          personality: BotPersonality.conservative,
          handSize: BotConfig.handToFootRushOpponentOnFootThreshold + 1,
          opponentOnFoot: true,
        );
        expect(
          botAI.shouldRushHandToFoot(bot, context()),
          isFalse,
          reason:
              'opponent foot pressure should not rush above ${BotConfig.handToFootRushOpponentOnFootThreshold}',
        );
      });

      test(
        'aggressive personality rushes at 6 but not 7 without opponent pressure',
        () {
          configureBot(
            personality: BotPersonality.aggressive,
            handSize: BotConfig.handToFootRushAggressiveThreshold,
          );
          expect(
            botAI.shouldRushHandToFoot(bot, context()),
            isTrue,
            reason:
                'aggressive bots should rush at ${BotConfig.handToFootRushAggressiveThreshold}',
          );

          configureBot(
            personality: BotPersonality.aggressive,
            handSize: BotConfig.handToFootRushAggressiveThreshold + 1,
          );
          expect(
            botAI.shouldRushHandToFoot(bot, context()),
            isFalse,
            reason:
                'aggressive bots should not rush above ${BotConfig.handToFootRushAggressiveThreshold} without pressure',
          );
        },
      );

      test(
        'aggressive with opponent on foot rushes at margin threshold but not above',
        () {
          final rushAtMargin =
              BotConfig.handToFootRushOpponentOnFootThreshold +
              BotConfig.handToFootRushAggressiveOpponentPressureMargin;

          configureBot(
            personality: BotPersonality.aggressive,
            handSize: rushAtMargin,
            opponentOnFoot: true,
          );
          expect(
            botAI.shouldRushHandToFoot(bot, context()),
            isTrue,
            reason:
                'aggressive bots should rush at opponent margin $rushAtMargin',
          );

          configureBot(
            personality: BotPersonality.aggressive,
            handSize: rushAtMargin + 1,
            opponentOnFoot: true,
          );
          expect(
            botAI.shouldRushHandToFoot(bot, context()),
            isFalse,
            reason: 'aggressive bots should not rush above opponent margin',
          );
        },
      );
    });

    group('makeHandToFootRushDecision', () {
      test('returns discard rush action below threshold, null above', () {
        configureBot(
          personality: BotPersonality.conservative,
          handSize: BotConfig.handToFootCriticalHandSize,
        );

        final rushDecision = botAI.makeHandToFootRushDecision(bot, context());
        expect(rushDecision, isNotNull);
        expect(rushDecision!.action, equals('noMeld'));

        configureBot(
          personality: BotPersonality.conservative,
          handSize: BotConfig.handToFootCriticalHandSize + 1,
        );
        expect(botAI.makeHandToFootRushDecision(bot, context()), isNull);
      });

      test('opponent pressure boundary returns rush discard at 8 only', () {
        configureBot(
          personality: BotPersonality.conservative,
          handSize: BotConfig.handToFootRushOpponentOnFootThreshold,
          opponentOnFoot: true,
        );

        final rushAtThreshold = botAI.makeHandToFootRushDecision(
          bot,
          context(),
        );
        expect(rushAtThreshold, isNotNull);
        expect(rushAtThreshold!.action, equals('noMeld'));

        configureBot(
          personality: BotPersonality.conservative,
          handSize: BotConfig.handToFootRushOpponentOnFootThreshold + 1,
          opponentOnFoot: true,
        );
        expect(botAI.makeHandToFootRushDecision(bot, context()), isNull);
      });

      test('aggressive boundary returns rush discard at 6 only', () {
        configureBot(
          personality: BotPersonality.aggressive,
          handSize: BotConfig.handToFootRushAggressiveThreshold,
        );

        final rushAtThreshold = botAI.makeHandToFootRushDecision(
          bot,
          context(),
        );
        expect(rushAtThreshold, isNotNull);
        expect(rushAtThreshold!.action, equals('noMeld'));

        configureBot(
          personality: BotPersonality.aggressive,
          handSize: BotConfig.handToFootRushAggressiveThreshold + 1,
        );
        expect(botAI.makeHandToFootRushDecision(bot, context()), isNull);
      });

      test('aggressive opponent margin returns rush discard at 10 only', () {
        final rushAtMargin =
            BotConfig.handToFootRushOpponentOnFootThreshold +
            BotConfig.handToFootRushAggressiveOpponentPressureMargin;

        configureBot(
          personality: BotPersonality.aggressive,
          handSize: rushAtMargin,
          opponentOnFoot: true,
        );

        final rushAtThreshold = botAI.makeHandToFootRushDecision(
          bot,
          context(),
        );
        expect(rushAtThreshold, isNotNull);
        expect(rushAtThreshold!.action, equals('noMeld'));

        configureBot(
          personality: BotPersonality.aggressive,
          handSize: rushAtMargin + 1,
          opponentOnFoot: true,
        );
        expect(botAI.makeHandToFootRushDecision(bot, context()), isNull);
      });
    });

    group('makeDecision integration', () {
      test('uses hand-to-foot rush below opponent threshold, not above', () {
        configureBot(
          personality: BotPersonality.conservative,
          handSize: BotConfig.handToFootRushOpponentOnFootThreshold,
          opponentOnFoot: true,
        );

        expect(botAI.makeHandToFootRushDecision(bot, context()), isNotNull);
        final belowThresholdDecision = botAI.makeDecision(bot, gameController);
        expect(belowThresholdDecision.action, equals('noMeld'));

        gameController.gameState.turnPhase = TurnPhase.discard;
        final discardDecision = botAI.makeDecision(bot, gameController);
        expect(discardDecision.action, equals('discard'));
        expect(discardDecision.data, isA<PlayingCard>());

        configureBot(
          personality: BotPersonality.conservative,
          handSize: BotConfig.handToFootRushOpponentOnFootThreshold + 1,
          opponentOnFoot: true,
        );

        final aboveThresholdDecision = botAI.makeDecision(bot, gameController);
        expect(
          botAI.makeHandToFootRushDecision(bot, context()),
          isNull,
          reason: 'rush hook must be inactive above opponent threshold',
        );
        expect(aboveThresholdDecision.action, equals('noMeld'));

        gameController.gameState.turnPhase = TurnPhase.discard;
        expect(
          botAI.makeDecision(bot, gameController).action,
          equals('discard'),
          reason: 'foot transition still discards above rush threshold',
        );
      });

      test(
        'aggressive bot rushes via makeDecision at 6 but rush hook is null at 7',
        () {
          configureBot(
            personality: BotPersonality.aggressive,
            handSize: BotConfig.handToFootRushAggressiveThreshold,
          );

          expect(botAI.makeHandToFootRushDecision(bot, context()), isNotNull);
          final belowThresholdDecision = botAI.makeDecision(
            bot,
            gameController,
          );
          expect(belowThresholdDecision.action, equals('noMeld'));

          gameController.gameState.turnPhase = TurnPhase.discard;
          expect(
            botAI.makeDecision(bot, gameController).action,
            equals('discard'),
          );

          configureBot(
            personality: BotPersonality.aggressive,
            handSize: BotConfig.handToFootRushAggressiveThreshold + 1,
          );

          expect(botAI.makeHandToFootRushDecision(bot, context()), isNull);
          final aboveThresholdDecision = botAI.makeDecision(
            bot,
            gameController,
          );
          expect(aboveThresholdDecision.action, equals('noMeld'));

          gameController.gameState.turnPhase = TurnPhase.discard;
          expect(
            botAI.makeDecision(bot, gameController).action,
            equals('discard'),
            reason:
                'foot transition still discards above aggressive rush threshold',
          );
        },
      );

      test(
        'critical hand rushes via makeDecision at 4 but rush hook is null at 5',
        () {
          configureBot(
            personality: BotPersonality.conservative,
            handSize: BotConfig.handToFootCriticalHandSize,
          );

          expect(botAI.makeHandToFootRushDecision(bot, context()), isNotNull);
          final belowThresholdDecision = botAI.makeDecision(
            bot,
            gameController,
          );
          expect(belowThresholdDecision.action, equals('noMeld'));

          gameController.gameState.turnPhase = TurnPhase.discard;
          expect(
            botAI.makeDecision(bot, gameController).action,
            equals('discard'),
          );

          configureBot(
            personality: BotPersonality.conservative,
            handSize: BotConfig.handToFootCriticalHandSize + 1,
          );

          expect(botAI.makeHandToFootRushDecision(bot, context()), isNull);
          final aboveThresholdDecision = botAI.makeDecision(
            bot,
            gameController,
          );
          expect(aboveThresholdDecision.action, equals('noMeld'));

          gameController.gameState.turnPhase = TurnPhase.discard;
          expect(
            botAI.makeDecision(bot, gameController).action,
            equals('discard'),
            reason:
                'foot transition still discards above critical rush threshold',
          );
        },
      );
    });
  });
}
