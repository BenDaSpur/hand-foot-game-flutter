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
