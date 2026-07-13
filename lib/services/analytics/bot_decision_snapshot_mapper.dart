import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../../models/round_score_breakdown.dart';
import 'bot_decision_analytics_snapshot.dart';

/// Maps live [GameState] into an immutable analytics snapshot.
class BotDecisionSnapshotMapper {
  BotDecisionSnapshotMapper._();

  static BotDecisionAnalyticsSnapshot fromGameState(GameState source) {
    final snapshotPlayers = source.players
        .map(_mapPlayer)
        .toList(growable: false);

    return BotDecisionAnalyticsSnapshot(
      players: snapshotPlayers,
      deckCards: List<PlayingCard>.from(source.deck.cards),
      deckSeed: source.deck.seed,
      discardPile: List<PlayingCard>.from(source.discardPile),
      recentActions: List<GameAction>.from(source.recentActions),
      currentPlayerIndex: source.currentPlayerIndex,
      phase: source.phase,
      turnPhase: source.turnPhase,
      round: source.round,
      discardPileFrozen: source.discardPileFrozen,
      hasDrawnFromDeck: source.hasDrawnFromDeck,
      hasMelded: source.hasMelded,
      soloSettings: source.soloSettings,
      finalTurnPhaseActive: source.finalTurnPhaseActive,
      playerWhoWentOutIndex: source.playerWhoWentOutIndex,
      playersAwaitingFinalTurn: Set<int>.from(source.playersAwaitingFinalTurn),
      winnerId: source.winner?.id,
    );
  }

  static AnalyticsPlayerSnapshot _mapPlayer(Player player) {
    return AnalyticsPlayerSnapshot(
      id: player.id,
      name: player.name,
      type: player.type,
      hand: List<PlayingCard>.from(player.hand),
      foot: List<PlayingCard>.from(player.foot),
      melds: player.melds
          .map(
            (meld) => AnalyticsMeldSnapshot(
              rank: meld.rank,
              cards: List<PlayingCard>.from(meld.cards),
            ),
          )
          .toList(growable: false),
      newlyDrawnCardIndices: Set<int>.from(player.newlyDrawnCardIndices),
      roundScoreHistory: List<RoundScoreBreakdown>.from(
        player.roundScoreHistory,
      ),
      hasPickedUpFoot: player.hasPickedUpFoot,
      hasPlayedDown: player.hasPlayedDown,
      score: player.score,
    );
  }
}
