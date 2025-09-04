import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';

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

      // Set up players to have played down
      player1.hasPlayedDown = true;
      player2.hasPlayedDown = true;
      player3.hasPlayedDown = true;
    });

    test(
      'should detect 3s stalemate after deck reshuffle with repeated 3s discarding',
      () {
        // Make deck very small to trigger low deck condition
        while (gameState.deck.size > 5) {
          gameState.deck.drawCard();
        }

        // Simulate the scenario from your game state:
        // 1. Players discard several 3s
        // 2. Deck gets reshuffled (clearing most of discard pile)
        // 3. Players continue discarding 3s
        // 4. Should detect stalemate based on recent actions, not just current discard pile

        // First, add some 3s to discard pile
        gameState.discardPile.clear();
        gameState.discardPile.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
        );

        // Simulate several 3s being discarded with force reshuffles in between
        // This mimics the pattern seen in the user's game state

        // Player 1 discards 3
        gameState.currentPlayerIndex = 0;
        gameState.turnPhase = TurnPhase.discard;
        player1.hand.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.clubs),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.three, suit: Suit.clubs),
        );

        // Player 2 discards 3
        gameState.currentPlayerIndex = 1;
        gameState.turnPhase = TurnPhase.discard;
        player2.hand.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.spades),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.three, suit: Suit.spades),
        );

        // Player 3 discards 3
        gameState.currentPlayerIndex = 2;
        gameState.turnPhase = TurnPhase.discard;
        player3.hand.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
        );

        // Simulate a force reshuffle happening (this clears most of discard pile)
        gameState.recentActions.add(
          GameAction(
            message: 'force reshuffled 6 cards from discard into deck',
            playerName: 'System',
          ),
        );

        // Clear discard pile to simulate post-reshuffle state (only a couple cards remain)
        gameState.discardPile.clear();
        gameState.discardPile.addAll([
          const PlayingCard(
            rank: CardRank.two,
            suit: Suit.hearts,
          ), // Wild card, not 3
          const PlayingCard(
            rank: CardRank.two,
            suit: Suit.spades,
          ), // Wild card, not 3
        ]);

        // Now continue with more 3s being discarded (this is where the enhanced logic should kick in)
        // Even though the current discard pile doesn't have only 3s, the recent actions show a pattern

        // Player 1 discards another 3
        gameState.currentPlayerIndex = 0;
        gameState.turnPhase = TurnPhase.discard;
        player1.hand.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
        );

        // Player 2 discards another 3
        gameState.currentPlayerIndex = 1;
        gameState.turnPhase = TurnPhase.discard;
        player2.hand.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
        );

        // At this point we should have:
        // - Recent actions showing multiple 3s discards (>=4)
        // - Recent actions showing reshuffles (>=1)
        // - Low deck (<10 cards)
        // - This should trigger the enhanced stalemate detection

        // Check that warning was shown due to enhanced detection
        final hasWarning = gameState.recentActions.any(
          (action) =>
              action.message.contains('WARNING: Only 3s in discard pile'),
        );
        expect(
          hasWarning,
          isTrue,
          reason:
              'Enhanced stalemate detection should trigger warning when recent actions show 3s pattern with reshuffles, even if current discard pile is mixed',
        );
      },
    );

    test('should end round when 3s stalemate continues after reshuffle', () {
      // Make deck very small
      while (gameState.deck.size > 5) {
        gameState.deck.drawCard();
      }

      // Set up the scenario: multiple 3s discarded, followed by reshuffle
      gameState.discardPile.clear();

      // Simulate multiple rounds of 3s being discarded with reshuffles
      for (int round = 0; round < 2; round++) {
        // Each round: all players discard 3s, then reshuffle happens
        for (int i = 0; i < 3; i++) {
          gameState.currentPlayerIndex = i;
          gameState.turnPhase = TurnPhase.discard;
          final three = PlayingCard(
            rank: CardRank.three,
            suit: Suit.values[(round * 3 + i) % 4],
          );
          gameState.players[i].hand.add(three);
          gameState.discard(three);
        }

        // Simulate reshuffle after each round
        if (round == 0) {
          gameState.recentActions.add(
            GameAction(
              message: 'force reshuffled 8 cards from discard into deck',
              playerName: 'System',
            ),
          );

          // Clear most of discard pile (simulate post-reshuffle)
          gameState.discardPile.clear();
          gameState.discardPile.addAll([
            const PlayingCard(rank: CardRank.two, suit: Suit.clubs),
            const PlayingCard(rank: CardRank.two, suit: Suit.diamonds),
          ]);
        }
      }

      // Check that stalemate was detected and round ended
      final hasStalemate = gameState.recentActions.any(
        (action) => action.message.contains('STALEMATE DETECTED'),
      );
      expect(
        hasStalemate,
        isTrue,
        reason: 'Round should end due to 3s stalemate even with reshuffles',
      );
      expect(gameState.phase, equals(GamePhase.roundEnd));
    });

    test(
      'should not trigger false positive when reshuffles happen with non-3s',
      () {
        // Make deck very small
        while (gameState.deck.size > 5) {
          gameState.deck.drawCard();
        }

        // Simulate reshuffles but with mixed card types (not all 3s)
        gameState.discardPile.clear();

        // Players discard mixed cards
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

        // Simulate reshuffle
        gameState.recentActions.add(
          GameAction(
            message: 'force reshuffled 5 cards from discard into deck',
            playerName: 'System',
          ),
        );

        // More mixed discards
        gameState.currentPlayerIndex = 0;
        gameState.turnPhase = TurnPhase.discard;
        player1.hand.add(
          const PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
        );

        // Should NOT trigger stalemate warning because not all discards were 3s
        final hasWarning = gameState.recentActions.any(
          (action) =>
              action.message.contains('WARNING: Only 3s in discard pile'),
        );
        expect(
          hasWarning,
          isFalse,
          reason:
              'Should not trigger stalemate warning when discards include non-3s',
        );
      },
    );
  });
}
