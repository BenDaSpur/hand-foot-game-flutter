import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/enhanced_multiplayer_controller.dart';
import '../game/game_controller_factory.dart';
import '../services/firebase_constants.dart';
import '../services/firebase_service.dart';
import '../utils/debug_logger.dart';

/// Result of rejoining or auto-resuming a multiplayer session.
class MultiplayerResumeResult {
  final EnhancedMultiplayerController controller;
  final String status;
  final String gameId;
  final String playerName;
  final bool isHost;

  const MultiplayerResumeResult({
    required this.controller,
    required this.status,
    required this.gameId,
    required this.playerName,
    required this.isHost,
  });

  bool get isWaiting => status == FirebaseConstants.gameStatusWaiting;
  bool get isPlaying => status == FirebaseConstants.gameStatusPlaying;
}

/// Service to handle multiplayer game resuming after crashes/disconnections
class MultiplayerResumeService {
  static const String _activeGameKey = 'active_multiplayer_game';
  static const String _playerNameKey = 'player_name';

  /// Save active multiplayer game info for crash recovery
  static Future<void> saveActiveGame({
    required String gameId,
    required String playerName,
    required bool isHost,
    String? playerId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final resolvedPlayerId =
          playerId ?? await FirebaseService.getMultiplayerUserId();

      final gameInfo = {
        'gameId': gameId,
        'playerName': playerName,
        'isHost': isHost,
        'playerId': resolvedPlayerId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(_activeGameKey, jsonEncode(gameInfo));
      await prefs.setString(_playerNameKey, playerName);

      DebugLogger.debug('Saved active multiplayer game: $gameId');
    } catch (e) {
      DebugLogger.error('Failed to save active game: $e');
    }
  }

  /// Get active multiplayer game info if exists
  static Future<Map<String, dynamic>?> getActiveGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gameInfoJson = prefs.getString(_activeGameKey);

      if (gameInfoJson == null) {
        return null;
      }

      final gameInfo = jsonDecode(gameInfoJson) as Map<String, dynamic>;

      // Check if game info is recent (within last 24 hours)
      final timestamp = gameInfo['timestamp'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      const maxAge = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

      if (age > maxAge) {
        // Game info is too old, clear it
        await clearActiveGame();
        return null;
      }

      return gameInfo;
    } catch (e) {
      DebugLogger.error('Failed to get active game: $e');
      await clearActiveGame(); // Clear corrupted data
      return null;
    }
  }

