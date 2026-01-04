import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import 'game_providers.dart';

/// Computed provider for current game state
/// Automatically updates when controller state changes (via event notifications)
final currentGameStateProvider = Provider<GameState?>((ref) {
  // Watch the controller state - when version changes, this will rebuild
  final controllerState = ref.watch(gameControllerProvider);
  // Force dependency on version by accessing it - this ensures rebuilds
  if (controllerState != null) {
    // Access version to create dependency - Riverpod will track this
    // The version change will cause this provider to rebuild
    controllerState.version; // Access to create dependency
    // Return game state - the version dependency ensures this rebuilds
    return controllerState.controller.gameState;
  }
  return null;
});

/// Computed provider for current player (reactive)
final currentPlayerProvider = Provider<Player?>((ref) {
  final gameState = ref.watch(currentGameStateProvider);
  return gameState?.currentPlayer;
});

/// Computed provider for leaderboard (sorted by score) - reactive
final leaderboardProvider = Provider<List<Player>>((ref) {
  final gameState = ref.watch(currentGameStateProvider);
  if (gameState == null) return [];
  
  final sortedPlayers = List<Player>.from(gameState.players);
  sortedPlayers.sort((a, b) => b.score.compareTo(a.score));
  return sortedPlayers;
});

/// Computed provider for game status summary
final gameStatusProvider = Provider<Map<String, dynamic>>((ref) {
  final gameState = ref.watch(currentGameStateProvider);
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
  final gameState = ref.watch(currentGameStateProvider);
  return gameState?.phase == GamePhase.gameEnd;
});

/// Computed provider for whether the round has ended
final isRoundEndedProvider = Provider<bool>((ref) {
  final gameState = ref.watch(currentGameStateProvider);
  return gameState?.phase == GamePhase.roundEnd;
});

/// Computed provider for game winner
final gameWinnerProvider = Provider<Player?>((ref) {
  final gameState = ref.watch(currentGameStateProvider);
  return gameState?.winner;
});

/// Computed provider for human player
final humanPlayerProvider = Provider<Player?>((ref) {
  final gameState = ref.watch(currentGameStateProvider);
  if (gameState == null) return null;
  
  try {
    return gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );
  } catch (e) {
    return null;
  }
});

/// Computed provider for bot players
final botPlayersProvider = Provider<List<Player>>((ref) {
  final gameState = ref.watch(currentGameStateProvider);
  if (gameState == null) return [];
  
  return gameState.players
      .where((p) => p.type == PlayerType.bot)
      .toList();
});

/// Computed provider for play-down requirement for current round
final playDownRequirementProvider = Provider<int>((ref) {
  final gameState = ref.watch(currentGameStateProvider);
  return gameState?.playDownRequirement ?? 0;
});

