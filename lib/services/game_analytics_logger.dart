import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../ai/bot_personality.dart';
import 'firebase_service.dart';
import 'device_service.dart';
import 'analytics_batcher.dart';

/// Comprehensive game analytics logging service for bot performance analysis
class GameAnalyticsLogger {
  static final Logger _logger = Logger('GameAnalyticsLogger');

  // Lazy initialization to prevent crashes if Firebase isn't available
  static FirebaseFirestore? _firestore;
  static FirebaseFirestore? get firestore {
    try {
      _firestore ??= FirebaseFirestore.instance;
      return _firestore;
    } catch (e) {
      _logger.warning('Firestore unavailable: $e');
      return null;
    }
  }

  // Collections
  static const String gameSessionsCollection = 'game_sessions';
  static const String botDecisionsCollection = 'bot_decisions';
  static const String gameEventsCollection = 'game_events';
  static const String performanceMetricsCollection = 'performance_metrics';

  // Privacy settings
  static bool _analyticsEnabled = true;
  static bool _detailedLoggingEnabled = false; // Only enable for opt-in users
  static const bool _readOperationsEnabled =
      false; // Disable reads for write-only mode
  static String? _currentSessionId;
  static DateTime? _sessionStartTime;

  /// Initialize analytics logging with privacy controls
  static Future<void> initialize({
    bool analyticsEnabled = true,
    bool detailedLoggingEnabled = false,
  }) async {
    _analyticsEnabled = analyticsEnabled;
    _detailedLoggingEnabled = detailedLoggingEnabled;

    if (_analyticsEnabled) {
      _logger.info(
        '🔬 Game Analytics Logger initialized - '
        'Basic: $_analyticsEnabled, Detailed: $_detailedLoggingEnabled',
      );
    }
  }

  /// Start a new game session for analytics tracking
  static Future<String?> startGameSession({
    required List<Player> players,
    required GameState gameState,
    String? gameMode,
    Map<String, BotPersonality>? botPersonalities,
  }) async {
    if (!_analyticsEnabled) return null;

    try {
      final sessionId = _generateSessionId();
      _currentSessionId = sessionId;
      _sessionStartTime = DateTime.now();

      // Count bots by personality
      final botPersonalityCount = <String, int>{};
      final botCount = players.where((p) => p.type == PlayerType.bot).length;

      if (botPersonalities != null) {
        for (final player in players) {
          if (player.type == PlayerType.bot) {
            final personality =
                botPersonalities[player.id] ?? BotPersonality.adaptive;
            final personalityName = personality.name;
            botPersonalityCount[personalityName] =
                (botPersonalityCount[personalityName] ?? 0) + 1;
          }
        }
      }

      final sessionData = {
        'sessionId': sessionId,
        'startTime': FieldValue.serverTimestamp(),
        'deviceId': await DeviceService.getDeviceId(),
        'gameMode': gameMode ?? 'singleplayer',
        'totalPlayers': players.length,
        'humanPlayers': players.where((p) => p.type == PlayerType.human).length,
        'botPlayers': botCount,
        'botPersonalities': botPersonalityCount,
        'initialRound': gameState.round,
        'gameSeed': gameState.deck.seed, // Include seed for reproducibility
        'status': 'active',
        'version': '1.0.0', // App version for tracking changes over time
      };

      final fs = firestore;
      if (fs != null) {
        await fs
            .collection(gameSessionsCollection)
            .doc(sessionId)
            .set(sessionData);
      }

      _logger.info('📊 Started game analytics session: $sessionId');
      await FirebaseService.logGameEvent(
        'analytics_session_started',
        parameters: {'session_id': sessionId},
      );

      return sessionId;
    } catch (e) {
      _logger.warning('Failed to start analytics session: $e');
      return null;
    }
  }

