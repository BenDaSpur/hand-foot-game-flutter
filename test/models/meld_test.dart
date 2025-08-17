import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';

void main() {
  group('Meld', () {
    test('should create natural meld with 3+ cards of same rank', () {
      final cards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ];
      
      final meld = Meld.createMeld(cards);
      
      expect(meld, isNotNull);
      expect(meld!.rank, equals(CardRank.ace));
      expect(meld.type, equals(MeldType.natural));
      expect(meld.cards.length, equals(3));
    });

    test('should create mixed meld with natural and wild cards', () {
      final cards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.two), // wild
      ];
      
      final meld = Meld.createMeld(cards);
      
      expect(meld, isNotNull);
      expect(meld!.rank, equals(CardRank.king));
      expect(meld.type, equals(MeldType.mixed));
      expect(meld.cards.length, equals(3));
    });

    test('should create wild meld with all wild cards', () {
      final cards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        const PlayingCard(suit: Suit.spades, rank: CardRank.two),
        const PlayingCard(rank: CardRank.joker),
      ];
      
      final meld = Meld.createMeld(cards);
      
      expect(meld, isNotNull);
      expect(meld!.rank, equals(CardRank.joker));
      expect(meld.type, equals(MeldType.wild));
      expect(meld.cards.length, equals(3));
    });

    test('should reject meld with less than 3 cards', () {
      final cards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
      ];
      
      final meld = Meld.createMeld(cards);
      
      expect(meld, isNull);
    });

    test('should reject meld containing 3s', () {
      final cards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
        const PlayingCard(suit: Suit.spades, rank: CardRank.three),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.three),
      ];
      
      final meld = Meld.createMeld(cards);
      
      expect(meld, isNull);
    });

    test('should reject meld with different natural ranks', () {
      final cards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
      ];
      
      final meld = Meld.createMeld(cards);
      
      expect(meld, isNull);
    });

    test('should reject mixed meld with too many wilds', () {
      final cards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // wild
        const PlayingCard(suit: Suit.clubs, rank: CardRank.two), // wild
        const PlayingCard(rank: CardRank.joker), // wild
      ];
      
      final meld = Meld.createMeld(cards);
      
      expect(meld, isNull);
    });

    test('should correctly identify books', () {
      final shortMeld = Meld(
        rank: CardRank.ace,
        cards: List.generate(3, (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.ace)),
        type: MeldType.natural,
      );
      
      final bookMeld = Meld(
        rank: CardRank.ace,
        cards: List.generate(7, (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.ace)),
        type: MeldType.natural,
      );
      
      expect(shortMeld.isBook, isFalse);
      expect(bookMeld.isBook, isTrue);
    });

    test('should correctly identify clean and dirty books', () {
      final cleanBook = Meld(
        rank: CardRank.ace,
        cards: List.generate(7, (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.ace)),
        type: MeldType.natural,
      );
      
      final dirtyBook = Meld(
        rank: CardRank.ace,
        cards: [
          ...List.generate(5, (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.ace)),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two), // wild
          const PlayingCard(rank: CardRank.joker), // wild
        ],
        type: MeldType.mixed,
      );
      
      expect(cleanBook.isClean, isTrue);
      expect(cleanBook.isDirty, isFalse);
      
      expect(dirtyBook.isClean, isFalse);
      expect(dirtyBook.isDirty, isTrue);
    });

    test('should calculate point values correctly', () {
      // Natural meld
      final naturalMeld = Meld(
        rank: CardRank.ace,
        cards: List.generate(3, (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.ace)),
        type: MeldType.natural,
      );
      expect(naturalMeld.pointValue, equals(60)); // 3 x 20 points
      
      // Natural book (7+ cards)
      final naturalBook = Meld(
        rank: CardRank.ace,
        cards: List.generate(7, (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.ace)),
        type: MeldType.natural,
      );
      expect(naturalBook.pointValue, equals(140 + 500)); // (7 x 20) + 500 bonus
      
      // Mixed book
      final mixedBook = Meld(
        rank: CardRank.ace,
        cards: [
          ...List.generate(5, (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.ace)),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two), // wild
          const PlayingCard(rank: CardRank.joker), // wild
        ],
        type: MeldType.mixed,
      );
      expect(mixedBook.pointValue, equals(100 + 20 + 50 + 300)); // (5x20) + 20 + 50 + 300 bonus
      
      // Wild book
      final wildBook = Meld(
        rank: CardRank.joker,
        cards: [
          ...List.generate(5, (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.two)),
          const PlayingCard(rank: CardRank.joker),
          const PlayingCard(rank: CardRank.joker),
        ],
        type: MeldType.wild,
      );
      expect(wildBook.pointValue, equals(100 + 100 + 1000)); // (5x20) + (2x50) + 1000 bonus
    });

    test('should add cards to meld correctly', () {
      final meld = Meld(
        rank: CardRank.ace,
        cards: [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        ],
        type: MeldType.natural,
      );
      
      // Can add matching natural card
      expect(meld.canAddCard(const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace)), isTrue);
      expect(meld.addCard(const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace)), isTrue);
      expect(meld.cards.length, equals(4));
      
      // Can add wild card
      expect(meld.canAddCard(const PlayingCard(suit: Suit.hearts, rank: CardRank.two)), isTrue);
      expect(meld.addCard(const PlayingCard(suit: Suit.hearts, rank: CardRank.two)), isTrue);
      expect(meld.cards.length, equals(5));
      
      // Cannot add different rank
      expect(meld.canAddCard(const PlayingCard(suit: Suit.hearts, rank: CardRank.king)), isFalse);
      expect(meld.addCard(const PlayingCard(suit: Suit.hearts, rank: CardRank.king)), isFalse);
      expect(meld.cards.length, equals(5));
      
      // Cannot add 3s
      expect(meld.canAddCard(const PlayingCard(suit: Suit.hearts, rank: CardRank.three)), isFalse);
      expect(meld.addCard(const PlayingCard(suit: Suit.hearts, rank: CardRank.three)), isFalse);
      expect(meld.cards.length, equals(5));
    });

    test('should prevent adding too many wilds to mixed meld', () {
      final meld = Meld(
        rank: CardRank.ace,
        cards: [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace), // natural
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace), // natural
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two), // wild
        ],
        type: MeldType.mixed,
      );
      
      // Can add one more wild (2 naturals, 1 wild + 1 more = 2 wilds max)
      expect(meld.canAddCard(const PlayingCard(rank: CardRank.joker)), isTrue);
      expect(meld.addCard(const PlayingCard(rank: CardRank.joker)), isTrue);
      
      // Cannot add another wild (would exceed naturals)
      expect(meld.canAddCard(const PlayingCard(suit: Suit.hearts, rank: CardRank.two)), isFalse);
    });

    test('should handle wild meld correctly', () {
      final meld = Meld(
        rank: CardRank.joker,
        cards: [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two),
          const PlayingCard(rank: CardRank.joker),
        ],
        type: MeldType.wild,
      );
      
      // Can add wild cards
      expect(meld.canAddCard(const PlayingCard(rank: CardRank.joker)), isTrue);
      expect(meld.canAddCard(const PlayingCard(suit: Suit.clubs, rank: CardRank.two)), isTrue);
      
      // Cannot add natural cards
      expect(meld.canAddCard(const PlayingCard(suit: Suit.hearts, rank: CardRank.ace)), isFalse);
      
      // Cannot add 3s
      expect(meld.canAddCard(const PlayingCard(suit: Suit.hearts, rank: CardRank.three)), isFalse);
    });
  });
}