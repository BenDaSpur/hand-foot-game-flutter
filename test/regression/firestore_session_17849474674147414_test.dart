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

/// Regressions from production session_17849474674147414 (round 1, gameSeed
/// 279181): the human hoarded 34 cards after a minimal play-down, the
/// adaptive bot put wilds in every meld it created (never go-out eligible,
/// two hand=0 `error` states), and the go-out-ready conservative bot stalled
/// for 6 minutes and took the discard pile mid-race.
void main() {
  late EnhancedBotAI botAI;
  late GameController gameController;
  late Player human;
  late Player bot;

  Meld dirtyBook(CardRank rank) {
    return Meld.createMeld([
      PlayingCard(suit: Suit.hearts, rank: rank),
      PlayingCard(suit: Suit.diamonds, rank: rank),
      PlayingCard(suit: Suit.clubs, rank: rank),
      PlayingCard(suit: Suit.spades, rank: rank),
      PlayingCard(suit: Suit.hearts, rank: rank),
      PlayingCard(suit: Suit.diamonds, rank: rank),
      const PlayingCard(suit: null, rank: CardRank.joker),
    ])!;
  }

  Meld cleanBook(CardRank rank) {
    return Meld.createMeld(
      List.generate(
        7,
        (i) => PlayingCard(suit: Suit.values[i % 4], rank: rank),
      ),
    )!;
  }

  void makeHumanHoarder({int handSize = 30}) {
    human.hasPlayedDown = true;
    human.hand.clear();
    human.hand.addAll(
      List.generate(
        handSize,
        (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.king),
      ),
    );
    human.melds.add(
      Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
      ])!,
    );
  }

  setUp(() {
    botAI = EnhancedBotAI(seed: 279181);
    human = Player(id: '1', name: 'You', type: PlayerType.human);
    bot = Player(id: '2', name: 'Bot', type: PlayerType.bot);
    gameController = GameController(players: [human, bot], seed: 279181);
    gameController.initializeGame();
    bot.hasPlayedDown = true;
    bot.hasPickedUpFoot = true;
    bot.hand.clear();
    bot.foot.clear();
    bot.melds.clear();
    human.hand.clear();
    human.foot.clear();
    human.melds.clear();
    gameController.gameState.currentPlayerIndex = 1;
    gameController.gameState.turnPhase = TurnPhase.meld;
    gameController.gameState.hasDrawnFromDeck = true;
  });

  group('Clean-book lane at meld creation (adaptive all-dirty bug)', () {
    test(
      'filterCleanLaneMeldCandidates prefers wild-free candidates',
      () {
        bot.melds.add(dirtyBook(CardRank.ace));

        final wildMeld = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        ];
        final naturalMeld = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
          const PlayingCard(suit: Suit.spades, rank: CardRank.eight),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
        ];

        final filtered = BotMeldAnalyzer.filterCleanLaneMeldCandidates(bot, [
          wildMeld,
          naturalMeld,
        ]);

        expect(filtered, equals([naturalMeld]));
      },
      tags: ['clean_book_lane'],
    );

    test(
      'filterCleanLaneMeldCandidates drops natural-pile poisoners',
      () {
        bot.melds.add(dirtyBook(CardRank.ace));
        bot.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
            const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
          ])!,
        );

        final poisoningMeld = [
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
          const PlayingCard(suit: null, rank: CardRank.joker),
        ];
        final dirtyNine = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        ];

        final filtered = BotMeldAnalyzer.filterCleanLaneMeldCandidates(bot, [
          poisoningMeld,
          dirtyNine,
        ]);

        expect(filtered, equals([dirtyNine]));
      },
      tags: ['clean_book_lane'],
    );

    test('no filtering once a clean book exists', () {
      bot.melds.add(cleanBook(CardRank.queen));

      final wildMeld = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
        const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
      ];
      final naturalMeld = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
        const PlayingCard(suit: Suit.spades, rank: CardRank.eight),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
      ];

      final filtered = BotMeldAnalyzer.filterCleanLaneMeldCandidates(bot, [
        wildMeld,
        naturalMeld,
      ]);

      expect(filtered.length, equals(2));
    }, tags: ['clean_book_lane']);

    test(
      'adaptive bot with only dirty books creates a wild-free meld when one exists',
      () {
        botAI.assignPersonality(bot.id, BotPersonality.adaptive);
        bot.melds.add(dirtyBook(CardRank.ace));
        bot.foot.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
          const PlayingCard(suit: Suit.spades, rank: CardRank.eight),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        ]);

        expect(bot.hasDirtyBook, isTrue);
        expect(bot.hasCleanBook, isFalse);

        final decision = botAI.makeDecision(bot, gameController);

        if (decision.action == 'createMeld') {
          final meld = decision.data as List<PlayingCard>;
          expect(meld.any((c) => c.isWild), isFalse);
        } else if (decision.action == 'addToMeld') {
          final addition = decision.data as Map<String, dynamic>;
          expect((addition['card'] as PlayingCard).isWild, isFalse);
        }
      },
      tags: ['clean_book_lane'],
    );
  });

  group('Empty-hand guard (adaptive error states)', () {
    test(
      'never melds the whole foot hand away without go-out books, even under '
      'hoarding pressure (session: createMeld tens at hand=3 produced error)',
      () {
        botAI.assignPersonality(bot.id, BotPersonality.adaptive);
        makeHumanHoarder();
        bot.melds.addAll([dirtyBook(CardRank.ace), dirtyBook(CardRank.jack)]);
        bot.foot.addAll([
          const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
        ]);

        expect(bot.canGoOutWithBooks, isFalse);

        final meldDecision = botAI.makeDecision(bot, gameController);
        expect(meldDecision.action, isNot('error'));
        if (meldDecision.action == 'createMeld') {
          final meld = meldDecision.data as List<PlayingCard>;
          expect(meld.length, lessThan(bot.currentHand.length));
        }

        gameController.gameState.turnPhase = TurnPhase.discard;
        final discardDecision = botAI.makeDecision(bot, gameController);
        expect(discardDecision.action, equals('discard'));
      },
      tags: ['empty_hand_guard'],
    );

    test('never adds the last foot card to a meld without go-out books '
        '(session: addToMeld six at hand=1 produced error)', () {
      makeHumanHoarder();
      bot.melds.add(dirtyBook(CardRank.ace));
      bot.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.spades, rank: CardRank.six),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
          const PlayingCard(suit: null, rank: CardRank.joker),
          const PlayingCard(suit: Suit.spades, rank: CardRank.six),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.six),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
        ])!,
      );
      bot.foot.add(const PlayingCard(suit: Suit.clubs, rank: CardRank.six));

      expect(bot.canGoOutWithBooks, isFalse);

      final meldDecision = botAI.makeDecision(bot, gameController);
      expect(meldDecision.action, isNot('addToMeld'));
      expect(meldDecision.action, isNot('error'));

      gameController.gameState.turnPhase = TurnPhase.discard;
      final discardDecision = botAI.makeDecision(bot, gameController);
      expect(discardDecision.action, equals('endTurn'));
    }, tags: ['empty_hand_guard']);

    test(
      'isSafeCreateMultipleMelds rejects plans emptying the foot',
      () {
        bot.melds.add(dirtyBook(CardRank.ace));
        bot.foot.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
          const PlayingCard(suit: Suit.spades, rank: CardRank.eight),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
        ]);

        final plan = [
          bot.currentHand.sublist(0, 3),
          bot.currentHand.sublist(3, 6),
        ];

        expect(BotEndGameManager.isSafeCreateMultipleMelds(bot, plan), isFalse);

        // Same plan is fine once both go-out books exist.
        bot.melds.add(cleanBook(CardRank.queen));
        expect(BotEndGameManager.isSafeCreateMultipleMelds(bot, plan), isTrue);
      },
      tags: ['empty_hand_guard'],
    );

    test(
      'isSafeCreateMultipleMelds allows emptying the hand pile pre-foot',
      () {
        bot.hasPickedUpFoot = false;
        bot.hand.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
        ]);

        expect(
          BotEndGameManager.isSafeCreateMultipleMelds(bot, [
            List<PlayingCard>.from(bot.currentHand),
          ]),
          isTrue,
        );
      },
      tags: ['empty_hand_guard'],
    );
  });

  group('Go-out race discipline (conservative bot stall)', () {
    setUp(() {
      bot.melds.addAll([cleanBook(CardRank.queen), dirtyBook(CardRank.five)]);
      makeHumanHoarder(handSize: 27);
    });

    test(
      'go-out-ready bot never takes the discard pile mid-race',
      () {
        // Session: the go-out-ready conservative bot unlocked a 39-card pile
        // (+7 cards) while racing a 30-card hoarder.
        bot.foot.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
        ]);
        gameController.gameState.discardPile.addAll(
          List.generate(
            20,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.five),
          ),
        );
        gameController.gameState.turnPhase = TurnPhase.draw;
        gameController.gameState.hasDrawnFromDeck = false;

        expect(bot.canGoOutWithBooks, isTrue);
        expect(
          BotEndGameManager.shouldGoOutAggressively(
            bot,
            gameController.gameState,
          ),
          isTrue,
        );

        final decision = botAI.makeDecision(bot, gameController);
        expect(decision.action, equals('drawFromDeck'));
      },
      tags: ['go_out_race'],
    );

    test(
      'buildFinishRoundDecision always sheds at 3-4 cards under pressure',
      () {
        bot.foot.addAll([
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.eight),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        ]);

        final endGameManager = BotEndGameManager();
        final discardDecision = endGameManager.buildFinishRoundDecision(
          bot,
          gameController,
          TurnPhase.discard,
        );

        expect(discardDecision, isNotNull);
        expect(discardDecision!.action, equals('discard'));
      },
      tags: ['go_out_race'],
    );

    test(
      'go-out-ready bot facing a hoarder goes out within 2 turns',
      () {
        bot.foot.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.eight),
        ]);

        var wentOut = false;
        for (var turn = 0; turn < 2 && !wentOut; turn++) {
          // Meld phase: apply shedding decisions until the bot stops melding.
          gameController.gameState.turnPhase = TurnPhase.meld;
          for (var step = 0; step < 8; step++) {
            final decision = botAI.makeDecision(bot, gameController);
            expect(decision.action, isNot('drawFromDiscard'));
            expect(decision.action, isNot('error'));
            if (decision.action == 'addToMeld') {
              final addition = decision.data as Map<String, dynamic>;
              final card = addition['card'] as PlayingCard;
              final meldIndex = addition['meldIndex'] as int;
              expect(bot.melds[meldIndex].addCard(card), isTrue);
              expect(bot.removeCardFromHand(card), isNotNull);
            } else if (decision.action == 'createMeld') {
              final meldCards = decision.data as List<PlayingCard>;
              bot.melds.add(Meld.createMeld(meldCards)!);
              for (final card in meldCards) {
                expect(bot.removeCardFromHand(card), isNotNull);
              }
            } else {
              break;
            }
          }

          // Discard phase: shed one more card or go out.
          gameController.gameState.turnPhase = TurnPhase.discard;
          final decision = botAI.makeDecision(bot, gameController);
          expect(decision.action, isNot('error'));
          if (decision.action == 'goOut') {
            wentOut = true;
          } else {
            expect(decision.action, equals('discard'));
            expect(
              bot.removeCardFromHand(decision.data as PlayingCard),
              isNotNull,
            );
            if (bot.currentHand.isEmpty && bot.canGoOut) {
              wentOut = true;
            }
          }
        }

        expect(wentOut, isTrue);
      },
      tags: ['go_out_race'],
    );
  });

  group('Adaptive hoarder counter (the missing punish)', () {
    setUp(() {
      botAI.assignPersonality(bot.id, BotPersonality.adaptive);
    });

    test(
      'played-down hoarder activates hoarder_counter strategy',
      () {
        // speed_counter requires !hasPlayedDown, so the session pattern
        // (minimal play-down, then 34-card hoard) matched no strategy.
        makeHumanHoarder(handSize: 25);
        bot.melds.add(dirtyBook(CardRank.ace));
        bot.foot.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.eight),
        ]);

        botAI.debugLegacyAdaptiveAdjustment(bot, gameController.gameState);

        expect(
          botAI.personalityManager.getAdaptiveStrategy(bot.id),
          equals('hoarder_counter'),
        );
      },
      tags: ['hoarder_counter'],
    );

    test(
      'hoarder_counter does not discard a wild just to freeze the pile',
      () {
        makeHumanHoarder(handSize: 25);
        // Pre-foot bot: wilds are not yet needed for a missing go-out book.
        bot.hasPickedUpFoot = false;
        bot.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
            const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          ])!,
        );
        bot.hand.addAll([
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.two),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
        ]);
        gameController.gameState.turnPhase = TurnPhase.discard;
        gameController.gameState.discardPileFrozen = false;

        final decision = botAI.makeDecision(bot, gameController);

        expect(decision.action, equals('discard'));
        expect(
          (decision.data as PlayingCard).isWild,
          isFalse,
          reason:
              'Competitive planner keeps wilds; pile freeze is not a discard rule',
        );
      },
      tags: ['hoarder_counter'],
    );

    test(
      'hoarder_counter keeps wilds with a hand above the wild guard',
      () {
        // Planner discard ranking protects wilds; it does not force-freeze
        // the pile the way the old cascade did.
        makeHumanHoarder(handSize: 25);
        bot.hasPickedUpFoot = false;
        bot.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
            const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          ])!,
        );
        bot.hand.addAll([
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.two),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          const PlayingCard(suit: Suit.spades, rank: CardRank.six),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
        ]);
        expect(
          bot.currentHand.length,
          greaterThan(BotConfig.wildDiscardDesperationHandSize),
        );
        gameController.gameState.turnPhase = TurnPhase.discard;
        gameController.gameState.discardPileFrozen = false;

        final decision = botAI.makeDecision(bot, gameController);

        expect(decision.action, equals('discard'));
        expect((decision.data as PlayingCard).isWild, isFalse);
      },
      tags: ['hoarder_counter'],
    );

    test(
      'hoarder_counter never freezes with a wild needed for the dirty book',
      () {
        makeHumanHoarder(handSize: 25);
        // On foot without both books: wilds must be protected.
        bot.melds.add(cleanBook(CardRank.queen));
        bot.foot.addAll([
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.two),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
        ]);
        gameController.gameState.turnPhase = TurnPhase.discard;

        final decision = botAI.makeDecision(bot, gameController);

        expect(decision.action, equals('discard'));
        expect((decision.data as PlayingCard).isWild, isFalse);
      },
      tags: ['hoarder_counter'],
    );

    test(
      'played-down hoarder triggers the hoarding rush for any bot',
      () {
        // Even below the 180-point penalty threshold, 20+ unmelded cards after
        // play-down is a punish window (new scenario 4b branch).
        human.hasPlayedDown = true;
        human.hand.clear();
        human.hand.addAll(
          List.generate(
            22,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.four),
          ),
        );

        bot.melds.addAll([cleanBook(CardRank.queen), dirtyBook(CardRank.five)]);
        bot.foot.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.eight),
        ]);

        expect(bot.canGoOutWithBooks, isTrue);

        final decision = botAI.makeDecision(bot, gameController);

        // Rush path: shed via meld or skip straight to the go-out discard —
        // never a strategic hold.
        expect(decision.action, anyOf('addToMeld', 'createMeld', 'noMeld'));
        gameController.gameState.turnPhase = TurnPhase.discard;
        final discardDecision = botAI.makeDecision(bot, gameController);
        // Still shedding: meld the 5 into the five book or discard.
        expect(discardDecision.action, anyOf('discard', 'addToMeld'));
      },
      tags: ['hoarder_counter'],
    );
  });
}
