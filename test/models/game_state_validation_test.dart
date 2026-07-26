import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Game State Validation Tests', () {
    late GameState gameState;
    late Player player;

    setUp(() {
      player = Player(id: '1', name: 'Test Player', type: PlayerType.human);
      final players = [player];
      final deck = Deck();
      gameState = GameState(players: players, deck: deck);

      gameState.phase = GamePhase.playing;
      gameState.turnPhase = TurnPhase.meld;
      gameState.hasDrawnFromDeck = true;
    });

    test('should validate normal game state without errors', () {
      // Set up normal game state
      player.hasPlayedDown = true;
      player.hasPickedUpFoot = true;

      // Add some cards to foot so player can't go out yet
      player.foot.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
      ]);

      // Create a valid meld
      final meld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ])!;
      player.melds.add(meld);

      // Capture initial actions count
      final initialActionsCount = gameState.recentActions.length;

      // This should not generate any validation errors
      gameState.validateGameState();

      // No new actions should have been added (no errors logged)
      expect(gameState.recentActions.length, equals(initialActionsCount));
    });

    test('should catch player who can go out but round has not ended', () {
      // Set up player who can go out
      player.hasPlayedDown = true;
      player.hasPickedUpFoot = true;

      // Create required clean and dirty books
      final cleanBook = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.king,
        ), // Second deck
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.king,
        ), // Second deck
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king), // Second deck
      ])!;

      final dirtyBook = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.queen,
        ), // Second deck
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.queen,
        ), // Second deck
        const PlayingCard(suit: Suit.clubs, rank: CardRank.two), // Wild card
      ])!;

      player.melds.addAll([cleanBook, dirtyBook]);

      // Player has no cards left (can go out)
      expect(player.canGoOut, isTrue);
      expect(
        gameState.phase,
        equals(GamePhase.playing),
      ); // But round hasn't ended

      // This should generate validation errors
      gameState.validateGameState();

      // Check that validation errors were logged
      final errorActions = gameState.recentActions
          .where((action) => action.message.contains('VALIDATION ERRORS'))
          .toList();
      expect(errorActions.length, greaterThan(0));

      final criticalErrors = gameState.recentActions
          .where((action) => action.message.contains('CRITICAL: Player'))
          .toList();
      expect(criticalErrors.length, greaterThan(0));
    });

    test('should catch player with foot picked up but hand not empty', () {
      // Create an impossible state
      player.hasPickedUpFoot = true;
      player.hand.add(const PlayingCard(suit: Suit.hearts, rank: CardRank.ace));
      player.foot.add(
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
      );

      // This should generate a validation error
      gameState.validateGameState();

      // Check that validation error was logged
      final errorActions = gameState.recentActions
          .where(
            (action) => action.message.contains(
              'has picked up foot but hand is not empty',
            ),
          )
          .toList();
      expect(errorActions.length, greaterThan(0));
    });

    test('does not flag the went-out player during final turns', () {
      final opponent = Player(
        id: '2',
        name: 'Opponent',
        type: PlayerType.human,
      );
      gameState.players.add(opponent);

      player.hasPlayedDown = true;
      player.hasPickedUpFoot = true;
      player.melds.addAll([
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ])!,
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        ])!,
      ]);

      gameState.finalTurnPhaseActive = true;
      gameState.playerWhoWentOutIndex = 0;
      gameState.playersAwaitingFinalTurn.add(1);
      gameState.currentPlayerIndex = 1;

      final initialActionsCount = gameState.recentActions.length;
      gameState.validateGameState();

      expect(gameState.recentActions.length, equals(initialActionsCount));
    });

    test('recoverStuckGoOutIfNeeded ends a desynced go-out round', () {
      final opponent = Player(
        id: '2',
        name: 'Opponent',
        type: PlayerType.human,
      );
      opponent.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
      ]);
      gameState.players.add(opponent);

      player.hasPlayedDown = true;
      player.hasPickedUpFoot = true;
      player.melds.addAll([
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ])!,
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        ])!,
      ]);

      expect(player.canGoOut, isTrue);
      expect(gameState.phase, GamePhase.playing);

      final recovered = gameState.recoverStuckGoOutIfNeeded();

      expect(recovered, isTrue);
      expect(gameState.phase, GamePhase.roundEnd);
      expect(
        gameState.recentActions.any(
          (action) => action.message.contains('Recovered stuck go-out'),
        ),
        isTrue,
      );
    });

    test('drawFromDeck recovers stuck go-out instead of dealing cards', () {
      final opponent = Player(
        id: '2',
        name: 'Opponent',
        type: PlayerType.human,
      );
      gameState.players.add(opponent);

      player.hasPlayedDown = true;
      player.hasPickedUpFoot = true;
      player.melds.addAll([
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ])!,
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        ])!,
      ]);

      gameState.turnPhase = TurnPhase.draw;
      gameState.hasDrawnFromDeck = false;
      final seededDeck = Deck.createHandAndFootDeck(2, seed: 99);
      gameState.deck.replaceCards(seededDeck.cards);

      expect(player.currentHand, isEmpty);
      expect(gameState.drawFromDeck(), isFalse);
      expect(player.currentHand, isEmpty);
      expect(gameState.phase, GamePhase.roundEnd);
    });

    test('should catch empty melds', () {
      // Create a meld and then manually make it empty (impossible state)
      final meld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ])!;
      player.melds.add(meld);

      // Manually clear the meld (simulating corruption)
      meld.cards.clear();

      // This should generate a validation error
      gameState.validateGameState();

      // Check that validation error was logged
      final errorActions = gameState.recentActions
          .where((action) => action.message.contains('has empty meld'))
          .toList();
      expect(errorActions.length, greaterThan(0));
    });
  });
}
