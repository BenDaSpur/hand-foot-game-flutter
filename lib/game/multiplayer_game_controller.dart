import 'dart:async';
import '../models/card.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../services/firebase_service.dart';
import 'game_controller.dart';

/// Multiplayer-enabled game controller that synchronizes with Firebase
class MultiplayerGameController {
  final String gameId;
  final String currentUserId;
  final GameController _localController;
  StreamSubscription<GameState?>? _gameStateSubscription;

  bool _isUpdating = false; // Prevent infinite loops
  bool _isHost = false;

  MultiplayerGameController._({
    required this.gameId,
    required this.currentUserId,
    required GameController localController,
  }) : _localController = localController;

  /// Create a new multiplayer game (host)
  static Future<MultiplayerGameController?> createGame({
    required String hostPlayerName,
    required int maxPlayers,
    required String hostUserId,
  }) async {
    try {
      // Get device-based user ID
      final deviceUserId = await FirebaseService.getDeviceUserId();
      if (deviceUserId == null) return null;

      // Create game in Firebase
      final gameId = await FirebaseService.createGame(
        hostPlayerName: hostPlayerName,
        maxPlayers: maxPlayers,
      );

      if (gameId == null) return null;

      // Create initial host player
      final hostPlayer = Player(
        id: deviceUserId,
        name: hostPlayerName,
        type: PlayerType.human,
      );

      // Create local game controller
      final localController = GameController(players: [hostPlayer]);

      final controller = MultiplayerGameController._(
        gameId: gameId,
        currentUserId: deviceUserId,
        localController: localController,
      );

      controller._isHost = true;
      await controller._startListening();

      return controller;
    } catch (e) {
      await FirebaseService.logGameEvent(
        'multiplayer_create_error',
        parameters: {'error': e.toString()},
      );
      return null;
    }
  }

  /// Join an existing multiplayer game
  static Future<MultiplayerGameController?> joinGame({
    required String gameId,
    required String playerName,
    required String userId,
  }) async {
    try {
      // Get device-based user ID
      final deviceUserId = await FirebaseService.getDeviceUserId();
      if (deviceUserId == null) return null;

      // Join game in Firebase
      final success = await FirebaseService.joinGame(
        gameId: gameId,
        playerName: playerName,
      );

      if (!success) return null;

      // Create temporary controller to listen for game state
      final player = Player(
        id: deviceUserId,
        name: playerName,
        type: PlayerType.human,
      );

      // Create local game controller
      final localController = GameController(players: [player]);

      final controller = MultiplayerGameController._(
        gameId: gameId,
        currentUserId: deviceUserId,
        localController: localController,
      );

      await controller._startListening();

      return controller;
    } catch (e) {
      await FirebaseService.logGameEvent(
        'multiplayer_join_error',
        parameters: {'error': e.toString()},
      );
      return null;
    }
  }

  /// Start the multiplayer game (host only)
  Future<bool> startMultiplayerGame() async {
    if (!_isHost) return false;

    try {
      final success = await FirebaseService.startGame(gameId);
      if (success) {
        await FirebaseService.logGameStarted(
          playerCount: gameState.players.length,
        );
      }
      return success;
    } catch (e) {
      await FirebaseService.logGameEvent(
        'multiplayer_start_error',
        parameters: {'error': e.toString()},
      );
      return false;
    }
  }

  /// Start listening to real-time game state changes
  Future<void> _startListening() async {
    _gameStateSubscription = FirebaseService.listenToGameState(gameId).listen(
      (newGameState) {
        if (newGameState != null && !_isUpdating) {
          _handleGameStateUpdate(newGameState);
        }
      },
      onError: (error) {
        FirebaseService.logSyncIssue(
          issueType: 'game_state_sync_error',
          errorMessage: error.toString(),
          gameId: gameId,
        );
      },
    );
  }

  /// Handle incoming game state updates from Firebase
  void _handleGameStateUpdate(GameState newGameState) {
    _isUpdating = true;

    try {
      // Update local game state with the new state from Firebase
      _updateLocalGameState(newGameState);

      // If it's our turn and we're not the current player, update
      final currentPlayer = newGameState.currentPlayer;
      if (currentPlayer.id == currentUserId) {
        // It's our turn - ensure UI is updated
        _notifyStateChanged();
      }
    } catch (e) {
      FirebaseService.logGameStateError(
        errorType: 'state_update_error',
        errorMessage: e.toString(),
        gameContext: {'gameId': gameId, 'userId': currentUserId},
      );
    } finally {
      _isUpdating = false;
    }
  }

  /// Update the local game state with data from Firebase
  void _updateLocalGameState(GameState newGameState) {
    // Copy the game state manually by replacing the internal state
    final localGameState = _localController.gameState;

    // Clear and update players
    localGameState.players.clear();
    localGameState.players.addAll(newGameState.players);

    // Update mutable game state properties
    localGameState.currentPlayerIndex = newGameState.currentPlayerIndex;
    localGameState.phase = newGameState.phase;
    localGameState.turnPhase = newGameState.turnPhase;
    localGameState.round = newGameState.round;
    localGameState.winner = newGameState.winner;
    localGameState.discardPileFrozen = newGameState.discardPileFrozen;
    localGameState.hasDrawnFromDeck = newGameState.hasDrawnFromDeck;
    localGameState.hasMelded = newGameState.hasMelded;

    // Update collections by clearing and re-adding
    localGameState.discardPile.clear();
    localGameState.discardPile.addAll(newGameState.discardPile);

    localGameState.recentActions.clear();
    localGameState.recentActions.addAll(newGameState.recentActions);
  }

