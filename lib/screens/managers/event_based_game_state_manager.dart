import 'dart:async';
import '../../models/game_state.dart';
import '../../game/game_controller.dart';
import '../../game/events/game_event.dart';
import '../../game/events/game_event_bus.dart';
import '../../utils/debug_logger.dart';

/// Event-based game state manager that reacts to game events.
///
/// This is an alternative implementation that uses the event bus
/// instead of polling or callbacks. It demonstrates the event-driven
/// architecture pattern.
class EventBasedGameStateManager {
  final GameController gameController;
  final GameEventBus eventBus;
  final Function() onStateChanged;
  final Function() onTurnEnd; // Separate callback for turn end events
  final Function() onGameEnd;
  final Function() onRoundEnd;

  final List<StreamSubscription> _subscriptions = [];
  bool _isDisposed = false;

  EventBasedGameStateManager({
    required this.gameController,
    required this.eventBus,
    required this.onStateChanged,
    required this.onTurnEnd,
    required this.onGameEnd,
    required this.onRoundEnd,
  }) {
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    // Listen for round end events
    _subscriptions.add(
      eventBus.subscribeToType<RoundEndedEvent>((event) {
        if (_isDisposed) return;
        DebugLogger.debug(
          'Round ended event received: Round ${event.roundNumber}',
        );
        _handleRoundEnd();
      }),
    );

    // Listen for game end events
    _subscriptions.add(
      eventBus.subscribeToType<GameEndedEvent>((event) {
        if (_isDisposed) return;
        DebugLogger.debug(
          'Game ended event received: Winner ${event.winner.name}',
        );
        onGameEnd();
      }),
    );

    // Listen for round start events
    _subscriptions.add(
      eventBus.subscribeToType<RoundStartedEvent>((event) {
        if (_isDisposed) return;
        DebugLogger.debug(
          'Round started event received: Round ${event.roundNumber}',
        );
        onStateChanged();
        onRoundEnd(); // Clear UI selections for new round
      }),
    );

    // Listen for turn ended events to trigger state updates and bot turn processing
    _subscriptions.add(
      eventBus.subscribeToType<TurnEndedEvent>((event) {
        if (_isDisposed) return;
        DebugLogger.debug(
          'TurnEndedEvent received - triggering state update and turn processing',
        );
        onStateChanged(); // Update UI state
        onTurnEnd(); // Trigger bot turn processing (only on turn end, not every state change)
      }),
    );

    // Listen for any game-changing events
    _subscriptions.add(
      eventBus.subscribeWhere(
        (event) =>
            event is MeldCreatedEvent ||
            event is CardDiscardedEvent ||
            event is FootPickedUpEvent ||
            event is PlayedDownEvent,
        (event) {
          if (_isDisposed) return;
          onStateChanged();
        },
      ),
    );
  }

  void _handleRoundEnd() {
    if (gameController.gameState.phase == GamePhase.roundEnd) {
      DebugLogger.debug('Handling round end from event');

      // Check if game should end
      if (gameController.gameState.phase == GamePhase.gameEnd) {
        onGameEnd();
        return;
      }

      // Round transition will be handled by RoundStartedEvent
      onStateChanged();
    }
  }

  /// Handle round transition (can be called manually if needed)
  Future<void> handleRoundTransition() async {
    if (gameController.gameState.phase != GamePhase.roundEnd) return;

    DebugLogger.debug('Handling round transition - calculating scores');

    // Brief pause to show scores
    await Future.delayed(const Duration(seconds: 2));

    // Check if game should end
    if (gameController.gameState.phase == GamePhase.gameEnd) {
      onGameEnd();
      return;
    }

    // Continue to next round
    try {
      gameController.nextRound();
      DebugLogger.debug('Advanced to round ${gameController.gameState.round}');
      // RoundStartedEvent will trigger onStateChanged and onRoundEnd
    } catch (e) {
      DebugLogger.error('Error during round transition: $e');
      throw Exception('Error advancing to next round: ${e.toString()}');
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

  /// Dispose and clean up subscriptions
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
