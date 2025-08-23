import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/services/game_save_service.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Continue Game Logic Tests', () {
    setUp(() async {
      // Clear any existing saved games before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('should detect single player game with bots correctly', () async {
      // Create a single player game with bots
      final players = [
        Player(id: '1', name: 'You', type: PlayerType.human),
        Player(id: '2', name: 'Bot 1', type: PlayerType.bot),
        Player(id: '3', name: 'Bot 2', type: PlayerType.bot),
      ];

      final gameController = GameController(players: players, seed: 12345);
      gameController.initializeGame();

      // Save the game
      await GameSaveService.saveGame(gameController.gameState, 12345);

      // Load and verify the saved game
      final savedGameData = await GameSaveService.loadGame();
      expect(savedGameData, isNotNull);

      final savedPlayers = savedGameData!['players'] as List;
      int humanPlayerCount = 0;
      int botPlayerCount = 0;

      for (final playerData in savedPlayers) {
        final playerType = playerData['type'] as String;
        if (playerType == PlayerType.human.name) {
          humanPlayerCount++;
        } else if (playerType == PlayerType.bot.name) {
          botPlayerCount++;
        }
      }

      // This should be a single player game (1 human + bots)
      expect(humanPlayerCount, equals(1));
      expect(botPlayerCount, greaterThan(0));
    });

    test('should not detect multiplayer game as single player', () async {
      // Create a multiplayer game (multiple humans)
      final players = [
        Player(id: '1', name: 'Player 1', type: PlayerType.human),
        Player(id: '2', name: 'Player 2', type: PlayerType.human),
        Player(id: '3', name: 'Bot 1', type: PlayerType.bot),
      ];

      final gameController = GameController(players: players, seed: 12345);
      gameController.initializeGame();

      // Save the game
      await GameSaveService.saveGame(gameController.gameState, 12345);

      // Load and verify the saved game
      final savedGameData = await GameSaveService.loadGame();
      expect(savedGameData, isNotNull);

      final savedPlayers = savedGameData!['players'] as List;
      int humanPlayerCount = 0;

      for (final playerData in savedPlayers) {
        final playerType = playerData['type'] as String;
        if (playerType == PlayerType.human.name) {
          humanPlayerCount++;
        }
      }

      // This should NOT be a single player game (multiple humans)
      expect(humanPlayerCount, greaterThan(1));
    });

    test('should successfully restore saved single player game', () async {
      // Create a single player game with bots
      final players = [
        Player(id: '1', name: 'You', type: PlayerType.human),
        Player(id: '2', name: 'Bot 1', type: PlayerType.bot),
        Player(id: '3', name: 'Bot 2', type: PlayerType.bot),
      ];

      final gameController = GameController(players: players, seed: 12345);
      gameController.initializeGame();

      // Make some game progress
      final initialRound = gameController.gameState.round;
      final initialPhase = gameController.gameState.phase;

      // Save the game
      await GameSaveService.saveGame(gameController.gameState, 12345);

      // Load and restore the game
      final savedGameData = await GameSaveService.loadGame();
      expect(savedGameData, isNotNull);

      final restoredController = GameSaveService.restoreGameController(
        savedGameData!,
      );
      expect(restoredController, isNotNull);

      // Verify the restored game has the same state
      expect(restoredController!.gameState.round, equals(initialRound));
      expect(restoredController.gameState.phase, equals(initialPhase));
      expect(restoredController.gameState.players.length, equals(3));

      // Verify player types are preserved
      int humanCount = 0;
      int botCount = 0;
      for (final player in restoredController.gameState.players) {
        if (player.type == PlayerType.human) humanCount++;
        if (player.type == PlayerType.bot) botCount++;
      }
      expect(humanCount, equals(1));
      expect(botCount, equals(2));
    });

    test('should return null for corrupted save data', () async {
      // Set up corrupted save data in SharedPreferences
      SharedPreferences.setMockInitialValues({
        'hand_foot_game_save': 'invalid_json_data',
      });

      // Try to load the corrupted data
      final savedGameData = await GameSaveService.loadGame();
      expect(savedGameData, isNull);
    });

    test('should return false for hasSavedGame when no save exists', () async {
      final hasSaved = await GameSaveService.hasSavedGame();
      expect(hasSaved, isFalse);
    });

    test('should return true for hasSavedGame when save exists', () async {
      // Create and save a game
      final players = [
        Player(id: '1', name: 'You', type: PlayerType.human),
        Player(id: '2', name: 'Bot 1', type: PlayerType.bot),
      ];

      final gameController = GameController(players: players, seed: 12345);
      gameController.initializeGame();
      await GameSaveService.saveGame(gameController.gameState, 12345);

      final hasSaved = await GameSaveService.hasSavedGame();
      expect(hasSaved, isTrue);
    });
  });
}
