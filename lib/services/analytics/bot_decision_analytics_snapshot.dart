import 'dart:collection';

import '../../config/game_config.dart';
import '../../config/solo_game_settings.dart';
import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../../models/round_score_breakdown.dart';

/// Immutable game-state capture for bot-decision analytics before mutations apply.
class BotDecisionAnalyticsSnapshot {
  BotDecisionAnalyticsSnapshot({
    required List<AnalyticsPlayerSnapshot> players,
    required List<PlayingCard> deckCards,
    required this.deckSeed,
    required List<PlayingCard> discardPile,
    required List<GameAction> recentActions,
    required this.currentPlayerIndex,
    required this.phase,
    required this.turnPhase,
    required this.round,
    required this.discardPileFrozen,
    required this.hasDrawnFromDeck,
    required this.hasMelded,
    required this.soloSettings,
    required this.finalTurnPhaseActive,
    required this.playerWhoWentOutIndex,
    required Set<int> playersAwaitingFinalTurn,
    required this.winnerId,
  }) : players = UnmodifiableListView(players),
       deckCards = UnmodifiableListView(deckCards),
       discardPile = UnmodifiableListView(discardPile),
       recentActions = UnmodifiableListView(recentActions),
       playersAwaitingFinalTurn = UnmodifiableSetView(playersAwaitingFinalTurn);

  final UnmodifiableListView<AnalyticsPlayerSnapshot> players;
  final UnmodifiableListView<PlayingCard> deckCards;
  final int? deckSeed;
  final UnmodifiableListView<PlayingCard> discardPile;
  final UnmodifiableListView<GameAction> recentActions;
  final int currentPlayerIndex;
  final GamePhase phase;
  final TurnPhase turnPhase;
  final int round;
  final bool discardPileFrozen;
  final bool hasDrawnFromDeck;
  final bool hasMelded;
  final SoloGameSettings soloSettings;
  final bool finalTurnPhaseActive;
  final int? playerWhoWentOutIndex;
  final UnmodifiableSetView<int> playersAwaitingFinalTurn;
  final String? winnerId;

  int get deckSize => deckCards.length;

  AnalyticsPlayerSnapshot playerById(String id) {
    return players.firstWhere((player) => player.id == id);
  }
}

/// Immutable player capture for bot-decision analytics.
class AnalyticsPlayerSnapshot {
  AnalyticsPlayerSnapshot({
    required this.id,
    required this.name,
    required this.type,
    required List<PlayingCard> hand,
    required List<PlayingCard> foot,
    required List<AnalyticsMeldSnapshot> melds,
    required Set<int> newlyDrawnCardIndices,
    required List<RoundScoreBreakdown> roundScoreHistory,
    required this.hasPickedUpFoot,
    required this.hasPlayedDown,
    required this.score,
  }) : hand = UnmodifiableListView(hand),
       foot = UnmodifiableListView(foot),
       melds = UnmodifiableListView(melds),
       newlyDrawnCardIndices = UnmodifiableSetView(newlyDrawnCardIndices),
       roundScoreHistory = UnmodifiableListView(roundScoreHistory);

  final String id;
  final String name;
  final PlayerType type;
  final UnmodifiableListView<PlayingCard> hand;
  final UnmodifiableListView<PlayingCard> foot;
  final UnmodifiableListView<AnalyticsMeldSnapshot> melds;
  final UnmodifiableSetView<int> newlyDrawnCardIndices;
  final UnmodifiableListView<RoundScoreBreakdown> roundScoreHistory;
  final bool hasPickedUpFoot;
  final bool hasPlayedDown;
  final int score;

  List<PlayingCard> get currentHand => hasPickedUpFoot ? foot : hand;

  bool get hasCleanBook => melds.any((meld) => meld.isBook && meld.isClean);

  bool get hasDirtyBook => melds.any((meld) => meld.isBook && meld.isDirty);

  bool get canGoOutWithBooks => hasCleanBook && hasDirtyBook;
}

/// Immutable meld capture for bot-decision analytics.
class AnalyticsMeldSnapshot {
  AnalyticsMeldSnapshot({required this.rank, required List<PlayingCard> cards})
    : cards = UnmodifiableListView(cards);

  final CardRank rank;
  final UnmodifiableListView<PlayingCard> cards;

  bool get isBook => cards.length >= GameConfig.bookSize;

  bool get isClean => isBook && !cards.any((card) => card.isWild);

  bool get isDirty => isBook && cards.any((card) => card.isWild);
}
