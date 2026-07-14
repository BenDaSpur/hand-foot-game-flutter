import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/config/solo_game_settings.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

/// Simulates meld-phase iterations the way [BotTurnManager] does.
void _runFinalTurnMeldLoop(
  EnhancedBotAI botAI,
  GameController gc,
  Player bot, {
  int maxIterations = 25,
}) {
  var iterations = 0;
  while (gc.gameState.turnPhase == TurnPhase.meld &&
      iterations < maxIterations) {
    iterations++;
    final decision = botAI.makeDecision(bot, gc);
    if (decision.action == 'noMeld') {
      gc.gameState.turnPhase = TurnPhase.discard;
      return;
    }

    final ok = switch (decision.action) {
      'addToMeld' => () {
        final data = decision.data as Map<String, dynamic>;
        final card = data['card'] as PlayingCard;
        final handCard = bot.findHandCardInstance(card);
        if (handCard == null) {
          return false;
        }
        return gc.addCardToMeld(data['meldIndex'] as int, handCard);
      }(),
      'createMeld' => gc.createMeld(
        List<PlayingCard>.from(decision.data as List),
      ),
      'createMultipleMelds' => () {
        var success = true;
        for (final meld in List<List<PlayingCard>>.from(
          (decision.data as List).map((e) => List<PlayingCard>.from(e as List)),
        )) {
          if (!gc.createMeld(meld)) {
            success = false;
            break;
          }
        }
        return success;
      }(),
      _ => false,
    };

    expect(
      ok,
      isTrue,
      reason:
          'Final-turn action ${decision.action} must succeed '
          '(hand=${bot.currentHand.map((c) => c.compactName).join(",")})',
    );
  }
}

void _setActiveHand(Player bot, List<PlayingCard> cards) {
  final pile = bot.hasPickedUpFoot ? bot.foot : bot.hand;
  pile
    ..clear()
    ..addAll(cards);
}

Meld _cleanKingBook() => Meld.createMeld([
  const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
  const PlayingCard(suit: Suit.spades, rank: CardRank.king),
  const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
  const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
  const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
  const PlayingCard(suit: Suit.spades, rank: CardRank.king),
  const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
])!;

Meld _dirtyQueenBook() => Meld.createMeld([
  const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
  const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
  const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
  const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
  const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
  const PlayingCard(suit: Suit.spades, rank: CardRank.two),
  const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
])!;

({EnhancedBotAI botAI, GameController gc, Player human, Player bot})
_setupFinalTurnBot({bool onFoot = true}) {
  final botAI = EnhancedBotAI(seed: 42);
  final human = Player(id: 'h', name: 'You', type: PlayerType.human);
  final bot = Player(id: 'b', name: 'Bot', type: PlayerType.bot);
  final gc = GameController(
    players: [human, bot],
    seed: 42,
    soloSettings: SoloGameSettings.defaults,
  );
  gc.initializeGame();
  bot.hasPlayedDown = true;
  bot.hasPickedUpFoot = onFoot;
  gc.gameState.currentPlayerIndex = 1;
  gc.gameState.turnPhase = TurnPhase.meld;
  gc.gameState.hasDrawnFromDeck = true;
  gc.gameState.finalTurnPhaseActive = true;
  gc.gameState.playersAwaitingFinalTurn.add(1);
  gc.gameState.playerWhoWentOutIndex = 0;
  return (botAI: botAI, gc: gc, human: human, bot: bot);
}