  /// End the current game session with summary data
  static Future<void> endGameSession({
    required GameState gameState,
    String? winnerId,
    int? totalTurns,
    Map<String, BotPersonality>? botPersonalities,
  }) async {
    if (!_analyticsEnabled ||
        _currentSessionId == null ||
        _sessionStartTime == null) {
      return;
    }

    try {
      final sessionDuration = DateTime.now().difference(_sessionStartTime!);
      final finalScores = gameState.players.map((p) => p.score).toList();
      final botPerformance = <String, Map<String, dynamic>>{};

      // Analyze bot performance
      for (final player in gameState.players.where(
        (p) => p.type == PlayerType.bot,
      )) {
        final personality =
            botPersonalities?[player.id] ?? BotPersonality.adaptive;
        botPerformance[player.id] = {
          'personality': personality.name,
          'finalScore': player.score,
          'hasPickedUpFoot': player.hasPickedUpFoot,
          'hasPlayedDown': player.hasPlayedDown,
          'meldCount': player.melds.length,
          'bookCount': player.melds.where((m) => m.cards.length >= 7).length,
          'cleanBookCount': player.melds
              .where((m) => m.cards.length >= 7 && m.isClean)
              .length,
          'cardsInHand': player.currentHand.length,
        };
      }

      final sessionEndData = {
        'endTime': FieldValue.serverTimestamp(),
        'sessionDuration': sessionDuration.inSeconds,
        'finalRound': gameState.round,
        'winnerId': winnerId,
        'winnerName': gameState.winner?.name,
        'finalScores': finalScores,
        'gamePhase': gameState.phase.name,
        'totalTurns': totalTurns,
        'botPerformance': botPerformance,
        'status': 'completed',
      };

      final fs = firestore;
      if (fs != null) {
        await fs
            .collection(gameSessionsCollection)
            .doc(_currentSessionId!)
            .update(sessionEndData);
      }

      _logger.info('📊 Ended game analytics session: $_currentSessionId');
      await FirebaseService.logGameEvent(
        'analytics_session_ended',
        parameters: {
          'session_id': _currentSessionId!,
          'duration_seconds': sessionDuration.inSeconds,
          'final_round': gameState.round,
        },
      );

      _currentSessionId = null;
      _sessionStartTime = null;
    } catch (e) {
      _logger.warning('Failed to end analytics session: $e');
    }
  }

