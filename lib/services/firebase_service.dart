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
import 'firebase_constants.dart';

// Conditional Firebase options import
// This will be available in production builds but not in development/test
FirebaseOptions? _getFirebaseOptions() {
  if (kDebugMode) {
    return null; // Skip Firebase options in debug mode to avoid missing file issues
  }

  try {
    // In production, this import should be available from the build workflow
    // For now, we'll return null and let Firebase use default configuration
    return null;
  } catch (e) {
    return null;
  }
}

/// Firebase service for handling multiplayer game state synchronization
class FirebaseService {
  static final Logger _logger = Logger('FirebaseService');
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
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
      // Initialize Firebase with options if available, otherwise use default
      final options = _getFirebaseOptions();
      await Firebase.initializeApp(options: options);

      // Explicitly initialize analytics for web
      if (kIsWeb) {
        try {
          await _analytics.setAnalyticsCollectionEnabled(true);
          _logger.info('Firebase Analytics enabled for web');
        } catch (e) {
          _logger.warning('Failed to enable web analytics: $e');
        }
      }

      _logger.info('Firebase initialized successfully');
    } catch (e) {
      _logger.warning('Firebase initialization failed: $e');
      // Don't throw - allow app to continue without Firebase
      // This handles cases where Firebase isn't properly configured
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
      await _analytics.logEvent(
        name: eventName,
        parameters: parameters?.cast<String, Object>(),
      );

      // Debug logging for web to verify analytics is working
      if (kIsWeb && kDebugMode) {
        _logger.info(
          'Analytics event logged: $eventName with params: $parameters',
        );
      }
    } catch (e) {
      _logger.warning('Failed to log analytics event $eventName: $e');
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

  /// Sign in anonymously for multiplayer games
  static Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      _logger.info('Signed in anonymously: ${userCredential.user?.uid}');
      return userCredential.user;
    } catch (e) {
      _logger.severe('Anonymous sign in failed: $e');
      return null;
    }
  }

  /// Create a new multiplayer game with validation and rate limiting
  static Future<String?> createGame({
    required String hostPlayerName,
    required int maxPlayers,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _logger.warning('Cannot create game: user not signed in');
        return null;
      }

      // Validate inputs
      if (!_isValidPlayerName(hostPlayerName)) {
        _logger.warning('Invalid player name: $hostPlayerName');
        return null;
      }

      if (!_isValidPlayerCount(maxPlayers)) {
        _logger.warning('Invalid max players: $maxPlayers');
        return null;
      }

      // Check rate limiting
      if (await _hasExceededGameCreationLimit(user.uid)) {
        _logger.warning('User ${user.uid} exceeded game creation limit');
        await logGameEvent(
          'game_creation_rate_limited',
          parameters: {'user_id': user.uid},
        );
        return null;
      }

      // Create initial game state with host player
      final hostPlayer = Player(
        id: user.uid,
        name: hostPlayerName,
        type: PlayerType.human,
      );

      final gameDoc = await _firestore.collection(gamesCollection).add({
        'hostId': user.uid,
        'maxPlayers': maxPlayers,
        'status': FirebaseConstants.gameStatusWaiting,
        'createdAt': FieldValue.serverTimestamp(),
        'players': [_playerToMap(hostPlayer)],
        'gameState': null, // Will be set when game starts
      });

      // Update rate limiting counters
      await _updateGameCreationLimits(user.uid);

      _logger.info('Created game: ${gameDoc.id}');
      await logGameCreated(maxPlayers: maxPlayers);
      return gameDoc.id;
    } catch (e) {
      _logger.severe('Failed to create game: $e');
      await logGameEvent(
        'game_creation_failed',
        parameters: {'error': e.toString()},
      );
      return null;
    }
  }

  /// Join an existing game with validation
  static Future<bool> joinGame({
    required String gameId,
    required String playerName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _logger.warning('Cannot join game: user not signed in');
        return false;
      }

      // Validate inputs
      if (!_isValidGameId(gameId)) {
        _logger.warning('Invalid game ID: $gameId');
        return false;
      }

      if (!_isValidPlayerName(playerName)) {
        _logger.warning('Invalid player name: $playerName');
        return false;
      }

      final gameDoc = await _firestore
          .collection(gamesCollection)
          .doc(gameId)
          .get();
      if (!gameDoc.exists) {
        _logger.warning('Game not found: $gameId');
        return false;
      }

      final gameData = gameDoc.data()!;
      final players = List<Map<String, dynamic>>.from(
        gameData['players'] ?? [],
      );
      final maxPlayers = gameData['maxPlayers'] as int;

      if (players.length >= maxPlayers) {
        _logger.warning('Game is full: $gameId');
        return false;
      }

      if (gameData['status'] != FirebaseConstants.gameStatusWaiting) {
        _logger.warning('Game is not accepting players: $gameId');
        return false;
      }

      // Add new player
      final newPlayer = Player(
        id: user.uid,
        name: playerName,
        type: PlayerType.human,
      );

      players.add(_playerToMap(newPlayer));

      await _firestore.collection(gamesCollection).doc(gameId).update({
        'players': players,
      });

      _logger.info('Joined game: $gameId as $playerName');
      await logGameJoined();
      return true;
    } catch (e) {
      _logger.severe('Failed to join game: $e');
      return false;
    }
  }

  /// Start a game (host only)
  static Future<bool> startGame(String gameId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final gameDoc = await _firestore
          .collection(gamesCollection)
          .doc(gameId)
          .get();
      if (!gameDoc.exists) return false;

      final gameData = gameDoc.data()!;
      if (gameData['hostId'] != user.uid) {
        _logger.warning('Only host can start game');
        return false;
      }

      final playersData = List<Map<String, dynamic>>.from(
        gameData['players'] ?? [],
      );
      final players = playersData.map(_playerFromMap).toList();

      // Create initial game state
      final deck = Deck.createHandAndFootDeck(players.length);
      final gameState = GameState(players: players, deck: deck);

      // Deal initial cards
      gameState.dealCards();
      gameState.startRound();

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
      await _firestore.collection(gamesCollection).doc(gameId).update({
        'gameState': _gameStateToMap(gameState),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      _logger.severe('Failed to update game state: $e');
      return false;
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
    if (gameId.length < FirebaseConstants.minGameIdLength) return false;

    // Basic alphanumeric check
    final validChars = RegExp(r'^[a-zA-Z0-9]+$');
    return validChars.hasMatch(gameId);
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
}
