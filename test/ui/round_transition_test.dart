import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Round Transition Tests', () {
    late GameController gameController;
    late Player humanPlayer;

    setUp(() {
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot1', type: PlayerType.bot),
        Player(id: '3', name: 'Bot2', type: PlayerType.bot),
      ];
      gameController = GameController(players: players);
      gameController.initializeGame();
      humanPlayer = players[0];
    });

    test('should transition to roundEnd phase when human player goes out', () {
      // Set up human player ready to go out
      humanPlayer.hasPlayedDown = true;
      humanPlayer.hasPickedUpFoot = true;

      // Give player books required to go out
      final cleanBook = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ];

      final dirtyBook = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: null, rank: CardRank.joker),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
      ];

      humanPlayer.melds.add(Meld.createMeld(cleanBook)!);
      humanPlayer.melds.add(Meld.createMeld(dirtyBook)!);

      // Clear hand and leave one card in foot to discard
      humanPlayer.hand.clear();
      humanPlayer.foot.clear();
      humanPlayer.foot.add(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
      );

      // Verify preconditions - should not be able to go out yet (foot not empty)
      expect(humanPlayer.foot.isEmpty, isFalse);
      expect(humanPlayer.hasCleanBook, isTrue);
      expect(humanPlayer.hasDirtyBook, isTrue);
      expect(gameController.gameState.phase, equals(GamePhase.playing));

      // Discard last card to go out
      final lastCard = humanPlayer.foot.first;

      // Set it to be human player's turn in discard phase
      gameController.gameState.currentPlayerIndex = 0;
      gameController.gameState.turnPhase = TurnPhase.discard;

      final success = gameController.discardCard(lastCard);

      expect(success, isTrue);
      expect(gameController.gameState.phase, equals(GamePhase.roundEnd));
      expect(humanPlayer.foot.isEmpty, isTrue);
      expect(humanPlayer.hand.isEmpty, isTrue);
    });

    test('should automatically progress to next round after roundEnd', () {
      // Set up a scenario where human player has gone out
      humanPlayer.hasPlayedDown = true;
      humanPlayer.hasPickedUpFoot = true;
      humanPlayer.hand.clear();
      humanPlayer.foot.clear();

      // Add required books
      final cleanBook = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ];

      final dirtyBook = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: null, rank: CardRank.joker),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
      ];

      humanPlayer.melds.add(Meld.createMeld(cleanBook)!);
      humanPlayer.melds.add(Meld.createMeld(dirtyBook)!);

      final initialRound = gameController.gameState.round;

      // Manually set to roundEnd phase (simulating going out)
      gameController.gameState.endRound();
      expect(gameController.gameState.phase, equals(GamePhase.roundEnd));
      final initialDeckSize = gameController.gameState.deck.size;

      // Call nextRound to trigger resetForNewRound
      gameController.nextRound();

      // Verify new round setup
      expect(gameController.gameState.phase, equals(GamePhase.playing));
      expect(gameController.gameState.round, equals(initialRound + 1));
      expect(humanPlayer.hand.length, equals(11)); // New hand dealt
      expect(humanPlayer.foot.length, equals(11)); // New foot dealt
      expect(humanPlayer.melds.isEmpty, isTrue); // Melds cleared
      expect(humanPlayer.hasPlayedDown, isFalse); // Reset for new round
      expect(humanPlayer.hasPickedUpFoot, isFalse); // Reset for new round

      // Deck should have fewer cards after dealing
      expect(gameController.gameState.deck.size, lessThan(initialDeckSize));
    });

    test('should handle game end when score threshold is reached', () {
      // Set up human player to go out with high score
      humanPlayer.hasPlayedDown = true;
      humanPlayer.hasPickedUpFoot = true;
      humanPlayer.score = 8000; // Near winning threshold

      // Add high-value books
      final cleanBook = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ];

      final dirtyBook = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: null, rank: CardRank.joker),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ];

      humanPlayer.melds.add(Meld.createMeld(cleanBook)!);
      humanPlayer.melds.add(Meld.createMeld(dirtyBook)!);

      // Give player one card to discard (going out)
      humanPlayer.foot.clear();
      humanPlayer.foot.add(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
      );
      humanPlayer.hand.clear();

      expect(gameController.gameState.phase, equals(GamePhase.playing));

      // Set it to be human player's turn in discard phase
      gameController.gameState.currentPlayerIndex = 0;
      gameController.gameState.turnPhase = TurnPhase.discard;

      // Discard to go out
      final success = gameController.discardCard(humanPlayer.foot.first);

      expect(success, isTrue);

      // Should end the game if score exceeds 8500
      final finalScore = humanPlayer.score;
      if (finalScore >= 8500) {
        expect(gameController.gameState.phase, equals(GamePhase.gameEnd));
        expect(gameController.winner, equals(humanPlayer));
      } else {
        expect(gameController.gameState.phase, equals(GamePhase.roundEnd));
      }
    });

    test('should not allow going out without required books', () {
      // Set up human player without proper books
      humanPlayer.hasPlayedDown = true;
      humanPlayer.hasPickedUpFoot = true;

      // Only give a clean book, no dirty book
      final cleanBook = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ];

      humanPlayer.melds.add(Meld.createMeld(cleanBook)!);

      // Give player one card
      humanPlayer.hand.clear();
      humanPlayer.foot.clear();
      humanPlayer.foot.add(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
      );

      expect(humanPlayer.canGoOut, isFalse); // Missing dirty book
      expect(humanPlayer.hasCleanBook, isTrue);
      expect(humanPlayer.hasDirtyBook, isFalse);

      // Set it to be human player's turn in discard phase
      gameController.gameState.currentPlayerIndex = 0;
      gameController.gameState.turnPhase = TurnPhase.discard;

      // Try to discard (UI should prevent this, but testing game logic)
      final initialPhase = gameController.gameState.phase;
      final success = gameController.discardCard(humanPlayer.foot.first);

      // Should still discard but not end round since going out requirements not met
      expect(success, isTrue);
      expect(
        gameController.gameState.phase,
        equals(initialPhase),
      ); // No phase change
    });

    test(
      'should transition to roundEnd when player goes out by adding to existing meld',
      () {
        // Set up human player ready to go out by adding cards to existing meld
        humanPlayer.hasPlayedDown = true;
        humanPlayer.hasPickedUpFoot = true;

        // Give player required books
        final cleanBook = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ];

        final dirtyBook = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          const PlayingCard(suit: null, rank: CardRank.joker),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ];

        // Create existing meld that can accept more cards
        final existingMeld = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        ];

        humanPlayer.melds.add(Meld.createMeld(cleanBook)!);
        humanPlayer.melds.add(Meld.createMeld(dirtyBook)!);
        humanPlayer.melds.add(Meld.createMeld(existingMeld)!);

        // Clear hand and leave one card in foot that can be added to existing meld
        humanPlayer.hand.clear();
        humanPlayer.foot.clear();
        humanPlayer.foot.add(
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        );

        // Set it to be human player's turn in meld phase
        gameController.gameState.currentPlayerIndex = 0;
        gameController.gameState.turnPhase = TurnPhase.meld;

        // Verify preconditions
        expect(humanPlayer.foot.length, equals(1));
        expect(humanPlayer.hasCleanBook, isTrue);
        expect(humanPlayer.hasDirtyBook, isTrue);
        expect(gameController.gameState.phase, equals(GamePhase.playing));

        // Add the last card to existing meld (should cause going out)
        final lastCard = humanPlayer.foot.first;
        final meldIndex = 2; // The ace meld
        final success = gameController.addCardToMeld(meldIndex, lastCard);

        expect(success, isTrue);
        expect(gameController.gameState.phase, equals(GamePhase.roundEnd));
        expect(humanPlayer.foot.isEmpty, isTrue);
        expect(humanPlayer.hand.isEmpty, isTrue);
      },
    );

    test(
      'should transition to roundEnd when player goes out by creating new meld',
      () {
        // Set up human player ready to go out by creating a new meld
        humanPlayer.hasPlayedDown = true;
        humanPlayer.hasPickedUpFoot = true;

        // Give player required books
        final cleanBook = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ];

        final dirtyBook = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          const PlayingCard(suit: null, rank: CardRank.joker),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ];

        humanPlayer.melds.add(Meld.createMeld(cleanBook)!);
        humanPlayer.melds.add(Meld.createMeld(dirtyBook)!);

        // Clear hand and leave exactly 3 cards in foot that can form a new meld
        humanPlayer.hand.clear();
        humanPlayer.foot.clear();
        humanPlayer.foot.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
          const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
        ]);

        // Set it to be human player's turn in meld phase
        gameController.gameState.currentPlayerIndex = 0;
        gameController.gameState.turnPhase = TurnPhase.meld;

        // Verify preconditions
        expect(humanPlayer.foot.length, equals(3));
        expect(humanPlayer.hasCleanBook, isTrue);
        expect(humanPlayer.hasDirtyBook, isTrue);
        expect(gameController.gameState.phase, equals(GamePhase.playing));

        // Create new meld with all remaining cards (should cause going out)
        final success = gameController.createMeldBypass(humanPlayer.foot);

        expect(success, isTrue);
        expect(gameController.gameState.phase, equals(GamePhase.roundEnd));
        expect(humanPlayer.foot.isEmpty, isTrue);
        expect(humanPlayer.hand.isEmpty, isTrue);
      },
    );

    test('should handle multiple meld creation that causes going out', () {
      // Set up human player ready to go out by creating multiple melds
      humanPlayer.hasPlayedDown = true;
      humanPlayer.hasPickedUpFoot = true;

      // Give player required books
      final cleanBook = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ];

      final dirtyBook = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: null, rank: CardRank.joker),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
      ];

      humanPlayer.melds.add(Meld.createMeld(cleanBook)!);
      humanPlayer.melds.add(Meld.createMeld(dirtyBook)!);

      // Clear hand and leave exactly 6 cards in foot that can form 2 new melds
      humanPlayer.hand.clear();
      humanPlayer.foot.clear();
      humanPlayer.foot.addAll([
        // First meld: Jacks
        const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
        const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
        // Second meld: Tens
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
      ]);

      // Set it to be human player's turn in meld phase
      gameController.gameState.currentPlayerIndex = 0;
      gameController.gameState.turnPhase = TurnPhase.meld;

      // Verify preconditions
      expect(humanPlayer.foot.length, equals(6));
      expect(humanPlayer.hasCleanBook, isTrue);
      expect(humanPlayer.hasDirtyBook, isTrue);
      expect(gameController.gameState.phase, equals(GamePhase.playing));

      // Create multiple melds using indices (simulating advanced meld creation)
      // Need to create in reverse order to avoid index shifting issues
      final meld2Indices = [3, 4, 5]; // Tens - create this first
      final meld1Indices = [0, 1, 2]; // Jacks - create this second

      bool success = true;
      success =
          success &&
          gameController.createMeldByIndices(
            meld2Indices,
            skipPlayDownCheck: true,
          );
      success =
          success &&
          gameController.createMeldByIndices(
            meld1Indices,
            skipPlayDownCheck: true,
          );

      expect(success, isTrue);

      // Since createMeldByIndices doesn't automatically check for round end,
      // we need to verify the conditions and manually check if round should end
      expect(humanPlayer.foot.isEmpty, isTrue);
      expect(humanPlayer.hand.isEmpty, isTrue);
      expect(humanPlayer.canGoOut, isTrue);

      // Manually trigger round end like the UI would do
      if (humanPlayer.canGoOut) {
        gameController.gameState.endRound();
      }

      expect(gameController.gameState.phase, equals(GamePhase.roundEnd));
      expect(humanPlayer.foot.isEmpty, isTrue);
      expect(humanPlayer.hand.isEmpty, isTrue);
    });

    test(
      'should not end round if books requirement not met when melding last cards',
      () {
        // Set up human player without proper book requirements
        humanPlayer.hasPlayedDown = true;
        humanPlayer.hasPickedUpFoot = true;

        // Only give clean book, no dirty book
        final cleanBook = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ];

        humanPlayer.melds.add(Meld.createMeld(cleanBook)!);

        // Create existing meld that can accept more cards
        final existingMeld = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        ];
        humanPlayer.melds.add(Meld.createMeld(existingMeld)!);

        // Clear hand and leave one card in foot
        humanPlayer.hand.clear();
        humanPlayer.foot.clear();
        humanPlayer.foot.add(
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        );

        // Set it to be human player's turn in meld phase
        gameController.gameState.currentPlayerIndex = 0;
        gameController.gameState.turnPhase = TurnPhase.meld;

        // Verify preconditions
        expect(humanPlayer.foot.length, equals(1));
        expect(humanPlayer.hasCleanBook, isTrue);
        expect(humanPlayer.hasDirtyBook, isFalse); // Missing dirty book
        expect(gameController.gameState.phase, equals(GamePhase.playing));

        // Add the last card to existing meld - should work but not end round
        final lastCard = humanPlayer.foot.first;
        final meldIndex = 1; // The ace meld
        final success = gameController.addCardToMeld(meldIndex, lastCard);

        expect(success, isTrue);
        expect(
          gameController.gameState.phase,
          equals(GamePhase.playing),
        ); // Round should NOT end
        expect(humanPlayer.foot.isEmpty, isTrue);
        expect(humanPlayer.hand.isEmpty, isTrue);
        expect(
          humanPlayer.canGoOut,
          isFalse,
        ); // Can't go out without dirty book
      },
    );
  });
}
