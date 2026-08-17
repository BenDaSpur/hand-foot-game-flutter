import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/player.dart';
import '../../models/game_state.dart';
import '../../game/game_controller.dart';
import '../../ai/enhanced_bot_ai.dart';
import '../../ai/bot_personality.dart';
import '../../config/bot_configurations.dart';
import '../../services/game_save_service.dart';
import '../../utils/debug_logger.dart';
import '../../theme/balatro_theme.dart';

/// Manages game persistence, save/load, and export/import functionality.
///
/// This class handles all game state persistence including automatic saving,
/// manual save/load operations, and export/import functionality with
/// bot personality preservation.
/// Extracted from GameScreen to improve code organization.
class PersistenceManager {
  final GameController gameController;
  final EnhancedBotAI botAI;
  final Function() onStateChanged;
  final Function(GameController, Map<String, String>) onGameLoaded;

  PersistenceManager({
    required this.gameController,
    required this.botAI,
    required this.onStateChanged,
    required this.onGameLoaded,
  });

  Map<String, BotPersonality> _liveBotPersonalities() {
    final botPersonalities = <String, BotPersonality>{};
    for (final player in gameController.gameState.players) {
      if (player.type == PlayerType.bot) {
        botPersonalities[player.id] = botAI.personalityManager.getPersonality(
          player.id,
        );
      }
    }
    return botPersonalities;
  }

  /// Save current game state to local storage
  Future<void> saveGameState() async {
    try {
      await GameSaveService.saveGame(
        gameController.gameState,
        gameController.gameSeed,
        botPersonalities: _liveBotPersonalities(),
      );
    } catch (e) {
      DebugLogger.error('Failed to save game state: $e');
    }
  }

  /// Export current game state with bot personalities
  String exportGameState() {
    return gameController.exportGameState(
      serializeBotPersonalities(_liveBotPersonalities()),
    );
  }

  /// Copy exported game state to clipboard
  void copyGameStateToClipboard(BuildContext context) {
    final gameStateBase64 = exportGameState();
    Clipboard.setData(ClipboardData(text: gameStateBase64));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Compact game save copied to clipboard',
          style: TextStyle(color: BalatroTheme.primaryText),
        ),
        backgroundColor: BalatroTheme.neonBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Copy game seed to clipboard
  void copySeedToClipboard(BuildContext context) {
    final seed = gameController.gameSeed?.toString() ?? 'No seed';
    Clipboard.setData(ClipboardData(text: seed));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Game seed copied: $seed',
          style: const TextStyle(color: BalatroTheme.primaryText),
        ),
        backgroundColor: BalatroTheme.neonOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Load game from JSON string (export format)
  void loadGameFromJson(String inputText, BuildContext context) {
    if (inputText.trim().isEmpty) {
      _showErrorDialog(
        context,
        'Please paste a valid game save (Base64 or JSON).',
      );
      return;
    }

    try {
      final importResult = GameController.fromExportJson(inputText);
      if (importResult == null) {
        _showErrorDialog(
          context,
          'Failed to load game save. The format may be invalid or corrupted.',
        );
        return;
      }

      // Notify parent about successful load
      onGameLoaded(importResult.controller, importResult.botPersonalities);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Game loaded successfully! Seed: ${importResult.controller.gameSeed ?? "No seed"}',
            style: const TextStyle(color: BalatroTheme.primaryText),
          ),
          backgroundColor: BalatroTheme.neonGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      DebugLogger.error('Error loading game from JSON: $e');
      _showErrorDialog(context, 'Error loading game: ${e.toString()}');
    }
  }

  /// Check if there's a saved game available
  Future<bool> hasSavedGame() async {
    return await GameController.hasSavedGame();
  }

  /// Load saved game from local storage
  Future<GameController?> loadSavedGame() async {
    try {
      final savedData = await GameSaveService.loadGame();
      if (savedData != null) {
        return GameSaveService.restoreGameController(savedData);
      }
      return null;
    } catch (e) {
      DebugLogger.error('Error loading saved game: $e');
      return null;
    }
  }

  /// Restore game state from saved data
  Future<void> restoreFromSavedState() async {
    try {
      final savedController = await loadSavedGame();
      if (savedController != null) {
        onGameLoaded(savedController, <String, String>{});
        onStateChanged();
        return;
      }
      DebugLogger.warning('No saved state available for recovery');
    } catch (e) {
      DebugLogger.error('Error restoring from saved state: $e');
    }
  }

  /// Clear any saved game data
  Future<void> clearSavedGame() async {
    try {
      // Implementation depends on GameSaveService having a clear method
      // For now, just log the intent
      DebugLogger.debug('Clearing saved game data');
    } catch (e) {
      DebugLogger.error('Error clearing saved game: $e');
    }
  }

  /// Validate that the game state is ready for saving
  bool canSaveGame() {
    try {
      final gameState = gameController.gameState;

      // Don't save if game hasn't started
      if (gameState.phase == GamePhase.setup) {
        return false;
      }

      // Don't save if game has ended
      if (gameState.phase == GamePhase.gameEnd) {
        return false;
      }

      // Ensure we have valid players
      if (gameState.players.isEmpty) {
        return false;
      }

      return true;
    } catch (e) {
      DebugLogger.error('Error checking if game can be saved: $e');
      return false;
    }
  }

  /// Get game state summary for debugging
  Map<String, dynamic> getGameStateSummary() {
    final gameState = gameController.gameState;

    return {
      'phase': gameState.phase.toString(),
      'turnPhase': gameState.turnPhase.toString(),
      'round': gameState.round,
      'currentPlayer': gameState.currentPlayer.name,
      'playerCount': gameState.players.length,
      'deckSize': gameState.deck.size,
      'discardPileSize': gameState.discardPile.length,
    };
  }

  /// Helper method to show error dialogs
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: BalatroTheme.heartsColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Error',
              style: TextStyle(
                color: BalatroTheme.heartsColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: BalatroTheme.heartsColor.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }
}
