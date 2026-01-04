import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/game_controller.dart';
import '../game/game_interface.dart';
import '../game/enhanced_multiplayer_controller.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../ai/enhanced_bot_ai.dart';
import '../game/events/game_event_bus.dart';
import '../game/events/game_event.dart';
import '../services/game_event_listener.dart';
import '../utils/debug_logger.dart';

/// Provider for the global game event bus
final gameEventBusProvider = Provider<GameEventBus>((ref) {
  return gameEventBus;
});

/// Wrapper class to force Riverpod to detect state changes
/// Since GameController reference doesn't change, we wrap it with a version counter
class GameControllerState {
  final GameController controller;
  final int version;

  GameControllerState(this.controller, [this.version = 0]);

  GameControllerState incrementVersion() {
    return GameControllerState(controller, version + 1);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameControllerState &&
        other.controller == controller &&
        other.version == version;
  }

  @override
  int get hashCode => Object.hash(controller, version);
}

/// Provider for the game controller (singleplayer)
/// This is a StateNotifier that manages the game controller lifecycle
/// and automatically notifies listeners when game state changes via events
class GameControllerNotifier extends StateNotifier<GameControllerState?> {
  StreamSubscription? _eventSubscription;
  GameEventBus? _eventBus;
  Timer? _debounceTimer;
  bool _pendingUpdate = false;
  bool _isUpdating = false; // Prevent concurrent updates
  DateTime? _lastUpdateTime; // Track when last update occurred
  static const _minUpdateInterval = Duration(
    milliseconds: 1000,
  ); // Minimum time between updates (increased to prevent loops)

  GameControllerNotifier() : super(null);

  void initializeGame({
    required List<Player> players,
    int? seed,
    GameEventBus? eventBus,
  }) {
    final controller = GameController(
      players: players,
      seed: seed,
      eventBus: eventBus,
    );
    _setControllerWithEventSubscription(controller, eventBus);
  }

  void setController(GameController controller, [GameEventBus? eventBus]) {
    _setControllerWithEventSubscription(controller, eventBus);
  }

  void _setControllerWithEventSubscription(
    GameController controller,
    GameEventBus? eventBus,
  ) {
    // Cancel previous subscription
    _eventSubscription?.cancel();
    _debounceTimer?.cancel();

    state = GameControllerState(controller);
    _eventBus = eventBus ?? gameEventBus;

    // Reset update tracking to prevent immediate updates after initialization
    _lastUpdateTime = DateTime.now();
    _pendingUpdate = false;
    _isUpdating = false;

    // Subscribe to events to trigger state notifications
    // This makes the provider reactive to game state changes
    // CRITICAL: Only update on turn/round/game-level events to prevent infinite loops
    // Don't update on every card/meld event - those are handled by direct state reads
    _eventSubscription = _eventBus!.subscribeWhere(
      (event) {
        // Only update on high-level events that require UI rebuilds
        // Skip individual card/meld events during bot turns to prevent excessive rebuilds
        if (event is TurnEndedEvent ||
            event is RoundStartedEvent ||
            event is RoundEndedEvent ||
            event is PlayerWentOutEvent ||
            event is GameEndedEvent) {
          return true;
        }
        // Update on CardDrawnEvent for human players (to show drawn cards immediately)
        if (event is CardDrawnEvent && event.player?.type == PlayerType.human) {
          return true;
        }
        // Update on DiscardPileUnlockedEvent for human players (to show unlocked cards)
        if (event is DiscardPileUnlockedEvent &&
            event.player?.type == PlayerType.human) {
          return true;
        }
        return false;
      },
      (event) {
        // Notify listeners that state may have changed
        // Use debouncing and rate limiting to prevent rapid-fire updates that cause infinite loops
        if (state != null && !_isUpdating) {
          // Critical events (turn/round/game changes + human draw actions) always update immediately
          final isCriticalEvent =
              event is TurnEndedEvent ||
              event is RoundStartedEvent ||
              event is RoundEndedEvent ||
              event is GameEndedEvent ||
              (event is CardDrawnEvent &&
                  event.player?.type == PlayerType.human) ||
              (event is DiscardPileUnlockedEvent &&
                  event.player?.type == PlayerType.human);

          // Rate limiting: Don't update if we updated too recently (unless it's a critical event)
          if (!isCriticalEvent) {
            final now = DateTime.now();
            if (_lastUpdateTime != null &&
                now.difference(_lastUpdateTime!) < _minUpdateInterval) {
              // Too soon since last update, skip this one
              DebugLogger.debug(
                'GameControllerNotifier: Rate limit - skipping update (${now.difference(_lastUpdateTime!).inMilliseconds}ms since last)',
              );
              return;
            }
          }

          // Additional guard: Don't update during bot turns to prevent loops
          // BUT always allow critical events to update so UI knows when turn changes
          final currentPlayer = state!.controller.gameState.currentPlayer;
          if (currentPlayer.type == PlayerType.bot && !isCriticalEvent) {
            // Skip updates during bot turns (except critical events)
            DebugLogger.debug(
              'GameControllerNotifier: Skipping update during bot turn (${currentPlayer.name})',
            );
            return;
          }

          _pendingUpdate = true;

          // Cancel existing timer
          _debounceTimer?.cancel();

          // Critical events update SYNCHRONOUSLY to prevent stale UI
          // Non-critical events use debounce to batch rapid updates
          if (isCriticalEvent) {
            // Update synchronously for critical events (turn/round/game changes)
            // This ensures UI reflects current state immediately when user interacts
            final currentState = state;
            if (currentState != null && !_isUpdating) {
              _isUpdating = true;
              try {
                DebugLogger.debug(
                  'GameControllerNotifier: SYNC update for critical event, version ${currentState.version}',
                );
                final newState = currentState.incrementVersion();
                state = newState;
                _pendingUpdate = false;
                _lastUpdateTime = DateTime.now();
                DebugLogger.debug(
                  'GameControllerNotifier: State updated to version ${newState.version}',
                );
              } catch (e) {
                DebugLogger.error(
                  'GameControllerNotifier: Error updating state: $e',
                );
                _pendingUpdate = false;
              } finally {
                _isUpdating = false;
              }
            } else {
              _pendingUpdate = false;
            }
          } else {
            // Schedule update after a delay to batch rapid events and prevent build loops
            _debounceTimer = Timer(const Duration(milliseconds: 500), () {
              // Check if notifier is still valid (not disposed) before updating
              if (_pendingUpdate && !_isUpdating) {
                final currentState = state;
                if (currentState != null) {
                  // Check rate limit again before updating
                  final now = DateTime.now();
                  if (_lastUpdateTime != null &&
                      now.difference(_lastUpdateTime!) < _minUpdateInterval) {
                    _pendingUpdate = false;
                    return;
                  }

                  _isUpdating = true;
                  try {
                    DebugLogger.debug(
                      'GameControllerNotifier: Applying debounced state update, version ${currentState.version}',
                    );
                    // Create new state with incremented version to trigger rebuild
                    final newState = currentState.incrementVersion();
                    state = newState;
                    _pendingUpdate = false;
                    _lastUpdateTime = now;
                    DebugLogger.debug(
                      'GameControllerNotifier: State updated to version ${newState.version}',
                    );
                  } catch (e) {
                    // Handle errors gracefully (e.g., if notifier was disposed during timer)
                    DebugLogger.error(
                      'GameControllerNotifier: Error updating state: $e',
                    );
                    _pendingUpdate = false;
                  } finally {
                    _isUpdating = false;
                  }
                } else {
                  // State is null, clear pending update
                  _pendingUpdate = false;
                }
              }
            });
          } // Close else block for non-critical events
        }
      },
    );
  }

