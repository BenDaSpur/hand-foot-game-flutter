import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Player', () {
    late Player player;

    setUp(() {
      player = Player(id: '1', name: 'Test Player', type: PlayerType.human);
    });

    test('should create player with correct initial state', () {
      expect(player.id, equals('1'));
      expect(player.name, equals('Test Player'));
      expect(player.type, equals(PlayerType.human));
      expect(player.hand, isEmpty);
      expect(player.foot, isEmpty);
      expect(player.melds, isEmpty);
      expect(player.hasPickedUpFoot, isFalse);
      expect(player.hasPlayedDown, isFalse);
      expect(player.score, equals(0));
    });

    test('should deal cards to hand and foot', () {
      final handCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      ];
      final footCards = [
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
      ];

      player.dealHand(handCards);
      player.dealFoot(footCards);

      expect(player.hand, equals(handCards));
      expect(player.foot, equals(footCards));
      expect(
        player.currentHand,
        equals(handCards),
      ); // Should use hand initially
    });

    test('should switch to foot when picking up foot', () {
      final handCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
      ];
      final footCards = [
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
      ];

      player.dealHand(handCards);
      player.dealFoot(footCards);

      // Initially uses hand
      expect(player.currentHand, equals(handCards));
      expect(player.hasPickedUpFoot, isFalse);

      // Clear hand and pick up foot
      player.hand.clear();
      player.pickUpFoot();

      expect(player.hasPickedUpFoot, isTrue);
      expect(player.currentHand, equals(footCards));
    });

    test('should not pick up foot if hand is not empty', () {
      final handCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
      ];
      final footCards = [
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
      ];

      player.dealHand(handCards);
      player.dealFoot(footCards);

      player.pickUpFoot(); // Should not work

      expect(player.hasPickedUpFoot, isFalse);
      expect(player.currentHand, equals(handCards));
    });

    test('should add and remove cards from current hand', () {
      final card1 = const PlayingCard(suit: Suit.hearts, rank: CardRank.ace);
      final card2 = const PlayingCard(suit: Suit.spades, rank: CardRank.king);

      player.addCardToHand(card1);
      player.addCardToHand(card2);

      expect(player.currentHand, contains(card1));
      expect(player.currentHand, contains(card2));
      expect(player.currentHand.length, equals(2));

      final removed = player.removeCardFromHand(card1);
      expect(removed, equals(card1));
      expect(player.currentHand, isNot(contains(card1)));
      expect(player.currentHand.length, equals(1));

      final notRemoved = player.removeCardFromHand(
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
      );
      expect(notRemoved, isNull);
    });

    test('should remove cards by indices correctly', () {
      final cards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
      ];

      player.dealHand(cards);

      // Remove indices 1 and 3 (king and jack)
      final removed = player.removeCardsByIndices([1, 3]);

      expect(removed.length, equals(2));
      expect(removed, contains(cards[1])); // king
      expect(removed, contains(cards[3])); // jack
      expect(player.currentHand.length, equals(2));
      expect(player.currentHand, contains(cards[0])); // ace
      expect(player.currentHand, contains(cards[2])); // queen
    });

    test('should create valid meld and mark as played down', () {
      final cards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
      ];

      player.dealHand(cards);

      final meldCards = cards.take(3).toList();
      final success = player.createMeld(meldCards, playDownRequirement: 60);

      expect(success, isTrue);
      expect(player.hasPlayedDown, isTrue);
      expect(player.melds.length, equals(1));
      expect(player.melds.first.rank, equals(CardRank.ace));
      expect(player.currentHand.length, equals(1)); // One card left
      expect(player.currentHand.first.rank, equals(CardRank.king));
    });

    test('should reject meld if play down requirement not met', () {
      final cards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four), // 5 points
        const PlayingCard(suit: Suit.spades, rank: CardRank.four), // 5 points
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four), // 5 points
      ];

      player.dealHand(cards);

      final success = player.createMeld(cards, playDownRequirement: 60);

      expect(success, isFalse);
      expect(player.hasPlayedDown, isFalse);
      expect(player.melds, isEmpty);
      expect(player.currentHand.length, equals(3)); // All cards still in hand
    });

    test('should add cards to existing meld of same rank', () {
      // Create initial meld
      final initialCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ];

      player.dealHand([
        ...initialCards,
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace), // Extra ace
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // Wild
      ]);

      // Create first meld
      final success1 = player.createMeld(initialCards, playDownRequirement: 60);
      expect(success1, isTrue);
      expect(player.melds.length, equals(1));
      expect(player.melds.first.cards.length, equals(3));

      // Add more cards to the same meld
      final additionalCards = [
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
      ];
      final success2 = player.createMeld(additionalCards);

      expect(success2, isTrue);
      expect(player.melds.length, equals(1)); // Still only one meld
      expect(player.melds.first.cards.length, equals(5)); // But with more cards
      expect(player.currentHand, isEmpty);
    });

    test('should allow multiple melds after first play down', () {
      player.dealHand([
        // First meld (aces)
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        // Second meld (kings)
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ]);

      // Create first meld (meets requirement)
      final firstMeld = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ];
      final success1 = player.createMeld(firstMeld, playDownRequirement: 60);

      expect(success1, isTrue);
      expect(player.hasPlayedDown, isTrue);

      // Create second meld (no requirement check since already played down)
      final secondMeld = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ];
      final success2 = player.createMeld(secondMeld);

      expect(success2, isTrue);
      expect(player.melds.length, equals(2));
    });

    test('should calculate hand and meld values correctly', () {
      player.dealHand([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace), // 20 points
        const PlayingCard(suit: Suit.spades, rank: CardRank.king), // 10 points
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.three,
        ), // -300 points (red 3)
      ]);

      // Add a meld manually for testing
      final meld = Meld(
        rank: CardRank.queen,
        cards: List.generate(
          7,
          (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        ),
        type: MeldType.natural,
      );
      player.melds.add(meld);

      expect(player.calculateHandValue(), equals(-270)); // 20 + 10 - 300
      expect(player.calculateMeldValue(), equals(570)); // (7 * 10) + 500 bonus
      expect(player.calculateTotalScore(), equals(840)); // 570 - (-270)
    });

    test('should identify books correctly', () {
      expect(player.hasBook(), isFalse);
      expect(player.bookCount, equals(0));
      expect(player.hasCleanBook, isFalse);
      expect(player.hasDirtyBook, isFalse);
      expect(player.canGoOutWithBooks, isFalse);

      // Add clean book
      final cleanBook = Meld(
        rank: CardRank.ace,
        cards: List.generate(
          7,
          (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        ),
        type: MeldType.natural,
      );
      player.melds.add(cleanBook);

      expect(player.hasBook(), isTrue);
      expect(player.bookCount, equals(1));
      expect(player.hasCleanBook, isTrue);
      expect(player.hasDirtyBook, isFalse);
      expect(player.canGoOutWithBooks, isFalse); // Need both clean and dirty

      // Add dirty book
      final dirtyBook = Meld(
        rank: CardRank.king,
        cards: [
          ...List.generate(
            5,
            (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          ),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two), // wild
          const PlayingCard(rank: CardRank.joker), // wild
        ],
        type: MeldType.mixed,
      );
      player.melds.add(dirtyBook);

      expect(player.bookCount, equals(2));
      expect(player.hasCleanBook, isTrue);
      expect(player.hasDirtyBook, isTrue);
      expect(player.canGoOutWithBooks, isTrue); // Now has both
    });

    test('should identify going out correctly', () {
      // Player hasn't picked up foot yet
      expect(player.canGoOut, isFalse);

      // Pick up foot
      player.hand.clear();
      player.pickUpFoot();

      // Foot not empty yet
      player.foot.add(const PlayingCard(suit: Suit.hearts, rank: CardRank.ace));
      expect(player.canGoOut, isFalse);

      // Empty foot but no books
      player.foot.clear();
      expect(player.canGoOut, isFalse);

      // Add required books
      final cleanBook = Meld(
        rank: CardRank.ace,
        cards: List.generate(
          7,
          (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        ),
        type: MeldType.natural,
      );
      final dirtyBook = Meld(
        rank: CardRank.king,
        cards: [
          ...List.generate(
            5,
            (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          ),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two), // wild
          const PlayingCard(rank: CardRank.joker), // wild
        ],
        type: MeldType.mixed,
      );
      player.melds.addAll([cleanBook, dirtyBook]);

      expect(player.canGoOut, isTrue);
    });

    test('should sort hand by different criteria', () {
      final cards = [
        const PlayingCard(rank: CardRank.joker),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.four),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.two),
      ];

      player.dealHand(List.from(cards));

      // Sort by rank (meld value)
      player.sortHandByRank();
      expect(
        player.currentHand.first.rank,
        equals(CardRank.two),
      ); // Lowest meld value
      expect(
        player.currentHand.last.rank,
        equals(CardRank.joker),
      ); // Jokers go last

      // Reset and sort by suit
      player.dealHand(List.from(cards));
      player.sortHandBySuit();
      expect(
        player.currentHand.last.rank,
        equals(CardRank.joker),
      ); // Jokers still last

      // Reset and sort by point value
      player.dealHand(List.from(cards));
      player.sortHandByValue();
      expect(
        player.currentHand.first.pointValue,
        equals(5),
      ); // Four has lowest point value
      expect(
        player.currentHand.last.pointValue,
        equals(50),
      ); // Joker has highest
    });

    test('should find meld by rank correctly', () {
      final aceMeld = Meld(
        rank: CardRank.ace,
        cards: [const PlayingCard(suit: Suit.hearts, rank: CardRank.ace)],
        type: MeldType.natural,
      );
      final kingMeld = Meld(
        rank: CardRank.king,
        cards: [const PlayingCard(suit: Suit.hearts, rank: CardRank.king)],
        type: MeldType.natural,
      );

      player.melds.addAll([aceMeld, kingMeld]);

      expect(player.findMeldByRank(CardRank.ace), equals(0));
      expect(player.findMeldByRank(CardRank.king), equals(1));
      expect(player.findMeldByRank(CardRank.queen), equals(-1));
    });

    test('should handle duplicate cards correctly when creating melds', () {
      // Simulate multiple decks with identical cards
      player.dealHand([
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.ace,
        ), // First ace of hearts
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.ace,
        ), // Duplicate ace of hearts
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
      ]);

      // Create meld with both identical ace of hearts cards plus one more ace
      final meldCards = [
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.ace,
        ), // Should match first instance
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.ace,
        ), // Should match second instance
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
      ];

      final success = player.createMeld(meldCards, playDownRequirement: 60);

      expect(success, isTrue);
      expect(player.hasPlayedDown, isTrue);
      expect(player.melds.length, equals(1));
      expect(player.melds.first.cards.length, equals(3));
      expect(
        player.currentHand.length,
        equals(2),
      ); // King + remaining ace should remain
      expect(
        player.currentHand.where((card) => card.rank == CardRank.ace).length,
        equals(1),
      ); // Only one ace should remain
    });

    test('should handle duplicate cards when adding to existing meld', () {
      // Create initial meld with first ace
      final initialCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ];

      player.dealHand([
        ...initialCards,
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.ace,
        ), // Fourth ace
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.ace,
        ), // Duplicate ace of hearts
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // Wild card
      ]);

      // Create initial meld
      final success1 = player.createMeld(initialCards, playDownRequirement: 60);
      expect(success1, isTrue);
      expect(player.currentHand.length, equals(3));

      // Add duplicate ace of hearts and wild card to existing meld
      final additionalCards = [
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.ace,
        ), // This duplicate should be found correctly
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // Wild card
      ];
      final success2 = player.createMeld(additionalCards);

      expect(success2, isTrue);
      expect(player.melds.length, equals(1)); // Still only one meld
      expect(
        player.melds.first.cards.length,
        equals(5),
      ); // Original 3 + 2 added
      expect(
        player.currentHand.length,
        equals(1),
      ); // Only diamonds ace should remain
      expect(player.currentHand.first.suit, equals(Suit.diamonds));
    });
  });
}
