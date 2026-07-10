import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/services/analytics_fields.dart';
import 'package:hand_foot_game_flutter/services/analytics_trackers.dart';

void main() {
  group('drawSourceFromAction', () {
    test('maps draw actions to normalized drawSource', () {
      expect(drawSourceFromAction('drawFromDeck'), 'deck');
      expect(drawSourceFromAction('drawFromDiscard'), 'discard');
      expect(drawSourceFromAction('unlockDiscardPile'), 'unlock');
      expect(drawSourceFromAction('discardCard'), isNull);
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
  });
}
