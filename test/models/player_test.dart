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

    test('should resolve duplicate rank+suit cards when removing', () {
      final kingInHand = const PlayingCard(
        suit: Suit.hearts,
        rank: CardRank.king,
      );
      final kingDuplicate = const PlayingCard(
        suit: Suit.hearts,
        rank: CardRank.king,
      );
      player.dealHand([kingInHand, kingDuplicate]);

      final removed = player.removeCardFromHand(
        PlayingCard(suit: Suit.hearts, rank: CardRank.king),
      );

      expect(removed, isNotNull);
      expect(player.currentHand.length, 1);
      expect(
        player.hasHandCard(kingInHand) || player.hasHandCard(kingDuplicate),
        isTrue,
      );
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

      // Sort by rank (display order: 3s → 4-K → Aces → 2s → Jokers)
      player.sortHandByRank();
      expect(
        player.currentHand.first.rank,
        equals(CardRank.four),
      ); // Four comes first (lowest display order of available cards)
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

    test(
      'should allow going out with books that become mixed through wild card addition',
      () {
        // Set up player using foot with empty hand/foot
        player.hasPickedUpFoot = true;
        player.hand.clear();
        player.foot.clear();

        // Create a clean book (natural, 7+ cards)
        final cleanBookCards = List.generate(
          7,
          (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
        );
        final cleanBook = Meld.createMeld(cleanBookCards)!;
        player.melds.add(cleanBook);

        expect(player.hasCleanBook, isTrue);
        expect(player.hasDirtyBook, isFalse);
        expect(player.canGoOutWithBooks, isFalse); // Needs both clean AND dirty
        expect(player.canGoOut, isFalse);

        // Create another natural book that will become dirty
        final initialNaturalCards = List.generate(
          7,
          (i) => const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        );
        final bookToBeDirty = Meld.createMeld(initialNaturalCards)!;
        player.melds.add(bookToBeDirty);

        // Still no dirty book
        expect(player.hasCleanBook, isTrue);
        expect(player.hasDirtyBook, isFalse);
        expect(player.canGoOutWithBooks, isFalse);
        expect(player.canGoOut, isFalse);

        // Add a wild card to the second book - should become dirty dynamically
        final wildCard = const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.two,
        );
        final success = bookToBeDirty.addCard(wildCard);

        expect(success, isTrue);
        expect(bookToBeDirty.type, equals(MeldType.mixed));
        expect(bookToBeDirty.isDirty, isTrue);

        // Now should be able to go out
        expect(player.hasCleanBook, isTrue);
        expect(player.hasDirtyBook, isTrue);
        expect(player.canGoOutWithBooks, isTrue);
        expect(player.canGoOut, isTrue);
      },
    );

    test('should track newly drawn cards correctly with duplicate cards', () {
      // Setup initial hand with Queen of Spades
      player.hand.clear();
      player.hand.addAll([
        const PlayingCard(
          suit: Suit.spades,
          rank: CardRank.queen,
        ), // Existing card
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.king,
        ), // Other cards
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ]);

      // Clear any existing newly drawn tracking
      player.clearNewlyDrawnCards();

      // Verify initial state - no newly drawn cards
      expect(player.isCardIndexNewlyDrawn(0), false); // Queen of Spades
      expect(player.isCardIndexNewlyDrawn(1), false); // King
      expect(player.isCardIndexNewlyDrawn(2), false); // Ace

      // Draw another Queen of Spades (same rank/suit but different object)
      final newQueenOfSpades = PlayingCard(
        suit: Suit.spades,
        rank: CardRank.queen,
      );
      player.addNewlyDrawnCard(newQueenOfSpades);

      // Verify hand state - after auto-sorting: Queen, Queen, King, Ace
      expect(player.currentHand.length, 4);

      // With auto-sorting, the two Queens will be grouped together
      // Find the index of the newly drawn Queen
      int newQueenIndex = -1;
      for (int i = 0; i < player.currentHand.length; i++) {
        if (identical(player.currentHand[i], newQueenOfSpades)) {
          newQueenIndex = i;
          break;
        }
      }
      expect(
        newQueenIndex != -1,
        true,
        reason: 'Should find the newly drawn Queen in hand',
      );

      // Check newly drawn status - exactly one Queen should be newly drawn
      int queensFound = 0;
      int newlyDrawnQueensFound = 0;
      for (int i = 0; i < player.currentHand.length; i++) {
        if (player.currentHand[i].rank == CardRank.queen) {
          queensFound++;
          if (player.isCardIndexNewlyDrawn(i)) {
            newlyDrawnQueensFound++;
          }
        }
      }
      expect(queensFound, 2, reason: 'Should have 2 Queens total');
      expect(
        newlyDrawnQueensFound,
        1,
        reason: 'Should have exactly 1 newly drawn Queen',
      );

      // Test object-based method works correctly with identical instances
      expect(
        player.isCardNewlyDrawn(newQueenOfSpades),
        true,
        reason: 'New Queen should be marked as newly drawn',
      );

      // The original Queen should not be newly drawn
      bool foundOriginalQueen = false;
      for (int i = 0; i < player.currentHand.length; i++) {
        if (player.currentHand[i].rank == CardRank.queen &&
            !identical(player.currentHand[i], newQueenOfSpades)) {
          foundOriginalQueen = true;
          expect(
            player.isCardNewlyDrawn(player.currentHand[i]),
            false,
            reason: 'Original Queen should not be marked as newly drawn',
          );
          break;
        }
      }
      expect(
        foundOriginalQueen,
        true,
        reason: 'Should find the original Queen',
      );

      // Remove one of the Queens - find which one was removed
      final cardToRemove =
          player.currentHand.first; // Should be a Queen after sorting
      expect(
        cardToRemove.rank,
        CardRank.queen,
        reason: 'First card should be a Queen after sorting',
      );

      final removedCard = player.removeCardFromHand(cardToRemove);
      expect(removedCard, isNotNull);

      // Verify removal worked correctly
      expect(player.currentHand.length, 3);

      // Check that exactly one Queen remains and it should be the newly drawn one
      int remainingQueens = 0;
      bool newQueenStillNewlyDrawn = false;

      for (int i = 0; i < player.currentHand.length; i++) {
        if (player.currentHand[i].rank == CardRank.queen) {
          remainingQueens++;
          if (identical(player.currentHand[i], newQueenOfSpades) &&
              player.isCardIndexNewlyDrawn(i)) {
            newQueenStillNewlyDrawn = true;
          }
        }
      }

      expect(remainingQueens, 1, reason: 'Should have 1 Queen remaining');
      expect(
        newQueenStillNewlyDrawn,
        true,
        reason: 'Newly drawn Queen should still be marked as newly drawn',
      );

      // Clear newly drawn cards
      player.clearNewlyDrawnCards();

      // Verify all cards are no longer marked as newly drawn
      for (int i = 0; i < player.currentHand.length; i++) {
        expect(
          player.isCardIndexNewlyDrawn(i),
          false,
          reason: 'No cards should be marked as newly drawn after clearing',
        );
      }
    });

    test('should count all unplayed cards as negative when round ends', () {
      final player = Player(id: '1', name: 'Test', type: PlayerType.human);

      // Give player cards that include meldable cards in hand pile
      player.dealHand([
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.ten,
        ), // 10 points - will be melded
        const PlayingCard(
          suit: Suit.spades,
          rank: CardRank.ten,
        ), // 10 points - will be melded
        const PlayingCard(
          suit: Suit.clubs,
          rank: CardRank.ten,
        ), // 10 points - will be melded
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.king,
        ), // 10 points - stays in hand
        const PlayingCard(
          suit: Suit.spades,
          rank: CardRank.queen,
        ), // 10 points - stays in hand
      ]); // 50 points total in hand

      // Give player some cards in foot pile
      player.dealFoot([
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace), // 20 points
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.jack,
        ), // 10 points
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.three,
        ), // -300 points (red 3)
      ]); // -270 points in foot (20 + 10 - 300)

      // Create a meld with the three tens (will be removed from hand)
      final meld = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
      ]; // 3 * 10 = 30 points
      final meldSuccess = player.createMeld(
        meld,
        playDownRequirement: 30,
      ); // 3 tens = 30 points, should pass
      expect(meldSuccess, isTrue); // Verify meld was created

      // Verify meld was created successfully
      expect(player.melds.length, equals(1));
      expect(player.currentHand.length, equals(2)); // King + Queen remain

      // After meld creation: hand has King + Queen (20 penalty), foot has Ace + Jack + Red3 (20+10+300=330 penalty)
      // Total penalty: 20 + 330 = 350 points

      // Normal calculation (only active hand): 30 (meld) - 20 (current hand penalty) = 10
      final normalScore = player.calculateTotalScore();
      expect(normalScore, equals(10));

      // Round-end calculation (all unplayed): 30 (meld) - 350 (all penalty) = -320
      final roundEndScore = player.calculateTotalScore(
        includeAllUnplayedCards: true,
      );
      expect(roundEndScore, equals(-320));

      // Verify the individual components
      expect(player.calculateMeldValue(), equals(30));
      expect(
        player.calculateHandValue(),
        equals(20),
      ); // Only active hand (King + Queen)
      expect(
        player.calculateAllUnplayedCardsValue(),
        equals(350),
      ); // Hand + foot penalty: 20 + (20+10+300) = 350
    });
  });
}
