import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_meld_analyzer.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('BotMeldAnalyzer Tests', () {
    late BotMeldAnalyzer meldAnalyzer;
    late GameController gameController;
    late Player botPlayer;

    setUp(() {
      meldAnalyzer = BotMeldAnalyzer();

      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      gameController = GameController(players: players);
      gameController.initializeGame();
      botPlayer = players[1];
    });

    group('Meld Analysis', () {
      test('should get possible melds with caching', () {
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
        ]);

        final melds1 = meldAnalyzer.getPossibleMelds(botPlayer, gameController);
        final melds2 = meldAnalyzer.getPossibleMelds(botPlayer, gameController);

        expect(melds1, isNotEmpty);
        expect(melds1, equals(melds2)); // Should be cached
      });

      test('should clear cache properly', () {
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ]);

        final melds = meldAnalyzer.getPossibleMelds(botPlayer, gameController);
        expect(melds, isNotEmpty);

        meldAnalyzer.clearCache();
        // Cache should be cleared, but melds should still be found
        final newMelds = meldAnalyzer.getPossibleMelds(
          botPlayer,
          gameController,
        );
        expect(newMelds, isNotEmpty);
      });
    });

    group('Meld Selection', () {
      test('should choose largest meld correctly', () {
        final meld1 = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ];

        final meld2 = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        ];

        final largestMeld = meldAnalyzer.chooseLargestMeld([meld1, meld2]);
        expect(largestMeld, equals(meld2)); // Should choose the 4-card meld
      });

      test('should find best meld with preferences', () {
        final cleanMeld = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ];

        final dirtyMeld = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: null, rank: CardRank.joker), // Wild
        ];

        final bestMeld = meldAnalyzer.findBestMeld([
          cleanMeld,
          dirtyMeld,
        ], preferClean: true);
        expect(bestMeld, equals(cleanMeld)); // Should prefer clean meld
      });
    });

    group('Add to Meld Analysis', () {
      test('should find cards to add to existing melds', () {
        // Create existing meld
        final existingMeld = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ];
        botPlayer.melds.add(Meld.createMeld(existingMeld)!);

        // Give bot matching cards
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(
            suit: Suit.diamonds,
            rank: CardRank.king,
          ), // Can add
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        ]);

        final additions = meldAnalyzer.findCardsToAddToExistingMelds(
          botPlayer,
          gameController,
        );
        expect(additions, isNotEmpty);

        final addition = additions.first;
        expect(addition['card'], isA<PlayingCard>());
        expect(addition['meldIndex'], equals(0));

        final card = addition['card'] as PlayingCard;
        expect(card.rank, equals(CardRank.king));
      });
    });

    group('Meld Quality Analysis', () {
      test('should identify weak meld opportunities', () {
        // Give bot only low-value cards
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.four),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
        ]);

        final hasOnlyWeak = meldAnalyzer.hasOnlyWeakMeldOpportunities(
          botPlayer,
          gameController,
        );
        expect(hasOnlyWeak, isTrue);
      });

      test('should find natural meld opportunities', () {
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: null, rank: CardRank.joker), // Wild
        ]);

        final naturalMelds = meldAnalyzer.findNaturalMeldOpportunities(
          botPlayer,
          gameController,
        );
        expect(naturalMelds, isNotEmpty);

        final firstMeld = naturalMelds.first;
        expect(firstMeld.every((card) => !card.isWild), isTrue);
      });

      test('should find wild meld opportunities', () {
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: null, rank: CardRank.joker), // Wild
        ]);

        final wildMelds = meldAnalyzer.findWildMeldOpportunities(
          botPlayer,
          gameController,
        );
        expect(wildMelds, isNotEmpty);

        final firstMeld = wildMelds.first;
        expect(firstMeld.any((card) => card.isWild), isTrue);
      });
    });

    group('Book Analysis', () {
      test('should find melds with book potential', () {
        // Create a 5-card meld (book potential)
        final almostBook = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        ];
        botPlayer.melds.add(Meld.createMeld(almostBook)!);

        final booksInProgress = meldAnalyzer.findMeldsWithBookPotential(
          botPlayer,
        );
        expect(booksInProgress, hasLength(1));
        expect(booksInProgress.first.cards.length, equals(5));
      });

      test('should find existing books', () {
        // Create a 7-card book
        final book = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ];
        botPlayer.melds.add(Meld.createMeld(book)!);

        final existingBooks = meldAnalyzer.findExistingBooks(botPlayer);
        expect(existingBooks, hasLength(1));
        expect(existingBooks.first.cards.length, equals(7));
      });

      test('should count books correctly', () {
        // Clean book
        final cleanBook = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ];

        // Dirty book
        final dirtyBook = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: null, rank: CardRank.joker), // Wild
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // Wild
        ];

        botPlayer.melds.add(Meld.createMeld(cleanBook)!);
        botPlayer.melds.add(Meld.createMeld(dirtyBook)!);

        final bookCounts = meldAnalyzer.countBooks(botPlayer);
        expect(bookCounts['clean'], equals(1));
        expect(bookCounts['dirty'], equals(1));
      });
    });

    group('Strategic Analysis', () {
      test('should analyze hand composition', () {
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: null, rank: CardRank.joker), // Wild
          const PlayingCard(suit: Suit.hearts, rank: CardRank.three), // Penalty
        ]);

        final composition = meldAnalyzer.analyzeHandComposition(botPlayer);
        expect(composition['potentialMelds'], equals(1)); // Kings
        expect(composition['wildCards'], equals(1));
        expect(composition['penaltyCards'], equals(1));
        expect(composition['strongRanks'], equals(1)); // 3 Kings
      });

      test('should estimate meld potential', () {
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: null, rank: CardRank.joker), // Wild
        ]);

        final potential = meldAnalyzer.estimateMeldPotential(
          botPlayer,
          gameController,
        );
        expect(potential, greaterThan(0)); // Should have some potential
      });

      test('should find best play-down combination', () {
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        ]);

        final combination = meldAnalyzer.findBestPlayDownCombination(
          botPlayer,
          gameController,
          60, // Requirement
        );

        expect(combination, isNotEmpty);
        final totalValue = meldAnalyzer.calculateTotalMeldValue(combination);
        expect(totalValue, greaterThanOrEqualTo(60));
      });
    });

    group('Error Handling', () {
      test('should handle empty meld lists', () {
        expect(meldAnalyzer.chooseLargestMeld([]), isNull);
        expect(meldAnalyzer.findBestMeld([]), isEmpty);
      });

      test('should handle empty hands', () {
        botPlayer.hand.clear();

        final melds = meldAnalyzer.getPossibleMelds(botPlayer, gameController);
        expect(melds, isEmpty);

        final composition = meldAnalyzer.analyzeHandComposition(botPlayer);
        expect(composition['potentialMelds'], equals(0));
      });
    });
  });
}
