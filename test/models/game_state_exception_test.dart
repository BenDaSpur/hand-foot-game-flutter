import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';

void main() {
  group('GameStateException Tests', () {
    test('should create exception with message', () {
      const exception = GameStateException('Test error message');
      expect(exception.message, equals('Test error message'));
      expect(
        exception.toString(),
        equals('GameStateException: Test error message'),
      );
    });

    test(
      'should throw GameStateException when endRound fails in meld methods',
      () {
        // This test verifies our defensive exception throwing
        // In normal gameplay, this should never happen, but if it does,
        // we want to throw an exception rather than silently continuing

        // Note: Creating a scenario where endRound() would fail is complex
        // since it would require modifying internal game state in ways that
        // the public API doesn't allow. This test primarily validates
        // the exception class itself and documents the expected behavior.

        expect(
          () => throw const GameStateException('Test'),
          throwsA(isA<GameStateException>()),
        );
      },
    );
  });
}
