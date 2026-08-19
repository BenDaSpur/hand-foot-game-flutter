import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/game_config.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Three Stalemate With Reshuffle Tests', () {
    late GameState gameState;
    late Player player1;
    late Player player2;
    late Player player3;

    setUp(() {
      player1 = Player(id: '1', name: 'You', type: PlayerType.human);
      player2 = Player(id: '2', name: 'Alex', type: PlayerType.bot);
      player3 = Player(id: '3', name: 'Bob', type: PlayerType.bot);

      gameState = GameState(
        players: [player1, player2, player3],
        deck: Deck.createHandAndFootDeck(3, seed: 12345),
      );

      gameState.startRound();
      gameState.dealCards();

      player1.hasPlayedDown = true;
      player2.hasPlayedDown = true;
      player3.hasPlayedDown = true;
    });

    test('mixed pile after a reshuffle does not warn from recentActions', () {
      while (gameState.deck.size > 5) {
        gameState.deck.drawCard();
      }

      gameState.discardPile.clear();
      gameState.discardPile.add(
        const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
      );

      // Two 3-discards is not a full rotation, so no warning yet.
      for (var i = 0; i < 2; i++) {
        gameState.currentPlayerIndex = i;
        gameState.turnPhase = TurnPhase.discard;
        final three = PlayingCard(rank: CardRank.three, suit: Suit.values[i]);
        gameState.players[i].hand.add(three);
        gameState.discard(three);
      }

      gameState.recentActions.add(
        GameAction(
          message: 'force reshuffled 6 cards from discard into deck',
          playerName: 'System',
        ),
      );

      gameState.discardPile.clear();
      gameState.discardPile.addAll([
        const PlayingCard(rank: CardRank.two, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.two, suit: Suit.spades),
      ]);

      gameState.currentPlayerIndex = 0;
      gameState.turnPhase = TurnPhase.discard;
      player1.hand.add(
        const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
      );
      gameState.discard(
        const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
      );

      gameState.currentPlayerIndex = 1;
      gameState.turnPhase = TurnPhase.discard;
      player2.hand.add(
        const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
      );
      gameState.discard(
        const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
      );

      expect(
        gameState.recentActions.any(
          (action) =>
              action.message.contains('WARNING: Only 3s in discard pile'),
        ),
        isFalse,
        reason:
            'A mixed discard pile must not trip stalemate from older 3-discards '
            'plus a reshuffle log',
      );
      expect(gameState.phase, GamePhase.playing);
    });

    test(
      'consecutive 3s with an all-3s pile still end after two rotations',
      () {
        while (gameState.deck.size > 5) {
          gameState.deck.drawCard();
        }

        gameState.discardPile.clear();
        gameState.discardPile.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
        );

        for (int rotation = 0; rotation < 2; rotation++) {
          for (int i = 0; i < 3; i++) {
            gameState.currentPlayerIndex = i;
            gameState.turnPhase = TurnPhase.discard;
            final three = PlayingCard(
              rank: CardRank.three,
              suit: Suit.values[(rotation * 3 + i) % 4],
            );
            gameState.players[i].hand.add(three);
            gameState.discard(three);
          }
        }

        expect(
          gameState.recentActions.any(
            (action) => action.message.contains('STALEMATE DETECTED'),
          ),
          isTrue,
        );
        expect(gameState.phase, GamePhase.roundEnd);
        expect(
          gameState.emergencyRoundEndReason,
          EmergencyRoundEndReason.stalemate,
        );
      },
    );

    test(
      'should not trigger false positive when reshuffles happen with non-3s',
      () {
        while (gameState.deck.size > 5) {
          gameState.deck.drawCard();
        }

        gameState.discardPile.clear();

        gameState.currentPlayerIndex = 0;
        gameState.turnPhase = TurnPhase.discard;
        player1.hand.add(
          const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
        );

        gameState.currentPlayerIndex = 1;
        gameState.turnPhase = TurnPhase.discard;
        player2.hand.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.clubs),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.three, suit: Suit.clubs),
        );

        gameState.currentPlayerIndex = 2;
        gameState.turnPhase = TurnPhase.discard;
        player3.hand.add(
          const PlayingCard(rank: CardRank.queen, suit: Suit.spades),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.queen, suit: Suit.spades),
        );

        gameState.recentActions.add(
          GameAction(
            message: 'force reshuffled 5 cards from discard into deck',
            playerName: 'System',
          ),
        );

        gameState.currentPlayerIndex = 0;
        gameState.turnPhase = TurnPhase.discard;
        player1.hand.add(
          const PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
        );

        final hasWarning = gameState.recentActions.any(
          (action) =>
              action.message.contains('WARNING: Only 3s in discard pile'),
        );
        expect(hasWarning, isFalse);
      },
    );

    test(
      'reshuffling discard into the deck resets stalemate count',
      () {
        while (gameState.deck.size > 9) {
          gameState.deck.drawCard();
        }

        gameState.discardPile.clear();
        gameState.discardPile.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
        );

        // Five consecutive 3s: one short of ending after two rotations.
        for (var i = 0; i < 5; i++) {
          gameState.currentPlayerIndex = i % 3;
          gameState.turnPhase = TurnPhase.discard;
          final three = PlayingCard(
            rank: CardRank.three,
            suit: Suit.values[i % Suit.values.length],
          );
          gameState.players[i % 3].hand.add(three);
          gameState.discard(three);
        }

        expect(gameState.phase, GamePhase.playing);
        expect(gameState.discardPile.length, greaterThanOrEqualTo(2));

        while (gameState.deck.size > 0) {
          gameState.deck.drawCard();
        }
        gameState.turnPhase = TurnPhase.draw;
        gameState.hasDrawnFromDeck = false;
        expect(gameState.drawFromDeck(), isTrue);
        expect(
          gameState.deck.size,
          lessThan(GameConfig.stalemateDeckThreshold),
        );

        gameState.recentActions.clear();
        gameState.turnPhase = TurnPhase.discard;
        final extraThree = PlayingCard(
          rank: CardRank.three,
          suit: Suit.values[gameState.currentPlayerIndex % Suit.values.length],
        );
        gameState.currentPlayer.hand.add(extraThree);
        gameState.discard(extraThree);

        expect(gameState.phase, GamePhase.playing);
        expect(gameState.emergencyRoundEndReason, isNull);
        expect(
          gameState.recentActions.any(
            (action) => action.message.contains('STALEMATE'),
          ),
          isFalse,
        );
      },
      tags: ['regression'],
    );
  });
}
