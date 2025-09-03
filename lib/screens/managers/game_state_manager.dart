import '../../models/player.dart';
import '../../models/game_state.dart';
import '../../game/game_controller.dart';
import '../../utils/debug_logger.dart';

/// Manages game state transitions and validation for the game screen.
///
/// This class handles round transitions, game end detection, state validation,
/// and other game state management concerns.
/// Extracted from GameScreen to improve code organization.
class GameStateManager {
  final GameController gameController;
  final Function() onStateChanged;
  final Function() onGameEnd;
  final Function() onRoundEnd;

  GameStateManager({
    required this.gameController,
    required this.onStateChanged,
    required this.onGameEnd,
    required this.onRoundEnd,
  });

  /// Check if round transition is needed and trigger it
  void checkForRoundTransition() {
    if (gameController.gameState.phase == GamePhase.roundEnd) {
      DebugLogger.debug('Triggering round transition check');
      handleRoundTransition().catchError((error) {
        DebugLogger.error('Error in round transition check: $error');
      });
    }
  }

  /// Check and handle round end if needed
  Future<void> checkAndHandleRoundEnd() async {
    if (gameController.gameState.phase == GamePhase.roundEnd) {
      await handleRoundTransition();
    }
  }

  /// Handle complete round transition with proper state management
  Future<void> handleRoundTransition() async {
    if (gameController.gameState.phase != GamePhase.roundEnd) return;

    DebugLogger.debug('Handling round transition - calculating scores');

    // Brief pause to show scores
    await Future.delayed(const Duration(seconds: 2));

    // Check if game should end (phase set to gameEnd by endRound() logic)
    if (gameController.gameState.phase == GamePhase.gameEnd) {
      final scores = gameController.gameState.players
          .map((p) => p.score)
          .toList();
      final highestScore = scores.isEmpty
          ? 0
          : scores.reduce((a, b) => a > b ? a : b);

      DebugLogger.debug(
        'Game end condition met - highest score: $highestScore',
      );
      onGameEnd();
      return;
    }

    // Continue to next round
    try {
      gameController.nextRound();
      DebugLogger.debug('Advanced to round ${gameController.gameState.round}');

      onStateChanged();
      onRoundEnd();
    } catch (e) {
      DebugLogger.error('Error during round transition: $e');
      throw Exception('Error advancing to next round: ${e.toString()}');
    }
  }

  /// Handle immediate round end during bot processing
  void handleRoundEnd() {
    if (gameController.gameState.phase == GamePhase.roundEnd) {
      DebugLogger.debug('Immediate round end handling');
      onStateChanged();
    }
  }

  /// Validate current game state for consistency
  bool validateGameState() {
    try {
      final gameState = gameController.gameState;

      // Basic state validation
      if (gameState.players.isEmpty) {
        DebugLogger.error('Game state invalid - no players');
        return false;
      }

      if (gameState.currentPlayerIndex < 0 ||
          gameState.currentPlayerIndex >= gameState.players.length) {
        DebugLogger.error(
          'Game state invalid - currentPlayerIndex out of bounds',
        );
        return false;
      }

      // Phase validation
      if (gameState.phase == GamePhase.setup) {
        DebugLogger.warning('Game state in setup phase during validation');
        return false;
      }

      return true;
    } catch (e) {
      DebugLogger.error('Error validating game state: $e');
      return false;
    }
  }

  /// Validate human player state for UI consistency
  void validateHumanPlayerState() {
    try {
      final humanPlayer = gameController.gameState.players.firstWhere(
        (p) => p.type == PlayerType.human,
        orElse: () => throw StateError('No human player found'),
      );

      final gameState = gameController.gameState;

      // Check for hand/foot consistency
      if (humanPlayer.hasPickedUpFoot && humanPlayer.foot.isNotEmpty) {
        DebugLogger.warning(
          'Human player has picked up foot but foot still contains cards',
        );
      }

      // Check for valid turn phase
      if (gameState.currentPlayer.id == humanPlayer.id) {
        if (gameState.turnPhase == TurnPhase.draw &&
            gameState.hasDrawnFromDeck) {
          DebugLogger.debug('Human should advance to meld phase');
        }
      }
    } catch (e) {
      DebugLogger.error('Error validating human player state: $e');
    }
  }

  /// Attempt to recover from corrupted game state
  bool attemptGameStateRecovery() {
    try {
      DebugLogger.debug('Attempting game state recovery');

      final gameState = gameController.gameState;

      // Reset to safe state
      if (gameState.phase == GamePhase.setup) {
        gameState.phase = GamePhase.playing;
      }

      if (gameState.currentPlayerIndex < 0 ||
          gameState.currentPlayerIndex >= gameState.players.length) {
        gameState.currentPlayerIndex = 0;
      }

      // Ensure valid turn phase
      if (gameState.turnPhase != TurnPhase.draw &&
          gameState.turnPhase != TurnPhase.meld &&
          gameState.turnPhase != TurnPhase.discard) {
        gameState.turnPhase = TurnPhase.draw;
        gameState.hasDrawnFromDeck = false;
      }

      DebugLogger.debug('Game state recovery completed');
      return true;
    } catch (e) {
      DebugLogger.error('Game state recovery failed: $e');
      return false;
    }
  }

  /// Force next player turn (emergency use only)
  void forceNextTurn() {
    try {
      DebugLogger.debug('Forcing turn advancement (emergency)');

      final gameState = gameController.gameState;

      // Reset turn state
      gameState.turnPhase = TurnPhase.draw;
      gameState.hasDrawnFromDeck = false;
      gameState.hasMelded = false;

      // Advance to next player
      gameState.nextPlayer();

      onStateChanged();

      DebugLogger.debug('Emergency turn advancement completed');
    } catch (e) {
      DebugLogger.error('Error in emergency turn advancement: $e');
    }
  }

  /// Get current game phase
  GamePhase get currentPhase => gameController.gameState.phase;

  /// Get current turn phase
  TurnPhase get currentTurnPhase => gameController.gameState.turnPhase;

  /// Get current player
  Player get currentPlayer => gameController.gameState.currentPlayer;

  /// Check if it's currently a human player's turn
  bool get isHumanTurn => currentPlayer.type == PlayerType.human;

  /// Check if it's currently a bot player's turn
  bool get isBotTurn => currentPlayer.type == PlayerType.bot;

  /// Check if the game has ended
  bool get isGameEnded => currentPhase == GamePhase.gameEnd;

  /// Check if the round has ended
  bool get isRoundEnded => currentPhase == GamePhase.roundEnd;
}
