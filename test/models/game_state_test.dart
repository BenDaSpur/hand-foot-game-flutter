import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';

void main() {
  group('GameState', () {
    late List<Player> players;
    late GameState gameState;

    setUp(() {
      players = [
        Player(id: '1', name: 'Player 1', type: PlayerType.human),
        Player(id: '2', name: 'Player 2', type: PlayerType.bot),
      ];
      final deck = Deck.createHandAndFootDeck(players.length);
      gameState = GameState(players: players, deck: deck);
    });

    test('should initialize with correct default values', () {
      expect(gameState.players, equals(players));
      expect(gameState.currentPlayerIndex, equals(0));
      expect(gameState.phase, equals(GamePhase.setup));
      expect(gameState.turnPhase, equals(TurnPhase.draw));
      expect(gameState.round, equals(1));
      expect(gameState.discardPile, isEmpty);
      expect(gameState.recentActions, isEmpty);
      expect(gameState.discardPileFrozen, isFalse);
      expect(gameState.hasDrawnFromDeck, isFalse);
      expect(gameState.hasMelded, isFalse);
      expect(gameState.winner, isNull);
    });

    test('should get current player correctly', () {
      expect(gameState.currentPlayer, equals(players[0]));

      gameState.currentPlayerIndex = 1;
      expect(gameState.currentPlayer, equals(players[1]));
    });

    test('should get top discard correctly', () {
      expect(gameState.topDiscard, isNull);

      final card = const PlayingCard(suit: Suit.hearts, rank: CardRank.ace);
      gameState.discardPile.add(card);
      expect(gameState.topDiscard, equals(card));
    });

    test('should calculate play down requirement correctly', () {
      expect(
        gameState.playDownRequirement,
        equals(60),
      ); // Round 1: 30 + (1 * 30)

      gameState.round = 2;
      expect(
        gameState.playDownRequirement,
        equals(90),
      ); // Round 2: 30 + (2 * 30)

      gameState.round = 3;
      expect(
        gameState.playDownRequirement,
        equals(120),
      ); // Round 3: 30 + (3 * 30)
    });

    test('should advance to next player correctly', () {
      expect(gameState.currentPlayerIndex, equals(0));
      expect(gameState.turnPhase, equals(TurnPhase.draw));
      expect(gameState.hasDrawnFromDeck, isFalse);
      expect(gameState.hasMelded, isFalse);

      gameState.hasDrawnFromDeck = true;
      gameState.hasMelded = true;
      gameState.turnPhase = TurnPhase.discard;

      gameState.nextPlayer();

      expect(gameState.currentPlayerIndex, equals(1));
      expect(gameState.turnPhase, equals(TurnPhase.draw));
      expect(gameState.hasDrawnFromDeck, isFalse);
      expect(gameState.hasMelded, isFalse);

      // Should wrap around
      gameState.nextPlayer();
      expect(gameState.currentPlayerIndex, equals(0));
    });

    test('should start round correctly', () {
      gameState.phase = GamePhase.roundEnd;
      gameState.currentPlayerIndex = 1;
      gameState.discardPileFrozen = true;
      gameState.hasDrawnFromDeck = true;
      gameState.hasMelded = true;

      // Add some cards to discard pile and player melds
      gameState.discardPile.add(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
      );
      players[0].melds.add(createTestMeld());
      players[0].hasPlayedDown = true;
      players[0].hasPickedUpFoot = true;

      gameState.startRound();

      expect(gameState.phase, equals(GamePhase.playing));
      expect(gameState.currentPlayerIndex, equals(0));
      expect(gameState.turnPhase, equals(TurnPhase.draw));
      expect(gameState.discardPileFrozen, isFalse);
      expect(gameState.hasDrawnFromDeck, isFalse);
      expect(gameState.hasMelded, isFalse);
      expect(gameState.discardPile, isEmpty);

      // Players should be reset
      for (final player in players) {
        expect(player.melds, isEmpty);
        expect(player.hasPlayedDown, isFalse);
        expect(player.hasPickedUpFoot, isFalse);
      }
    });

    test('should deal cards correctly', () {
      gameState.dealCards();

      // Each player should have 11 cards in hand and foot
      for (final player in players) {
        expect(player.hand.length, equals(11));
        expect(player.foot.length, equals(11));
      }

      // Should have one card in discard pile
      expect(gameState.discardPile.length, equals(1));

      // If discard is wild, pile should be frozen
      if (gameState.topDiscard!.isWild) {
        expect(gameState.discardPileFrozen, isTrue);
      }
    });

    test('should draw from deck correctly', () {
      gameState.turnPhase = TurnPhase.draw;
      gameState.hasDrawnFromDeck = false;

      final initialDeckSize = gameState.deck.size;
      final initialHandSize = gameState.currentPlayer.currentHand.length;

      final success = gameState.drawFromDeck();

      expect(success, isTrue);
      expect(gameState.hasDrawnFromDeck, isTrue);
      expect(gameState.turnPhase, equals(TurnPhase.meld));
      expect(gameState.deck.size, equals(initialDeckSize - 2)); // Drew 2 cards
      expect(
        gameState.currentPlayer.currentHand.length,
        equals(initialHandSize + 2),
      );
    });

    test('should not draw from deck twice', () {
      gameState.turnPhase = TurnPhase.draw;
      gameState.hasDrawnFromDeck = true; // Already drawn

      final success = gameState.drawFromDeck();

      expect(success, isFalse);
    });

    test('should check discard pile unlock conditions correctly', () {
      // Setup: player has played down and has matching cards
      players[0].hasPlayedDown = true;
      players[0].dealHand([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ]);

      gameState.discardPile.add(
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
      );
      gameState.hasDrawnFromDeck = false;

      expect(gameState.canUnlockDiscard(), isTrue);

      // Should fail if player hasn't played down
      players[0].hasPlayedDown = false;
      expect(gameState.canUnlockDiscard(), isFalse);
      players[0].hasPlayedDown = true;

      // Should fail if already drawn from deck
      gameState.hasDrawnFromDeck = true;
      expect(gameState.canUnlockDiscard(), isFalse);
      gameState.hasDrawnFromDeck = false;

      // Should fail if top card is wild
      gameState.discardPile.clear();
      gameState.discardPile.add(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
      );
      expect(gameState.canUnlockDiscard(), isFalse);

      // Should fail if top card is a 3
      gameState.discardPile.clear();
      gameState.discardPile.add(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
      );
      expect(gameState.canUnlockDiscard(), isFalse);

      // Should fail if not enough matching cards
      gameState.discardPile.clear();
      gameState.discardPile.add(
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
      );
      expect(gameState.canUnlockDiscard(), isFalse); // Player only has 1 queen
    });

    test('should unlock discard pile correctly', () {
      // Setup
      players[0].hasPlayedDown = true;
      players[0].dealHand([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
      ]);

      gameState.discardPile.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        const PlayingCard(suit: Suit.spades, rank: CardRank.five),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.six),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
        const PlayingCard(suit: Suit.spades, rank: CardRank.nine), // Top card
      ]);

      // Add matching cards for the top discard (nine)
      players[0].currentHand.addAll([
        const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
      ]);

      final initialHandSize = players[0].currentHand.length;
      final success = gameState.unlockDiscard();

      expect(success, isTrue);
      expect(gameState.turnPhase, equals(TurnPhase.meld));
      expect(players[0].melds.length, equals(1)); // Created meld with the nines
      expect(players[0].melds.first.rank, equals(CardRank.nine));
      expect(
        players[0].melds.first.cards.length,
        equals(3),
      ); // 2 from hand + top discard

      // Should have taken additional cards from discard pile
      expect(players[0].currentHand.length, greaterThan(initialHandSize - 2));
      expect(gameState.discardPile.length, equals(0)); // All cards taken
    });

    test(
      'should add unlocked cards to existing meld instead of creating new one',
      () {
        final testPlayers = [
          Player(id: '1', name: 'Player 1', type: PlayerType.human),
          Player(id: '2', name: 'Player 2', type: PlayerType.bot),
        ];
        final deck = Deck.createHandAndFootDeck(testPlayers.length);
        final gameState = GameState(players: testPlayers, deck: deck);
        gameState.startRound();

        // Give first player an existing meld of nines
        final existingNines = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
        ];
        final existingMeld = Meld.createMeld(existingNines)!;
        testPlayers[0].melds.add(existingMeld);
        testPlayers[0].hasPlayedDown = true;

        // Give first player 2 matching natural cards for the top discard
        testPlayers[0].currentHand.addAll([
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
        ]);

        // Set up discard pile with 9 on top
        gameState.discardPile.addAll([
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine), // Top card
        ]);

        final initialMeldCount = testPlayers[0].melds.length;
        final initialMeldSize = existingMeld.cards.length;

        final success = gameState.unlockDiscard();

        expect(success, isTrue);

        // Should not have created a new meld
        expect(testPlayers[0].melds.length, equals(initialMeldCount));

        // Should have added to existing meld
        expect(
          existingMeld.cards.length,
          equals(initialMeldSize + 3),
        ); // 2 from hand + 1 from discard

        // Existing meld should now have 6 nines total
        expect(existingMeld.cards.length, equals(6));
        expect(
          existingMeld.cards.every((card) => card.rank == CardRank.nine),
          isTrue,
        );
      },
    );

    test(
      'should create new meld when unlocking discard with no existing meld of that rank',
      () {
        final testPlayers2 = [
          Player(id: '1', name: 'Player 1', type: PlayerType.human),
          Player(id: '2', name: 'Player 2', type: PlayerType.bot),
        ];
        final deck2 = Deck.createHandAndFootDeck(testPlayers2.length);
        final gameState2 = GameState(players: testPlayers2, deck: deck2);
        gameState2.startRound();

        // Give first player an existing meld of kings (different rank)
        final existingKings = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        ];
        final existingMeld = Meld.createMeld(existingKings)!;
        testPlayers2[0].melds.add(existingMeld);
        testPlayers2[0].hasPlayedDown = true;

        // Give first player 2 matching natural cards for the top discard (different rank)
        testPlayers2[0].currentHand.addAll([
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
        ]);

        // Set up discard pile with 9 on top (different from existing meld)
        gameState2.discardPile.addAll([
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine), // Top card
        ]);

        final initialMeldCount = testPlayers2[0].melds.length;

        final success = gameState2.unlockDiscard();

        expect(success, isTrue);

        // Should have created a new meld since no existing nine meld
        expect(testPlayers2[0].melds.length, equals(initialMeldCount + 1));

        // New meld should contain the 3 nines
        final nineMeld = testPlayers2[0].melds.firstWhere(
          (m) => m.rank == CardRank.nine,
        );
        expect(nineMeld.cards.length, equals(3));
        expect(
          nineMeld.cards.every((card) => card.rank == CardRank.nine),
          isTrue,
        );

        // Existing king meld should be unchanged
        expect(existingMeld.cards.length, equals(3));
        expect(
          existingMeld.cards.every((card) => card.rank == CardRank.king),
          isTrue,
        );
      },
    );

    test('should create meld correctly', () {
      gameState.turnPhase = TurnPhase.meld;

      final cards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ];

      players[0].dealHand(cards);

      final success = gameState.playMeld(cards);

      expect(success, isTrue);
      expect(gameState.hasMelded, isTrue);
      expect(players[0].hasPlayedDown, isTrue);
      expect(players[0].melds.length, equals(1));
      expect(players[0].currentHand, isEmpty);
    });

    test('should not create meld during wrong phase', () {
      gameState.turnPhase = TurnPhase.draw; // Wrong phase

      final cards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ];

      players[0].dealHand(cards);

      final success = gameState.playMeld(cards);

      expect(success, isFalse);
      expect(gameState.hasMelded, isFalse);
    });

    test('should discard correctly and advance turn', () {
      gameState.turnPhase = TurnPhase.meld;
      gameState.hasMelded = true;

      final card = const PlayingCard(suit: Suit.hearts, rank: CardRank.ace);
      players[0].dealHand([card]);

      final initialPlayer = gameState.currentPlayerIndex;
      final success = gameState.discard(card);

      expect(success, isTrue);
      expect(gameState.discardPile.last, equals(card));
      expect(players[0].currentHand, isEmpty);
      expect(
        gameState.currentPlayerIndex,
        isNot(equals(initialPlayer)),
      ); // Advanced to next player
    });

    test('should freeze discard pile when discarding wild card', () {
      gameState.turnPhase = TurnPhase.meld;
      gameState.hasMelded = true;

      final wildCard = const PlayingCard(suit: Suit.hearts, rank: CardRank.two);
      players[0].dealHand([wildCard]);

      expect(gameState.discardPileFrozen, isFalse);

      final success = gameState.discard(wildCard);

      expect(success, isTrue);
      expect(gameState.discardPileFrozen, isTrue);
    });

    test('should trigger foot pickup when hand empties', () {
      gameState.turnPhase = TurnPhase.meld;
      gameState.hasMelded = true;

      final card = const PlayingCard(suit: Suit.hearts, rank: CardRank.ace);
      players[0].dealHand([card]);
      players[0].dealFoot([
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      ]);

      expect(players[0].hasPickedUpFoot, isFalse);

      final success = gameState.discard(card);

      expect(success, isTrue);
      expect(players[0].hasPickedUpFoot, isTrue);
    });

    test('should end round when player goes out', () {
      gameState.turnPhase = TurnPhase.meld;
      gameState.hasMelded = true;
      gameState.phase = GamePhase.playing;

      // Setup player to go out
      players[0].hasPickedUpFoot = true;
      players[0].foot.clear(); // Empty foot

      // Add required books
      players[0].melds.addAll([createCleanBook(), createDirtyBook()]);

      final card = const PlayingCard(suit: Suit.hearts, rank: CardRank.ace);
      players[0].foot.add(card); // Add one card to discard

      final success = gameState.discard(card);

      expect(success, isTrue);
      expect(gameState.phase, equals(GamePhase.roundEnd));
    });

    test('should end game when player reaches 8500 points', () {
      players[0].score = 8400; // Close to winning

      // Add enough meld value to exceed 8500
      players[0].melds.add(createCleanBook()); // Worth 570 points

      gameState.endRound();

      expect(gameState.phase, equals(GamePhase.gameEnd));
      expect(gameState.winner, equals(players[0]));
    });

    test('should reset for new round correctly', () {
      // Setup end of round state
      gameState.phase = GamePhase.roundEnd;
      gameState.round = 1;

      players[0].dealHand([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
      ]);
      players[0].dealFoot([
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      ]);
      gameState.discardPile.add(
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
      );

      final initialDeckSize = gameState.deck.size;

      gameState.resetForNewRound();

      expect(gameState.phase, equals(GamePhase.playing));
      expect(
        gameState.round,
        equals(1),
      ); // Round stays same until endRound called
      expect(gameState.discardPile, isNotEmpty); // New discard from dealing
      expect(
        gameState.deck.size,
        lessThan(initialDeckSize),
      ); // Cards were dealt

      // Players should have new hands/feet
      for (final player in players) {
        expect(player.hand.length, equals(11));
        expect(player.foot.length, equals(11));
      }
    });

    test('should get players in turn order', () {
      gameState.currentPlayerIndex = 1;

      final orderedPlayers = gameState.getPlayersInOrder();

      expect(orderedPlayers[0], equals(players[1])); // Current player first
      expect(orderedPlayers[1], equals(players[0])); // Then others in order
    });
  });
}

// Helper functions for creating test melds
Meld createTestMeld() {
  return Meld(
    rank: CardRank.ace,
    cards: [
      const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
      const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
      const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
    ],
    type: MeldType.natural,
  );
}

Meld createCleanBook() {
  return Meld(
    rank: CardRank.ace,
    cards: List.generate(
      7,
      (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
    ),
    type: MeldType.natural,
  );
}

Meld createDirtyBook() {
  return Meld(
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
}