  /// Delegate game actions to local controller and sync with Firebase
  bool drawFromDeck() {
    if (!_isCurrentUser()) return false;

    final success = _localController.drawFromDeck();
    if (success) {
      _syncGameState();
      _logPlayerAction('draw_from_deck', success: success);
    }
    return success;
  }

  bool drawFromDiscardPile() {
    if (!_isCurrentUser()) return false;

    final success = _localController.drawFromDiscardPile();
    if (success) {
      _syncGameState();
      _logPlayerAction('draw_from_discard', success: success);
    }
    return success;
  }

  bool unlockDiscardPile() {
    if (!_isCurrentUser()) return false;

    final success = _localController.unlockDiscardPile();
    if (success) {
      _syncGameState();
      _logPlayerAction('unlock_discard', success: success);
    }
    return success;
  }

  bool createMeld(List<PlayingCard> cards) {
    if (!_isCurrentUser()) return false;

    final success = _localController.createMeld(cards);
    if (success) {
      _syncGameState();
      _logMeldAction(cards, success);
    }
    return success;
  }

  bool createMeldByIndices(
    List<int> cardIndices, {
    bool skipPlayDownCheck = false,
  }) {
    if (!_isCurrentUser()) return false;

    final success = _localController.createMeldByIndices(
      cardIndices,
      skipPlayDownCheck: skipPlayDownCheck,
    );
    if (success) {
      _syncGameState();
      _logPlayerAction('create_meld_by_indices', success: success);
    }
    return success;
  }

  bool createMultipleMeldsFromIndices(
    List<List<int>> allMeldIndices, {
    bool skipPlayDownCheck = false,
  }) {
    if (!_isCurrentUser()) return false;

    final success = _localController.createMultipleMeldsFromIndices(
      allMeldIndices,
      skipPlayDownCheck: skipPlayDownCheck,
    );
    if (success) {
      _syncGameState();
      _logPlayerAction('create_multiple_melds', success: success);
    }
    return success;
  }

  bool addCardToMeld(int meldIndex, PlayingCard card) {
    if (!_isCurrentUser()) return false;

    final success = _localController.addCardToMeld(meldIndex, card);
    if (success) {
      _syncGameState();
      _logPlayerAction('add_to_meld', success: success);
    }
    return success;
  }

  bool discardCard(PlayingCard card) {
    if (!_isCurrentUser()) return false;

    final success = _localController.discardCard(card);
    if (success) {
      _syncGameState();
      _logPlayerAction('discard', success: success);

      // Check if game ended
      if (gameState.phase == GamePhase.gameEnd) {
        _logGameCompletion();
      }
    }
    return success;
  }

  /// Get the current game state
  GameState get gameState => _localController.gameState;

  /// Sync the current game state to Firebase
  Future<void> _syncGameState() async {
    if (_isUpdating) return; // Prevent sync loops

    _isUpdating = true;
    try {
      await FirebaseService.updateGameState(gameId, gameState);
    } catch (e) {
      FirebaseService.logSyncIssue(
        issueType: 'game_state_sync_failed',
        errorMessage: e.toString(),
        gameId: gameId,
      );
    } finally {
      _isUpdating = false;
    }
  }

  /// Check if the current user is the active player
  bool _isCurrentUser() {
    return gameState.currentPlayer.id == currentUserId;
  }

  /// Get the current user's player object
  Player? getCurrentUserPlayer() {
    try {
      return gameState.players.firstWhere((p) => p.id == currentUserId);
    } catch (e) {
      return null;
    }
  }

  /// Log player actions for analytics and debugging
  void _logPlayerAction(String action, {required bool success, String? error}) {
    FirebaseService.logPlayerAction(
      action,
      playerId: currentUserId,
      success: success,
      errorMessage: error,
      additionalData: {
        'game_id': gameId,
        'round': gameState.round,
        'turn_phase': gameState.turnPhase.name,
      },
    );
  }

  /// Log meld creation with details
  void _logMeldAction(List<PlayingCard> cards, bool success) {
    final humanPlayer = getCurrentUserPlayer();
    if (humanPlayer != null) {
      FirebaseService.logMeldAttempt(
        playerId: currentUserId,
        cardCount: cards.length,
        success: success,
        isFirstMeld: !humanPlayer.hasPlayedDown,
        pointValue: cards.fold<int>(0, (sum, card) => sum + card.pointValue),
      );
    }
  }

  /// Log game completion
  void _logGameCompletion() {
    FirebaseService.logGameCompleted(
      playerCount: gameState.players.length,
      roundCount: gameState.round,
      gameDurationSeconds: 0, // TODO: Track actual game duration
    );
  }

  /// Initialize the game (delegate to local controller)
  void initializeGame() {
    _localController.initializeGame();
  }

  /// Check if player can go out (delegate to local controller)
  bool canPlayerGoOut() {
    return _localController.canPlayerGoOut();
  }

  /// Get game status (delegate to local controller)
  Map<String, dynamic> getGameStatus() {
    return _localController.getGameStatus();
  }

  /// Check if game is over (delegate to local controller)
  bool get isGameOver => _localController.isGameOver;

  /// Get winner (delegate to local controller)
  Player? get winner => _localController.winner;

  /// Get current round (delegate to local controller)
  int get currentRound => _localController.currentRound;

  /// Get leaderboard (delegate to local controller)
  List<Player> get leaderboard => _localController.leaderboard;

  /// Notify listeners that state has changed (for UI updates)
  void _notifyStateChanged() {
    // This would typically be handled by a state management solution
    // For now, we'll rely on the UI polling for updates
  }

  /// Check if current user is the game host
  bool get isHost => _isHost;

  /// Get current user ID
  String get userId => currentUserId;

  /// Dispose of resources
  void dispose() {
    _gameStateSubscription?.cancel();
  }
}