  /// Log a detailed bot decision for analysis
  static Future<void> logBotDecision({
    required String botId,
    required String decision,
    required String reasoning,
    required BotPersonality personality,
    required GameState gameState,
    Map<String, dynamic>? decisionContext,
    double? confidence,
    List<String>? alternativeActions,
    Map<String, double>? riskAssessment,
  }) async {
    if (!_analyticsEnabled) return; // Removed detailed logging requirement
    if (_currentSessionId == null) return;

    try {
      final botPlayer = gameState.players.firstWhere((p) => p.id == botId);

      final decisionData = {
        'sessionId': _currentSessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'botId': botId,
        'botPersonality': personality.name,
        'decision': decision,
        'reasoning': reasoning,
        'confidence': confidence,
        'alternativeActions': alternativeActions,
        'riskAssessment': riskAssessment,

        // Game context
        'round': gameState.round,
        'turnPhase': gameState.turnPhase.name,
        'currentPlayerIndex': gameState.currentPlayerIndex,
        'discardPileSize': gameState.discardPile.length,
        'discardPileFrozen': gameState.discardPileFrozen,
        'gameSeed': gameState.deck.seed, // For reproducible analysis
        // Bot state
        'botHandSize': botPlayer.currentHand.length,
        'botHandCards': botPlayer.currentHand
            .map((c) => c.compactName)
            .toList(),
        'botHasPlayedDown': botPlayer.hasPlayedDown,
        'botHasPickedUpFoot': botPlayer.hasPickedUpFoot,
        'botScore': botPlayer.score,
        'botMeldCount': botPlayer.melds.length,
        'botBookCount': botPlayer.melds
            .where((m) => m.cards.length >= 7)
            .length,
        'botMelds': botPlayer.melds
            .map(
              (meld) => {
                'cards': meld.cards.map((c) => c.compactName).toList(),
                'rank': meld.cards.first.rank.name,
                'isClean': meld.isClean,
                'isBook': meld.cards.length >= 7,
                'size': meld.cards.length,
              },
            )
            .toList(),

        // Game state context
        'deckSize': gameState.deck.size,
        'topDiscardCard': gameState.discardPile.isNotEmpty
            ? gameState.discardPile.last.compactName
            : null,

        // Opponent context
        'opponentCount': gameState.players.length - 1,
        'dangerousOpponents': _countDangerousOpponents(gameState, botId),
        'opponents': gameState.players
            .where((p) => p.id != botId)
            .map(
              (opponent) => {
                'id': opponent.id,
                'type': opponent.type.name,
                'handSize': opponent.currentHand.length,
                'hasPlayedDown': opponent.hasPlayedDown,
                'hasPickedUpFoot': opponent.hasPickedUpFoot,
                'score': opponent.score,
                'meldCount': opponent.melds.length,
                'bookCount': opponent.melds
                    .where((m) => m.cards.length >= 7)
                    .length,
                'visibleMelds': opponent.melds
                    .map(
                      (meld) => {
                        'rank': meld.cards.first.rank.name,
                        'size': meld.cards.length,
                        'isClean': meld.isClean,
                        'isBook': meld.cards.length >= 7,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),

        // Additional context
        'decisionContext': decisionContext,
      };

      // Use batching for bot decisions (high frequency)
      await AnalyticsBatcher.addToBatch(
        collection: botDecisionsCollection,
        data: decisionData,
        priority: false, // Bot decisions can be batched
        turnCompletion: true, // Flush faster on turn completion
      );

      if (kDebugMode) {
        _logger.fine(
          '🤖 Logged bot decision: $decision for $botId ($personality)',
        );
      }
    } catch (e) {
      _logger.warning('Failed to log bot decision: $e');
    }
  }

  /// Log game events for pattern analysis
  static Future<void> logGameEvent({
    required String eventType,
    required String playerId,
    PlayerType? playerType,
    Map<String, dynamic>? eventData,
    bool? success,
    String? errorMessage,
  }) async {
    if (!_analyticsEnabled) return;
    if (_currentSessionId == null) return;

    try {
      // Sanitize eventData to prevent "Invalid double" Firebase errors
      final sanitizedEventData = eventData != null
          ? _sanitizeAnalyticsData(eventData)
          : null;

      final eventLogData = {
        'sessionId': _currentSessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'eventType': eventType,
        'playerId': playerId,
        'playerType': playerType?.name,
        'success': success,
        'errorMessage': errorMessage,
        'eventData': sanitizedEventData,
      };

      // Use batching for game events (high frequency)
      await AnalyticsBatcher.addToBatch(
        collection: gameEventsCollection,
        data: eventLogData,
        priority: false, // Game events can be batched
        turnCompletion: true, // Flush faster on turn completion
      );

      if (kDebugMode) {
        _logger.fine('🎯 Logged game event: $eventType for $playerId');
      }
    } catch (e) {
      _logger.warning('Failed to log game event: $e');
    }
  }

  /// Log bot personality performance metrics
  static Future<void> logBotPerformanceMetrics({
    required String botId,
    required BotPersonality personality,
    required GameState gameState,
    required Map<String, double> performanceMetrics,
  }) async {
    if (!_analyticsEnabled) return;
    if (_currentSessionId == null) return;

    try {
      final botPlayer = gameState.players.firstWhere((p) => p.id == botId);

      final metricsData = {
        'sessionId': _currentSessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'botId': botId,
        'personality': personality.name,
        'round': gameState.round,

        // Performance metrics
        'metrics': performanceMetrics,

        // Current bot state for correlation
        'botScore': botPlayer.score,
        'botPosition': _calculatePlayerPosition(gameState, botId),
        'handsizeEfficiency': _calculateHandSizeEfficiency(botPlayer),
        'meldEfficiency': _calculateMeldEfficiency(botPlayer),
        'bookProgress': _calculateBookProgress(botPlayer),
      };

      // Use batching for performance metrics (medium frequency)
      await AnalyticsBatcher.addToBatch(
        collection: performanceMetricsCollection,
        data: metricsData,
        priority: false, // Performance metrics can be batched
      );

      if (kDebugMode) {
        _logger.fine('📈 Logged performance metrics for $botId ($personality)');
      }
    } catch (e) {
      _logger.warning('Failed to log performance metrics: $e');
    }
  }

  /// Log specific decision outcomes for learning
  static Future<void> logDecisionOutcome({
    required String botId,
    required String originalDecision,
    required String outcome,
    required int turnsLater,
    double? outcomeScore, // Positive/negative impact score
    Map<String, dynamic>? outcomeContext,
  }) async {
    if (!_analyticsEnabled) {
      return; // Removed detailed logging requirement for decision outcomes
    }
    if (_currentSessionId == null) return;

    try {
      final outcomeData = {
        'sessionId': _currentSessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'botId': botId,
        'originalDecision': originalDecision,
        'outcome': outcome,
        'turnsLater': turnsLater,
        'outcomeScore': outcomeScore,
        'outcomeContext': outcomeContext,
      };

      // Use batching for decision outcomes (low frequency but can be batched)
      await AnalyticsBatcher.addToBatch(
        collection: botDecisionsCollection,
        data: outcomeData,
        priority: false, // Decision outcomes can be batched
      );

      if (kDebugMode) {
        _logger.fine(
          '🎯 Logged decision outcome: $originalDecision -> $outcome',
        );
      }
    } catch (e) {
      _logger.warning('Failed to log decision outcome: $e');
    }
  }

  /// Get bot performance analytics (for debugging/development)
  static Future<Map<String, dynamic>?> getBotPerformanceAnalytics({
    required BotPersonality personality,
    int? limitDays,
    int? specificSeed, // Analyze performance on specific seed
    List<int>? seedRange, // Analyze performance across seed range
  }) async {
    if (!_analyticsEnabled || !_readOperationsEnabled) return null;

    try {
      final cutoffDate = limitDays != null
          ? DateTime.now().subtract(Duration(days: limitDays))
          : DateTime.now().subtract(const Duration(days: 30));

      // Build query with filters
      final fs = firestore;
      if (fs == null) return null;

      var query = fs
          .collection(gameSessionsCollection)
          .where('botPersonalities.${personality.name}', isGreaterThan: 0);

      // Add date filter
      query = query.where(
        'startTime',
        isGreaterThan: Timestamp.fromDate(cutoffDate),
      );

      // Add seed filters if specified
      if (specificSeed != null) {
        query = query.where('gameSeed', isEqualTo: specificSeed);
      } else if (seedRange != null && seedRange.length == 2) {
        query = query
            .where('gameSeed', isGreaterThanOrEqualTo: seedRange[0])
            .where('gameSeed', isLessThanOrEqualTo: seedRange[1]);
      }

      final sessions = await query.limit(100).get();

      if (sessions.docs.isEmpty) return null;

      // Aggregate performance data
      final analytics = <String, dynamic>{
        'personality': personality.name,
        'totalGames': sessions.docs.length,
        'winRate': 0.0,
        'averageScore': 0.0,
        'averageRounds': 0.0,
        'averageGameDuration': 0.0,
        'playDownSuccessRate': 0.0,
        'footTransitionRate': 0.0,
        'bookCompletionRate': 0.0,
      };

      int wins = 0;
      int totalScore = 0;
      int totalRounds = 0;
      int totalDuration = 0;
      int playDowns = 0;
      int footTransitions = 0;
      int booksCompleted = 0;
      int totalBots = 0;

      for (final doc in sessions.docs) {
        final data = doc.data();
        final botPerformance =
            data['botPerformance'] as Map<String, dynamic>? ?? {};

        for (final botData in botPerformance.values) {
          if (botData['personality'] == personality.name) {
            totalBots++;
            totalScore += (botData['finalScore'] as num?)?.toInt() ?? 0;

            if (botData['hasPlayedDown'] == true) playDowns++;
            if (botData['hasPickedUpFoot'] == true) footTransitions++;

            final bookCount = (botData['bookCount'] as num?)?.toInt() ?? 0;
            if (bookCount > 0) booksCompleted += bookCount;

            // Check if this bot won (highest score)
            final finalScores = List<int>.from(data['finalScores'] ?? []);
            if (finalScores.isNotEmpty) {
              final maxScore = finalScores.reduce((a, b) => a > b ? a : b);
              if (botData['finalScore'] == maxScore) wins++;
            }
          }
        }

        totalRounds += (data['finalRound'] as num?)?.toInt() ?? 0;
        totalDuration += (data['sessionDuration'] as num?)?.toInt() ?? 0;
      }

      if (totalBots > 0 && sessions.docs.isNotEmpty) {
        // Safe division with validation to prevent NaN/Infinity
        analytics['winRate'] = totalBots > 0
            ? (wins / totalBots * 100).round()
            : 0;
        analytics['averageScore'] = totalBots > 0
            ? (totalScore / totalBots).round()
            : 0;
        analytics['averageRounds'] = sessions.docs.isNotEmpty
            ? (totalRounds / sessions.docs.length).round()
            : 0;
        analytics['averageGameDuration'] = sessions.docs.isNotEmpty
            ? (totalDuration / sessions.docs.length).round()
            : 0;
        analytics['playDownSuccessRate'] = totalBots > 0
            ? (playDowns / totalBots * 100).round()
            : 0;
        analytics['footTransitionRate'] = totalBots > 0
            ? (footTransitions / totalBots * 100).round()
            : 0;
        analytics['bookCompletionRate'] = totalBots > 0
            ? (booksCompleted / totalBots * 100).round()
            : 0;
        analytics['totalBotInstances'] = totalBots;
      }

      return analytics;
    } catch (e) {
      _logger.warning('Failed to get bot performance analytics: $e');
      return null;
    }
  }

  /// Get seeds where bots perform poorly (for focused improvement)
  static Future<List<Map<String, dynamic>>> getChallengingSeeds({
    required BotPersonality personality,
    int? limitDays,
    int limit = 10,
  }) async {
    if (!_analyticsEnabled || !_readOperationsEnabled) return [];

    try {
      final cutoffDate = limitDays != null
          ? DateTime.now().subtract(Duration(days: limitDays))
          : DateTime.now().subtract(const Duration(days: 30));

      final fs = firestore;
      if (fs == null) return [];

      final sessions = await fs
          .collection(gameSessionsCollection)
          .where('botPersonalities.${personality.name}', isGreaterThan: 0)
          .where('startTime', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .orderBy('startTime')
          .limit(200) // Get more data for analysis
          .get();

      if (sessions.docs.isEmpty) return [];

      // Analyze performance by seed
      final seedPerformance = <int, Map<String, dynamic>>{};

      for (final doc in sessions.docs) {
        final data = doc.data();
        final seed = data['gameSeed'] as int?;
        if (seed == null) continue;

        final botPerformance =
            data['botPerformance'] as Map<String, dynamic>? ?? {};

        // Find this personality's performance in the game
        for (final botData in botPerformance.values) {
          if (botData['personality'] == personality.name) {
            if (!seedPerformance.containsKey(seed)) {
              seedPerformance[seed] = {
                'seed': seed,
                'totalGames': 0,
                'totalScore': 0,
                'wins': 0,
                'losses': 0,
              };
            }

            final seedStats = seedPerformance[seed]!;
            seedStats['totalGames'] = (seedStats['totalGames'] as int) + 1;
            seedStats['totalScore'] =
                (seedStats['totalScore'] as int) +
                (botData['finalScore'] as int? ?? 0);

            // Check if bot won (would need to compare with other players)
            final finalScores = List<int>.from(data['finalScores'] ?? []);
            if (finalScores.isNotEmpty) {
              final maxScore = finalScores.reduce((a, b) => a > b ? a : b);
              if (botData['finalScore'] == maxScore) {
                seedStats['wins'] = (seedStats['wins'] as int) + 1;
              } else {
                seedStats['losses'] = (seedStats['losses'] as int) + 1;
              }
            }
          }
        }
      }

      // Calculate performance metrics and sort by worst performance
      final challengingSeeds = <Map<String, dynamic>>[];

      for (final seedData in seedPerformance.values) {
        if ((seedData['totalGames'] as int) >= 2) {
          // Only include seeds with multiple games
          final wins = seedData['wins'] as int;
          final totalGames = seedData['totalGames'] as int;
          final avgScore = (seedData['totalScore'] as int) / totalGames;
          final winRate = wins / totalGames;

          challengingSeeds.add({
            ...seedData,
            'averageScore': avgScore.round(),
            'winRate': winRate,
            'difficulty': 1.0 - winRate, // Higher difficulty = lower win rate
          });
        }
      }

      // Sort by difficulty (worst performance first)
      challengingSeeds.sort(
        (a, b) =>
            (b['difficulty'] as double).compareTo(a['difficulty'] as double),
      );

      return challengingSeeds.take(limit).toList();
    } catch (e) {
      _logger.warning('Failed to get challenging seeds: $e');
      return [];
    }
  }

  // Helper methods for analytics calculations

  static String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'session_$timestamp$random';
  }

  static int _countDangerousOpponents(GameState gameState, String botId) {
    return gameState.players
        .where(
          (p) =>
              p.id != botId && p.hasPickedUpFoot && p.currentHand.length <= 5,
        )
        .length;
  }

  static int _calculatePlayerPosition(GameState gameState, String playerId) {
    final sortedScores = gameState.players.map((p) => p.score).toList()
      ..sort((a, b) => b.compareTo(a)); // Descending order

    final playerScore = gameState.players
        .firstWhere((p) => p.id == playerId)
        .score;

    return sortedScores.indexOf(playerScore) + 1; // 1-based position
  }

  static double _calculateHandSizeEfficiency(Player player) {
    // Lower hand size is better (more efficient play)
    final handSize = player.currentHand.length;
    if (handSize == 0) return 1.0;

    // Normalize to 0-1 scale (15+ cards = 0, 0 cards = 1)
    final efficiency = (15 - handSize.clamp(0, 15)) / 15.0;

    // Validate result to prevent Firebase "Invalid double" errors
    if (efficiency.isNaN || efficiency.isInfinite) return 0.0;
    return efficiency;
  }

  static int _calculateMeldEfficiency(Player player) {
    if (player.melds.isEmpty) return 0;

    // Calculate average meld size and book ratio with safety checks
    final totalCards = player.melds.fold(
      0,
      (total, meld) => total + meld.cards.length,
    );

    // Prevent division by zero and validate inputs
    if (player.melds.isEmpty || totalCards == 0) return 0;

    final averageMeldSize = totalCards / player.melds.length;
    final bookCount = player.melds.where((m) => m.cards.length >= 7).length;
    final bookRatio = bookCount / player.melds.length;

    // Combine metrics with validation to prevent NaN/Infinity
    final efficiency = (averageMeldSize / 10.0 + bookRatio) / 2.0 * 100;

    // Validate result before returning to prevent Firebase "Invalid double" errors
    if (efficiency.isNaN || efficiency.isInfinite || efficiency < 0) return 0;
    return efficiency.round();
  }

  static double _calculateBookProgress(Player player) {
    if (player.melds.isEmpty) return 0.0;

    final cleanBooks = player.melds
        .where((m) => m.cards.length >= 7 && m.isClean)
        .length;
    final dirtyBooks = player.melds
        .where((m) => m.cards.length >= 7 && !m.isClean)
        .length;

    // Need both types to go out - give partial credit for having one type
    if (cleanBooks > 0 && dirtyBooks > 0) return 1.0;
    if (cleanBooks > 0 || dirtyBooks > 0) return 0.5;
    return 0.0;
  }

  /// Sanitize analytics data to prevent Firebase "Invalid double" errors
  static Map<String, dynamic> _sanitizeAnalyticsData(
    Map<String, dynamic> data,
  ) {
    final sanitized = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is double) {
        // Check for invalid double values that cause Firebase errors
        if (value.isNaN || value.isInfinite) {
          sanitized[key] = 0; // Replace invalid doubles with 0
        } else {
          sanitized[key] = value;
        }
      } else if (value is Map<String, dynamic>) {
        // Recursively sanitize nested maps
        sanitized[key] = _sanitizeAnalyticsData(value);
      } else if (value is List) {
        // Sanitize lists
        sanitized[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _sanitizeAnalyticsData(item);
          } else if (item is double && (item.isNaN || item.isInfinite)) {
            return 0;
          }
          return item;
        }).toList();
      } else {
        // Keep other types as-is
        sanitized[key] = value;
      }
    }

