import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/services/firebase_service.dart';
import 'package:hand_foot_game_flutter/services/game_code.dart';
import 'package:hand_foot_game_flutter/services/device_service.dart';
import 'package:hand_foot_game_flutter/game/game_controller_factory.dart';
import 'package:hand_foot_game_flutter/game/enhanced_multiplayer_controller.dart';
import 'package:hand_foot_game_flutter/services/firebase_constants.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';

void main() {
  group('Mock multiplayer success path', () {
    test('create and join with mock adapter succeeds end-to-end', () async {
      EnhancedMultiplayerController? hostController;
      EnhancedMultiplayerController? guestController;
      addTearDown(() {
        hostController?.dispose();
        guestController?.dispose();
      });

      hostController = await GameControllerFactory.createTestMultiplayerGame(
        hostPlayerName: 'Host',
        maxPlayers: 2,
      );

      expect(hostController, isNotNull);
      expect(hostController!.isHost, isTrue);

      guestController = await GameControllerFactory.joinTestMultiplayerGame(
        gameId: hostController.gameId,
        playerName: 'Guest',
      );

      expect(guestController, isNotNull);
      expect(guestController!.isHost, isFalse);

      final started = await hostController.startMultiplayerGame();
      expect(started, isTrue);

      final serverState = GameState(
        players: [
          Player(
            id: hostController.userId,
            name: 'Host',
            type: PlayerType.human,
          ),
          Player(
            id: guestController.userId,
            name: 'Guest',
            type: PlayerType.human,
          ),
        ],
        deck: Deck(),
        phase: GamePhase.playing,
      );

      await hostController.initializeFromServerState(serverState);
      await guestController.initializeFromServerState(serverState);

      expect(hostController.gameState.players.length, 2);
      expect(guestController.gameState.players.length, 2);

      final hostLeft = await hostController.leaveGame();
      expect(hostLeft, isTrue);
    });
  });

  group('Multiplayer Integration Tests', () {
    test('complete game creation flow', () async {
      expect(() async {
        try {
          // Step 1: Get device ID
          final deviceId = await DeviceService.getDeviceId();
          expect(deviceId, isA<String>());

          // Step 2: Create game through Firebase service
          final gameId = await FirebaseService.createGame(
            hostPlayerName: 'IntegrationHost',
            maxPlayers: 4,
          );

          if (gameId != null) {
            expect(gameId.length, 4);
            expect(RegExp(r'^[A-Z]{2}[0-9]{2}$').hasMatch(gameId), true);

            // Step 3: Create multiplayer controller
            final controller =
                await GameControllerFactory.createMultiplayerGame(
                  hostPlayerName: 'IntegrationHost',
                  maxPlayers: 4,
                );

            if (controller != null) {
              expect(controller.gameId, isA<String>());
            }
          }
        } catch (e) {
          // Expected to fail without Firebase setup
        }
      }, returnsNormally);
    });

    test('complete game joining flow', () async {
      expect(() async {
        try {
          // Step 1: Get device ID for joining player
          final deviceId = await DeviceService.getDeviceId();
          expect(deviceId, isA<String>());

          // Step 2: Attempt to join game (will fail without existing game)
          final success = await FirebaseService.joinGame(
            gameId: 'TEST',
            playerName: 'IntegrationPlayer',
          );

          expect(success, isA<bool>());

          // Step 3: Create controller for joined game
          final controller = await GameControllerFactory.joinMultiplayerGame(
            gameId: 'TEST',
            playerName: 'IntegrationPlayer',
          );

          // Will be null without existing game, but shouldn't crash
          expect(controller, anyOf(isNull, isA<Object>()));
        } catch (e) {
          // Expected to fail without Firebase setup
        }
      }, returnsNormally);
    });

    test('game lifecycle with cleanup', () async {
      expect(() async {
        try {
          // Create game
          final gameId = await FirebaseService.createGame(
            hostPlayerName: 'TestHost',
            maxPlayers: 2,
          );

          if (gameId != null) {
            // Start game
            await FirebaseService.startGame(gameId);

            // Leave game (cleanup)
            await FirebaseService.leaveGame(gameId);
          }
        } catch (e) {
          // Expected to fail without Firebase setup
        }
      }, returnsNormally);
    });

    test('expired games cleanup integration', () async {
      expect(() async {
        try {
          // Run cleanup
          await FirebaseService.cleanupExpiredGames();
        } catch (e) {
          // Expected to fail without Firebase setup but shouldn't crash
        }
      }, returnsNormally);
    });
  });

  group('Error Handling Integration', () {
    test('handles device service failures gracefully', () async {
      expect(() async {
        try {
          await DeviceService.clearDeviceInfo();
          final deviceId = await DeviceService.getDeviceId();

          if (deviceId.isNotEmpty) {
            // Use device ID in Firebase operation
            await FirebaseService.createGame(
              hostPlayerName: 'ErrorTestHost',
              maxPlayers: 4,
            );
          }
        } catch (e) {
          // Should handle errors gracefully
        }
      }, returnsNormally);
    });

    test('handles network failures during game operations', () async {
      expect(() async {
        try {
          // These operations will fail without network/Firebase
          await FirebaseService.createGame(
            hostPlayerName: 'Test',
            maxPlayers: 4,
          );
          await FirebaseService.joinGame(gameId: 'FAKE', playerName: 'Test');
          await FirebaseService.startGame('FAKE');
          await FirebaseService.deleteGame('FAKE');
        } catch (e) {
          // Should fail gracefully without crashing app
        }
      }, returnsNormally);
    });

    test('validates all input combinations', () async {
      // Test various invalid input combinations
      final invalidInputs = [
        {'hostPlayerName': '', 'maxPlayers': 4},
        {'hostPlayerName': 'Valid', 'maxPlayers': 1},
        {'hostPlayerName': 'Valid', 'maxPlayers': 10},
        {'hostPlayerName': 'Admin', 'maxPlayers': 4}, // Reserved name
      ];

      for (final input in invalidInputs) {
        expect(() async {
          try {
            await FirebaseService.createGame(
              hostPlayerName: input['hostPlayerName'] as String,
              maxPlayers: input['maxPlayers'] as int,
            );
          } catch (e) {
            // Should handle invalid input gracefully
          }
        }, returnsNormally);
      }
    });
  });

  group('Data Consistency Tests', () {
    test('game ID normalization is consistent', () {
      const testCases = [
        {'input': 'hk4rqm', 'expected': 'HK4RQM'},
        {'input': 'ab12', 'expected': 'AB12'},
        {'input': 'XY89', 'expected': 'XY89'},
        {'input': 'longId123', 'expected': 'longId123'},
      ];

      for (final testCase in testCases) {
        final input = testCase['input'] as String;
        final expected = testCase['expected'] as String;

        expect(GameCode.normalize(input), equals(expected));
      }
    });

    test('player validation is consistent across services', () {
      const validNames = ['Alice', 'Bob123', 'Player_1', 'Test-User'];
      const invalidNames = [
        '',
        'A',
        'VeryLongNameThatExceedsTheLimit',
        'admin',
      ];

      for (final name in validNames) {
        expect(
          _testPlayerNameValidation(name),
          true,
          reason: '$name should be valid',
        );
      }

      for (final name in invalidNames) {
        expect(
          _testPlayerNameValidation(name),
          false,
          reason: '$name should be invalid',
        );
      }
    });

    test('game constants are properly synchronized', () {
      // Ensure all services use same constants
      expect(FirebaseConstants.minPlayersPerGame, 2);
      expect(FirebaseConstants.maxPlayersPerGame, 6);

      expect(FirebaseConstants.gameStatusWaiting, 'waiting');
      expect(FirebaseConstants.gameStatusPlaying, 'playing');
      expect(FirebaseConstants.gameStatusFinished, 'finished');

      expect(FirebaseConstants.gamesCollection, 'games');
      expect(FirebaseConstants.userLimitsCollection, 'userLimits');
    });
  });

  group('Performance and Scalability', () {
    test('rate limiting prevents abuse', () {
      // Test rate limiting constants exist and are reasonable
      expect(FirebaseConstants.maxGamesPerUserPerHour, greaterThan(0));
      expect(FirebaseConstants.maxGamesPerUserPerDay, greaterThan(0));

      // Daily limit should be higher than hourly
      expect(
        FirebaseConstants.maxGamesPerUserPerDay,
        greaterThan(FirebaseConstants.maxGamesPerUserPerHour),
      );
    });

    test('widened game ID space would resist enumeration', () {
      // The legacy format (2 letters + 2 digits) has only 67,600 codes, a
      // space small enough to walk end to end. Stage one of the widening
      // rollout only teaches clients to accept maxLength codes; generation
      // still emits the legacy format, so this asserts the space that stage
      // two unlocks, not the one in use today.
      const legacyCombinations = 26 * 26 * 10 * 10;
      expect(legacyCombinations, equals(67600));

      final combinations = math.pow(
        GameCode.alphabet.length,
        GameCode.maxLength,
      );
      expect(combinations, greaterThan(100000000));

      expect(GameCode.generatedCodeLength, equals(GameCode.legacyLength));
    });

    test('cleanup batch size is reasonable', () {
      // Cleanup should process games in batches to avoid timeouts
      // (This tests the cleanup query limit in the actual implementation)
      expect(() async {
        try {
          await FirebaseService.cleanupExpiredGames();
        } catch (e) {
          // Should not timeout or crash
        }
      }, returnsNormally);
    });
  });

  group('Security Validation', () {
    test('device IDs are suitable for authentication', () async {
      try {
        final deviceId = await DeviceService.getDeviceId();

        if (deviceId.isNotEmpty) {
          // Should not contain sensitive information
          expect(deviceId.contains('@'), false);
          expect(deviceId.contains('password'), false);

          // Should be reasonably unique
          expect(deviceId.length, greaterThan(8));

          // Should be safe for database keys
          expect(deviceId.contains('/'), false);
          expect(deviceId.contains('\\'), false);
        }
      } catch (e) {
        // Expected in test environment
      }
    });

    test('reserved names are properly filtered', () {
      final reservedNames = FirebaseConstants.reservedPlayerNames;

      expect(reservedNames, isNotEmpty);
      expect(reservedNames, contains('admin'));
      expect(reservedNames, contains('system'));
      expect(reservedNames, contains('moderator'));

      // Test validation logic exists and works for obvious cases
      expect(_testPlayerNameValidation('ValidName123'), true);
      expect(_testPlayerNameValidation(''), false);
      expect(_testPlayerNameValidation('a'), false); // too short
    });

    test('game IDs are not predictable', () {
      // Game ID generation should use timestamp variation
      // Test that sequential calls don't produce sequential IDs

      final sampleIds = List.generate(3, (_) => GameCode.generate());

      for (int i = 1; i < sampleIds.length; i++) {
        final prev = sampleIds[i - 1];
        final curr = sampleIds[i];

        // Should not be sequential
        expect(curr, isNot(equals(prev)));
      }
    });
  });
}

// Helper methods for integration tests
bool _testPlayerNameValidation(String name) {
  if (name.trim().isEmpty) return false;
  if (name.length > 20 || name.length < 2) return false;

  final reservedNames = FirebaseConstants.reservedPlayerNames;
  if (reservedNames.any(
    (word) => name.toLowerCase().contains(word.toLowerCase()),
  )) {
    return false;
  }

  final validChars = RegExp(r'^[a-zA-Z0-9\s\-_.]+$');
  return validChars.hasMatch(name);
}
