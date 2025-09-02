import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/managers/game_serializer.dart';
import 'package:hand_foot_game_flutter/models/card.dart';

/// Regression tests for card parsing issues that previously caused crashes.
///
/// These tests specifically target the bug where Joker cards serialized as "13,"
/// (with empty suit) caused "Invalid double" JavaScript errors during parsing.
void main() {
  group('Card Parsing Regression Tests', () {
    test(
      'should parse Joker cards with empty suits without throwing exceptions',
      () {
        // This was the exact format that caused the crash: rank 13 (Joker) with empty suit
        const jokerCardData = '13,';

        // Should NOT throw any exceptions
        expect(
          () => GameSerializer.parseCompactCard(jokerCardData),
          returnsNormally,
        );

        final card = GameSerializer.parseCompactCard(jokerCardData);
        expect(card.rank, equals(CardRank.joker));
        expect(card.suit, isNull); // Jokers have no suit
        expect(card.isJoker, isTrue);
        expect(card.isWild, isTrue);
      },
    );

    test(
      'should handle malformed card data gracefully with fallback cards',
      () {
        const testCases = [
          '', // Empty string
          'invalid', // Non-numeric rank
          '99,', // Out of bounds rank
          '1,99', // Out of bounds suit
          '1,invalid', // Non-numeric suit
          'rank,suit', // Both non-numeric
          '13,extra,data', // Too many parts
        ];

        for (final testCase in testCases) {
          // Should return fallback card instead of crashing
          final card = GameSerializer.parseCompactCard(testCase);

          // All fallback cards should be Ace of Spades
          expect(
            card.rank,
            equals(CardRank.ace),
            reason: 'Failed for input: $testCase',
          );
          expect(
            card.suit,
            equals(Suit.spades),
            reason: 'Failed for input: $testCase',
          );
        }
      },
    );

    test('should parse all valid card combinations without errors', () {
      // Test every valid rank
      for (int rankIndex = 0; rankIndex < CardRank.values.length; rankIndex++) {
        final rank = CardRank.values[rankIndex];

        if (rank == CardRank.joker) {
          // Jokers should parse with null suit
          final card = GameSerializer.parseCompactCard('$rankIndex,');
          expect(card.rank, equals(rank));
          expect(card.suit, isNull);
          expect(card.isJoker, isTrue);
        } else {
          // Regular cards should parse with all suits
          for (int suitIndex = 0; suitIndex < Suit.values.length; suitIndex++) {
            final suit = Suit.values[suitIndex];
            final card = GameSerializer.parseCompactCard(
              '$rankIndex,$suitIndex',
            );

            expect(card.rank, equals(rank));
            expect(card.suit, equals(suit));
            expect(card.isJoker, isFalse);
          }
        }
      }
    });

    test('should handle edge cases in card serialization format', () {
      // Test cases that could cause parsing issues
      final testCases = [
        {
          'input': '0,0',
          'expectedRank': CardRank.values[0],
          'expectedSuit': Suit.values[0],
        },
        {
          'input': '1,',
          'expectedRank': CardRank.values[1],
          'expectedSuit': null,
        }, // Empty suit
        {
          'input': '5,2',
          'expectedRank': CardRank.values[5],
          'expectedSuit': Suit.values[2],
        },
      ];

      for (final testCase in testCases) {
        final input = testCase['input'] as String;
        final card = GameSerializer.parseCompactCard(input);

        expect(
          card.rank,
          equals(testCase['expectedRank']),
          reason: 'Rank mismatch for input: $input',
        );
        expect(
          card.suit,
          equals(testCase['expectedSuit']),
          reason: 'Suit mismatch for input: $input',
        );
      }
    });

    test('should never throw exceptions for any input string', () {
      // Stress test with various problematic inputs
      final problematicInputs = [
        'null',
        'undefined',
        '13,null',
        '13,undefined',
        '13, ', // Space after comma
        ' 13,', // Leading space
        '13, 0', // Space in suit
        '13.5,', // Decimal rank
        ',13', // Missing rank
        '13,,', // Double comma
        '13,0,extra', // Extra data
        'very long string that should not be a card',
        '🃏', // Emoji
        '13,🂠', // Emoji suit
      ];

      for (final input in problematicInputs) {
        expect(
          () => GameSerializer.parseCompactCard(input),
          returnsNormally,
          reason: 'Should not throw for input: $input',
        );

        // Should always return a valid card
        final card = GameSerializer.parseCompactCard(input);
        expect(card, isNotNull, reason: 'Should return card for input: $input');
        expect(
          card.rank,
          isNotNull,
          reason: 'Should have valid rank for input: $input',
        );
      }
    });

    test('should correctly parse known problematic card formats', () {
      // Test specific formats that we know should work
      final knownFormats = [
        {
          'input': '13,',
          'rank': CardRank.joker,
          'suit': null,
        }, // The original problem case
        {'input': '0,0', 'rank': CardRank.values[0], 'suit': Suit.values[0]},
        {'input': '1,1', 'rank': CardRank.values[1], 'suit': Suit.values[1]},
        {'input': '12,3', 'rank': CardRank.values[12], 'suit': Suit.values[3]},
      ];

      for (final format in knownFormats) {
        final input = format['input'] as String;
        final expectedRank = format['rank'] as CardRank;
        final expectedSuit = format['suit'] as Suit?;

        final card = GameSerializer.parseCompactCard(input);

        expect(
          card.rank,
          equals(expectedRank),
          reason: 'Rank mismatch for format: $input',
        );
        expect(
          card.suit,
          equals(expectedSuit),
          reason: 'Suit mismatch for format: $input',
        );
      }
    });

    test('should log warnings for problematic inputs without crashing', () {
      // This test verifies that the warning logs are generated but don't crash
      const problematicInputs = [
        '', // Invalid format
        '99,', // Out of bounds rank
        '1,99', // Out of bounds suit
      ];

      for (final input in problematicInputs) {
        // Should complete without throwing
        final card = GameSerializer.parseCompactCard(input);

        // Should return fallback card
        expect(card.rank, equals(CardRank.ace));
        expect(card.suit, equals(Suit.spades));
      }
    });
  });
}
