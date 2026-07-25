@Tags(['clean_book_first'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_config.dart';
import 'package:hand_foot_game_flutter/ai/bot_end_game_manager.dart';
import 'package:hand_foot_game_flutter/ai/bot_meld_analyzer.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Clean-book-first AI (2026.07-clean-book-first)', () {
    late BotEndGameManager endGameManager;
    late EnhancedBotAI botAI;
    late BotMeldAnalyzer analyzer;
    late GameController gameController;
    late Player botPlayer;

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

    setUp(() {
      endGameManager = BotEndGameManager();
      botAI = EnhancedBotAI(seed: 42);
      analyzer = BotMeldAnalyzer();
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];
      gameController = GameController(players: players, seed: 42);
      botPlayer = players[1];
      botAI.assignPersonality(botPlayer.id, BotPersonality.adaptive);
      botPlayer.hasPlayedDown = true;
      botPlayer.hasPickedUpFoot = true;
      gameController.gameState.currentPlayerIndex = 1;
    });

    test('botAiVersion bumped for go-out-race-clean-lane', () {
      expect(BotConfig.botAiVersion, '2026.07-go-out-race-clean-lane');
    });

    test(
      'adds naturals to incomplete natural pile when clean book missing',
      () {
        // Regression: Meld.isClean is false for size < 7, so old code never
        // extended in-progress natural piles toward a clean book.
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

        expect(BotMeldAnalyzer.isAllNatural(botPlayer.melds[1]), isTrue);
        expect(botPlayer.melds[1].isClean, isFalse); // not a completed book

        botPlayer.hand.clear();
        botPlayer.foot.clear();
        botPlayer.foot.addAll([
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
        ]);

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
        expect(addition['meldIndex'], equals(1));
      },
      tags: ['clean_book_first'],
    );

    test(
      'hard-blocks wild onto only natural near-book without clean book',
      () {
        botPlayer.melds.clear();
        botPlayer.melds.add(dirtyBook());
        botPlayer.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          ])!,
        );

        botPlayer.hand.clear();
        botPlayer.foot.clear();
        botPlayer.foot.add(
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.two),
        );

        expect(botPlayer.hasCleanBook, isFalse);

        final options = analyzer.findCardsToAddToExistingMelds(
          botPlayer,
          gameController,
        );
        final wildOntoNatural = options.where((o) {
          final card = o['card'] as PlayingCard;
          final meld = o['meld'] as Meld;
          return card.isWild && BotMeldAnalyzer.isAllNatural(meld);
        }).toList();

        expect(wildOntoNatural, isNotEmpty);
        for (final option in wildOntoNatural) {
          expect(
            option['priority'] as int,
            lessThanOrEqualTo(-50000),
            reason: 'Must not contaminate natural pile before clean book',
          );
        }

        // Wild onto already-dirty book remains allowed (not hard-blocked)
        final wildOntoDirty = options.where((o) {
          final card = o['card'] as PlayingCard;
          final meld = o['meld'] as Meld;
          return card.isWild && !BotMeldAnalyzer.isAllNatural(meld);
        }).toList();
        expect(wildOntoDirty, isNotEmpty);
        expect(wildOntoDirty.first['priority'] as int, greaterThan(-50000));
      },
      tags: ['clean_book_first'],
    );

    test(
      'refuses last-card discard on foot without go-out books',
      () {
        botPlayer.melds.clear();
        botPlayer.melds.add(dirtyBook());
        botPlayer.melds.add(
          Meld(
            rank: CardRank.ten,
            cards: [
              const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
              const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
              const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
              const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.two),
            ],
            type: MeldType.mixed,
          ),
        );

        botPlayer.hand.clear();
        botPlayer.foot.clear();
        botPlayer.foot.add(
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        );

        expect(botPlayer.hasDirtyBook, isTrue);
        expect(botPlayer.hasCleanBook, isFalse);
        expect(botPlayer.canGoOutWithBooks, isFalse);

        gameController.gameState.turnPhase = TurnPhase.discard;
        gameController.gameState.hasDrawnFromDeck = true;

        final endDecision = endGameManager.handleEndGame(
          botPlayer,
          gameController,
        );
        expect(endDecision, isNotNull);
        expect(endDecision!.action, equals('endTurn'));
        expect(endDecision.action, isNot('discard'));

        final aiDecision = botAI.makeDecision(botPlayer, gameController);
        expect(aiDecision.action, isNot('discard'));
        expect(aiDecision.action, anyOf(equals('endTurn'), equals('error')));
      },
      tags: ['clean_book_first'],
    );

    test(
      'does not strategic-hold with both books and tiny foot hand',
      () {
        botPlayer.melds.clear();
        botPlayer.melds.addAll([cleanBook(), dirtyBook()]);
        botPlayer.hand.clear();
        botPlayer.foot.clear();
        botPlayer.foot.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.eight),
        ]);

        expect(botPlayer.canGoOutWithBooks, isTrue);
        expect(botPlayer.currentHand.length, equals(2));

        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        final decision = botAI.makeDecision(botPlayer, gameController);

        // Finish path: noMeld (then discard) or direct meld/discard — never
        // a long strategic hold that blocks going out.
        expect(decision.action, isNot('error'));
        if (decision.action == 'noMeld') {
          // noMeld is OK when preparing to discard for go-out
          expect(botPlayer.canGoOutWithBooks, isTrue);
        } else {
          expect(
            decision.action,
            anyOf(
              equals('discard'),
              equals('addToMeld'),
              equals('createMeld'),
              equals('goOut'),
            ),
          );
        }

        // Explicitly: holding reasoning should not apply via makeDecision
        // when eligible to finish — discard phase should discard.
        gameController.gameState.turnPhase = TurnPhase.discard;
        final discardDecision = botAI.makeDecision(botPlayer, gameController);
        expect(discardDecision.action, equals('discard'));
      },
      tags: ['clean_book_first'],
    );

    test(
      'completes six-card natural pile into clean book before dirty inflation',
      () {
        botPlayer.melds.clear();
        botPlayer.melds.add(dirtyBook());
        botPlayer.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.four),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            const PlayingCard(suit: Suit.spades, rank: CardRank.four),
          ])!,
        );

        botPlayer.hand.clear();
        botPlayer.foot.clear();
        botPlayer.foot.addAll([
          const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.two),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
        ]);

        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        final decision = endGameManager.handleEndGame(
          botPlayer,
          gameController,
        );

        expect(decision, isNotNull);
        expect(decision!.action, equals('addToMeld'));
        final addition = decision.data as Map<String, dynamic>;
        final card = addition['card'] as PlayingCard;
        expect(card.rank, equals(CardRank.four));
        expect(card.isWild, isFalse);
      },
      tags: ['clean_book_first'],
    );
  });
}
