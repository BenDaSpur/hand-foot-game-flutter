import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_game_context.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

/// Regression tests from Firestore session_17839500130143014 (gameSeed 139404).
///
/// Failure modes: draw-loop hoarding on hand pile, Carl noMeld at hand=3 with 1
/// book while opponent on foot, Alex failing to multi-meld toward foot.
void main() {
  group('Firestore session_17839500130143014 regressions', () {
    const sessionSeed = 139404;

    late EnhancedBotAI botAI;
    late GameController gameController;
    late Player human;
    late Player carl;
    late Player alex;

    setUp(() {
      botAI = EnhancedBotAI(seed: sessionSeed);
      human = Player(id: '1', name: 'You', type: PlayerType.human);
      alex = Player(id: '2', name: 'Alex', type: PlayerType.bot);
      carl = Player(id: '3', name: 'Carl', type: PlayerType.bot);
      gameController = GameController(
        players: [human, alex, carl],
        seed: sessionSeed,
      );
      gameController.initializeGame();
      botAI.assignPersonality(alex.id, BotPersonality.adaptive);
      botAI.assignPersonality(carl.id, BotPersonality.conservative);
    });

    BotGameContext context() =>
        BotGameContext(gameController.gameState, gameController);

    void setCurrentPlayer(Player bot) {
      gameController.gameState.currentPlayerIndex = gameController
          .gameState
          .players
          .indexWhere((p) => p.id == bot.id);
    }

    test('bots still draw from deck at start of turn on small hand pile', () {
      for (final bot in [alex, carl]) {
        bot
          ..hasPlayedDown = true
          ..hasPickedUpFoot = false
          ..hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
            const PlayingCard(suit: Suit.spades, rank: CardRank.six),
          ]);
        setCurrentPlayer(bot);
        gameController.gameState.turnPhase = TurnPhase.draw;
        gameController.gameState.hasDrawnFromDeck = false;

        final decision = botAI.makeDecision(bot, gameController);

        expect(
          decision.action,
          'drawFromDeck',
          reason: '${bot.name} must draw before melding',
        );
      }
    });

    test(
      'Carl conservative melds at hand=3 with 1 book while opponent on foot',
      () {
        human.hasPickedUpFoot = true;
        carl
          ..hasPlayedDown = true
          ..hasPickedUpFoot = false
          ..melds
          ..clear()
          ..addAll([
            Meld.createMeld([
              const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
              const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
              const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
              const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
            ])!,
            Meld.createMeld([
              const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
              const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
            ])!,
          ]);
        carl.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
            const PlayingCard(suit: Suit.spades, rank: CardRank.six),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
          ]);
        setCurrentPlayer(carl);
        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        final decision = botAI.makeDecision(carl, gameController);

        expect(decision.action, isNot('noMeld'));
        expect(
          decision.action,
          anyOf('addToMeld', 'createMeld', 'createMultipleMelds'),
        );
      },
    );

    test(
      'hand pile completion returns null instead of blocking noMeld when stuck',
      () {
        carl
          ..hasPlayedDown = true
          ..hasPickedUpFoot = false
          ..melds
          ..clear()
          ..add(
            Meld.createMeld([
              const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
              const PlayingCard(suit: Suit.spades, rank: CardRank.king),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
            ])!,
          );
        carl.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.six),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          ]);
        setCurrentPlayer(carl);
        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        expect(botAI.shouldCompleteHandPileForFoot(carl, context()), isTrue);

        final completion = botAI.makeCompleteHandPileForFootDecision(
          carl,
          context(),
        );

        expect(completion, isNull);
      },
    );

    test(
      'Alex adaptive uses multi-meld rush at hand=7 with opponent on foot',
      () {
        human.hasPickedUpFoot = true;
        alex
          ..hasPlayedDown = true
          ..hasPickedUpFoot = false
          ..melds.clear();
        alex.hand
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
        setCurrentPlayer(alex);
        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        final decision = botAI.makeDecision(alex, gameController);

        expect(decision.action, isNot('noMeld'));
        expect(
          decision.action,
          anyOf('createMultipleMelds', 'createMeld', 'addToMeld'),
        );
      },
    );
  });
}
