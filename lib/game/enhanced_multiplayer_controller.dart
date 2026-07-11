import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/card.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../config/game_config.dart';
import '../models/multiplayer_errors.dart';
import '../services/multiplayer_resume_service.dart';
import '../services/firebase_service.dart';
import '../utils/debug_logger.dart';
import 'game_controller.dart';
import 'network_adapter.dart';
import 'game_interface.dart';

/// Enhanced multiplayer game controller that follows DRY principles
/// by delegating game logic to the existing GameController while
/// managing multiplayer-specific concerns through NetworkAdapter
class EnhancedMultiplayerController implements MultiplayerGameInterface {
  // Configuration constants
  static const Duration _syncRetryDelay = Duration(seconds: 2);
  static const Duration _reconnectionDelay = Duration(seconds: 5);
  final String gameId;
  final String currentUserId;
  final GameController _gameController;
  final NetworkAdapter _networkAdapter;

  StreamSubscription<GameState?>? _gameStateSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  bool _isUpdating = false; // Prevent sync loops
  final bool _isHost;
  bool _isOnline = true;
  Timer? _reconnectionTimer;

  // Race condition protection for network operations
  bool _isNetworkOperationInProgress = false;
  final Queue<Future<void> Function()> _networkOperationQueue =
      Queue<Future<void> Function()>();

  // Reactive state management
  final StreamController<GameState> _stateStreamController =
      StreamController<GameState>.broadcast();
  bool _isDisposed = false;

  EnhancedMultiplayerController._({
    required this.gameId,
    required this.currentUserId,
    required GameController gameController,
    required NetworkAdapter networkAdapter,
    required bool isHost,
  }) : _gameController = gameController,
       _networkAdapter = networkAdapter,
       _isHost = isHost;

  /// Factory method to create a new multiplayer game (host)
  static Future<EnhancedMultiplayerController?> createGame({
    required String hostPlayerName,
    required int maxPlayers,
    required NetworkAdapter networkAdapter,
  }) async {
    try {
      final userId = await networkAdapter.getCurrentUserId();
      if (userId == null) return null;

      final gameId = await networkAdapter.createGame(
        hostPlayerName: hostPlayerName,
        maxPlayers: maxPlayers,
      );
      if (gameId == null) return null;

      // Create host player for local game controller
      final hostPlayer = Player(
        id: userId,
        name: hostPlayerName,
        type: PlayerType.human,
      );

      final gameController = GameController(players: [hostPlayer]);

      final controller = EnhancedMultiplayerController._(
        gameId: gameId,
        currentUserId: userId,
        gameController: gameController,
        networkAdapter: networkAdapter,
        isHost: true,
      );

      await controller._startListening();

      // Save active game for crash recovery
      await MultiplayerResumeService.saveActiveGame(
        gameId: gameId,
        playerName: hostPlayerName,
        isHost: true,
      );

      return controller;
    } catch (e) {
      return null;
    }
  }

  /// Factory method to join an existing multiplayer game
  static Future<EnhancedMultiplayerController?> joinGame({
    required String gameId,
    required String playerName,
    required NetworkAdapter networkAdapter,
  }) async {
    try {
      final userId = await networkAdapter.getCurrentUserId();
      if (userId == null) return null;

      final success = await networkAdapter.joinGame(
        gameId: gameId,
        playerName: playerName,
      );
      if (!success) return null;

      final gameData = await FirebaseService.getGame(gameId);
      final isHost = gameData?['hostId'] == userId;

      // Create temporary player for local game controller
      final tempPlayer = Player(
        id: userId,
        name: playerName,
        type: PlayerType.human,
      );

      final gameController = GameController(players: [tempPlayer]);

      final controller = EnhancedMultiplayerController._(
        gameId: gameId,
        currentUserId: userId,
        gameController: gameController,
        networkAdapter: networkAdapter,
        isHost: isHost,
      );

      await controller._startListening();

      // Save active game for crash recovery (joining player)
      await MultiplayerResumeService.saveActiveGame(
        gameId: gameId,
        playerName: playerName,
        isHost: false,
      );

      return controller;
    } catch (e) {
      return null;
    }
  }

