import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hand_foot_game_flutter/services/multiplayer_resume_service.dart';

void main() {
  group('MultiplayerResumeService Tests', () {
    setUp(() {
      // Initialize SharedPreferences with in-memory storage for testing
      SharedPreferences.setMockInitialValues({});
    });

    test('should save and retrieve active game info', () async {
      // Save active game
      await MultiplayerResumeService.saveActiveGame(
        gameId: 'TEST123',
        playerName: 'TestPlayer',
        isHost: true,
        playerId: 'auth-uid-123',
      );

      // Retrieve active game
      final activeGame = await MultiplayerResumeService.getActiveGame();

      expect(activeGame, isNotNull);
      expect(activeGame!['gameId'], 'TEST123');
      expect(activeGame['playerName'], 'TestPlayer');
      expect(activeGame['isHost'], true);
      expect(activeGame['playerId'], 'auth-uid-123');
      expect(activeGame['timestamp'], isA<int>());
    });

    test('should clear active game info', () async {
      // Save then clear
      await MultiplayerResumeService.saveActiveGame(
        gameId: 'TEST123',
        playerName: 'TestPlayer',
        isHost: false,
        playerId: 'auth-uid-456',
      );

      await MultiplayerResumeService.clearActiveGame();

      final activeGame = await MultiplayerResumeService.getActiveGame();
      expect(activeGame, isNull);
    });

    test('should return null for expired game info', () async {
      // Manually save expired game info
      final prefs = await SharedPreferences.getInstance();
      final expiredTimestamp =
          DateTime.now().millisecondsSinceEpoch -
          (25 * 60 * 60 * 1000); // 25 hours ago

      await prefs.setString('active_multiplayer_game', '''
        {
          "gameId": "EXPIRED123", 
          "playerName": "ExpiredPlayer",
          "isHost": false,
          "playerId": "auth-uid-old",
          "timestamp": $expiredTimestamp
        }
      ''');

      final activeGame = await MultiplayerResumeService.getActiveGame();
      expect(activeGame, isNull, reason: 'Should return null for expired game');
    });

    test('should handle corrupted game data gracefully', () async {
      // Save corrupted data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_multiplayer_game', 'invalid json data');

      final activeGame = await MultiplayerResumeService.getActiveGame();
      expect(
        activeGame,
        isNull,
        reason: 'Should return null for corrupted data',
      );

      // Should have cleared corrupted data
      final clearedData = prefs.getString('active_multiplayer_game');
      expect(clearedData, isNull, reason: 'Should clear corrupted data');
    });

    test('should save and retrieve stored player name', () async {
      await MultiplayerResumeService.saveActiveGame(
        gameId: 'TEST123',
        playerName: 'StoredPlayer',
        isHost: true,
        playerId: 'auth-uid-789',
      );

      final storedName = await MultiplayerResumeService.getStoredPlayerName();
      expect(storedName, 'StoredPlayer');
    });

    test('legacy bookmarks without playerId remain readable', () async {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString('active_multiplayer_game', '''
        {
          "gameId": "LEGACY1",
          "playerName": "LegacyPlayer",
          "isHost": false,
          "timestamp": $timestamp
        }
      ''');

      final activeGame = await MultiplayerResumeService.getActiveGame();
      expect(activeGame, isNotNull);
      expect(activeGame!['gameId'], 'LEGACY1');
      expect(activeGame['playerId'], isNull);
    });
  });
}
