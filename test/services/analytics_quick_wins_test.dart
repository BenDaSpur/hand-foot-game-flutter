import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/services/analytics_fields.dart';
import 'package:hand_foot_game_flutter/services/analytics_trackers.dart';
import 'package:hand_foot_game_flutter/services/game_analytics_logger.dart';

void main() {
  group('drawSourceFromAction', () {
    test('maps draw actions to normalized drawSource', () {
      expect(drawSourceFromAction('drawFromDeck'), 'deck');
      expect(drawSourceFromAction('drawFromDiscard'), 'unlock');
      expect(drawSourceFromAction('unlockDiscardPile'), 'unlock');
      expect(drawSourceFromAction('discardCard'), isNull);
    });

    test('treats bot discard action names as discards', () {
      expect(isDiscardAction('discardCard'), isTrue);
      expect(isDiscardAction('discard'), isTrue);
      expect(isDiscardAction('CardDiscarded'), isTrue);
      expect(isDiscardAction('drawFromDeck'), isFalse);
    });

    test('maps event-bus action names to normalized drawSource', () {
      expect(drawSourceFromAction('card_drawn'), 'deck');
      expect(drawSourceFromAction('discard_pile_unlocked'), 'unlock');
    });
  });

  group('shouldSkipEventBusTurnTracking', () {
    test('skips duplicate event-bus turn metrics', () {
      expect(shouldSkipEventBusTurnTracking('card_drawn'), isTrue);
      expect(shouldSkipEventBusTurnTracking('meld_created'), isTrue);
      expect(shouldSkipEventBusTurnTracking('discard_pile_unlocked'), isTrue);
      expect(shouldSkipEventBusTurnTracking('CardDiscarded'), isTrue);
      expect(shouldSkipEventBusTurnTracking('player_went_out'), isFalse);
    });
  });

  group('TurnTracker', () {
    test('accumulates actions and resets on clear', () {
      final tracker = TurnTracker();

      tracker.recordAction(
        playerId: 'human_1',
        action: 'drawFromDeck',
        handSize: 12,
        round: 1,
        playerType: 'human',
      );
      tracker.recordAction(
        playerId: 'human_1',
        action: 'createMultipleMelds',
        handSize: 8,
        round: 1,
        playerType: 'human',
      );
      tracker.recordAction(
        playerId: 'human_1',
        action: 'discardCard',
        handSize: 7,
        round: 1,
        playerType: 'human',
        discardedCardRank: 'five',
      );

      final summary = tracker.toSummary(
        turnNumber: 3,
        nextPlayerId: 'bot_1',
        nextPlayerType: 'bot',
      );

      expect(summary['actionCount'], 3);
      expect(summary['drawSources'], ['deck']);
      expect(summary['meldsCreated'], 1);
      expect(summary['discardedRank'], 'five');
      expect(summary['handSizeAtEnd'], 7);
      expect(summary['nextPlayerId'], 'bot_1');

      tracker.reset();
      expect(tracker.actionCount, 0);
      expect(tracker.drawSources, isEmpty);
    });

    test('records bot discard action names', () {
      final tracker = TurnTracker();
      tracker.recordAction(
        playerId: 'bot_1',
        action: 'discard',
        handSize: 6,
        playerType: 'bot',
        discardedCardRank: 'three',
      );
      expect(tracker.toSummary(turnNumber: 4)['discardedRank'], 'three');
    });

    test('does not clear round when a null round is recorded', () {
      final tracker = TurnTracker();

      tracker.recordAction(
        playerId: 'human_1',
        action: 'drawFromDeck',
        round: 2,
      );
      tracker.recordAction(
        playerId: 'human_1',
        action: 'discardCard',
        round: null,
      );

      expect(tracker.round, 2);
    });
  });

  group('DiscardOutcomeTracker', () {
    test('resolves opponent took discard', () {
      final tracker = DiscardOutcomeTracker();
      tracker.registerDiscard(
        discarderId: 'bot_1',
        cardRank: 'seven',
        turnNumber: 5,
      );

      final result = tracker.onOpponentTookDiscard(
        takerId: 'human_1',
        fromDeck: false,
      );

      expect(result, isNotNull);
      expect(result!.outcome, 'opponent_took_discard');
      expect(result.turnsLater, 0);
      expect(result.outcomeContext['takerId'], 'human_1');
      expect(tracker.hasPending, isFalse);
    });

    test('resolves opponent unlocked discard pile', () {
      final tracker = DiscardOutcomeTracker();
      tracker.registerDiscard(
        discarderId: 'human_1',
        cardRank: 'four',
        turnNumber: 2,
      );

      final result = tracker.onOpponentUnlocked(takerId: 'bot_2');

      expect(result, isNotNull);
      expect(result!.outcome, 'opponent_unlocked');
      expect(tracker.hasPending, isFalse);
    });

    test('resolves discard not taken on turn end', () {
      final tracker = DiscardOutcomeTracker();
      tracker.registerDiscard(
        discarderId: 'bot_1',
        cardRank: 'king',
        turnNumber: 8,
      );

      final result = tracker.onTurnEndedWithoutTake();

      expect(result, isNotNull);
      expect(result!.outcome, 'discard_not_taken');
      expect(result.turnsLater, 1);
      expect(tracker.hasPending, isFalse);
    });

    test('ignores same-player discard take', () {
      final tracker = DiscardOutcomeTracker();
      tracker.registerDiscard(
        discarderId: 'bot_1',
        cardRank: 'ace',
        turnNumber: 1,
      );

      final result = tracker.onOpponentTookDiscard(
        takerId: 'bot_1',
        fromDeck: false,
      );

      expect(result, isNull);
      expect(tracker.hasPending, isTrue);
    });

    test('resolves superseded pending discard before registering anew', () {
      final tracker = DiscardOutcomeTracker();
      tracker.registerDiscard(
        discarderId: 'bot_1',
        cardRank: 'seven',
        turnNumber: 3,
      );

      final superseded = tracker.registerDiscard(
        discarderId: 'human_1',
        cardRank: 'queen',
        turnNumber: 4,
      );

      expect(superseded, isNotNull);
      expect(superseded!.outcome, 'discard_not_taken');
      expect(superseded.outcomeContext['cardRank'], 'seven');
      expect(tracker.discarderId, 'human_1');
      expect(tracker.cardRank, 'queen');
      expect(tracker.hasPending, isTrue);
    });
  });

  group('discardedRank extraction', () {
    test('reads bot discard ranks from decision context', () {
      expect(
        GameAnalyticsLogger.discardedRankFromDecisionForTest('discard', {
          'discardedRank': 'five',
        }),
        'five',
      );
      expect(
        GameAnalyticsLogger.discardedRankFromDecisionForTest('discardCard', {
          'discardedCard': 'King♠',
        }),
        'King♠',
      );
      expect(
        GameAnalyticsLogger.discardedRankFromDecisionForTest('drawFromDeck', {
          'discardedRank': 'five',
        }),
        isNull,
      );
    });

    test('reads human discard ranks from event data or nested context', () {
      expect(
        GameAnalyticsLogger.discardedRankFromEventDataForTest('discardCard', {
          'cardRank': 'king',
        }),
        'king',
      );
      expect(
        GameAnalyticsLogger.discardedRankFromEventDataForTest('CardDiscarded', {
          'context': {'cardRank': 'seven'},
        }),
        'seven',
      );
    });
  });

  group('session progress snapshot', () {
    test('includes every player score, foot, and book count', () {
      final human = Player(id: 'human', name: 'You', type: PlayerType.human);
      final bot = Player(id: 'bot', name: 'Adaptive', type: PlayerType.bot);
      final controller = GameController(players: [human, bot], seed: 194022);
      controller.initializeGame();
      human.hasPlayedDown = true;
      human.hasPickedUpFoot = true;
      human.score = 1140;
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = false;
      bot.score = 320;
      bot.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        ])!,
      );

      final snapshot = GameAnalyticsLogger.progressSnapshotForTest(
        controller.gameState,
      );
      expect(snapshot['round'], controller.gameState.round);
      expect(snapshot['scores'], [1140, 320]);
      final players = snapshot['players'] as List<dynamic>;
      expect(players, hasLength(2));
      final humanSnap = players.first as Map<String, dynamic>;
      final botSnap = players.last as Map<String, dynamic>;
      expect(humanSnap['hasPickedUpFoot'], isTrue);
      expect(humanSnap['hasPlayedDown'], isTrue);
      expect(botSnap['hasPickedUpFoot'], isFalse);
      expect(botSnap['bookCount'], 1);
      expect(botSnap['meldCount'], 1);
      expect(botSnap.containsKey('handSize'), isTrue);
    });
  });
}
