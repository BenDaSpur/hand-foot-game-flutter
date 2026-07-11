import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/deck.dart';
import '../models/card.dart';
import '../models/meld.dart';
import '../models/multiplayer_result.dart';
import 'firebase_constants.dart';
import 'device_service.dart';

// Import Firebase options - production builds inject config via Vercel or CI secrets
import '../firebase_options.dart';

/// Firebase service for handling multiplayer game state synchronization
class FirebaseService {
  static final Logger _logger = Logger('FirebaseService');
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Use constants from FirebaseConstants
  static const String gamesCollection = FirebaseConstants.gamesCollection;
  static const String playersCollection = FirebaseConstants.playersCollection;
  static const String userLimitsCollection =
      FirebaseConstants.userLimitsCollection;

  // Rate limiting constants
  static const int maxGamesPerUserPerHour =
      FirebaseConstants.maxGamesPerUserPerHour;
  static const int maxGamesPerUserPerDay =
      FirebaseConstants.maxGamesPerUserPerDay;

  static bool _firebaseCoreInitialized = false;
  static bool _isAuthenticated = false;
  static String? lastOperationError;

  /// True when Firebase options point at a real project (not the public stub).
  static bool get isConfigured {
    try {
      return !DefaultFirebaseOptions.currentPlatform.projectId.contains('stub');
    } catch (e) {
      return false;
    }
  }

  /// True when Firebase is configured and the user has an anonymous auth session.
  static bool get isMultiplayerAvailable => isConfigured && _isAuthenticated;

  /// Initialize Firebase with proper configuration
  static Future<void> initialize() async {
    // In test environments, skip Firebase initialization completely
    final bool isTestEnvironment = const bool.fromEnvironment(
      'FLUTTER_TEST',
      defaultValue: false,
    );

    if (isTestEnvironment) {
      _logger.info('Skipping Firebase initialization in test environment');
      return;
    }

    try {
      // Use Firebase options (stub by default, overwritten in production builds)
      final options = DefaultFirebaseOptions.currentPlatform;

      final configType = options.projectId.contains('stub')
          ? 'stub'
          : 'production';
      _logger.info('🔥 Using $configType Firebase configuration');

      _logger.info(
        '🔥 Initializing Firebase with $configType configuration for ${options.projectId}',
      );

      await Firebase.initializeApp(options: options);
      _firebaseCoreInitialized = true;
      _logger.info('🚀 Firebase core initialized successfully');

      if (isConfigured) {
        await ensureAuthenticated();
      }

      // Explicitly initialize analytics for web
      if (kIsWeb) {
        try {
          await _analytics.setAnalyticsCollectionEnabled(true);
          _logger.info('✅ Firebase Analytics enabled for web');
        } catch (e) {
          _logger.warning('❌ Failed to enable web analytics: $e');
        }
      }

      _logger.info('🎉 Firebase initialized successfully');
    } catch (e) {
      _logger.warning('❌ Firebase initialization failed: $e');
      // Don't throw - allow app to continue without Firebase
      // This handles cases where Firebase isn't properly configured
      rethrow; // Let main.dart handle the error gracefully
    }
  }

  /// Ensure the user is signed in anonymously for Firestore security rules.
  static Future<bool> ensureAuthenticated() async {
    if (!_firebaseCoreInitialized || !isConfigured) {
      _isAuthenticated = false;
      return false;
    }

    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        _isAuthenticated = true;
        return true;
      }

