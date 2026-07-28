import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import 'game_providers.dart';

/// Reads the live [GameState] off the controller held by
/// [gameControllerProvider].
///
/// Every computed provider below must derive from [gameControllerProvider]
/// through this helper rather than from [currentGameStateProvider]. The
/// controller mutates one long-lived [GameState] instance, so a provider that
/// returns that instance emits an unchanged value on every turn; Riverpod's
/// equality check then suppresses the update and anything watching it keeps
/// serving whatever it computed the first time. [GameControllerState] carries a
/// version counter that changes on each turn/round event, so depending on it
/// directly keeps derived values honest.
GameState? _liveGameState(Ref ref) {
  return ref.watch(gameControllerProvider)?.controller.gameState;
}

/// Computed provider for current game state.
final currentGameStateProvider = Provider<GameState?>(_liveGameState);

/// Computed provider for current player (reactive)
final currentPlayerProvider = Provider<Player?>((ref) {
  return _liveGameState(ref)?.currentPlayer;
});

/// Computed provider for leaderboard (sorted by score) - reactive
final leaderboardProvider = Provider<List<Player>>((ref) {
  final gameState = _liveGameState(ref);
  if (gameState == null) return [];

  final sortedPlayers = List<Player>.from(gameState.players);
  sortedPlayers.sort((a, b) => b.score.compareTo(a.score));
  return sortedPlayers;
});

/// Computed provider for game status summary
final gameStatusProvider = Provider<Map<String, dynamic>>((ref) {
  final gameState = _liveGameState(ref);
  if (gameState == null) {
    return {
      'phase': 'setup',
      'turnPhase': 'draw',
      'currentPlayer': null,
      'round': 0,
      'deckSize': 0,
      'discardPileSize': 0,
    };
  }

  return {
    'phase': gameState.phase.name,
    'turnPhase': gameState.turnPhase.name,
    'currentPlayer': gameState.currentPlayer.name,
    'round': gameState.round,
    'deckSize': gameState.deck.size,
    'discardPileSize': gameState.discardPile.length,
    'topDiscard': gameState.topDiscard?.displayName,
    'canDrawFromDiscard': gameState.canDrawFromDiscard,
    'discardPileFrozen': gameState.discardPileFrozen,
  };
});

/// Computed provider for whether it's a human player's turn
final isHumanTurnProvider = Provider<bool>((ref) {
  final currentPlayer = ref.watch(currentPlayerProvider);
  return currentPlayer?.type == PlayerType.human;
});

/// Computed provider for whether it's a bot player's turn
final isBotTurnProvider = Provider<bool>((ref) {
  final currentPlayer = ref.watch(currentPlayerProvider);
  return currentPlayer?.type == PlayerType.bot;
});

/// Computed provider for whether the game has ended
final isGameEndedProvider = Provider<bool>((ref) {
  return _liveGameState(ref)?.phase == GamePhase.gameEnd;
});

/// Computed provider for whether the round has ended
final isRoundEndedProvider = Provider<bool>((ref) {
  return _liveGameState(ref)?.phase == GamePhase.roundEnd;
});

/// Computed provider for game winner
final gameWinnerProvider = Provider<Player?>((ref) {
  return _liveGameState(ref)?.winner;
});

/// Computed provider for human player
final humanPlayerProvider = Provider<Player?>((ref) {
  final gameState = _liveGameState(ref);
  if (gameState == null) return null;

  try {
    return gameState.players.firstWhere((p) => p.type == PlayerType.human);
  } catch (e) {
    return null;
  }
});

/// Computed provider for bot players
final botPlayersProvider = Provider<List<Player>>((ref) {
  final gameState = _liveGameState(ref);
  if (gameState == null) return [];

  return gameState.players.where((p) => p.type == PlayerType.bot).toList();
});

/// Computed provider for play-down requirement for current round
final playDownRequirementProvider = Provider<int>((ref) {
  return _liveGameState(ref)?.playDownRequirement ?? 0;
});
