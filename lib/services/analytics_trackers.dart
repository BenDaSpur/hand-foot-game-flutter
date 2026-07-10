import 'analytics_fields.dart';

/// Tracks per-turn action metrics for [turn_summaries] collection.
class TurnTracker {
  int actionCount = 0;
  final List<String> drawSources = [];
  int meldsCreated = 0;
  String? discardedRank;
  int? handSizeAtEnd;
  int? round;
  String? playerId;
  String? playerType;

  void recordAction({
    required String playerId,
    required String action,
    int? handSize,
    int? round,
    String? playerType,
    String? discardedCardRank,
  }) {
    this.playerId = playerId;
    this.round = round;
    if (playerType != null) {
      this.playerType = playerType;
    }
    actionCount++;
    if (handSize != null) {
      handSizeAtEnd = handSize;
    }

    final drawSource = drawSourceFromAction(action);
    if (drawSource != null) {
      drawSources.add(drawSource);
    }
    if (isMeldCreationAction(action)) {
      meldsCreated++;
    }
    if (isDiscardAction(action) && discardedCardRank != null) {
      discardedRank = discardedCardRank;
    }
  }

  Map<String, dynamic> toSummary({
    required int turnNumber,
    String? nextPlayerId,
    String? nextPlayerType,
  }) {
    return {
      'playerId': playerId,
      'playerType': playerType,
      'turnNumber': turnNumber,
      'round': round,
      'actionCount': actionCount,
      'drawSources': List<String>.from(drawSources),
      'meldsCreated': meldsCreated,
      'discardedRank': discardedRank,
      'handSizeAtEnd': handSizeAtEnd,
      'nextPlayerId': nextPlayerId,
      'nextPlayerType': nextPlayerType,
    };
  }

  void reset() {
    actionCount = 0;
    drawSources.clear();
    meldsCreated = 0;
    discardedRank = null;
    handSizeAtEnd = null;
    round = null;
    playerId = null;
    playerType = null;
  }
}

/// Outcome of resolving a pending discard for [decision_outcomes] collection.
class DiscardOutcomeResult {
  final String discarderId;
  final String outcome;
  final int turnsLater;
  final Map<String, dynamic> outcomeContext;

  const DiscardOutcomeResult({
    required this.discarderId,
    required this.outcome,
    required this.turnsLater,
    required this.outcomeContext,
  });
}

/// Tracks pending discards until an opponent takes, unlocks, or passes.
class DiscardOutcomeTracker {
  String? discarderId;
  String? cardRank;
  int? turnNumber;

  bool get hasPending => discarderId != null && cardRank != null;

  void registerDiscard({
    required String discarderId,
    required String cardRank,
    required int turnNumber,
  }) {
    this.discarderId = discarderId;
    this.cardRank = cardRank;
    this.turnNumber = turnNumber;
  }

  DiscardOutcomeResult? onOpponentTookDiscard({
    required String takerId,
    required bool fromDeck,
  }) {
    if (!hasPending || fromDeck) {
      return null;
    }
    if (takerId == discarderId) {
      return null;
    }

    final result = DiscardOutcomeResult(
      discarderId: discarderId!,
      outcome: 'opponent_took_discard',
      turnsLater: 0,
      outcomeContext: {
        'cardRank': cardRank,
        'discarderId': discarderId,
        'takerId': takerId,
        'turnNumber': turnNumber,
      },
    );
    clear();
    return result;
  }

  DiscardOutcomeResult? onOpponentUnlocked({required String takerId}) {
    if (!hasPending) {
      return null;
    }
    if (takerId == discarderId) {
      return null;
    }

    final result = DiscardOutcomeResult(
      discarderId: discarderId!,
      outcome: 'opponent_unlocked',
      turnsLater: 0,
      outcomeContext: {
        'cardRank': cardRank,
        'discarderId': discarderId,
        'takerId': takerId,
        'turnNumber': turnNumber,
      },
    );
    clear();
    return result;
  }

  DiscardOutcomeResult? onTurnEndedWithoutTake() {
    if (!hasPending) {
      return null;
    }

    final result = DiscardOutcomeResult(
      discarderId: discarderId!,
      outcome: 'discard_not_taken',
      turnsLater: 1,
      outcomeContext: {
        'cardRank': cardRank,
        'discarderId': discarderId,
        'turnNumber': turnNumber,
      },
    );
    clear();
    return result;
  }

  void clear() {
    discarderId = null;
    cardRank = null;
    turnNumber = null;
  }
}