    return sanitized;
  }

  // Privacy and configuration methods

  static bool get isAnalyticsEnabled => _analyticsEnabled;
  static bool get isDetailedLoggingEnabled => _detailedLoggingEnabled;
  static String? get currentSessionId => _currentSessionId;

  static void enableAnalytics(bool enabled) {
    _analyticsEnabled = enabled;
    _logger.info('Analytics ${enabled ? 'enabled' : 'disabled'}');
  }

  static void enableDetailedLogging(bool enabled) {
    _detailedLoggingEnabled = enabled;
    _logger.info('Detailed logging ${enabled ? 'enabled' : 'disabled'}');
  }

  // ============= DATA EXPORT METHODS FOR ANALYSIS =============

  /// Export comprehensive analytics data for external analysis
  static Future<Map<String, dynamic>> exportAnalyticsData({
    int? limitDays,
    bool includeDetailedLogs = false,
  }) async {
    if (!_analyticsEnabled || !_readOperationsEnabled) {
      return {'error': 'Analytics not enabled or read operations disabled'};
    }

    try {
      final cutoffDate = limitDays != null
          ? DateTime.now().subtract(Duration(days: limitDays))
          : DateTime.now().subtract(const Duration(days: 30));

      final exportData = <String, dynamic>{
        'exportTimestamp': DateTime.now().toIso8601String(),
        'limitDays': limitDays ?? 30,
        'personalities': {},
        'summary': {},
        'challengingScenarios': {},
      };

      // Get performance data for each personality
      for (final personality in BotPersonality.values) {
        final analytics = await getBotPerformanceAnalytics(
          personality: personality,
          limitDays: limitDays,
        );

        if (analytics != null) {
          exportData['personalities'][personality.name] = analytics;

          // Get challenging seeds for this personality
          final challengingSeeds = await getChallengingSeeds(
            personality: personality,
            limitDays: limitDays,
            limit: 10,
          );

          exportData['challengingScenarios'][personality.name] =
              challengingSeeds;
        }
      }

      // Calculate overall summary statistics
      final fs = firestore;
      if (fs == null) return exportData;

      final allSessions = await fs
          .collection(gameSessionsCollection)
          .where('startTime', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .limit(500)
          .get();

      exportData['summary'] = {
        'totalSessions': allSessions.docs.length,
        'dateRange': {
          'from': cutoffDate.toIso8601String(),
          'to': DateTime.now().toIso8601String(),
        },
        'gameTypes': {},
        'playerDistribution': {},
      };

      // Analyze session distribution
      final gameTypes = <String, int>{};
      final playerCounts = <int, int>{};

      for (final doc in allSessions.docs) {
        final data = doc.data();
        final gameMode = data['gameMode'] as String? ?? 'unknown';
        final playerCount = data['totalPlayers'] as int? ?? 0;

        gameTypes[gameMode] = (gameTypes[gameMode] ?? 0) + 1;
        playerCounts[playerCount] = (playerCounts[playerCount] ?? 0) + 1;
      }

      exportData['summary']['gameTypes'] = gameTypes;
      exportData['summary']['playerDistribution'] = playerCounts;

      // Include raw session data if requested (for detailed analysis)
      if (includeDetailedLogs) {
        exportData['rawSessions'] = allSessions.docs
            .map((doc) => doc.data())
            .toList();
      }

      return exportData;
    } catch (e) {
      _logger.severe('Failed to export analytics data: $e');
      return {'error': 'Export failed: $e'};
    }
  }

  /// Export analytics as JSON string for easy sharing
  static Future<String> exportAnalyticsAsJson({
    int? limitDays,
    bool includeDetailedLogs = false,
    bool prettyPrint = true,
  }) async {
    final data = await exportAnalyticsData(
      limitDays: limitDays,
      includeDetailedLogs: includeDetailedLogs,
    );

    if (prettyPrint) {
      final encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    }

    return jsonEncode(data);
  }

  /// Export specific personality comparison data
  static Future<Map<String, dynamic>> exportPersonalityComparison({
    List<BotPersonality>? personalities,
    int? limitDays,
    List<String>? metrics,
  }) async {
    personalities ??= BotPersonality.values;
    metrics ??= [
      'winRate',
      'averageScore',
      'playDownSuccessRate',
      'bookCompletionRate',
    ];

    final comparison = <String, dynamic>{
      'exportTimestamp': DateTime.now().toIso8601String(),
      'personalities': {},
      'comparison': {},
      'rankings': {},
    };

    final personalityData = <String, Map<String, dynamic>>{};

    // Collect data for each personality
    for (final personality in personalities) {
      final analytics = await getBotPerformanceAnalytics(
        personality: personality,
        limitDays: limitDays,
      );

      if (analytics != null) {
        personalityData[personality.name] = analytics;
        comparison['personalities'][personality.name] = analytics;
      }
    }

    // Create metric-by-metric comparison
    for (final metric in metrics) {
      final metricComparison = <String, dynamic>{};
      final metricRanking = <Map<String, dynamic>>[];

      for (final entry in personalityData.entries) {
        final value = entry.value[metric];
        if (value != null) {
          metricComparison[entry.key] = value;
          metricRanking.add({'personality': entry.key, 'value': value});
        }
      }

      // Sort ranking by value (descending for most metrics)
      metricRanking.sort(
        (a, b) => (b['value'] as num).compareTo(a['value'] as num),
      );

      comparison['comparison'][metric] = metricComparison;
      comparison['rankings'][metric] = metricRanking;
    }

    return comparison;
  }

  /// Get analytics summary for quick status check
  static Future<Map<String, dynamic>> getAnalyticsSummary({
    int? limitDays,
  }) async {
    final data = await exportAnalyticsData(limitDays: limitDays);

    if (data.containsKey('error')) return data;

    final summary = <String, dynamic>{
      'dataAvailable': true,
      'totalSessions': data['summary']['totalSessions'],
      'dateRange': data['summary']['dateRange'],
      'personalitiesAnalyzed': (data['personalities'] as Map).keys.length,
      'readyForAnalysis': false,
    };

    // Determine if we have enough data for meaningful analysis
    final totalSessions = data['summary']['totalSessions'] as int;
    final personalities = data['personalities'] as Map<String, dynamic>;

    int totalBotInstances = 0;
    for (final personalityData in personalities.values) {
      final instances = personalityData['totalBotInstances'] as int? ?? 0;
      totalBotInstances += instances;
    }

    // Consider ready if we have 20+ sessions and 50+ bot instances
    summary['readyForAnalysis'] =
        totalSessions >= 20 && totalBotInstances >= 50;
    summary['totalBotInstances'] = totalBotInstances;
    summary['recommendedMinimum'] = {
      'sessions': 20,
      'botInstances': 50,
      'currentSessions': totalSessions,
      'currentBotInstances': totalBotInstances,
    };

    return summary;
  }
}
