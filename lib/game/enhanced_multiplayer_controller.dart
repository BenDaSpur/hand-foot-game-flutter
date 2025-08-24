import 'dart:async';
import 'dart:collection';
import '../models/card.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import 'game_controller.dart';
import 'network_adapter.dart';

/// Enhanced multiplayer game controller that follows DRY principles
/// by delegating game logic to the existing GameController while
/// managing multiplayer-specific concerns through NetworkAdapter
class EnhancedMultiplayerController {
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

      // Emit state to UI listeners
      _stateStreamController.add(_gameController.gameState);

      // Handle turn changes
      if (_isCurrentUser()) {
        _notifyStateChanged();
      }
    } catch (e) {
      // Log error
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
        await _networkAdapter.syncGameState(gameId, _gameController.gameState);
      } catch (e) {
        // Log sync error - individual network operations handle their own errors
      } finally {
        _isUpdating = false;
      }
    });
  }

  void _notifyStateChanged() {
    // Additional UI update logic if needed
  }

  // Delegate all game interface methods to the game controller
  // while adding multiplayer-specific logic

  GameState get gameState => _gameController.gameState;

  void initializeGame() {
    // Don't initialize for multiplayer - state comes from server
  }

  bool drawFromDeck() {
    if (!_isCurrentUser()) return false;

    final success = _gameController.drawFromDeck();
    if (success) {
      _stateStreamController.add(_gameController.gameState);
      if (_isOnline) {
        _syncGameState();
      }
    }
    return success;
  }

  bool drawFromDiscardPile() {
    if (!_isCurrentUser()) return false;

    final success = _gameController.drawFromDiscardPile();
    if (success) {
      _syncGameState();
    }
    return success;
  }

  bool unlockDiscardPile() {
    if (!_isCurrentUser()) return false;

    final success = _gameController.unlockDiscardPile();
    if (success) {
      _syncGameState();
    }
    return success;
  }

  bool canUnlockDiscard() {
    return _gameController.canUnlockDiscard();
  }

  bool createMeld(List<PlayingCard> cards) {
    if (!_isCurrentUser()) return false;

    final success = _gameController.createMeld(cards);
    if (success) {
      _syncGameState();
    }
    return success;
  }

  bool createMeldBypass(List<PlayingCard> cards) {
    if (!_isCurrentUser()) return false;

    final success = _gameController.createMeldBypass(cards);
    if (success) {
      _syncGameState();
    }
    return success;
  }

  bool createMeldByIndices(
    List<int> cardIndices, {
    bool skipPlayDownCheck = false,
  }) {
    if (!_isCurrentUser()) return false;

    final success = _gameController.createMeldByIndices(
      cardIndices,
      skipPlayDownCheck: skipPlayDownCheck,
    );
    if (success) {
      _syncGameState();
    }
    return success;
  }

  bool createMultipleMeldsFromIndices(
    List<List<int>> allMeldIndices, {
    bool skipPlayDownCheck = false,
  }) {
    if (!_isCurrentUser()) return false;

    final success = _gameController.createMultipleMeldsFromIndices(
      allMeldIndices,
      skipPlayDownCheck: skipPlayDownCheck,
    );
    if (success) {
      _syncGameState();
    }
    return success;
  }

  bool addCardToMeld(int meldIndex, PlayingCard card) {
    if (!_isCurrentUser()) return false;

    final success = _gameController.addCardToMeld(meldIndex, card);
    if (success) {
      _syncGameState();
    }
    return success;
  }

  bool discardCard(PlayingCard card) {
    if (!_isCurrentUser()) return false;

    final success = _gameController.discardCard(card);
    if (success) {
      _syncGameState();
    }
    return success;
  }

  // Delegate read-only operations directly
  bool canPlayerGoOut() => _gameController.canPlayerGoOut();

  bool get isGameOver => _gameController.isGameOver;

  Player? get winner => _gameController.winner;

  int get currentRound => _gameController.currentRound;

  List<Player> get leaderboard => _gameController.leaderboard;

  Map<String, dynamic> getGameStatus() => _gameController.getGameStatus();

  void nextRound() {
    // Host controls round progression
    if (_isHost) {
      _gameController.nextRound();
      _syncGameState();
    }
  }

  List<List<PlayingCard>> findPossibleMelds(Player player) {
    return _gameController.findPossibleMelds(player);
  }

  List<PlayingCard> getPlayableCards() {
    return _gameController.getPlayableCards();
  }

  Future<void> saveGame() async {
    // Multiplayer games are automatically saved via network sync
    // No local persistence needed
  }

  int? get gameSeed => _gameController.gameSeed;

  String? exportGameState() => _gameController.exportGameState();

  void clearAllNewlyDrawnCards() => _gameController.clearAllNewlyDrawnCards();

  // Multiplayer-specific properties
  bool get isHost => _isHost;
  String get userId => currentUserId;
  bool get isOnline => _isOnline;
  Stream<bool> get connectionStream => _networkAdapter.connectionStream;
  Stream<GameState> get gameStateStream => _stateStreamController.stream;

  void dispose() {
    _gameStateSubscription?.cancel();
    _connectionSubscription?.cancel();
    _reconnectionTimer?.cancel();
    _stateStreamController.close();
    _networkAdapter.dispose();
  }
}
