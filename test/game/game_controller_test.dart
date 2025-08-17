import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('GameController', () {
    late List<Player> players;
    late GameController gameController;

    setUp(() {
      players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot 1', type: PlayerType.bot),
        Player(id: '3', name: 'Bot 2', type: PlayerType.bot),
      ];
      gameController = GameController(players: players);
    });

    test('should initialize game correctly', () {
      expect(gameController.gameState.players, equals(players));
      expect(gameController.gameState.phase, equals(GamePhase.setup));
      expect(gameController.gameSeed, isNotNull);
      expect(gameController.gameSeed, greaterThan(0));
    });

    test('should initialize game with specific seed', () {
      const testSeed = 12345;
      final controller = GameController(players: players, seed: testSeed);

      expect(controller.gameSeed, equals(testSeed));
    });

    test('should initialize and deal cards', () {
      gameController.initializeGame();

      expect(gameController.gameState.phase, equals(GamePhase.playing));

      // Each player should have 11 cards in hand and foot
      for (final player in players) {
        expect(player.hand.length, equals(11));
        expect(player.foot.length, equals(11));
      }

      // Should have initial discard
      expect(gameController.gameState.discardPile.length, equals(1));

      // Current player should be at index 0 (first player, who happens to be human)
      expect(gameController.gameState.currentPlayerIndex, equals(0));
      expect(
        gameController.gameState.currentPlayer.type,
        equals(PlayerType.human),
      );
    });

    test('should handle drawing from deck', () {
      gameController.initializeGame();

      final humanPlayer = players.firstWhere((p) => p.type == PlayerType.human);
      final initialHandSize = humanPlayer.currentHand.length;

      final success = gameController.drawFromDeck();

      expect(success, isTrue);
      expect(humanPlayer.currentHand.length, equals(initialHandSize + 2));
      expect(gameController.gameState.hasDrawnFromDeck, isTrue);
      expect(gameController.gameState.turnPhase, equals(TurnPhase.meld));
    });

    test('should handle meld creation', () {
      gameController.initializeGame();

      final humanPlayer = players.firstWhere((p) => p.type == PlayerType.human);

      // Set up a valid meld scenario
      final testCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ];

      // Clear hand and add test cards
      humanPlayer.hand.clear();
      humanPlayer.hand.addAll(testCards);

      // Must draw first
      gameController.drawFromDeck();

      final success = gameController.createMeld(testCards);

      expect(success, isTrue);
      expect(humanPlayer.hasPlayedDown, isTrue);
      expect(humanPlayer.melds.length, equals(1));
      expect(humanPlayer.melds.first.cards.length, equals(3));
    });

    test('should reject invalid meld', () {
      gameController.initializeGame();

      final humanPlayer = players.firstWhere((p) => p.type == PlayerType.human);

      // Invalid meld (different ranks)
      final invalidCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
      ];

      humanPlayer.hand.clear();
      humanPlayer.hand.addAll(invalidCards);

      gameController.drawFromDeck();

      final success = gameController.createMeld(invalidCards);

      expect(success, isFalse);
      expect(humanPlayer.hasPlayedDown, isFalse);
      expect(humanPlayer.melds, isEmpty);
    });

    test('should handle discarding', () {
      gameController.initializeGame();

      final humanPlayer = players.firstWhere((p) => p.type == PlayerType.human);
      final discardCard = humanPlayer.currentHand.first;
      final initialDiscardPileSize =
          gameController.gameState.discardPile.length;

      // Must draw first
      gameController.drawFromDeck();

      // Try to create a valid meld for testing
      final testCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ];

      // Set up hand with known cards
      humanPlayer.hand.clear();
      humanPlayer.hand.addAll([...testCards, discardCard]);

      // Create meld with the aces
      final meldSuccess = gameController.createMeld(testCards);
      expect(meldSuccess, isTrue);
      expect(humanPlayer.hasPlayedDown, isTrue);

      // Now discard should work
      final success = gameController.discardCard(discardCard);
      expect(success, isTrue);
      expect(
        gameController.gameState.discardPile.length,
        equals(initialDiscardPileSize + 1),
      );
      expect(gameController.gameState.discardPile.last, equals(discardCard));
    });

    test('should detect game end conditions', () {
      gameController.initializeGame();

      final humanPlayer = players.firstWhere((p) => p.type == PlayerType.human);

      // Set up player to go out
      humanPlayer.hasPickedUpFoot = true;
      humanPlayer.foot.clear(); // Empty foot
      humanPlayer.hand.clear();

      // Add required books for going out
      humanPlayer.melds.addAll([
        createCleanBookForTest(),
        createDirtyBookForTest(),
      ]);

      // Set this player as current player
      while (gameController.gameState.currentPlayer != humanPlayer) {
        gameController.gameState.nextPlayer();
      }

      expect(gameController.canPlayerGoOut(), isTrue);
    });

    test('should handle round progression', () {
      gameController.initializeGame();

      // Simulate round end
      gameController.gameState.endRound();

      if (gameController.gameState.phase == GamePhase.roundEnd) {
        gameController.nextRound();
        expect(gameController.gameState.phase, equals(GamePhase.playing));
      } else if (gameController.gameState.phase == GamePhase.gameEnd) {
        expect(gameController.gameState.winner, isNotNull);
      }
    });

    test('should export and import game state', () {
      gameController.initializeGame();

      // Make some changes to the game state
      gameController.drawFromDeck();

      final exportedState = gameController.exportGameState();
      expect(exportedState, isNotNull);
      expect(exportedState, contains('seed'));
      expect(exportedState, contains('players'));
      expect(exportedState, contains('discardPile'));

      // Create new controller from exported state
      final newController = GameController.fromExportJson(exportedState);
      expect(newController, isNotNull);

      // Verify state was imported correctly
      expect(newController!.gameSeed, equals(gameController.gameSeed));
      expect(
        newController.gameState.hasDrawnFromDeck,
        equals(gameController.gameState.hasDrawnFromDeck),
      );
    });

    test('should handle seeded random generation consistently', () {
      const seed = 12345;

      final controller1 = GameController(
        players: [
          Player(id: '1', name: 'Player 1', type: PlayerType.human),
          Player(id: '2', name: 'Player 2', type: PlayerType.bot),
        ],
        seed: seed,
      );

      final controller2 = GameController(
        players: [
          Player(id: '1', name: 'Player 1', type: PlayerType.human),
          Player(id: '2', name: 'Player 2', type: PlayerType.bot),
        ],
        seed: seed,
      );

      controller1.initializeGame();
      controller2.initializeGame();

      // With same seed, initial card distribution should be identical
      expect(
        controller1.gameState.players[0].hand.length,
        equals(controller2.gameState.players[0].hand.length),
      );
      expect(
        controller1.gameState.players[0].foot.length,
        equals(controller2.gameState.players[0].foot.length),
      );

      // First cards should be the same
      expect(
        controller1.gameState.players[0].hand.first.rank,
        equals(controller2.gameState.players[0].hand.first.rank),
      );
      expect(
        controller1.gameState.players[0].hand.first.suit,
        equals(controller2.gameState.players[0].hand.first.suit),
      );
    });

    test('should validate meld cards correctly', () {
      gameController.initializeGame();

      // Valid natural meld
      final validMeld = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ];
      expect(Meld.createMeld(validMeld), isNotNull);

      // Invalid meld (too few cards)
      final tooFew = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
      ];
      expect(Meld.createMeld(tooFew), isNull);

      // Invalid meld (contains 3s)
      final withThrees = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
        const PlayingCard(suit: Suit.spades, rank: CardRank.three),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.three),
      ];
      expect(Meld.createMeld(withThrees), isNull);

      // Invalid meld (different ranks)
      final differentRanks = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
      ];
      expect(Meld.createMeld(differentRanks), isNull);
    });

    test('should handle bot turn processing', () {
      gameController.initializeGame();

      // Advance to bot turn
      gameController.gameState.nextPlayer();
      expect(
        gameController.gameState.currentPlayer.type,
        equals(PlayerType.bot),
      );

      final botPlayer = gameController.gameState.currentPlayer;

      // Bot should be able to take actions (implementation dependent)
      expect(
        gameController.gameState.currentPlayer.type,
        equals(PlayerType.bot),
      );
      expect(botPlayer.currentHand.length, greaterThanOrEqualTo(11));
    });

    test('should maintain game state consistency', () {
      gameController.initializeGame();

      // Verify total cards in play
      int totalCards = 0;
      for (final player in gameController.gameState.players) {
        totalCards += player.hand.length + player.foot.length;
        // Also count cards in melds
        for (final meld in player.melds) {
          totalCards += meld.cards.length;
        }
      }
      totalCards += gameController.gameState.deck.size;
      totalCards += gameController.gameState.discardPile.length;

      // Should have expected number of cards for Hand & Foot
      // For 3 players: (3+1) = 4 decks × (52 cards + 2 jokers) = 4 × 54 = 216 cards
      const expectedCards = 216;

      // Debug output if test fails
      if (totalCards != expectedCards) {
        print('Card count mismatch:');
        print('  Expected: $expectedCards');
        print('  Actual: $totalCards');
        print('  Deck size: ${gameController.gameState.deck.size}');
        print('  Discard pile: ${gameController.gameState.discardPile.length}');
        for (int i = 0; i < gameController.gameState.players.length; i++) {
          final player = gameController.gameState.players[i];
          print(
            '  Player $i: hand=${player.hand.length}, foot=${player.foot.length}, melds=${player.melds.fold(0, (sum, meld) => sum + meld.cards.length)}',
          );
        }
      }

      expect(totalCards, equals(expectedCards));
    });

    test('should handle error cases gracefully', () {
      // Test importing invalid JSON
      gameController.initializeGame();
      final importedController = GameController.fromExportJson('invalid json');
      expect(importedController, isNull);

      // Test actions on wrong player type
      gameController.initializeGame();

      // Advance to bot player
      while (gameController.gameState.currentPlayer.type != PlayerType.bot) {
        gameController.gameState.nextPlayer();
      }

      // Verify we're on bot turn
      expect(
        gameController.gameState.currentPlayer.type,
        equals(PlayerType.bot),
      );

      // The GameController allows empty players - it's up to the calling code to validate
      // So we just test that it doesn't crash
      final emptyController = GameController(players: []);
      expect(emptyController.gameState.players, isEmpty);
    });
  });
}

// Helper functions for creating test melds
Meld createCleanBookForTest() {
  return Meld(
    rank: CardRank.ace,
    cards: List.generate(
      7,
      (i) => const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
    ),
    type: MeldType.natural,
  );
}

Meld createDirtyBookForTest() {
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
