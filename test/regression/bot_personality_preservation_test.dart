import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

/// Test to ensure bot personalities are preserved across export/import operations
void main() {
  group('Bot Personality Preservation Tests', () {
    test('export should include bot personalities in save data', () {
      // Setup: Create game with specific bot personalities
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'BotA', type: PlayerType.bot),
        Player(id: '3', name: 'BotB', type: PlayerType.bot),
      ];

      final controller = GameController(players: players);
      controller.initializeGame();

      // Set up specific bot personalities for testing
      final botPersonalities = {
        '2': 'BotPersonality.conservative',
        '3': 'BotPersonality.aggressive',
      };

      // Act: Export game state with personalities
      final exportedData = controller.exportGameState(botPersonalities);

      // Assert: Export should contain the data and not be null/empty
      expect(exportedData, isNotNull);
      expect(exportedData, isNotEmpty);

      // The actual personality data is embedded in the compressed format,
      // so we can't easily verify the content here, but we can verify
      // the method accepts the parameter and returns data
    });

    test('import should restore bot personalities from save data', () {
      // Setup: Create game with specific bot personalities
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'BotA', type: PlayerType.bot),
        Player(id: '3', name: 'BotB', type: PlayerType.bot),
      ];

      final originalController = GameController(players: players);
      originalController.initializeGame();

      // Set up specific bot personalities for testing
      final originalPersonalities = {
        '2': 'BotPersonality.conservative',
        '3': 'BotPersonality.aggressive',
      };

      // Act: Export game state with personalities
      final exportedData = originalController.exportGameState(
        originalPersonalities,
      );

      // Act: Import the exported data
      final importResult = GameController.fromExportJson(exportedData);

      // Assert: Import should succeed and contain bot personalities
      expect(importResult, isNotNull);
      expect(importResult!.controller, isNotNull);
      expect(importResult.botPersonalities, isNotNull);

      // Assert: Personalities should be preserved
      expect(
        importResult.botPersonalities['2'],
        equals('BotPersonality.conservative'),
      );
      expect(
        importResult.botPersonalities['3'],
        equals('BotPersonality.aggressive'),
      );

      // Assert: Game controller should be properly restored
      expect(importResult.controller.gameState.players.length, equals(3));
      expect(importResult.controller.gameState.players[1].name, equals('BotA'));
      expect(importResult.controller.gameState.players[2].name, equals('BotB'));
    });

    test('import should handle empty personality data gracefully', () {
      // Setup: Create game without personalities
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'BotA', type: PlayerType.bot),
      ];

      final controller = GameController(players: players);
      controller.initializeGame();

      // Act: Export game state without personalities (null parameter)
      final exportedData = controller.exportGameState();

      // Act: Import the exported data
      final importResult = GameController.fromExportJson(exportedData);

      // Assert: Import should succeed with empty personalities map
      expect(importResult, isNotNull);
      expect(importResult!.controller, isNotNull);
      expect(importResult.botPersonalities, isNotNull);
      expect(importResult.botPersonalities, isEmpty);
    });

    test('round-trip export/import preserves all bot personality data', () {
      // Setup: Create game with multiple bot personalities
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Conservative Bot', type: PlayerType.bot),
        Player(id: '3', name: 'Aggressive Bot', type: PlayerType.bot),
        Player(id: '4', name: 'Book Builder Bot', type: PlayerType.bot),
        Player(id: '5', name: 'Adaptive Bot', type: PlayerType.bot),
      ];

      final controller = GameController(players: players);
      controller.initializeGame();

      // Set up all personality types for comprehensive testing
      final originalPersonalities = {
        '2': 'BotPersonality.conservative',
        '3': 'BotPersonality.aggressive',
        '4': 'BotPersonality.bookBuilder',
        '5': 'BotPersonality.adaptive',
      };

      // Act: Export and then import
      final exportedData = controller.exportGameState(originalPersonalities);
      final importResult = GameController.fromExportJson(exportedData);

      // Assert: All personality data should be preserved exactly
      expect(importResult, isNotNull);
      expect(importResult!.botPersonalities.length, equals(4));

      for (final entry in originalPersonalities.entries) {
        expect(
          importResult.botPersonalities[entry.key],
          equals(entry.value),
          reason: 'Personality for bot ${entry.key} should be preserved',
        );
      }

      // Assert: Game state should also be properly restored
      expect(importResult.controller.gameState.players.length, equals(5));
      expect(
        importResult.controller.gameState.players
            .where((p) => p.type == PlayerType.bot)
            .length,
        equals(4),
      );
    });
  });
}