  /// Start the multiplayer game (host only)
  @override
  Future<bool> startMultiplayerGame() async {
    if (!_isHost) return false;
    return await _networkAdapter.startGame(gameId);
  }

  /// Leave the multiplayer game and clean up Firestore lobby/player records.
  @override
  Future<bool> leaveGame() async {
    if (_isDisposed) {
      return false;
    }
    return await _networkAdapter.leaveGame(gameId);
  }

  Future<void> _startListening() async {
    // Start network listeners
    _gameStateSubscription = _networkAdapter
        .listenToGameState(gameId)
        .listen(
          (newGameState) {
            if (newGameState != null && !_isUpdating && _isOnline) {
              _handleGameStateUpdate(newGameState);
            }
          },
          onError: (error) {
            if (_isOnline) {
              _scheduleReconnection();
            }
          },
        );

    _connectionSubscription = _networkAdapter.connectionStream.listen((
      isConnected,
    ) {
      _handleConnectionChange(isConnected);
    });
  }

  void _handleConnectionChange(bool isConnected) {
    final wasOnline = _isOnline;
    _isOnline = isConnected;

    if (!wasOnline && isConnected) {
      _onConnectionRestored();
    } else if (wasOnline && !isConnected) {
      _onConnectionLost();
    }
  }

  void _onConnectionRestored() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;

    // Restart listeners
    _gameStateSubscription?.cancel();
    _gameStateSubscription = _networkAdapter.listenToGameState(gameId).listen((
      newGameState,
    ) {
      if (newGameState != null && !_isUpdating && _isOnline) {
        _handleGameStateUpdate(newGameState);
      }
    });