      await auth.signInAnonymously();
      _isAuthenticated = auth.currentUser != null;
      if (_isAuthenticated) {
        _logger.info(
          'Signed in anonymously for multiplayer: ${auth.currentUser!.uid.substring(0, 8)}...',
        );
      }
      return _isAuthenticated;
    } catch (e) {
      _logger.warning('Anonymous authentication failed: $e');
      _isAuthenticated = false;
      return false;
    }
  }

  /// Get Firebase Analytics instance
  static FirebaseAnalytics get analytics => _analytics;

  /// Log game events for analytics
  static Future<void> logGameEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      // Log analytics events with sanitized parameter info
      _logger.info('🔥 Logging Firebase event: $eventName');
      if (kDebugMode) {
        // Only log full parameters in debug mode
        _logger.info('📊 Event parameters: $parameters');
      } else {
        // In production, only log parameter count for security
        _logger.info('📊 Event parameters count: ${parameters?.length ?? 0}');
      }

      await _analytics.logEvent(
        name: eventName,
        parameters: parameters?.cast<String, Object>(),
      );

      // Success logging for debugging
      _logger.info(
        '✅ Firebase Analytics event logged successfully: $eventName',
      );
    } catch (e) {
      _logger.warning(
        '❌ Failed to log Firebase Analytics event $eventName: $e',
      );
    }
  }

  /// Log when user creates a multiplayer game
  static Future<void> logGameCreated({required int maxPlayers}) async {
    await logGameEvent(
      'game_created',
      parameters: {'max_players': maxPlayers, 'game_type': 'multiplayer'},
    );
  }

  /// Log when user joins a multiplayer game
  static Future<void> logGameJoined() async {
    await logGameEvent('game_joined', parameters: {'game_type': 'multiplayer'});
  }

  /// Log when a multiplayer game starts
  static Future<void> logGameStarted({required int playerCount}) async {
    await logGameEvent(
      'game_started',
      parameters: {'player_count': playerCount, 'game_type': 'multiplayer'},
    );
  }

  /// Log when a multiplayer game ends
  static Future<void> logGameCompleted({
    required int playerCount,
    required int roundCount,
    required int gameDurationSeconds,
  }) async {
    await logGameEvent(
      'game_completed',
      parameters: {
        'player_count': playerCount,
        'rounds_played': roundCount,
        'duration_seconds': gameDurationSeconds,
        'game_type': 'multiplayer',
      },
    );
  }

  // === GAME DEBUGGING EVENTS ===

  /// Log round transitions
  static Future<void> logRoundEvent(
    String action, {
    required int round,
    required int playerCount,
    String? winnerId,
    List<int>? playerScores,
  }) async {
    await logGameEvent(
      'round_$action',
      parameters: {
        'round': round,
        'player_count': playerCount,
        if (winnerId != null) 'winner_id': winnerId,
        if (playerScores != null) 'player_scores': playerScores,
      },
    );
  }

  /// Log player actions
  static Future<void> logPlayerAction(
    String action, {
    required String playerId,
    required bool success,
    String? errorMessage,
    Map<String, dynamic>? additionalData,
  }) async {
    await logGameEvent(
      'player_$action',
      parameters: {
        'player_id': playerId,
        'success': success,
        if (errorMessage != null) 'error': errorMessage,
        ...?additionalData,
      },
    );
  }

  /// Log meld creation attempts
  static Future<void> logMeldAttempt({
    required String playerId,
    required int cardCount,
    required bool success,
    required bool isFirstMeld,
    String? failureReason,
    int? pointValue,
  }) async {
    await logPlayerAction(
      'meld_attempt',
      playerId: playerId,
      success: success,
      errorMessage: failureReason,
      additionalData: {
        'card_count': cardCount,
        'is_first_meld': isFirstMeld,
        if (pointValue != null) 'point_value': pointValue,
      },
    );
  }

  /// Log unlock discard pile attempts
  static Future<void> logUnlockAttempt({
    required String playerId,
    required bool success,
    String? failureReason,
    int? discardPileSize,
  }) async {
    await logPlayerAction(
      'unlock_attempt',
      playerId: playerId,
      success: success,
      errorMessage: failureReason,
      additionalData: {
        if (discardPileSize != null) 'discard_pile_size': discardPileSize,
      },
    );
  }

  /// Log going out attempts
  static Future<void> logGoOutAttempt({
    required String playerId,
    required bool success,
    required bool hasCleanBook,
    required bool hasDirtyBook,
    required bool footEmpty,
    String? failureReason,
  }) async {
    await logPlayerAction(
      'go_out_attempt',
      playerId: playerId,
      success: success,
      errorMessage: failureReason,
      additionalData: {
        'has_clean_book': hasCleanBook,
        'has_dirty_book': hasDirtyBook,
        'foot_empty': footEmpty,
      },
    );
  }

  /// Log bot AI decisions (for debugging bot behavior)
  static Future<void> logBotDecision({
    required String botId,
    required String action,
    required String reasoning,
    Map<String, dynamic>? context,
  }) async {
    await logGameEvent(
      'bot_decision',
      parameters: {
        'bot_id': botId,
        'action': action,
        'reasoning': reasoning,
        ...?context,
      },
    );
  }

  /// Log game state validation errors
  static Future<void> logGameStateError({
    required String errorType,
    required String errorMessage,
    Map<String, dynamic>? gameContext,
  }) async {
    await logGameEvent(
      'game_state_error',
      parameters: {
        'error_type': errorType,
        'error_message': errorMessage,
        ...?gameContext,
      },
    );
  }

  /// Log performance issues
  static Future<void> logPerformanceIssue({
    required String operation,
    required int durationMs,
    Map<String, dynamic>? context,
  }) async {
    await logGameEvent(
      'performance_issue',
      parameters: {
        'operation': operation,
        'duration_ms': durationMs,
        ...?context,
      },
    );
  }

  /// Log network/sync issues
  static Future<void> logSyncIssue({
    required String issueType,
    required String errorMessage,
    String? gameId,
  }) async {
    await logGameEvent(
      'sync_issue',
      parameters: {
        'issue_type': issueType,
        'error_message': errorMessage,
        if (gameId != null) 'game_id': gameId,
      },
    );
  }

  /// Delete a game (host only)
  static Future<bool> deleteGame(String gameId) async {
    try {
      final userId = await getDeviceUserId();
      if (userId == null) return false;

      final gameDoc = await _firestore
          .collection(gamesCollection)
          .doc(gameId)
          .get();

      if (!gameDoc.exists) return false;

      final gameData = gameDoc.data()!;

      // Only host can delete
      if (gameData['hostId'] != userId) {
        _logger.warning('Only host can delete game');
        return false;
      }

      await _firestore.collection(gamesCollection).doc(gameId).delete();

      _logger.info('Deleted game: $gameId');
      await logGameEvent('game_deleted', parameters: {'game_id': gameId});
      return true;
    } catch (e) {
      _logger.severe('Failed to delete game: $e');
      return false;
    }
  }

  /// Remove player from game lobby
  static Future<bool> leaveGame(String gameId) async {
    try {
      final userId = await getDeviceUserId();
      if (userId == null) return false;

      final gameDoc = await _firestore
          .collection(gamesCollection)
          .doc(gameId)
          .get();

      if (!gameDoc.exists) return false;

      final gameData = gameDoc.data()!;
      final players = List<Map<String, dynamic>>.from(
        gameData['players'] ?? [],
      );

      // If host is leaving, delete the entire game
      if (gameData['hostId'] == userId) {
        return await deleteGame(gameId);
      }

      // Remove player from list
      players.removeWhere((player) => player['id'] == userId);

      await _firestore.collection(gamesCollection).doc(gameId).update({
        'players': players,
      });

      _logger.info('Left game: $gameId');
      await logGameEvent('game_left', parameters: {'game_id': gameId});
      return true;
    } catch (e) {
      _logger.severe('Failed to leave game: $e');
      return false;
    }
  }

  /// Clean up expired games (games in waiting status older than 30 minutes)
  static Future<void> cleanupExpiredGames() async {
    try {
      final thirtyMinutesAgo = DateTime.now().subtract(
        const Duration(minutes: 30),
      );

      final expiredGames = await _firestore
          .collection(gamesCollection)
          .where('status', isEqualTo: FirebaseConstants.gameStatusWaiting)
          .where('createdAt', isLessThan: Timestamp.fromDate(thirtyMinutesAgo))
          .limit(50) // Process in batches
          .get();

      final batch = _firestore.batch();

      for (final doc in expiredGames.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (expiredGames.docs.isNotEmpty) {
        _logger.info('Cleaned up ${expiredGames.docs.length} expired games');
        await logGameEvent(
          'expired_games_cleaned',
          parameters: {'count': expiredGames.docs.length},
        );
      }
    } catch (e) {
      _logger.warning('Failed to cleanup expired games: $e');
    }
  }

  /// Get Firebase Auth UID for multiplayer player identity (matches Firestore rules).
  static Future<String?> getMultiplayerUserId() async {
    if (!isConfigured) {
      return null;
    }
    if (!await ensureAuthenticated()) {
      return null;
    }
    return FirebaseAuth.instance.currentUser?.uid;
  }

  /// Backwards-compatible alias — returns Firebase Auth UID, not device ID.
  static Future<String?> getDeviceUserId() {
    return getMultiplayerUserId();
  }

  /// Get device name for display purposes
  static Future<String> getDeviceUserName() async {
    try {
      return await DeviceService.getDeviceName();
    } catch (e) {
      _logger.warning('Failed to get device name: $e');
      return 'Unknown Device';
    }
  }

  /// Create a new multiplayer game with validation and rate limiting
  static Future<String?> createGame({
    required String hostPlayerName,
    required int maxPlayers,
  }) async {
    final result = await createGameWithResult(
      hostPlayerName: hostPlayerName,
      maxPlayers: maxPlayers,
    );
    return result.gameId;
  }

  /// Create a game and return a typed result for UI error handling.
  static Future<CreateGameResult> createGameWithResult({
    required String hostPlayerName,
    required int maxPlayers,
  }) async {
    lastOperationError = null;
    try {
      if (!isConfigured) {
        lastOperationError = multiplayerFailureMessage(
          MultiplayerFailureReason.notConfigured,
        );
        return const CreateGameResult(
          failureReason: MultiplayerFailureReason.notConfigured,
        );
      }

      final userId = await getMultiplayerUserId();
      if (userId == null) {
        _logger.warning('Cannot create game: failed to authenticate');
        lastOperationError = multiplayerFailureMessage(
          MultiplayerFailureReason.notAuthenticated,
        );
        return const CreateGameResult(
          failureReason: MultiplayerFailureReason.notAuthenticated,
        );
      }

      // Validate inputs
      if (!_isValidPlayerName(hostPlayerName)) {
        _logger.warning('Invalid player name: $hostPlayerName');
        lastOperationError = multiplayerFailureMessage(
          MultiplayerFailureReason.invalidInput,
        );
        return const CreateGameResult(
          failureReason: MultiplayerFailureReason.invalidInput,
        );
      }

      if (!_isValidPlayerCount(maxPlayers)) {
        _logger.warning('Invalid max players: $maxPlayers');
        lastOperationError = multiplayerFailureMessage(
          MultiplayerFailureReason.invalidInput,
        );
        return const CreateGameResult(
          failureReason: MultiplayerFailureReason.invalidInput,
        );
      }

      // Check rate limiting
      if (await _hasExceededGameCreationLimit(userId)) {
        _logger.warning('User $userId exceeded game creation limit');
        await logGameEvent(
          'game_creation_rate_limited',
          parameters: {'user_id': userId},
        );
        lastOperationError = multiplayerFailureMessage(
          MultiplayerFailureReason.rateLimited,
        );
        return const CreateGameResult(
          failureReason: MultiplayerFailureReason.rateLimited,
        );
      }

      // Generate short, user-friendly game ID
      final gameId = await _generateShortGameId();
      if (gameId == null) {
        _logger.warning('Failed to generate unique game ID');
        lastOperationError = multiplayerFailureMessage(
          MultiplayerFailureReason.unknown,
        );
        return const CreateGameResult(
          failureReason: MultiplayerFailureReason.unknown,
        );
      }

      // Create initial game state with host player
      final hostPlayer = Player(
        id: userId,
        name: hostPlayerName,
        type: PlayerType.human,
      );

      await _firestore.collection(gamesCollection).doc(gameId).set({
        'hostId': userId,
        'maxPlayers': maxPlayers,
        'status': FirebaseConstants.gameStatusWaiting,
        'createdAt': FieldValue.serverTimestamp(),
        'players': [_playerToMap(hostPlayer)],
        'gameState': null, // Will be set when game starts
      });

      // Update rate limiting counters
      await _updateGameCreationLimits(userId);

      _logger.info('Created game: $gameId');
      await logGameCreated(maxPlayers: maxPlayers);
      return CreateGameResult(gameId: gameId);
    } catch (e) {
      _logger.severe('Failed to create game: $e');
      await logGameEvent(
        'game_creation_failed',
        parameters: {'error': e.toString()},
      );
      final reason = _failureReasonFromException(e);
      _setLastOperationError(reason);
      return CreateGameResult(failureReason: reason);
    }
  }

  static void _setLastOperationError(MultiplayerFailureReason reason) {
    lastOperationError = multiplayerFailureMessage(reason);
  }

  /// Join an existing game with validation
  static Future<bool> joinGame({
    required String gameId,
    required String playerName,
  }) async {
    final result = await joinGameWithResult(
      gameId: gameId,
      playerName: playerName,
    );
    return result.isSuccess;
  }

  /// Join or rejoin a game and return a typed result for UI error handling.
  static Future<JoinGameResult> joinGameWithResult({
    required String gameId,
    required String playerName,
  }) async {
    lastOperationError = null;
    try {
      if (!isConfigured) {
        lastOperationError = multiplayerFailureMessage(
          MultiplayerFailureReason.notConfigured,
        );
        return const JoinGameResult(
          success: false,
          failureReason: MultiplayerFailureReason.notConfigured,
        );
      }

      final userId = await getMultiplayerUserId();
      if (userId == null) {
        _logger.warning('Cannot join game: failed to authenticate');
        _setLastOperationError(MultiplayerFailureReason.notAuthenticated);
        return const JoinGameResult(
          success: false,
          failureReason: MultiplayerFailureReason.notAuthenticated,
        );
      }

      // Normalize game ID (convert short codes to uppercase)
      final normalizedGameId = gameId.length == 4
          ? gameId.toUpperCase()
          : gameId;

      // Validate inputs
      if (!_isValidGameId(normalizedGameId)) {
        _logger.warning('Invalid game ID: $gameId');
        _setLastOperationError(MultiplayerFailureReason.invalidInput);
        return const JoinGameResult(
          success: false,
          failureReason: MultiplayerFailureReason.invalidInput,
        );
      }

      if (!_isValidPlayerName(playerName)) {
        _logger.warning('Invalid player name: $playerName');
        _setLastOperationError(MultiplayerFailureReason.invalidInput);
        return const JoinGameResult(
          success: false,
          failureReason: MultiplayerFailureReason.invalidInput,
        );
      }

      final gameDoc = await _firestore
          .collection(gamesCollection)
          .doc(normalizedGameId)
          .get();
      if (!gameDoc.exists) {
        _logger.warning('Game not found: $gameId');
        _setLastOperationError(MultiplayerFailureReason.gameNotFound);
        return const JoinGameResult(
          success: false,
          failureReason: MultiplayerFailureReason.gameNotFound,
        );
      }

      final gameData = gameDoc.data()!;
      final players = List<Map<String, dynamic>>.from(
        gameData['players'] ?? [],
      );
      final maxPlayers = gameData['maxPlayers'] as int;
      final status = gameData['status'] as String?;

      // Rejoin: player already in the game (waiting or playing)
      final existingPlayerIndex = players.indexWhere(
        (player) => player['id'] == userId,
      );
      if (existingPlayerIndex >= 0) {
        if (players[existingPlayerIndex]['name'] != playerName) {
          players[existingPlayerIndex]['name'] = playerName;
          await _firestore
              .collection(gamesCollection)
              .doc(normalizedGameId)
              .update({'players': players});
        }
        _logger.info('Rejoined game: $normalizedGameId as $playerName');
        return const JoinGameResult(success: true);
      }

      if (players.length >= maxPlayers) {
        _logger.warning('Game is full: $gameId');
        _setLastOperationError(MultiplayerFailureReason.gameFull);
        return const JoinGameResult(
          success: false,
          failureReason: MultiplayerFailureReason.gameFull,
        );
      }

      if (status != FirebaseConstants.gameStatusWaiting) {
        _logger.warning('Game is not accepting new players: $gameId');
        _setLastOperationError(MultiplayerFailureReason.gameNotAccepting);
        return const JoinGameResult(
          success: false,
          failureReason: MultiplayerFailureReason.gameNotAccepting,
        );
      }

      // Add new player
      final newPlayer = Player(
        id: userId,
        name: playerName,
        type: PlayerType.human,
      );

      players.add(_playerToMap(newPlayer));

      await _firestore.collection(gamesCollection).doc(normalizedGameId).update(
        {'players': players},
      );

      _logger.info('Joined game: $normalizedGameId as $playerName');
      await logGameJoined();
      return const JoinGameResult(success: true);
    } catch (e) {
      _logger.severe('Failed to join game: $e');
      final reason = _failureReasonFromException(e);
      _setLastOperationError(reason);
      return JoinGameResult(success: false, failureReason: reason);
    }
  }

  /// Start a game (host only)
  static Future<bool> startGame(String gameId) async {
    try {
      final userId = await getDeviceUserId();
      if (userId == null) return false;

      final gameDoc = await _firestore
          .collection(gamesCollection)
          .doc(gameId)
          .get();
      if (!gameDoc.exists) return false;

      final gameData = gameDoc.data()!;
      if (gameData['hostId'] != userId) {
        _logger.warning('Only host can start game');
        return false;
      }

      final playersData = List<Map<String, dynamic>>.from(
        gameData['players'] ?? [],
      );
      final players = playersData.map(_playerFromMap).toList();

      // Create initial game state with deterministic seed
      final gameSeed = DateTime.now().millisecondsSinceEpoch % 1000000;
      final deck = Deck.createHandAndFootDeck(players.length, seed: gameSeed);
      final gameState = GameState(players: players, deck: deck);

      // CRITICAL FIX: Shuffle deck before dealing (same as single-player)
      gameState.deck.shuffle();
      gameState.dealCards();
      gameState.startRound();

      _logger.info(
        'Created multiplayer game with seed: $gameSeed, deck size: ${deck.size}',
      );

      await _firestore.collection(gamesCollection).doc(gameId).update({
        'status': FirebaseConstants.gameStatusPlaying,
        'gameState': _gameStateToMap(gameState),
      });

      _logger.info('Started game: $gameId');
      await logGameStarted(playerCount: players.length);
      return true;
    } catch (e) {
      _logger.severe('Failed to start game: $e');
      return false;
    }
  }

  /// Update game state in Firestore
  static Future<bool> updateGameState(
    String gameId,
    GameState gameState,
  ) async {
    try {
      final updateData = {
        'gameState': _gameStateToMap(gameState),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // If game has ended, mark for cleanup (must match Firestore rules: playing -> finished)
      if (gameState.phase == GamePhase.gameEnd) {
        updateData['status'] = FirebaseConstants.gameStatusFinished;
        updateData['completedAt'] = FieldValue.serverTimestamp();

        // Schedule automatic cleanup after 1 hour
        updateData['cleanupAt'] = Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 1)),
        );
      }

      await _firestore
          .collection(gamesCollection)
          .doc(gameId)
          .update(updateData);
      return true;
    } catch (e) {
      _logger.severe('Failed to update game state: $e');
      return false;
    }
  }

  /// Get a single game document (for rejoin checks)
  static Future<Map<String, dynamic>?> getGame(String gameId) async {
    try {
      final doc = await _firestore
          .collection(gamesCollection)
          .doc(gameId)
          .get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      _logger.severe('Failed to get game: $e');
      return null;
    }
  }

  /// Clean up completed games (called periodically or manually)
  static Future<void> cleanupCompletedGames() async {
    try {
      final cutoffTime = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 1)),
      );

      final completedGames = await _firestore
          .collection(gamesCollection)
          .where('status', isEqualTo: FirebaseConstants.gameStatusFinished)
          .where('completedAt', isLessThan: cutoffTime)
          .limit(50) // Process in batches
          .get();

      final batch = _firestore.batch();
      for (final doc in completedGames.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (completedGames.docs.isNotEmpty) {
        _logger.info(
          'Cleaned up ${completedGames.docs.length} completed games',
        );
      }
    } catch (e) {
      _logger.warning('Failed to cleanup completed games: $e');
    }
  }

  /// Force cleanup a specific game (when players leave)
  static Future<void> cleanupGame(String gameId) async {
    try {
      await _firestore.collection(gamesCollection).doc(gameId).delete();
      _logger.info('Manually cleaned up game: $gameId');
    } catch (e) {
      _logger.warning('Failed to cleanup game $gameId: $e');
    }
  }

  /// Listen to game state changes
  static Stream<GameState?> listenToGameState(String gameId) {
    return _firestore.collection(gamesCollection).doc(gameId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      final gameData = snapshot.data()!;
      final gameStateData = gameData['gameState'] as Map<String, dynamic>?;

      if (gameStateData == null) return null;

      try {
        return _gameStateFromMap(gameStateData);
      } catch (e) {
        _logger.severe('Failed to parse game state: $e');
        return null;
      }
    });
  }

  /// Listen to game lobby changes (for waiting room)
  static Stream<Map<String, dynamic>?> listenToGameLobby(String gameId) {
    return _firestore.collection(gamesCollection).doc(gameId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return null;
      return snapshot.data();
    });
  }

  /// Convert GameState to Firestore map
  static Map<String, dynamic> _gameStateToMap(GameState gameState) {
    return {
      'players': gameState.players.map(_playerToMap).toList(),
      'deck': _deckToMap(gameState.deck),
      'discardPile': gameState.discardPile.map(_cardToMap).toList(),
      'recentActions': gameState.recentActions.map(_gameActionToMap).toList(),
      'currentPlayerIndex': gameState.currentPlayerIndex,
      'phase': gameState.phase.name,
      'turnPhase': gameState.turnPhase.name,
      'round': gameState.round,
      'winner': gameState.winner?.name,
      'discardPileFrozen': gameState.discardPileFrozen,
      'hasDrawnFromDeck': gameState.hasDrawnFromDeck,
      'hasMelded': gameState.hasMelded,
    };
  }

  /// Convert Firestore map to GameState
  static GameState _gameStateFromMap(Map<String, dynamic> data) {
    final playersData = List<Map<String, dynamic>>.from(data['players'] ?? []);
    final players = playersData.map(_playerFromMap).toList();

    final deckData = data['deck'] as Map<String, dynamic>;
    final deck = _deckFromMap(deckData);

    final discardPileData = List<Map<String, dynamic>>.from(
      data['discardPile'] ?? [],
    );
    final discardPile = discardPileData.map(_cardFromMap).toList();

    final recentActionsData = List<Map<String, dynamic>>.from(
      data['recentActions'] ?? [],
    );
    final recentActions = recentActionsData.map(_gameActionFromMap).toList();

    // Find winner by name if specified
    Player? winner;
    if (data['winner'] != null) {
      final winnerName = data['winner'] as String;
      try {
        winner = players.firstWhere((p) => p.name == winnerName);
      } catch (e) {
        // Winner not found in players list
        winner = null;
      }
    }

    return GameState(
      players: players,
      deck: deck,
      discardPile: discardPile,
      recentActions: recentActions,
      currentPlayerIndex: data['currentPlayerIndex'] ?? 0,
      phase: GamePhase.values.firstWhere(
        (phase) => phase.name == (data['phase'] ?? 'setup'),
        orElse: () => GamePhase.setup,
      ),
      turnPhase: TurnPhase.values.firstWhere(
        (phase) => phase.name == (data['turnPhase'] ?? 'draw'),
        orElse: () => TurnPhase.draw,
      ),
      round: data['round'] ?? 1,
      winner: winner,
      discardPileFrozen: data['discardPileFrozen'] ?? false,
      hasDrawnFromDeck: data['hasDrawnFromDeck'] ?? false,
      hasMelded: data['hasMelded'] ?? false,
    );
  }

  /// Convert Player to Firestore map
  static Map<String, dynamic> _playerToMap(Player player) {
    return {
      'id': player.id,
      'name': player.name,
      'type': player.type.name,
      'hand': player.hand.map(_cardToMap).toList(),
      'foot': player.foot.map(_cardToMap).toList(),
      'melds': player.melds.map(_meldToMap).toList(),
      'score': player.score,
      'hasPickedUpFoot': player.hasPickedUpFoot,
      'hasPlayedDown': player.hasPlayedDown,
      'newlyDrawnCardIndices': player.newlyDrawnCardIndices.toList(),
    };
  }

  /// Convert Firestore map to Player
  static Player _playerFromMap(Map<String, dynamic> data) {
    final handData = List<Map<String, dynamic>>.from(data['hand'] ?? []);
    final hand = handData.map(_cardFromMap).toList();

    final footData = List<Map<String, dynamic>>.from(data['foot'] ?? []);
    final foot = footData.map(_cardFromMap).toList();

    final meldsData = List<Map<String, dynamic>>.from(data['melds'] ?? []);
    final melds = meldsData
        .map(_meldFromMap)
        .where((m) => m != null)
        .cast<Meld>()
        .toList();

    final newlyDrawnIndices = List<int>.from(
      data['newlyDrawnCardIndices'] ?? [],
    );

    return Player(
        id: data['id'] ?? 'unknown',
        name: data['name'] ?? 'Unknown',
        type: PlayerType.values.firstWhere(
          (type) => type.name == (data['type'] ?? 'human'),
          orElse: () => PlayerType.human,
        ),
        hand: hand,
        foot: foot,
        melds: melds,
        newlyDrawnCardIndices: Set<int>.from(newlyDrawnIndices),
      )
      ..score = data['score'] ?? 0
      ..hasPickedUpFoot = data['hasPickedUpFoot'] ?? false
      ..hasPlayedDown = data['hasPlayedDown'] ?? false;
  }

  /// Convert Deck to Firestore map
  static Map<String, dynamic> _deckToMap(Deck deck) {
    return {'cards': deck.cards.map(_cardToMap).toList()};
  }

  /// Convert Firestore map to Deck
  static Deck _deckFromMap(Map<String, dynamic> data) {
    final cardsData = List<Map<String, dynamic>>.from(data['cards'] ?? []);
    final cards = cardsData.map(_cardFromMap).toList();
    return Deck.fromCards(cards);
  }

  /// Convert PlayingCard to Firestore map
  static Map<String, dynamic> _cardToMap(PlayingCard card) {
    return {'rank': card.rank.name, 'suit': card.suit?.name};
  }

  /// Convert Firestore map to PlayingCard
  static PlayingCard _cardFromMap(Map<String, dynamic> data) {
    final rank = CardRank.values.firstWhere((r) => r.name == data['rank']);

    // Handle jokers which don't have suits
    if (rank == CardRank.joker) {
      return PlayingCard(rank: rank);
    }

    final suit = Suit.values.firstWhere((s) => s.name == data['suit']);
    return PlayingCard(rank: rank, suit: suit);
  }

  /// Convert Meld to Firestore map
  static Map<String, dynamic> _meldToMap(Meld meld) {
    return {'cards': meld.cards.map(_cardToMap).toList()};
  }

  /// Convert Firestore map to Meld
  static Meld? _meldFromMap(Map<String, dynamic> data) {
    final cardsData = List<Map<String, dynamic>>.from(data['cards'] ?? []);
    final cards = cardsData.map(_cardFromMap).toList();
    return Meld.createMeld(cards);
  }

  /// Convert GameAction to Firestore map
  static Map<String, dynamic> _gameActionToMap(GameAction action) {
    return {
      'message': action.message,
      'playerName': action.playerName,
      'timestamp': Timestamp.fromDate(action.timestamp),
    };
  }

  /// Convert Firestore map to GameAction
  static GameAction _gameActionFromMap(Map<String, dynamic> data) {
    return GameAction.withTimestamp(
      message: data['message'] ?? '',
      playerName: data['playerName'] ?? 'Unknown',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  // === VALIDATION HELPERS ===

  /// Validate player name using constants
  static bool _isValidPlayerName(String name) {
    if (name.trim().isEmpty) return false;
    if (name.length > FirebaseConstants.maxPlayerNameLength) return false;
    if (name.length < FirebaseConstants.minPlayerNameLength) return false;

    // Check for inappropriate content (basic filter)
    final lowercaseName = name.toLowerCase();
    if (FirebaseConstants.reservedPlayerNames.any(
      (word) => lowercaseName.contains(word),
    )) {
      return false;
    }

    // Only allow alphanumeric and basic punctuation
    final validChars = RegExp(r'^[a-zA-Z0-9\s\-_\.]+$');
    return validChars.hasMatch(name);
  }

  /// Validate player count using constants
  static bool _isValidPlayerCount(int count) {
    return count >= FirebaseConstants.minPlayersPerGame &&
        count <= FirebaseConstants.maxPlayersPerGame;
  }

  /// Validate game ID format
  static bool _isValidGameId(String gameId) {
    if (gameId.trim().isEmpty) return false;

    // Accept either short format (4 chars) or long Firebase format
    if (gameId.length == 4) {
      // Short game ID format: AB12
      final validChars = RegExp(r'^[A-Z0-9]{4}$');
      return validChars.hasMatch(gameId.toUpperCase());
    }

    // Original validation for longer IDs
    if (gameId.length < FirebaseConstants.minGameIdLength) return false;
    final validChars = RegExp(r'^[a-zA-Z0-9]+$');
    return validChars.hasMatch(gameId);
  }

  /// Generate a short, user-friendly game ID (e.g., AB12)
  static Future<String?> _generateShortGameId() async {
    const maxAttempts =
        20; // More attempts since shorter IDs have higher collision chance

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      // Generate cryptographically secure 4-character code: 2 letters + 2 numbers
      final letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      final numbers = '0123456789';

      // Use crypto-secure random generation instead of predictable timestamp
      final secureRandom = math.Random.secure();
      String gameId = '';
      gameId += letters[secureRandom.nextInt(letters.length)];
      gameId += letters[secureRandom.nextInt(letters.length)];
      gameId += numbers[secureRandom.nextInt(numbers.length)];
      gameId += numbers[secureRandom.nextInt(numbers.length)];

      // Check if this ID already exists
      try {
        final existingDoc = await _firestore
            .collection(gamesCollection)
            .doc(gameId)
            .get();

        if (!existingDoc.exists) {
          return gameId;
        }
      } catch (e) {
        _logger.warning('Error checking game ID uniqueness: $e');
        // Continue trying with next attempt
      }
    }

    _logger.severe(
      'Failed to generate unique game ID after $maxAttempts attempts',
    );
    return null;
  }

  // === RATE LIMITING ===

  /// Check if user has exceeded game creation limits
  static Future<bool> _hasExceededGameCreationLimit(String userId) async {
    try {
      final now = DateTime.now();
      final hourAgo = now.subtract(const Duration(hours: 1));
      final dayAgo = now.subtract(const Duration(days: 1));

      final userLimitDoc = await _firestore
          .collection(userLimitsCollection)
          .doc(userId)
          .get();

      if (!userLimitDoc.exists) {
        return false; // First time creating, allow
      }

      final data = userLimitDoc.data()!;
      final recentCreations = List<Timestamp>.from(data['gameCreations'] ?? []);

      // Count games created in last hour and day
      int gamesLastHour = 0;
      int gamesLastDay = 0;

      for (final timestamp in recentCreations) {
        final creationTime = timestamp.toDate();
        if (creationTime.isAfter(hourAgo)) {
          gamesLastHour++;
        }
        if (creationTime.isAfter(dayAgo)) {
          gamesLastDay++;
        }
      }

      return gamesLastHour >= maxGamesPerUserPerHour ||
          gamesLastDay >= maxGamesPerUserPerDay;
    } catch (e) {
      _logger.warning('Failed to check rate limiting: $e');
      return false; // Allow on error to prevent blocking users
    }
  }

  /// Update game creation limits tracking
  static Future<void> _updateGameCreationLimits(String userId) async {
    try {
      final now = Timestamp.now();
      final dayAgo = now.toDate().subtract(const Duration(days: 1));

      await _firestore.collection(userLimitsCollection).doc(userId).set({
        'gameCreations': FieldValue.arrayUnion([now]),
        'lastUpdated': now,
      }, SetOptions(merge: true));

      // Clean up old entries (older than 1 day) in a separate operation
      // This prevents the document from growing indefinitely
      _cleanupOldLimitEntries(userId, dayAgo);
    } catch (e) {
      _logger.warning('Failed to update rate limiting: $e');
      // Non-critical, don't throw
    }
  }

  /// Clean up old rate limiting entries (fire and forget)
  static void _cleanupOldLimitEntries(String userId, DateTime cutoffDate) {
    _firestore
        .collection(userLimitsCollection)
        .doc(userId)
        .get()
        .then((doc) {
          if (!doc.exists) return;

          final data = doc.data()!;
          final allCreations = List<Timestamp>.from(
            data['gameCreations'] ?? [],
          );
          final recentCreations = allCreations
              .where((timestamp) => timestamp.toDate().isAfter(cutoffDate))
              .toList();

          if (recentCreations.length < allCreations.length) {
            // Only update if we're actually removing entries
            doc.reference.update({
              'gameCreations': recentCreations,
              'lastCleaned': Timestamp.now(),
            });
          }
        })
        .catchError((error) {
          _logger.warning('Failed to cleanup old limit entries: $error');
        });
  }

  static MultiplayerFailureReason _failureReasonFromException(Object e) {
    final message = e.toString().toLowerCase();
    if (message.contains('permission-denied') ||
        message.contains('permission denied')) {
      return MultiplayerFailureReason.permissionDenied;
    }
    return MultiplayerFailureReason.unknown;
  }

  /// Exposed for unit tests verifying Firestore serialization round-trips.
  @visibleForTesting
  static Map<String, dynamic> gameStateToMapForTesting(GameState gameState) {
    return _gameStateToMap(gameState);
  }

  /// Exposed for unit tests verifying Firestore deserialization round-trips.
  @visibleForTesting
  static GameState gameStateFromMapForTesting(Map<String, dynamic> data) {
    return _gameStateFromMap(data);
  }
}
