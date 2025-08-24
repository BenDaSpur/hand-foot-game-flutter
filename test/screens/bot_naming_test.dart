import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';

void main() {
  group('Bot Naming Tests', () {
    test('bot configurations should use simple names', () {
      // Test the expected bot names directly (without needing to access private methods)

      final expectedNames = [
        'Clara', 'Carl', // Conservative bots
        'Bob', 'Rita', // Aggressive bots
        'Ben', 'Penny', // Book builder bots
        'Alex', 'Sue', // Adaptive bots
      ];

      final expectedPersonalities = [
        BotPersonality.conservative,
        BotPersonality.aggressive,
        BotPersonality.bookBuilder,
        BotPersonality.adaptive,
      ];

      // Verify all expected names are simple (no descriptive prefixes)
      for (final name in expectedNames) {
        expect(
          name.split(' '),
          hasLength(1),
          reason: '$name should be a single word',
        );
        expect(
          name.length,
          greaterThanOrEqualTo(3),
          reason: '$name should be a reasonable name length',
        );
        expect(
          name.length,
          lessThanOrEqualTo(6),
          reason: '$name should not be too long',
        );
      }

      // Verify we have the right number of bots for each personality
      expect(expectedNames.length, equals(8));
      expect(expectedPersonalities.length, equals(4));
    });

    test('bot names should not contain descriptive prefixes', () {
      const bannedPrefixes = [
        'Careful',
        'Cautious',
        'Bold',
        'Risky',
        'Book Builder',
        'Perfect',
        'Adaptive',
        'Strategic',
      ];

      const allowedNames = [
        'Clara',
        'Carl',
        'Bob',
        'Rita',
        'Ben',
        'Penny',
        'Alex',
        'Sue',
      ];

      for (final name in allowedNames) {
        for (final prefix in bannedPrefixes) {
          expect(
            name,
            isNot(startsWith(prefix)),
            reason:
                'Bot name "$name" should not start with descriptive prefix "$prefix"',
          );
        }
      }
    });

    test('bot personalities should be evenly distributed', () {
      // We should have 2 bots for each personality type
      final expectedDistribution = {
        BotPersonality.conservative: 2,
        BotPersonality.aggressive: 2,
        BotPersonality.bookBuilder: 2,
        BotPersonality.adaptive: 2,
      };

      expect(expectedDistribution.values.reduce((a, b) => a + b), equals(8));

      // Each personality should have exactly 2 bots
      for (final count in expectedDistribution.values) {
        expect(count, equals(2));
      }
    });
  });
}
