import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_end_game_manager.dart';
import 'package:hand_foot_game_flutter/ai/bot_foot_transition_manager.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Finish round strategy', () {
    late BotEndGameManager endGameManager;
    late EnhancedBotAI botAI;
    late GameController gameController;
    late Player botPlayer;

    Meld cleanBook() {
      return Meld(
        rank: CardRank.ace,
        cards: List.generate(
          7,
          (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.ace),
        ),
        type: MeldType.natural,
      );
    }

    Meld dirtyBook() {
      return Meld(
        rank: CardRank.king,
        cards: [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: null, rank: CardRank.joker),
        ],
        type: MeldType.mixed,
      );
    }

    setUp(() {
      endGameManager = BotEndGameManager();
      botAI = EnhancedBotAI();
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];
      gameController = GameController(players: players);
      botPlayer = players[1];
      botPlayer.hasPlayedDown = true;
      botPlayer.hasPickedUpFoot = true;
      botPlayer.melds.addAll([cleanBook(), dirtyBook()]);
      gameController.gameState.currentPlayerIndex = 1;
    });

    test('discards last card instead of invalid goOut when 1 card remains', () {
      botPlayer.hand.clear();
      botPlayer.foot.clear();
      botPlayer.foot.add(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
      );

      expect(botPlayer.canGoOutWithBooks, isTrue);
      expect(botPlayer.canGoOut, isFalse);

      gameController.gameState.turnPhase = TurnPhase.discard;

      final decision = endGameManager.buildFinishRoundDecision(
        botPlayer,
        gameController,
        TurnPhase.discard,
      );

      expect(decision, isNotNull);
      expect(decision!.action, equals('discard'));
      expect((decision.data as PlayingCard).rank, equals(CardRank.five));
    });

    test('enhanced bot AI discards last card in discard phase', () {
      botPlayer.hand.clear();
      botPlayer.foot.clear();
      botPlayer.foot.add(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
      );
      gameController.gameState.turnPhase = TurnPhase.discard;

      final decision = botAI.makeDecision(botPlayer, gameController);

      expect(decision.action, equals('discard'));
      expect(decision.data, isA<PlayingCard>());
    });

    test('returns goOut only when hand is empty', () {
      botPlayer.hand.clear();
      botPlayer.foot.clear();

      gameController.gameState.turnPhase = TurnPhase.discard;

      final decision = endGameManager.buildFinishRoundDecision(
        botPlayer,
        gameController,
        TurnPhase.discard,
      );

      expect(decision, isNotNull);
      expect(decision!.action, equals('goOut'));
    });

    test(
      'does not aggressively finish when only dirty books exist',
      () {
        botPlayer.melds.clear();
        botPlayer.melds.add(dirtyBook());
        botPlayer.melds.add(
          Meld(
            rank: CardRank.queen,
            cards: [
              const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
              const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
              const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
              const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
            ],
            type: MeldType.mixed,
          ),
        );
        botPlayer.hand.clear();
        botPlayer.foot.clear();
        botPlayer.foot.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
        ]);

        expect(botPlayer.hasDirtyBook, isTrue);
        expect(botPlayer.hasCleanBook, isFalse);
        expect(botPlayer.canGoOutWithBooks, isFalse);

        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        final decision = endGameManager.handleEndGame(
          botPlayer,
          gameController,
        );

        expect(decision, isNotNull);
        expect(decision!.action, isNot('discard'));
        expect(decision.action, isNot('goOut'));
      },
      tags: ['clean_book_regression'],
    );

    test(
      'builds clean book lane when dirty books exist but clean is missing',
      () {
        botPlayer.melds.clear();
        botPlayer.melds.add(dirtyBook());
        botPlayer.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
            const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          ])!,
        );
        botPlayer.hand.clear();
        botPlayer.foot.clear();
        botPlayer.foot.add(
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
        );

        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        final decision = endGameManager.handleEndGame(
          botPlayer,
          gameController,
        );

        expect(decision, isNotNull);
        expect(decision!.action, equals('addToMeld'));
        final addition = decision.data as Map<String, dynamic>;
        expect((addition['card'] as PlayingCard).rank, equals(CardRank.seven));
      },
      tags: ['clean_book_regression'],
    );

    test(
      'rejects meld that leaves a single card without both book types',
      () {
        botPlayer.melds.clear();
        botPlayer.melds.add(dirtyBook());
        botPlayer.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
            const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          ])!,
        );
        botPlayer.hand.clear();
        botPlayer.foot.clear();
        botPlayer.foot.addAll([
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
        ]);

        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        final decision = botAI.makeDecision(botPlayer, gameController);

        expect(decision.action, isNot('addToMeld'));
      },
      tags: ['clean_book_regression'],
    );

    test(
      'allows meld that completes clean book even when one card remains',
      () {
        botPlayer.melds.clear();
        botPlayer.melds.add(dirtyBook());
        botPlayer.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
            const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
            const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          ])!,
        );
        botPlayer.hand.clear();
        botPlayer.foot.clear();
        botPlayer.foot.addAll([
          const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
        ]);

        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        final decision = botAI.makeDecision(botPlayer, gameController);

        expect(decision.action, equals('addToMeld'));
        final addition = decision.data as Map<String, dynamic>;
        expect((addition['card'] as PlayingCard).rank, equals(CardRank.seven));
      },
      tags: ['clean_book_regression'],
    );

    test('post-playdown transition triggers on hand pile with 8+ cards', () {
      final transitionManager = BotFootTransitionManager();
      botPlayer.hasPickedUpFoot = false;
      botPlayer.hand.clear();
      botPlayer.dealHand(
        List.generate(
          9,
          (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.five),
        ),
      );

      gameController.gameState.turnPhase = TurnPhase.discard;

      final decision = transitionManager.handleFootTransition(
        botPlayer,
        gameController,
      );
      expect(decision, isNotNull);
      expect(decision!.action, anyOf('discard', 'createMeld', 'addToMeld'));
    });
  });
}
