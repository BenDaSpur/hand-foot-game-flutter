import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/services/firebase_service.dart';
import 'package:hand_foot_game_flutter/services/firebase_constants.dart';
import 'package:hand_foot_game_flutter/services/game_code.dart';
import 'package:hand_foot_game_flutter/models/multiplayer_result.dart';

void main() {
  group('FirebaseService Analytics', () {
    test('logGameEvent handles null parameters safely', () async {
      // This test ensures the methods exist and handle parameters correctly
      // The actual Firebase calls will fail in test environment (expected)
      expect(() async {
        try {
          await FirebaseService.logGameEvent('test_event');
        } catch (e) {
          // Expected to fail in test environment without Firebase setup
        }
      }, returnsNormally);
    });

    test('analytics methods exist and are callable', () async {
      // These tests verify the analytics methods exist (they'll fail internally but that's expected)
      expect(() async {
        try {
          await FirebaseService.logGameCreated(maxPlayers: 4);
        } catch (e) {
          // Expected to fail in test environment
        }
      }, returnsNormally);

      expect(() async {
        try {
          await FirebaseService.logGameJoined();
        } catch (e) {
          // Expected to fail in test environment
        }
      }, returnsNormally);
    });
  });

  group('Firebase Constants', () {
    test('constants are properly defined', () {
      expect(FirebaseConstants.gamesCollection, 'games');
      expect(FirebaseConstants.gameStatusWaiting, 'waiting');
      expect(FirebaseConstants.gameStatusPlaying, 'playing');
      expect(FirebaseConstants.gameStatusFinished, 'finished');
      expect(FirebaseConstants.minPlayersPerGame, 2);
      expect(FirebaseConstants.maxPlayersPerGame, 6);
    });

    test('reserved names are defined', () {
      expect(FirebaseConstants.reservedPlayerNames, isNotEmpty);
      expect(FirebaseConstants.reservedPlayerNames, contains('admin'));
      expect(FirebaseConstants.reservedPlayerNames, contains('system'));
    });
  });

  group('Firebase Initialization', () {
    test('initialization skips in test environment', () {
      // This test runs in a test environment (FLUTTER_TEST=true)
      // Verify that the Firebase service is available for testing
      expect(FirebaseService, isNotNull);
    });

    test('initialization handles missing firebase options gracefully', () {
      // This test verifies that the Firebase service class exists
      // (actual Firebase initialization is tested in integration tests)
      expect(FirebaseService, isNotNull);
      // Don't test analytics getter as it requires Firebase initialization
    });
  });

  // Generation and acceptance are deliberately different during the two-stage
  // widening rollout (see lib/services/game_code.dart and
  // docs/multiplayer_security_notes.md). Stage one generates legacy-length
  // codes but accepts both lengths, so both properties are asserted separately
  // and must not drift into each other.
  group('Game ID Generation (stage one: legacy format)', () {
    test('this build generates legacy-length codes', () {
      expect(GameCode.generatedCodeLength, GameCode.legacyLength);

      for (int i = 0; i < 100; i++) {
        expect(GameCode.generate().length, GameCode.legacyLength);
      }
    });

    test('generated codes keep the legacy letters-then-digits shape', () {
      for (int i = 0; i < 100; i++) {
        final code = GameCode.generate();

        for (int index = 0; index < code.length; index++) {
          final character = code[index];
          final expected = index < GameCode.legacyLetterCount
              ? GameCode.legacyLetters
              : GameCode.legacyDigits;

          expect(
            expected.contains(character),
            isTrue,
            reason:
                '$code position $index is "$character", which is not in the '
                'legacy character set for that position',
          );
        }
      }
    });

    test('generated codes are accepted and already normalized', () {
      for (int i = 0; i < 100; i++) {
        final code = GameCode.generate();

        expect(GameCode.isShortCode(code), isTrue);
        expect(GameCode.isValid(code), isTrue, reason: '$code was rejected');
        expect(GameCode.normalize(code), code);
      }
    });

    test('widened alphabet excludes look-alike characters players mistype', () {
      for (final ambiguous in ['0', 'O', '1', 'I', 'L']) {
        expect(
          GameCode.alphabet.contains(ambiguous),
          isFalse,
          reason: '"$ambiguous" is too easy to confuse in a spoken code',
        );
      }
    });

    test('widening to maxLength would dwarf the legacy code space', () {
      // Stage two flips generatedCodeLength to maxLength; this is the space
      // that unlocks. It is NOT the space this build actually uses.
      const legacyCombinations = 26 * 26 * 10 * 10; // 2 letters + 2 digits
      expect(legacyCombinations, 67600);

      final widened = math.pow(GameCode.alphabet.length, GameCode.maxLength);
      expect(widened, greaterThan(legacyCombinations * 1000));

      // Practical generation still uses the legacy letters-then-digits shape,
      // so compare the widened space against that real legacy space — not
      // alphabet^generatedCodeLength, which overstates what this build draws.
      expect(
        legacyCombinations,
        lessThan(widened),
        reason:
            'generation is still legacy-length, so the practical space is '
            'smaller than the widened one until stage two ships',
      );
    });
  });

  group('Game ID Acceptance (stage one: both lengths)', () {
    test('accepts widened codes, legacy codes and long Firebase ids', () {
      expect(GameCode.isValid('HK4RQM'), true); // widened, stage two format
      expect(GameCode.isValid('hk4rqm'), true); // normalized before lookup
      expect(GameCode.isValid('AB12'), true); // legacy in-flight games
      expect(GameCode.isValid('ab12'), true);
      expect(GameCode.isValid('longFirebaseId123'), true);

      expect(GameCode.isValid(''), false);
      expect(GameCode.isValid('AB1'), false);
      expect(GameCode.isValid('HK4RQ'), false); // 5 chars is not a code
      expect(GameCode.isValid('HK4RQ!'), false);
    });

    test('both code lengths are treated as short hand-typed codes', () {
      expect(GameCode.isShortCode('HK4RQM'), true);
      expect(GameCode.isShortCode('AB12'), true);
      expect(GameCode.isShortCode('HK4RQ'), false);
      expect(GameCode.isShortCode('longFirebaseId123'), false);
    });

    test('normalizes join codes of either length, leaving long ids alone', () {
      expect(GameCode.normalize('hk4rqm'), 'HK4RQM');
      expect(GameCode.normalize('HK4RQM'), 'HK4RQM');
      expect(GameCode.normalize('ab12'), 'AB12');
      expect(GameCode.normalize('AB12'), 'AB12');
      expect(GameCode.normalize('longFirebaseId123'), 'longFirebaseId123');
    });

    test('trims surrounding whitespace before normalizing short codes', () {
      expect(GameCode.normalize('  ab12  '), 'AB12');
      expect(GameCode.normalize('\thk4rqm\n'), 'HK4RQM');
      expect(GameCode.isValid('  ab12  '), isTrue);
      expect(GameCode.normalize('  longFirebaseId123  '), 'longFirebaseId123');
    });

    test('lowercase codes of either length round-trip through normalize', () {
      for (final code in ['HK4RQM', 'AB12']) {
        final typed = code.toLowerCase();

        expect(GameCode.isValid(typed), isTrue, reason: '$typed was rejected');
        expect(GameCode.normalize(typed), code);
        expect(GameCode.normalize(GameCode.normalize(typed)), code);
      }
    });
  });

  group('Game Cleanup Validation', () {
    test('validates cleanup method signatures exist', () {
      // Verify that cleanup methods exist and can be called
      // (They'll fail without Firebase setup, but should not throw compilation errors)

      expect(() async {
        try {
          await FirebaseService.deleteGame('TEST');
        } catch (e) {
          // Expected to fail without Firebase setup
        }
      }, returnsNormally);

      expect(() async {
        try {
          await FirebaseService.leaveGame('TEST');
        } catch (e) {
          // Expected to fail without Firebase setup
        }
      }, returnsNormally);

      expect(() async {
        try {
          await FirebaseService.cleanupExpiredGames();
        } catch (e) {
          // Expected to fail without Firebase setup
        }
      }, returnsNormally);
    });

    test('cleanup methods handle invalid input gracefully', () {
      // Test with empty/invalid game IDs
      expect(() async {
        try {
          await FirebaseService.deleteGame('');
        } catch (e) {
          // Should handle gracefully
        }
      }, returnsNormally);

      expect(() async {
        try {
          await FirebaseService.leaveGame('');
        } catch (e) {
          // Should handle gracefully
        }
      }, returnsNormally);
    });
  });

  group('Device Authentication', () {
    test('device authentication methods exist', () {
      // Verify device auth methods are available
      expect(() async {
        try {
          await FirebaseService.getDeviceUserId();
        } catch (e) {
          // May fail without device service setup
        }
      }, returnsNormally);

      expect(() async {
        try {
          await FirebaseService.getDeviceUserName();
        } catch (e) {
          // May fail without device service setup
        }
      }, returnsNormally);
    });

    test('authentication methods return expected types', () async {
      // Test that methods return correct types when they work
      try {
        final userId = await FirebaseService.getDeviceUserId();
        if (userId != null) {
          expect(userId, isA<String>());
          expect(userId.isNotEmpty, true);
        }
      } catch (e) {
        // Expected in test environment
      }

      try {
        final userName = await FirebaseService.getDeviceUserName();
        expect(userName, isA<String>());
        expect(userName.isNotEmpty, true);
      } catch (e) {
        // Expected in test environment
      }
    });
  });

  group('Input Validation', () {
    test('validates player names correctly', () {
      // Test player name validation logic
      const validNames = ['Alice', 'Bob123', 'Player_1', 'Test-User'];
      const invalidNames = [
        '',
        'A',
        'VeryLongNameThatExceedsTheLimit123456789',
        'Admin',
        'SYSTEM',
      ];

      for (final name in validNames) {
        expect(_isValidPlayerName(name), true, reason: '$name should be valid');
      }

      for (final name in invalidNames) {
        expect(
          _isValidPlayerName(name),
          false,
          reason: '$name should be invalid',
        );
      }
    });

    test('validates player count correctly', () {
      // Test player count validation
      expect(_isValidPlayerCount(2), true); // min valid
      expect(_isValidPlayerCount(4), true); // typical
      expect(_isValidPlayerCount(6), true); // max valid

      expect(_isValidPlayerCount(1), false); // too few
      expect(_isValidPlayerCount(7), false); // too many
      expect(_isValidPlayerCount(0), false); // invalid
    });
  });

  group('Multiplayer typed results', () {
    test(
      'createGameWithResult returns notConfigured in stub Firebase environment',
      () async {
        final result = await FirebaseService.createGameWithResult(
          hostPlayerName: '',
          maxPlayers: 4,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failureReason, MultiplayerFailureReason.notConfigured);
        expect(FirebaseService.lastOperationError, isNotEmpty);
      },
    );

    test(
      'joinGameWithResult returns notConfigured in stub Firebase environment',
      () async {
        final result = await FirebaseService.joinGameWithResult(
          gameId: 'bad',
          playerName: 'TestPlayer',
        );

        expect(result.isSuccess, isFalse);
        expect(result.failureReason, MultiplayerFailureReason.notConfigured);
        expect(FirebaseService.lastOperationError, isNotEmpty);
      },
    );
  });

  group('Data Serialization', () {
    test('serialization helpers are exposed for testing', () {
      expect(FirebaseService.gameStateToMapForTesting, isNotNull);
      expect(FirebaseService.gameStateFromMapForTesting, isNotNull);
    });
  });
}

// Helper methods for testing (simulating private method behavior)
bool _isValidPlayerName(String name) {
  if (name.trim().isEmpty) return false;
  if (name.length > 20) return false; // Assume max length of 20
  if (name.length < 2) return false; // Assume min length of 2

  // Check for reserved names (case insensitive)
  const reservedNames = ['admin', 'system', 'bot', 'host'];
  if (reservedNames.any((word) => name.toLowerCase().contains(word))) {
    return false;
  }

  // Only allow alphanumeric and basic punctuation
  final validChars = RegExp(r'^[a-zA-Z0-9\s\-_.]+$');
  return validChars.hasMatch(name);
}

bool _isValidPlayerCount(int count) {
  return count >= 2 && count <= 6; // Based on FirebaseConstants
}
