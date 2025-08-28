import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';

void main() {
  group('PlayingCard', () {
    test('should create card with correct properties', () {
      const card = PlayingCard(suit: Suit.hearts, rank: CardRank.ace);

      expect(card.suit, equals(Suit.hearts));
      expect(card.rank, equals(CardRank.ace));
      expect(card.isRed, isTrue);
      expect(card.isBlack, isFalse);
    });

    test('should identify jokers correctly', () {
      const joker = PlayingCard(rank: CardRank.joker);

      expect(joker.isJoker, isTrue);
      expect(joker.isWild, isTrue);
      expect(joker.suit, isNull);
    });

    test('should identify wild cards correctly', () {
      const two = PlayingCard(suit: Suit.spades, rank: CardRank.two);
      const joker = PlayingCard(rank: CardRank.joker);
      const ace = PlayingCard(suit: Suit.hearts, rank: CardRank.ace);

      expect(two.isWild, isTrue);
      expect(joker.isWild, isTrue);
      expect(ace.isWild, isFalse);
    });

    test('should identify threes correctly', () {
      const redThree = PlayingCard(suit: Suit.hearts, rank: CardRank.three);
      const blackThree = PlayingCard(suit: Suit.spades, rank: CardRank.three);
      const four = PlayingCard(suit: Suit.clubs, rank: CardRank.four);

      expect(redThree.isThree, isTrue);
      expect(redThree.isRedThree, isTrue);
      expect(redThree.isBlackThree, isFalse);

      expect(blackThree.isThree, isTrue);
      expect(blackThree.isBlackThree, isTrue);
      expect(blackThree.isRedThree, isFalse);

      expect(four.isThree, isFalse);
      expect(four.isRedThree, isFalse);
      expect(four.isBlackThree, isFalse);
    });

    test('should calculate point values correctly', () {
      // High value cards
      expect(const PlayingCard(rank: CardRank.joker).pointValue, equals(50));
      expect(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two).pointValue,
        equals(20),
      );
      expect(
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace).pointValue,
        equals(20),
      );

      // Medium value cards
      expect(
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king).pointValue,
        equals(10),
      );
      expect(
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen).pointValue,
        equals(10),
      );
      expect(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.jack).pointValue,
        equals(10),
      );
      expect(
        const PlayingCard(suit: Suit.spades, rank: CardRank.ten).pointValue,
        equals(10),
      );
      expect(
        const PlayingCard(suit: Suit.clubs, rank: CardRank.nine).pointValue,
        equals(10),
      );

      // Low value cards
      expect(
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.eight).pointValue,
        equals(5),
      );
      expect(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.seven).pointValue,
        equals(5),
      );
      expect(
        const PlayingCard(suit: Suit.spades, rank: CardRank.six).pointValue,
        equals(5),
      );
      expect(
        const PlayingCard(suit: Suit.clubs, rank: CardRank.five).pointValue,
        equals(5),
      );
      expect(
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four).pointValue,
        equals(5),
      );

      // Threes (penalty)
      expect(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.three).pointValue,
        equals(-300),
      ); // Red 3
      expect(
        const PlayingCard(suit: Suit.spades, rank: CardRank.three).pointValue,
        equals(-5),
      ); // Black 3
    });

    test('should calculate meld values correctly', () {
      expect(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace).meldValue,
        equals(14),
      );
      expect(
        const PlayingCard(suit: Suit.spades, rank: CardRank.king).meldValue,
        equals(13),
      );
      expect(
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen).meldValue,
        equals(12),
      );
      expect(
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack).meldValue,
        equals(11),
      );
      expect(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ten).meldValue,
        equals(10),
      );
      expect(
        const PlayingCard(suit: Suit.spades, rank: CardRank.nine).meldValue,
        equals(9),
      );
      expect(
        const PlayingCard(suit: Suit.clubs, rank: CardRank.eight).meldValue,
        equals(8),
      );
      expect(
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven).meldValue,
        equals(7),
      );
      expect(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.six).meldValue,
        equals(6),
      );
      expect(
        const PlayingCard(suit: Suit.spades, rank: CardRank.five).meldValue,
        equals(5),
      );
      expect(
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four).meldValue,
        equals(4),
      );
      expect(
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.three).meldValue,
        equals(3),
      );
      expect(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two).meldValue,
        equals(2),
      );
      expect(const PlayingCard(rank: CardRank.joker).meldValue, equals(0));
    });

    test('should generate correct display names', () {
      expect(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace).displayName,
        equals('Ace♥'),
      );
      expect(
        const PlayingCard(suit: Suit.spades, rank: CardRank.king).displayName,
        equals('King♠'),
      );
      expect(
        const PlayingCard(rank: CardRank.joker).displayName,
        equals('Joker'),
      );
    });

    test('should generate compact names for action logs', () {
      expect(
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four).compactName,
        equals('4 ♦'),
      );
      expect(
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ten).compactName,
        equals('10 ♣'),
      );
      expect(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace).compactName,
        equals('A ♥'),
      );
      expect(
        const PlayingCard(suit: Suit.spades, rank: CardRank.king).compactName,
        equals('K ♠'),
      );
      expect(const PlayingCard(rank: CardRank.joker).compactName, equals('JK'));
    });

    test('should handle equality correctly', () {
      const card1 = PlayingCard(suit: Suit.hearts, rank: CardRank.ace);
      const card2 = PlayingCard(suit: Suit.hearts, rank: CardRank.ace);
      const card3 = PlayingCard(suit: Suit.spades, rank: CardRank.ace);

      expect(card1, equals(card2));
      expect(card1, isNot(equals(card3)));
    });

    test('should identify red and black cards correctly', () {
      const heartCard = PlayingCard(suit: Suit.hearts, rank: CardRank.five);
      const diamondCard = PlayingCard(
        suit: Suit.diamonds,
        rank: CardRank.seven,
      );
      const clubCard = PlayingCard(suit: Suit.clubs, rank: CardRank.nine);
      const spadeCard = PlayingCard(suit: Suit.spades, rank: CardRank.jack);

      expect(heartCard.isRed, isTrue);
      expect(heartCard.isBlack, isFalse);

      expect(diamondCard.isRed, isTrue);
      expect(diamondCard.isBlack, isFalse);

      expect(clubCard.isBlack, isTrue);
      expect(clubCard.isRed, isFalse);

      expect(spadeCard.isBlack, isTrue);
      expect(spadeCard.isRed, isFalse);
    });
  });
}