  void disposeController() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    state?.controller.dispose();
    state = null;
  }

  @override
  void dispose() {
    // Cancel all subscriptions and timers
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    // Reset flags
    _pendingUpdate = false;
    _isUpdating = false;
    _lastUpdateTime = null;
    super.dispose();
  }
}

/// Provider for singleplayer game controller
/// Note: Not using autoDispose to preserve game state across hot reloads
final gameControllerProvider =
    StateNotifierProvider<GameControllerNotifier, GameControllerState?>((ref) {
      return GameControllerNotifier();
    });

/// Convenience provider to get the controller directly
final gameControllerDirectProvider = Provider<GameController?>((ref) {
  return ref.watch(gameControllerProvider)?.controller;
});

/// Provider for multiplayer game controller
final multiplayerControllerProvider =
    StateNotifierProvider<
      MultiplayerControllerNotifier,
      EnhancedMultiplayerController?
    >((ref) {
      return MultiplayerControllerNotifier();
    });

/// StateNotifier for multiplayer controller
class MultiplayerControllerNotifier
    extends StateNotifier<EnhancedMultiplayerController?> {
  MultiplayerControllerNotifier() : super(null);

  void setController(EnhancedMultiplayerController controller) {
    state = controller;
  }

  void disposeController() {
    state?.dispose();
    state = null;
  }
}

/// Provider that returns the current game interface (singleplayer or multiplayer)
final gameInterfaceProvider = Provider<GameInterface?>((ref) {
  final singleplayerState = ref.watch(gameControllerProvider);
  final singleplayer = singleplayerState?.controller;
  final multiplayer = ref.watch(multiplayerControllerProvider);

  return multiplayer ?? singleplayer;
});

/// Provider for bot AI instance
final botAIProvider = Provider<EnhancedBotAI>((ref) {
  return EnhancedBotAI();
});

/// Provider for reactive game state stream (singleplayer)
/// Uses event bus to create a stream that emits when game state changes
final gameStateStreamProvider = StreamProvider<GameState>((ref) {
  final gameInterface = ref.watch(gameInterfaceProvider);

  if (gameInterface is MultiplayerGameInterface) {
    return gameInterface.gameStateStream;
  }

  // For singleplayer: create stream from events + controller state
  final controllerState = ref.watch(gameControllerProvider);
  final controller = controllerState?.controller;
  final eventBus = ref.watch(gameEventBusProvider);

  if (controller == null) {
    return const Stream<GameState>.empty();
  }

  // Create a stream that emits on any game-changing event
  final controllerStream = StreamController<GameState>.broadcast();

  // Subscribe to events that indicate state changes
  final subscription = eventBus.subscribe((event) {
    controllerStream.add(controller.gameState);
  });

  // Emit initial state
  controllerStream.add(controller.gameState);

  ref.onDispose(() {
    subscription.cancel();
    controllerStream.close();
  });

  return controllerStream.stream;
});

/// Provider for game event listener service
final gameEventListenerProvider = Provider.autoDispose<GameEventListener>((
  ref,
) {
  final eventBus = ref.watch(gameEventBusProvider);
  final listener = GameEventListener(eventBus);
  listener.startListening();

  ref.onDispose(() {
    listener.dispose();
  });

  return listener;
});

// Computed providers moved to computed_providers.dart for better organization