  /// Clear active game info (when game ends or player leaves)
  static Future<void> clearActiveGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeGameKey);
      DebugLogger.debug('Cleared active multiplayer game info');
    } catch (e) {
      DebugLogger.error('Failed to clear active game: $e');
    }
  }

  /// Check if a multiplayer game is still active and can be rejoined
  static Future<bool> canRejoinGame(String gameId) async {
    try {
      // Check if game still exists in Firebase
      final gameDoc = await FirebaseService.getGame(gameId);
      if (gameDoc == null) {
        return false;
      }

      final status = gameDoc['status'] as String?;
      return status == FirebaseConstants.gameStatusPlaying ||
          status == FirebaseConstants.gameStatusWaiting;
    } catch (e) {
      DebugLogger.error('Failed to check game status: $e');
      return false;
    }
  }

  /// True when the bookmark's playerId matches the current Auth UID.
  ///
  /// Bookmarks without playerId (legacy) are treated as matching so older
  /// clients can still rejoin via Auth UID on the server.
  static Future<bool> _bookmarkMatchesCurrentUser(
    Map<String, dynamic> activeGame,
  ) async {
    final storedPlayerId = activeGame['playerId'] as String?;
    if (storedPlayerId == null || storedPlayerId.isEmpty) {
      return true;
    }

    final currentUserId = await FirebaseService.getMultiplayerUserId();
    if (currentUserId == null) {
      // Auth unavailable (tests / unconfigured Firebase) — defer to server.
      return true;
    }

    return storedPlayerId == currentUserId;
  }

  /// Attempt to rejoin a multiplayer game
  static Future<EnhancedMultiplayerController?> rejoinGame({
    required String gameId,
    required String playerName,
  }) async {
    final result = await rejoinGameWithStatus(
      gameId: gameId,
      playerName: playerName,
    );
    return result?.controller;
  }

  /// Rejoin and return status so callers can open lobby vs game screen.
  static Future<MultiplayerResumeResult?> rejoinGameWithStatus({
    required String gameId,
    required String playerName,
  }) async {
    try {
      DebugLogger.debug('Attempting to rejoin game: $gameId as $playerName');

      final activeGame = await getActiveGame();
      if (activeGame != null &&
          activeGame['gameId'] == gameId &&
          !await _bookmarkMatchesCurrentUser(activeGame)) {
        DebugLogger.warning(
          'Cannot rejoin game $gameId - stored playerId does not match Auth UID',
        );
        await clearActiveGame();
        return null;
      }

      // Check if game is still active
      final gameDoc = await FirebaseService.getGame(gameId);
      if (gameDoc == null) {
        DebugLogger.warning(
          'Cannot rejoin game $gameId - game not found or ended',
        );
        await clearActiveGame();
        return null;
      }

      final status = gameDoc['status'] as String?;
      if (status != FirebaseConstants.gameStatusPlaying &&
          status != FirebaseConstants.gameStatusWaiting) {
        DebugLogger.warning('Cannot rejoin game $gameId - status is $status');
        await clearActiveGame();
        return null;
      }

      // Use the existing joinGame logic
      final controller = await GameControllerFactory.joinMultiplayerGame(
        gameId: gameId,
        playerName: playerName,
      );

      if (controller == null) {
        return null;
      }

      final isHost = controller.isHost;

      // Save the rejoined game info with authoritative host status + playerId
      await saveActiveGame(
        gameId: gameId,
        playerName: playerName,
        isHost: isHost,
        playerId: controller.userId,
      );

      DebugLogger.debug(
        'Successfully rejoined game: $gameId (isHost: $isHost, status: $status)',
      );

      return MultiplayerResumeResult(
        controller: controller,
        status: status!,
        gameId: gameId,
        playerName: playerName,
        isHost: isHost,
      );
    } catch (e) {
      DebugLogger.error('Failed to rejoin game: $e');
      return null;
    }
  }

  /// Get stored player name for quick rejoin
  static Future<String?> getStoredPlayerName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_playerNameKey);
    } catch (e) {
      return null;
    }
  }

  /// Check for active games on app startup and offer to rejoin
  static Future<Map<String, dynamic>?> checkForRejoinOpportunity() async {
    try {
      final activeGame = await getActiveGame();
      if (activeGame == null) {
        return null;
      }

      if (!await _bookmarkMatchesCurrentUser(activeGame)) {
        await clearActiveGame();
        return null;
      }

      final gameId = activeGame['gameId'] as String;
      final canRejoin = await canRejoinGame(gameId);

      if (!canRejoin) {
        await clearActiveGame();
        return null;
      }

      return {
        'gameId': gameId,
        'playerName': activeGame['playerName'],
        'isHost': activeGame['isHost'],
        'playerId': activeGame['playerId'],
        'canRejoin': true,
      };
    } catch (e) {
      DebugLogger.error('Failed to check rejoin opportunity: $e');
      return null;
    }
  }

  /// Auto-resume into a live game when bookmark + Auth UID still match.
  ///
  /// Returns null when there is nothing to resume (caller may still show a
  /// manual REJOIN button if [checkForRejoinOpportunity] succeeds later).
  static Future<MultiplayerResumeResult?> attemptAutoResume() async {
    try {
      final opportunity = await checkForRejoinOpportunity();
      if (opportunity == null) {
        return null;
      }

      final gameId = opportunity['gameId'] as String;
      final playerName = opportunity['playerName'] as String;

      return rejoinGameWithStatus(gameId: gameId, playerName: playerName);
    } catch (e) {
      DebugLogger.error('Failed to auto-resume multiplayer game: $e');
      return null;
    }
  }
}