    // Request fresh sync
    _requestGameStateSync();
  }

  void _onConnectionLost() {
    // Keep local game state intact for offline play
  }

  void _scheduleReconnection() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(_reconnectionDelay, () async {
      if (!_isOnline && _networkAdapter.isConnected) {
        _gameStateSubscription?.cancel();
        _gameStateSubscription = _networkAdapter
            .listenToGameState(gameId)
            .listen((newGameState) {
              if (newGameState != null && !_isUpdating && _isOnline) {
                _handleGameStateUpdate(newGameState);
              }
            });
      }
    });
  }

  void _requestGameStateSync() {
    if (_isCurrentUser()) {
      _syncGameState();
    }
  }

  Future<void> _handleGameStateUpdate(GameState newGameState) async {
    if (_isDisposed) return; // Don't process updates after disposal

    _isUpdating = true;

    try {
      // Check for player disconnections (player count decreased)
      final oldPlayerCount = _gameController.gameState.players.length;
      final newPlayerCount = newGameState.players.length;

      if (newPlayerCount < oldPlayerCount && newPlayerCount > 0) {
        _handlePlayerDisconnect(oldPlayerCount, newPlayerCount);
      }

      // Validate state consistency before applying update
      _validateStateConsistency(newGameState);

      // Update local game state
      await _updateLocalGameState(newGameState);

      // Initialize from server state if this is the first update (now properly awaited)
      if (_gameController.gameState.phase == GamePhase.setup &&
          newGameState.phase != GamePhase.setup) {
        await initializeFromServerState(newGameState);
      }

      // Emit state to UI listeners (only if not disposed)
      if (!_isDisposed) {
        emitStateUpdate();
      }

      // State has been successfully updated and emitted
    } catch (e) {
      // Enhanced error handling with recovery
      _handleConnectionError(e);
    } finally {
      _isUpdating = false;
    }
  }

  /// Handle player disconnection events
  void _handlePlayerDisconnect(int oldCount, int newCount) {
    final disconnectedCount = oldCount - newCount;
    DebugLogger.warning(
      '$disconnectedCount player(s) disconnected. Game continuing with $newCount players.',
    );

    // Could add UI notification here
    // For now, game just continues with remaining players
  }

  /// Enhanced error handling with recovery mechanisms
  void _handleConnectionError(dynamic error) {
    // Classify error type for targeted handling
    final specificError = _classifyError(error);
    DebugLogger.error(specificError.toString());

    switch (specificError) {
      case NetworkError _:
        _handleNetworkError(specificError);
        break;
      case ValidationError _:
        _handleValidationError(specificError);
        break;
      case SyncError _:
        _handleSyncErrorTyped(specificError);
        break;
      default:
        _handleGenericError(specificError);
    }
  }

  /// Classify generic errors into specific types
  MultiplayerError _classifyError(dynamic error) {
    final errorMessage = error.toString().toLowerCase();

    if (errorMessage.contains('network') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('timeout') ||
        errorMessage.contains('firebase')) {
      return NetworkError('Connection failed', error);
    }

    if (errorMessage.contains('invalid') ||
        errorMessage.contains('validation') ||
        errorMessage.contains('state')) {
      return ValidationError('Invalid game state', error);
    }

    if (errorMessage.contains('sync') || errorMessage.contains('update')) {
      return SyncError('Synchronization failed', gameId, error);
    }

    return const MultiplayerError('Unknown error');
  }

  void _handleNetworkError(NetworkError error) {
    // Cancel current subscriptions and reconnect
    _gameStateSubscription?.cancel();
    _connectionSubscription?.cancel();
    _gameStateSubscription = null;
    _connectionSubscription = null;

    // Attempt to reconnect after a delay
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(_reconnectionDelay, () {
      if (!_isDisposed) {
        _attemptReconnection();
      }
    });
  }

  void _handleValidationError(ValidationError error) {
    print('DEBUG: Validation error - requesting fresh game state');
    // Force state refresh on validation errors
  }

  void _handleSyncErrorTyped(SyncError error) {
    DebugLogger.debug('Sync error - will retry on next operation');
    // Sync errors are handled by retry mechanisms in _syncGameState
  }

  void _handleGenericError(MultiplayerError error) {
    print('DEBUG: Generic error - maintaining current state');
    // Fallback: attempt basic reconnection
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(_reconnectionDelay, () {
      if (!_isDisposed) {
        _attemptReconnection();
      }
    });
  }

  /// Attempt to reconnect to game after connection loss
  Future<void> _attemptReconnection() async {
    try {
      print('DEBUG: Attempting to reconnect to game...');

      // Restart listeners
      await _startListening();

      // Verify we can still access the game
      final canRejoin = await MultiplayerResumeService.canRejoinGame(gameId);
      if (!canRejoin) {
        print('DEBUG: Cannot rejoin game - may have ended or been deleted');
        // Game may have ended, user should return to main menu
      }
    } catch (e) {
      print('ERROR: Reconnection failed: $e');
      // Could implement exponential backoff here
    }
  }

  Future<void> _updateLocalGameState(GameState newGameState) async {
    final localGameState = _gameController.gameState;

    // Update primitive properties
    localGameState.currentPlayerIndex = newGameState.currentPlayerIndex;
    localGameState.phase = newGameState.phase;
    localGameState.turnPhase = newGameState.turnPhase;
    localGameState.round = newGameState.round;
    localGameState.winner = newGameState.winner;
    localGameState.discardPileFrozen = newGameState.discardPileFrozen;
    localGameState.hasDrawnFromDeck = newGameState.hasDrawnFromDeck;
    localGameState.hasMelded = newGameState.hasMelded;

    // Set multiplayer privacy controls
    localGameState.setMultiplayerMode(true, currentUserId);

    // Atomic collection updates
    _replaceCollectionAtomically(localGameState.players, newGameState.players);
    _replaceCollectionAtomically(
      localGameState.discardPile,
      newGameState.discardPile,
    );
    _replaceCollectionAtomically(
      localGameState.recentActions,
      newGameState.recentActions,
    );

    // Keep deck in sync after draws (authoritative server state)
    localGameState.deck.replaceCards(newGameState.deck.cards);
  }

  void _replaceCollectionAtomically<T>(List<T> targetList, List<T> newData) {
    // More efficient approach: clear and add all
    targetList.clear();
    targetList.addAll(newData);
  }

  bool _isCurrentUser() {
    return _gameController.gameState.currentPlayer.id == currentUserId;
  }

  @override
  Player? getCurrentUserPlayer() {
    try {
      return _gameController.gameState.players.firstWhere(
        (p) => p.id == currentUserId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Queues network operations to prevent race conditions
  /// All network operations should go through this method for thread safety
  Future<void> _queueNetworkOperation(Future<void> Function() operation) async {
    final completer = Completer<void>();

    _networkOperationQueue.add(() async {
      try {
        await operation();
        completer.complete();
      } catch (error) {
        completer.completeError(error);
      }
    });

    _processNetworkQueue();
    return completer.future;
  }

  /// Processes the network operation queue serially to prevent race conditions
  void _processNetworkQueue() async {
    if (_isNetworkOperationInProgress || _networkOperationQueue.isEmpty) {
      return;
    }

    _isNetworkOperationInProgress = true;

    try {
      while (_networkOperationQueue.isNotEmpty && !_isDisposed) {
        final operation = _networkOperationQueue.removeFirst();
        try {
          await operation();
        } catch (e) {
          // Enhanced error handling for individual operations
          final specificError = _classifyError(e);
          DebugLogger.error(
            'Queue operation failed: ${specificError.toString()}',
          );

          // For critical errors, clear remaining queue to prevent cascade failures
          if (specificError is NetworkError) {
            print(
              'DEBUG: Network error detected - clearing remaining queue operations',
            );
            _networkOperationQueue.clear();
            break;
          }

          // For non-critical errors, continue processing queue
        }
      }
    } catch (e) {
      // Catastrophic error - clear queue and reset state
      print('FATAL QUEUE ERROR: $e');
      _networkOperationQueue.clear();
    } finally {
      _isNetworkOperationInProgress = false;
    }
  }

  Future<void> _syncGameState() async {
    if (_isDisposed || _isUpdating) return;

    return _queueNetworkOperation(() async {
      if (_isDisposed) return; // Double-check after queuing

      _isUpdating = true;
      try {
        // Validate game state before syncing
        if (_validateGameStateForSync()) {
          print(
            'DEBUG: Syncing to Firebase - currentPlayerIndex: ${_gameController.gameState.currentPlayerIndex}',
          );
          await _networkAdapter.syncGameState(
            gameId,
            _gameController.gameState,
          );
          print('DEBUG: Firebase sync completed successfully');
        } else {
          print('DEBUG: Game state validation failed - not syncing');
        }
      } catch (e) {
        // Handle sync errors gracefully
        _handleSyncError(e);
      } finally {
        _isUpdating = false;
      }
    });
  }

  /// Comprehensive game state validation to prevent corrupted states
  bool _validateGameStateForSync() {
    final gameState = _gameController.gameState;

    // Critical validations
    if (gameState.players.isEmpty) {
      print('ERROR: Cannot sync - no players in game state');
      return false;
    }

    if (gameState.currentPlayerIndex < 0 ||
        gameState.currentPlayerIndex >= gameState.players.length) {
      print(
        'ERROR: Invalid current player index: ${gameState.currentPlayerIndex}',
      );
      return false;
    }

    // Ensure current user is still in the game
    final currentUserPlayer = getCurrentUserPlayer();
    if (currentUserPlayer == null) {
      print('ERROR: Current user not found in game players');
      return false;
    }

    // Validate round consistency
    if (gameState.round < 1) {
      print('ERROR: Invalid round number: ${gameState.round}');
      return false;
    }

    // Validate deck state
    if (gameState.deck.size < 0) {
      print('ERROR: Invalid deck size: ${gameState.deck.size}');
      return false;
    }

    // Ensure phase consistency
    if (gameState.phase == GamePhase.gameEnd && gameState.winner == null) {
      print('ERROR: Game ended but no winner declared');
      return false;
    }

    return true;
  }

  /// Detect and handle state conflicts
  void _validateStateConsistency(GameState serverState) {
    final localState = _gameController.gameState;

    // Detect major inconsistencies that require full state reset
    bool needsFullReset = false;

    if (serverState.players.length != localState.players.length) {
      print('DEBUG: Player count mismatch - forcing full state reset');
      needsFullReset = true;
    }

    if (serverState.round != localState.round) {
      print(
        'DEBUG: Round mismatch - server: ${serverState.round}, local: ${localState.round}',
      );
      needsFullReset = true;
    }

    if (needsFullReset) {
      print('DEBUG: Forcing complete state replacement due to inconsistencies');
      // Force complete state replacement will happen in next update cycle
    }
  }

  /// Handle synchronization errors with appropriate fallback behavior
  void _handleSyncError(dynamic error) {
    // For now, just ensure we don't break the game flow
    // Could implement retry logic, conflict resolution, etc.

    // If we're offline, the error is expected
    if (!_isOnline) {
      return;
    }

    // For sync errors while online, we might want to:
    // 1. Retry after a delay
    // 2. Request fresh game state from server
    // 3. Show user a sync issue notification

    // Simple approach: request fresh sync after a delay
    Timer(_syncRetryDelay, () {
      if (_isOnline && !_isUpdating) {
        _requestGameStateSync();
      }
    });
  }

  // Delegate all game interface methods to the game controller
  // while adding multiplayer-specific logic

  @override
  GameState get gameState => _gameController.gameState;

  @override
  void initializeGame() {
    // Don't initialize for multiplayer - state comes from server
    // Game initialization happens in FirebaseService.startGame()
  }

  /// Initialize game state when it arrives from server (public for testing)
  @visibleForTesting
  Future<void> initializeFromServerState(GameState serverState) async {
    // CRITICAL FIX: Replace entire local game state with server state
    // The server has the authoritative game state with all players and proper initialization

    // Replace all game state properties
    _gameController.gameState.phase = serverState.phase;
    _gameController.gameState.currentPlayerIndex =
        serverState.currentPlayerIndex;
    _gameController.gameState.turnPhase = serverState.turnPhase;
    _gameController.gameState.round = serverState.round;
    _gameController.gameState.winner = serverState.winner;
    _gameController.gameState.discardPileFrozen = serverState.discardPileFrozen;
    _gameController.gameState.hasDrawnFromDeck = serverState.hasDrawnFromDeck;
    _gameController.gameState.hasMelded = serverState.hasMelded;

    // Keep minimal logging for important game state changes
    if (serverState.currentPlayerIndex !=
        _gameController.gameState.currentPlayerIndex) {
      print(
        'DEBUG: Turn changed to player ${serverState.currentPlayerIndex} (${serverState.players[serverState.currentPlayerIndex].name})',
      );
    }

    // Replace players list with server players (this is the key fix)
    _gameController.gameState.players.clear();
    _gameController.gameState.players.addAll(serverState.players);

    // Replace deck state
    _gameController.gameState.deck.replaceCards(serverState.deck.cards);

    // Replace discard pile
    _gameController.gameState.discardPile.clear();
    _gameController.gameState.discardPile.addAll(serverState.discardPile);

    // Replace recent actions
    _gameController.gameState.recentActions.clear();
    _gameController.gameState.recentActions.addAll(serverState.recentActions);
  }

  @override
  bool drawFromDeck() {
    if (_isDisposed) {
      print('DEBUG: drawFromDeck failed - controller disposed');
      return false;
    }

    if (!canPerformAction('drawFromDeck')) {
      print('DEBUG: drawFromDeck failed - canPerformAction returned false');
      print('  isMyTurn: $isMyTurn');
      print('  gamePhase: ${_gameController.gameState.phase}');
      print('  turnPhase: ${_gameController.gameState.turnPhase}');
      print('  currentPlayer: ${getCurrentUserPlayer()?.name ?? "null"}');
      print('  availableActions: ${getAvailableActions()}');
      print(
        '  hasDrawnFromDeck: ${_gameController.gameState.hasDrawnFromDeck}',
      );
      return false;
    }

    print('DEBUG: Attempting to draw from deck...');
    print('  deckSize: ${_gameController.gameState.deck.size}');
    print('  requiredDrawCount: ${GameConfig.requiredDrawCount}');

    final success = _gameController.drawFromDeck();
    print('DEBUG: drawFromDeck result: $success');

    if (success && !_isDisposed) {
      emitStateUpdate();
      if (_isOnline) {
        _syncGameState();
      }
    }
    return success;
  }

  @override
  bool drawFromDiscardPile() {
    if (!canPerformAction('drawFromDiscardPile')) return false;

    final success = _gameController.drawFromDiscardPile();
    if (success) {
      emitStateUpdate();
      if (_isOnline) {
        _syncGameState();
      }
    }
    return success;
  }

  @override
  bool unlockDiscardPile() {
    if (!canPerformAction('unlockDiscardPile')) return false;

    final success = _gameController.unlockDiscardPile();
    if (success) {
      emitStateUpdate();
      if (_isOnline) {
        _syncGameState();
      }
    }
    return success;
  }

  @override
  bool canUnlockDiscard() {
    return _gameController.canUnlockDiscard();
  }

  @override
  bool createMeld(List<PlayingCard> cards) {
    if (!canPerformAction('createMeld')) return false;

    final success = _gameController.createMeld(cards);
    if (success) {
      emitStateUpdate();
      if (_isOnline) {
        _syncGameState();
      }
    }
    return success;
  }

  @override
  bool createMeldBypass(List<PlayingCard> cards) {
    if (!canPerformAction('createMeld')) return false;

    final success = _gameController.createMeldBypass(cards);
    if (success) {
      emitStateUpdate();
      if (_isOnline) {
        _syncGameState();
      }
    }
    return success;
  }

  @override
  bool createMeldByIndices(
    List<int> cardIndices, {
    bool skipPlayDownCheck = false,
  }) {
    if (!canPerformAction('createMeld')) return false;

    final success = _gameController.createMeldByIndices(
      cardIndices,
      skipPlayDownCheck: skipPlayDownCheck,
    );
    if (success) {
      emitStateUpdate();
      if (_isOnline) {
        _syncGameState();
      }
    }
    return success;
  }

  @override
  bool createMultipleMeldsFromIndices(
    List<List<int>> allMeldIndices, {
    bool skipPlayDownCheck = false,
  }) {
    if (!canPerformAction('createMeld')) return false;

    final success = _gameController.createMultipleMeldsFromIndices(
      allMeldIndices,
      skipPlayDownCheck: skipPlayDownCheck,
    );
    if (success) {
      emitStateUpdate();
      if (_isOnline) {
        _syncGameState();
      }
    }
    return success;
  }

  @override
  bool addCardToMeld(int meldIndex, PlayingCard card) {
    if (!canPerformAction('addToMeld')) return false;

    final success = _gameController.addCardToMeld(meldIndex, card);
    if (success) {
      emitStateUpdate();
      if (_isOnline) {
        _syncGameState();
      }
    }
    return success;
  }

  @override
  bool discardCard(PlayingCard card) {
    if (!canPerformAction('discardCard')) return false;

    print('DEBUG: Attempting to discard ${card.compactName}...');
    print(
      '  currentPlayerIndex before: ${_gameController.gameState.currentPlayerIndex}',
    );
    print('  turnPhase before: ${_gameController.gameState.turnPhase}');

    final success = _gameController.discardCard(card);

    print('DEBUG: Discard result: $success');
    if (success) {
      print(
        '  currentPlayerIndex after: ${_gameController.gameState.currentPlayerIndex}',
      );
      print('  turnPhase after: ${_gameController.gameState.turnPhase}');

      // The GameController.discardCard() automatically advances turn and handles round end
      // We just need to sync the new state to all players
      emitStateUpdate();
      if (_isOnline) {
        print('DEBUG: Syncing game state after discard...');
        _syncGameState();
      }
    }
    return success;
  }

  // Delegate read-only operations directly
  @override
  bool canPlayerGoOut() => _gameController.canPlayerGoOut();

  @override
  bool get isGameOver => _gameController.isGameOver;

  @override
  Player? get winner => _gameController.winner;

  @override
  int get currentRound => _gameController.currentRound;

  @override
  List<Player> get leaderboard => _gameController.leaderboard;

  @override
  Map<String, dynamic> getGameStatus() => _gameController.getGameStatus();

  @override
  void nextRound() {
    // Host controls round progression
    if (_isHost) {
      _gameController.nextRound();
      emitStateUpdate();
      if (_isOnline) {
        _syncGameState();
      }
    }
  }

  /// Helper method to emit state updates to UI listeners
  @visibleForTesting
  void emitStateUpdate() {
    if (!_isDisposed && !_stateStreamController.isClosed) {
      _stateStreamController.add(_gameController.gameState);
    }
  }

  @override
  List<List<PlayingCard>> findPossibleMelds(Player player) {
    return _gameController.findPossibleMelds(player);
  }

  @override
  List<PlayingCard> getPlayableCards() {
    return _gameController.getPlayableCards();
  }

  @override
  Future<void> saveGame() async {
    // Multiplayer games are automatically saved via network sync
    // No local persistence needed
  }

  @override
  int? get gameSeed => _gameController.gameSeed;

  @override
  String? exportGameState([Map<String, String>? botPersonalities]) =>
      _gameController.exportGameState(botPersonalities);

  @override
  void clearAllNewlyDrawnCards() => _gameController.clearAllNewlyDrawnCards();

  // Turn management for multiplayer
  @override
  bool get isMyTurn => _isCurrentUser();

  // Debug properties for troubleshooting
  @visibleForTesting
  bool get isDisposed => _isDisposed;

  /// Get available actions for the current player
  @override
  List<String> getAvailableActions() {
    if (!isMyTurn) return [];

    final currentPlayer = getCurrentUserPlayer();
    if (currentPlayer == null) return [];

    final actions = <String>[];
    final gameState = _gameController.gameState;

    switch (gameState.turnPhase) {
      case TurnPhase.draw:
        if (!gameState.hasDrawnFromDeck) {
          actions.add('drawFromDeck');
          if (gameState.canDrawFromDiscard) {
            actions.add('drawFromDiscardPile');
          }
        }
        break;

      case TurnPhase.meld:
        // Always allow discarding during meld phase
        actions.add('discardCard');

        // Add melding options if player has cards
        if (currentPlayer.currentHand.isNotEmpty) {
          actions.add('createMeld');

          // Allow adding to existing melds if player has played down
          if (currentPlayer.hasPlayedDown && currentPlayer.melds.isNotEmpty) {
            actions.add('addToMeld');
          }
        }

        // Allow unlocking discard pile if conditions are met
        if (_gameController.canUnlockDiscard()) {
          actions.add('unlockDiscardPile');
        }
        break;

      case TurnPhase.discard:
        actions.add('discardCard');
        break;
    }

    return actions;
  }

  /// Check if a specific action is available for the current player
  @override
  bool canPerformAction(String action) {
    // CRITICAL: Only allow actions if it's the current user's turn
    if (!isMyTurn) {
      return false;
    }

    // Additional validation: ensure game is in playable state (playing or setup)
    if (_gameController.gameState.phase != GamePhase.playing &&
        _gameController.gameState.phase != GamePhase.setup) {
      return false;
    }

    // Check if user is in the game
    final currentPlayer = getCurrentUserPlayer();
    if (currentPlayer == null) {
      return false;
    }

    return getAvailableActions().contains(action);
  }

  /// Get turn status information for UI
  @override
  Map<String, dynamic> getTurnStatus() {
    return {
      'isMyTurn': isMyTurn,
      'currentPlayer': gameState.currentPlayer.name,
      'turnPhase': gameState.turnPhase.name,
      'availableActions': getAvailableActions(),
      'hasDrawn': gameState.hasDrawnFromDeck,
      'hasMelded': gameState.hasMelded,
    };
  }

  // Multiplayer-specific properties
  @override
  bool get isHost => _isHost;
  @override
  String get userId => currentUserId;
  @override
  bool get isOnline => _isOnline;
  @override
  Stream<bool> get connectionStream => _networkAdapter.connectionStream;
  @override
  Stream<GameState> get gameStateStream => _stateStreamController.stream;

  void dispose() {
    print(
      'DEBUG: EnhancedMultiplayerController.dispose() called for game: $gameId',
    );
    print('  userId: $currentUserId');
    print('  isHost: $_isHost');

    _isDisposed = true; // Mark as disposed to prevent further operations

    _gameStateSubscription?.cancel();
    _connectionSubscription?.cancel();
    _reconnectionTimer?.cancel();

    if (!_stateStreamController.isClosed) {
      _stateStreamController.close();
    }

    // Clear network operation queue to prevent memory leaks
    _networkOperationQueue.clear();
    _isNetworkOperationInProgress = false;

    // Only clear active game info when explicitly leaving (not on crashes)
    // MultiplayerResumeService.clearActiveGame() should be called manually when leaving

    _networkAdapter.dispose();
    print('DEBUG: EnhancedMultiplayerController disposal complete');
  }
}
