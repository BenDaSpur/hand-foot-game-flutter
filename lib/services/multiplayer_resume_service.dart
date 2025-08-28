import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/enhanced_multiplayer_controller.dart';
import '../game/game_controller_factory.dart';
import '../services/firebase_service.dart';
import '../utils/debug_logger.dart';

/// Service to handle multiplayer game resuming after crashes/disconnections
class MultiplayerResumeService {
  static const String _activeGameKey = 'active_multiplayer_game';
  static const String _playerNameKey = 'player_name';

  /// Save active multiplayer game info for crash recovery
  static Future<void> saveActiveGame({
    required String gameId,
    required String playerName,
    required bool isHost,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final gameInfo = {
        'gameId': gameId,
        'playerName': playerName,
        'isHost': isHost,
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

      if (gameInfoJson == null) return null;

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
      if (gameDoc == null) return false;

      final status = gameDoc['status'] as String?;
      return status == 'playing' || status == 'waiting';
    } catch (e) {
      DebugLogger.error('Failed to check game status: $e');
      return false;
    }
  }

  /// Attempt to rejoin a multiplayer game
  static Future<EnhancedMultiplayerController?> rejoinGame({
    required String gameId,
    required String playerName,
  }) async {
    try {
      DebugLogger.debug('Attempting to rejoin game: $gameId as $playerName');

      // Check if game is still active
      if (!await canRejoinGame(gameId)) {
        DebugLogger.warning(
          'Cannot rejoin game $gameId - game not found or ended',
        );
        await clearActiveGame();
        return null;
      }

      // Use the existing joinGame logic
      final controller = await GameControllerFactory.joinMultiplayerGame(
        gameId: gameId,
        playerName: playerName,
      );

      if (controller != null) {
        // Save the rejoined game info
        await saveActiveGame(
          gameId: gameId,
          playerName: playerName,
          isHost: false, // Rejoining players are not hosts
        );

        DebugLogger.debug('Successfully rejoined game: $gameId');
      }

      return controller;
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
      if (activeGame == null) return null;

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
        'canRejoin': true,
      };
    } catch (e) {
      DebugLogger.error('Failed to check rejoin opportunity: $e');
      return null;
    }
  }
}
