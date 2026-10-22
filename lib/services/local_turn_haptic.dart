import '../models/game_state.dart';

/// Whether the local player should feel a pulse because play just became
/// their turn.
///
/// Covers three arrivals:
/// - the opening lead, when this device first sees them playing
/// - a new round they lead
/// - a later turn after someone else has played
bool shouldPulseForLocalTurn({
  required String? localPlayerId,
  required String? currentPlayerId,
  required String? previousPlayerId,
  required GamePhase phase,
  required GamePhase? previousPhase,
  required int round,
  required int? previousRound,
}) {
  if (localPlayerId == null || currentPlayerId != localPlayerId) {
    return false;
  }
  if (phase != GamePhase.playing) {
    return false;
  }

  final becameMyTurn =
      previousPlayerId != null && previousPlayerId != localPlayerId;
  final roundStartedWithMe = previousRound != null && round != previousRound;
  final playBeganWithMe = previousPhase != GamePhase.playing;
  return becameMyTurn || roundStartedWithMe || playBeganWithMe;
}

/// Remembers the last turn the screen observed so a later snapshot can tell
/// a new arrival from the rest of the same turn.
///
/// [reset] when a different game is bound. An import can share the human id,
/// phase, and round with the game already on screen, and those retained
/// values would otherwise hide the new game's turn.
class LocalTurnHapticObservation {
  String? playerId;
  GamePhase? phase;
  int? round;

  void reset() {
    playerId = null;
    phase = null;
    round = null;
  }

  bool shouldPulse({
    required String? localPlayerId,
    required String currentPlayerId,
    required GamePhase phase,
    required int round,
  }) {
    return shouldPulseForLocalTurn(
      localPlayerId: localPlayerId,
      currentPlayerId: currentPlayerId,
      previousPlayerId: playerId,
      phase: phase,
      previousPhase: this.phase,
      round: round,
      previousRound: this.round,
    );
  }

  void record({
    required String currentPlayerId,
    required GamePhase phase,
    required int round,
  }) {
    playerId = currentPlayerId;
    this.phase = phase;
    this.round = round;
  }
}