void main() {
  group('Final turn dumping when one-more-turn rule is enabled', () {
    test('dumps addable cards, wilds onto dirty book, and new melds', () {
      final setup = _setupFinalTurnBot();
      final bot = setup.bot;
      bot.melds.addAll([_cleanKingBook(), _dirtyQueenBook()]);
      _setActiveHand(bot, [
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        const PlayingCard(suit: Suit.spades, rank: CardRank.five),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.three),
      ]);

      _runFinalTurnMeldLoop(setup.botAI, setup.gc, bot);

      expect(bot.currentHand.length, 2);
      expect(bot.currentHand.any((c) => c.rank == CardRank.five), isTrue);
      expect(bot.currentHand.any((c) => c.isThree), isTrue);
      expect(bot.melds.any((m) => m.rank == CardRank.ace), isTrue);
      // Wild went on dirty queens, not clean kings
      expect(bot.melds[0].isClean, isTrue);
      expect(bot.melds[1].cards.any((c) => c.isWild), isTrue);
    });

    test('does not retry stale meld cards after hand changes', () {
      final setup = _setupFinalTurnBot();
      final bot = setup.bot;
      bot.melds.addAll([_cleanKingBook(), _dirtyQueenBook()]);
      _setActiveHand(bot, [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.five),
      ]);

      // First decision creates the ace meld
      final first = setup.botAI.makeDecision(bot, setup.gc);
      expect(first.action, 'createMeld');
      expect(
        setup.gc.createMeld(List<PlayingCard>.from(first.data as List)),
        isTrue,
      );

      // Second decision must not invent another ace meld from cache
      final second = setup.botAI.makeDecision(bot, setup.gc);
      expect(second.action, 'noMeld');
    });

    test('empties hand pile into foot then melds playable foot cards', () {
      final setup = _setupFinalTurnBot(onFoot: false);
      final bot = setup.bot;
      bot.melds.addAll([_cleanKingBook(), _dirtyQueenBook()]);
      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        ]);
      bot.foot
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
          const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        ]);

      _runFinalTurnMeldLoop(setup.botAI, setup.gc, bot);

      expect(bot.hasPickedUpFoot, isTrue);
      expect(bot.currentHand.any((c) => c.rank == CardRank.jack), isFalse);
      expect(bot.currentHand.length, 1);
      expect(bot.currentHand.first.rank, CardRank.five);
    });

    test(
      'uses wild to create a meld that empties hand into foot, then builds books',
      () {
        final setup = _setupFinalTurnBot(onFoot: false);
        final bot = setup.bot;

        // Dirty queens book + 6 clean kings (one short of book)
        bot.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
          ])!,
        );
        bot.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          ])!,
        );

        // Wild must make Jack meld (not dump onto queens) so hand empties.
        bot.hand
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
            const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          ]);
        bot.foot
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
            const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
            const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          ]);

        _runFinalTurnMeldLoop(setup.botAI, setup.gc, bot);

        expect(bot.hasPickedUpFoot, isTrue);
        expect(bot.hasCleanBook, isTrue);
        expect(
          bot.melds.any((m) => m.rank == CardRank.jack),
          isTrue,
          reason: 'wild should form a jack meld to clear the hand pile',
        );
        expect(
          bot.melds.any((m) => m.rank == CardRank.ace && m.isBook),
          isTrue,
          reason: 'after reaching foot, should meld the ace book',
        );
        expect(bot.currentHand.length, 1);
        expect(bot.currentHand.first.rank, CardRank.five);
      },
    );

    test('prefers completing a clean book over a lower-impact add', () {
      final setup = _setupFinalTurnBot();
      final bot = setup.bot;
      bot.melds.addAll([
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        ])!,
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ])!,
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
          const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        ])!,
      ]);

      _setActiveHand(bot, [
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
      ]);

      final decision = setup.botAI.makeDecision(bot, setup.gc);
      expect(decision.action, 'addToMeld');
      final card = (decision.data as Map)['card'] as PlayingCard;
      expect(
        card.rank,
        CardRank.king,
        reason: 'completing the clean book (+500) should win',
      );
    });

    test('discards highest-penalty leftover card on final turn', () {
      final setup = _setupFinalTurnBot();
      final bot = setup.bot;
      bot.melds.addAll([_cleanKingBook(), _dirtyQueenBook()]);
      setup.gc.gameState.turnPhase = TurnPhase.discard;
      _setActiveHand(bot, [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.five),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.three), // red 3
      ]);

      final decision = setup.botAI.makeDecision(bot, setup.gc);
      expect(decision.action, 'discard');
      expect((decision.data as PlayingCard).isThree, isTrue);
      expect((decision.data as PlayingCard).pointValue, -300);
    });

    test('plays down when final turn requires meeting play-down', () {
      final botAI = EnhancedBotAI(seed: 42);
      final human = Player(id: 'h', name: 'You', type: PlayerType.human);
      final bot = Player(id: 'b', name: 'Bot', type: PlayerType.bot);
      final gc = GameController(
        players: [human, bot],
        seed: 42,
        soloSettings: SoloGameSettings.defaults,
      );
      gc.initializeGame();
      bot.hasPlayedDown = false;
      bot.hasPickedUpFoot = false;
      gc.gameState.round = 1;
      gc.gameState.currentPlayerIndex = 1;
      gc.gameState.turnPhase = TurnPhase.meld;
      gc.gameState.hasDrawnFromDeck = true;
      gc.gameState.finalTurnPhaseActive = true;
      gc.gameState.playersAwaitingFinalTurn.add(1);
      gc.gameState.playerWhoWentOutIndex = 0;

      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        ]);

      final decision = botAI.makeDecision(bot, gc);
      expect(decision.action, isIn(['createMeld', 'createMultipleMelds']));
    });

    test('skips illegal play-down when requirement cannot be met', () {
      final botAI = EnhancedBotAI(seed: 42);
      final human = Player(id: 'h', name: 'You', type: PlayerType.human);
      final bot = Player(id: 'b', name: 'Bot', type: PlayerType.bot);
      final gc = GameController(
        players: [human, bot],
        seed: 42,
        soloSettings: SoloGameSettings.defaults,
      );
      gc.initializeGame();
      bot.hasPlayedDown = false;
      bot.hasPickedUpFoot = false;
      gc.gameState.round = 4; // 150 pts required
      gc.gameState.currentPlayerIndex = 1;
      gc.gameState.turnPhase = TurnPhase.meld;
      gc.gameState.hasDrawnFromDeck = true;
      gc.gameState.finalTurnPhaseActive = true;
      gc.gameState.playersAwaitingFinalTurn.add(1);
      gc.gameState.playerWhoWentOutIndex = 0;

      bot.hand
        ..clear()
        ..addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        ]);

      final decision = botAI.makeDecision(bot, gc);
      expect(decision.action, 'noMeld');
    });

    test('makeDecision ignores final-turn dump when rule phase inactive', () {
      final setup = _setupFinalTurnBot();
      setup.gc.gameState.finalTurnPhaseActive = false;
      setup.gc.gameState.playersAwaitingFinalTurn.clear();
      final bot = setup.bot;
      bot.melds.addAll([_cleanKingBook(), _dirtyQueenBook()]);
      _setActiveHand(bot, [
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
      ]);

      // Without final-turn phase, bots may hold for strategy — just ensure no crash
      final decision = setup.botAI.makeDecision(bot, setup.gc);
      expect(decision.action, isNotEmpty);
    });

    test('multi-meld final turn only returns disjoint hand cards', () {
      final setup = _setupFinalTurnBot();
      final bot = setup.bot;
      bot.melds.addAll([_cleanKingBook(), _dirtyQueenBook()]);
      _setActiveHand(bot, [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
        const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
      ]);

      final decision = setup.botAI.makeDecision(bot, setup.gc);
      expect(decision.action, isIn(['createMultipleMelds', 'createMeld']));
      if (decision.action == 'createMultipleMelds') {
        final melds = List<List<PlayingCard>>.from(
          (decision.data as List).map((e) => List<PlayingCard>.from(e as List)),
        );
        expect(melds.length, greaterThanOrEqualTo(2));
        final claimed = <PlayingCard>{};
        for (final meld in melds) {
          for (final card in meld) {
            expect(
              claimed.add(card),
              isTrue,
              reason: 'multi-meld must not reuse the same card instance',
            );
            expect(identical(bot.findHandCardInstance(card), card), isTrue);
          }
        }
      }
    });

    test('overlapping maximal candidates fall back to one createMeld', () {
      final setup = _setupFinalTurnBot();
      final bot = setup.bot;
      // Only a clean book — wild cannot be added without spoiling it, so
      // the create path runs and must not invent two melds sharing the two.
      bot.melds.add(_cleanKingBook());
      _setActiveHand(bot, [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
        const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
      ]);

      final decision = setup.botAI.makeDecision(bot, setup.gc);
      if (decision.action == 'createMultipleMelds') {
        final melds = List<List<PlayingCard>>.from(
          (decision.data as List).map((e) => List<PlayingCard>.from(e as List)),
        );
        final claimed = <PlayingCard>{};
        for (final meld in melds) {
          for (final card in meld) {
            expect(
              claimed.add(card),
              isTrue,
              reason: 'must not reuse cards across createMultipleMelds',
            );
          }
        }
        expect(melds.length, 1); // only one wild — at most one valid meld
      } else {
        expect(decision.action, 'createMeld');
        final meld = List<PlayingCard>.from(decision.data as List);
        expect(meld.length, greaterThanOrEqualTo(3));
        expect(meld.where((c) => c.isWild).length, lessThanOrEqualTo(1));
      }
    });
  });
}
