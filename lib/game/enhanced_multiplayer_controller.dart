import 'dart:async';
import 'dart:collection';
import '../models/card.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import 'game_controller.dart';
import 'network_adapter.dart';
import 'game_interface.dart';

/// Enhanced multiplayer game controller that follows DRY principles
/// by delegating game logic to the existing GameController while
/// managing multiplayer-specific concerns through NetworkAdapter
class EnhancedMultiplayerController implements MultiplayerGameInterface {
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
        isHost: false,
      );

      await controller._startListening();
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
    _reconnectionTimer = Timer(const Duration(seconds: 5), () async {
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
    _isUpdating = true;

    try {
      // Update local game state
      await _updateLocalGameState(newGameState);

      // Initialize from server state if this is the first update
      if (_gameController.gameState.phase == GamePhase.setup &&
          newGameState.phase != GamePhase.setup) {
        _initializeFromServerState(newGameState);
      }

      // Emit state to UI listeners
      _emitStateUpdate();

      // Handle turn changes and notifications
      if (_isCurrentUser()) {
        _notifyStateChanged();
      }
    } catch (e) {
      // Log error but continue
    } finally {
      _isUpdating = false;
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
  }

  void _replaceCollectionAtomically<T>(List<T> targetList, List<T> newData) {
    if (targetList.isEmpty) {
      targetList.addAll(newData);
    } else {
      targetList.replaceRange(0, targetList.length, newData);
    }
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

    while (_networkOperationQueue.isNotEmpty) {
      final operation = _networkOperationQueue.removeFirst();
      try {
        await operation();
      } catch (e) {
        // Log error but continue processing queue
        // Individual operations handle their own error reporting
      }
    }

    _isNetworkOperationInProgress = false;
  }

  Future<void> _syncGameState() async {
    if (_isUpdating) return;

    return _queueNetworkOperation(() async {
      _isUpdating = true;
      try {
        // Validate game state before syncing
        if (_validateGameStateForSync()) {
          await _networkAdapter.syncGameState(
            gameId,
            _gameController.gameState,
          );
        }
      } catch (e) {
        // Handle sync errors gracefully
        _handleSyncError(e);
      } finally {
        _isUpdating = false;
      }
    });
  }

  /// Validate game state before syncing to prevent corrupted states
  bool _validateGameStateForSync() {
    final gameState = _gameController.gameState;

    // Basic validation checks
    if (gameState.currentPlayerIndex < 0 ||
        gameState.currentPlayerIndex >= gameState.players.length) {
      return false;
    }

    if (gameState.round < 1) {
      return false;
    }

    // Ensure phase consistency
    if (gameState.phase == GamePhase.gameEnd && gameState.winner == null) {
      // Game is ended but no winner - this shouldn't happen
      return false;
    }

    return true;
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
    Timer(const Duration(seconds: 2), () {
      if (_isOnline && !_isUpdating) {
        _requestGameStateSync();
      }
    });
  }

  void _notifyStateChanged() {
    // Additional UI update logic if needed
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

  /// Initialize game state when it arrives from server (used internally)
  void _initializeFromServerState(GameState serverState) {
    // This method is called when we receive the initial game state from the server
    // Ensure the local controller is properly set up
    _gameController.gameState.phase = serverState.phase;
    _gameController.gameState.currentPlayerIndex =
        serverState.currentPlayerIndex;
    _gameController.gameState.turnPhase = serverState.turnPhase;
    _gameController.gameState.round = serverState.round;
  }

  @override
  bool drawFromDeck() {
    if (!canPerformAction('drawFromDeck')) return false;

    final success = _gameController.drawFromDeck();
    if (success) {
      _emitStateUpdate();
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
      _emitStateUpdate();
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
      _emitStateUpdate();
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
      _emitStateUpdate();
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
      _emitStateUpdate();
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
      _emitStateUpdate();
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
      _emitStateUpdate();
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
      _emitStateUpdate();
      if (_isOnline) {
        _syncGameState();
      }
    }
    return success;
  }

  @override
  bool discardCard(PlayingCard card) {
    if (!canPerformAction('discardCard')) return false;

    final success = _gameController.discardCard(card);
    if (success) {
      _emitStateUpdate();
      if (_isOnline) {
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
      _emitStateUpdate();
      if (_isOnline) {
        _syncGameState();
      }
    }
  }

  /// Helper method to emit state updates to UI listeners
  void _emitStateUpdate() {
    _stateStreamController.add(_gameController.gameState);
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
  String? exportGameState() => _gameController.exportGameState();

  @override
  void clearAllNewlyDrawnCards() => _gameController.clearAllNewlyDrawnCards();

  // Turn management for multiplayer
  @override
  bool get isMyTurn => _isCurrentUser();

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
    _gameStateSubscription?.cancel();
    _connectionSubscription?.cancel();
    _reconnectionTimer?.cancel();
    _stateStreamController.close();

    // Clear network operation queue to prevent memory leaks
    _networkOperationQueue.clear();
    _isNetworkOperationInProgress = false;

    _networkAdapter.dispose();
  }
}
