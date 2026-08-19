import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';

void main() {
  group('Three Stalemate Detection Tests', () {
    late GameState gameState;
    late Player player1;
    late Player player2;
    late Player player3;

    setUp(() {
      player1 = Player(id: '1', name: 'Player 1', type: PlayerType.human);
      player2 = Player(id: '2', name: 'Player 2', type: PlayerType.bot);
      player3 = Player(id: '3', name: 'Player 3', type: PlayerType.bot);

      gameState = GameState(
        players: [player1, player2, player3],
        deck: Deck.createHandAndFootDeck(3, seed: 12345),
      );

      gameState.startRound();
      gameState.dealCards();

      // Set up players to have played down (required for game progression)
      player1.hasPlayedDown = true;
      player2.hasPlayedDown = true;
      player3.hasPlayedDown = true;
    });

    group('Stalemate Detection', () {
      test('should not trigger stalemate when deck has sufficient cards', () {
        // Add only 3s to discard pile
        gameState.discardPile.clear();
        gameState.discardPile.addAll([
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.three, suit: Suit.spades),
        ]);

        // Ensure deck has plenty of cards (deck.size > 10)
        // Default deck should have enough cards

        // Player discards a 3
        gameState.currentPlayerIndex = 0;
        gameState.turnPhase = TurnPhase.discard;
        final three = const PlayingCard(rank: CardRank.three, suit: Suit.clubs);
        player1.hand.add(three);

        final discarded = gameState.discard(three);
        expect(discarded, isTrue);

        // Check that warning was NOT shown
        final hasWarning = gameState.recentActions.any(
          (action) => action.message.contains('WARNING'),
        );
        expect(hasWarning, isFalse);
      });

      test('should detect stalemate when deck is low and only 3s in pile', () {
        // Make deck very small (less than 10 cards)
        while (gameState.deck.size > 9) {
          gameState.deck.drawCard();
        }
        expect(gameState.deck.size, lessThan(10));

        // Add only 3s to discard pile
        gameState.discardPile.clear();
        gameState.discardPile.addAll([
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.three, suit: Suit.spades),
        ]);

        // First player discards a 3
        gameState.currentPlayerIndex = 0;
        gameState.turnPhase = TurnPhase.discard;
        final three1 = const PlayingCard(
          rank: CardRank.three,
          suit: Suit.clubs,
        );
        player1.hand.add(three1);
        gameState.discard(three1);

        // No warning yet (first detection)
        final hasWarning1 = gameState.recentActions.any(
          (action) => action.message.contains('WARNING'),
        );
        expect(hasWarning1, isFalse);

        // Second player discards a 3
        gameState.turnPhase = TurnPhase.discard;
        final three2 = const PlayingCard(
          rank: CardRank.three,
          suit: Suit.diamonds,
        );
        player2.hand.add(three2);
        gameState.discard(three2);

        // Third player discards a 3
        gameState.turnPhase = TurnPhase.discard;
        final three3 = const PlayingCard(
          rank: CardRank.three,
          suit: Suit.hearts,
        );
        player3.hand.add(three3);
        gameState.discard(three3);

        // Now back to first player - should show warning
        gameState.turnPhase = TurnPhase.discard;
        final three4 = const PlayingCard(
          rank: CardRank.three,
          suit: Suit.spades,
        );
        player1.hand.add(three4);
        gameState.discard(three4);

        // Check that warning WAS shown after full rotation
        final hasWarning2 = gameState.recentActions.any(
          (action) =>
              action.message.contains('WARNING: Only 3s in discard pile'),
        );
        expect(hasWarning2, isTrue);
      });
    });

    group('Automatic Round Ending', () {
      test('should end round after two full rotations with only 3s', () {
        // Make deck very small
        while (gameState.deck.size > 9) {
          gameState.deck.drawCard();
        }

        // Add only 3s to discard pile
        gameState.discardPile.clear();
        gameState.discardPile.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
        );

        // First rotation - will trigger warning
        for (int i = 0; i < 3; i++) {
          gameState.currentPlayerIndex = i;
          gameState.turnPhase = TurnPhase.discard;
          final three = PlayingCard(rank: CardRank.three, suit: Suit.values[i]);
          gameState.players[i].hand.add(three);
          gameState.discard(three);
        }

        // Verify warning was shown
        final hasWarning = gameState.recentActions.any(
          (action) => action.message.contains('WARNING'),
        );
        expect(hasWarning, isTrue);

        // Second rotation - should end round
        for (int i = 0; i < 3; i++) {
          gameState.currentPlayerIndex = i;
          gameState.turnPhase = TurnPhase.discard;
          final three = PlayingCard(
            rank: CardRank.three,
            suit: Suit.values[(i + 1) % 4],
          );
          gameState.players[i].hand.add(three);

          if (i < 2) {
            // First two players discard normally
            gameState.discard(three);
            expect(gameState.phase, equals(GamePhase.playing));
          } else {
            // Third player's discard triggers round end
            gameState.discard(three);

            // Check that stalemate message was shown
            final hasStalemate = gameState.recentActions.any(
              (action) => action.message.contains('STALEMATE'),
            );
            expect(hasStalemate, isTrue);

            // Check that round ended
            expect(gameState.phase, equals(GamePhase.roundEnd));
          }
        }
      });

      test('should calculate penalties when ending due to stalemate', () {
        // Clear any melds to ensure no positive points
        player1.melds.clear();
        player2.melds.clear();
        player3.melds.clear();

        // Give players some cards in hand for penalty calculation
        player1.hand.clear();
        player1.hand.addAll([
          const PlayingCard(
            rank: CardRank.king,
            suit: Suit.hearts,
          ), // 10 points
          const PlayingCard(
            rank: CardRank.queen,
            suit: Suit.spades,
          ), // 10 points
        ]);

        player2.hand.clear();
        player2.hand.addAll([
          const PlayingCard(
            rank: CardRank.three,
            suit: Suit.hearts,
          ), // -300 penalty (red 3)
          const PlayingCard(rank: CardRank.ace, suit: Suit.clubs), // 15 points
        ]);

        // Set initial scores
        player1.score = 100;
        player2.score = 200;
        player3.score = 150;

        // Store initial scores for comparison
        final initialScore1 = player1.score;
        final initialScore2 = player2.score;

        // Make deck very small
        while (gameState.deck.size > 5) {
          gameState.deck.drawCard();
        }

        // Add only 3s to discard pile
        gameState.discardPile.clear();
        gameState.discardPile.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
        );

        // Trigger stalemate detection and warning
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

            // Check if round ended
            if (gameState.phase == GamePhase.roundEnd) {
              // Check that stalemate scoring happened
              final stalemateLog = gameState.recentActions.any(
                (action) => action.message.contains('STALEMATE'),
              );
              expect(stalemateLog, isTrue);

              // Verify scores changed (negative due to penalties)
              expect(player1.score, lessThan(initialScore1));
              expect(player2.score, lessThan(initialScore2));

              // Single endRound() scoring — no 2× pre-score + endRound
              expect(
                gameState.emergencyRoundEndReason,
                EmergencyRoundEndReason.stalemate,
              );
              expect(
                gameState.recentActions.any(
                  (action) =>
                      action.message.contains('(melds)') &&
                      action.message.contains('(cards)'),
                ),
                isFalse,
              );

              final endedRound = gameState.round - 1;
              for (final player in [player1, player2, player3]) {
                final breakdowns = player.roundScoreHistory
                    .where((b) => b.round == endedRound)
                    .toList();
                expect(breakdowns, hasLength(1));
              }
              expect(
                player1.score,
                initialScore1 +
                    player1.roundScoreHistory
                        .firstWhere((b) => b.round == endedRound)
                        .totalRoundScore,
              );
              expect(
                player2.score,
                initialScore2 +
                    player2.roundScoreHistory
                        .firstWhere((b) => b.round == endedRound)
                        .totalRoundScore,
              );

              // A second endRound() must not score again
              final scoresAfterFirstEnd = [
                player1.score,
                player2.score,
                player3.score,
              ];
              gameState.endRound();
              expect(player1.score, scoresAfterFirstEnd[0]);
              expect(player2.score, scoresAfterFirstEnd[1]);
              expect(player3.score, scoresAfterFirstEnd[2]);

              return; // Test successful
            }
          }
        }

        fail('Stalemate should have ended the round');
      });

      test('one 3-discard rotation does not end the round', () {
        while (gameState.deck.size > 9) {
          gameState.deck.drawCard();
        }
        gameState.discardPile.clear();
        gameState.discardPile.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
        );

        for (int i = 0; i < 3; i++) {
          gameState.currentPlayerIndex = i;
          gameState.turnPhase = TurnPhase.discard;
          final three = PlayingCard(rank: CardRank.three, suit: Suit.values[i]);
          gameState.players[i].hand.add(three);
          gameState.discard(three);
        }

        expect(gameState.phase, GamePhase.playing);
        expect(gameState.emergencyRoundEndReason, isNull);
        expect(
          gameState.recentActions.any(
            (action) => action.message.contains('STALEMATE'),
          ),
          isFalse,
        );
      });
    });

    group('Stalemate Reset', () {
      test('should reset stalemate tracking when non-3 is discarded', () {
        // Make deck very small
        while (gameState.deck.size > 9) {
          gameState.deck.drawCard();
        }

        // Add only 3s to discard pile
        gameState.discardPile.clear();
        gameState.discardPile.addAll([
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.three, suit: Suit.spades),
        ]);

        // First rotation with 3s
        for (int i = 0; i < 3; i++) {
          gameState.currentPlayerIndex = i;
          gameState.turnPhase = TurnPhase.discard;
          final three = PlayingCard(rank: CardRank.three, suit: Suit.values[i]);
          gameState.players[i].hand.add(three);
          gameState.discard(three);
        }

        // Back to first player - warning should appear
        gameState.currentPlayerIndex = 0;
        gameState.turnPhase = TurnPhase.discard;
        final three = const PlayingCard(rank: CardRank.three, suit: Suit.clubs);
        player1.hand.add(three);
        gameState.discard(three);

        final hasWarning = gameState.recentActions.any(
          (action) => action.message.contains('WARNING'),
        );
        expect(hasWarning, isTrue);

        // Now player 2 discards a NON-3 card
        gameState.turnPhase = TurnPhase.discard;
        final king = const PlayingCard(rank: CardRank.king, suit: Suit.hearts);
        player2.hand.add(king);
        gameState.discard(king);

        // Clear recent actions to check new behavior
        gameState.recentActions.clear();

        // Now continue with 3s again - should NOT immediately trigger stalemate
        // Need full rotation again before warning
        for (int i = 0; i < 3; i++) {
          final playerIndex = (i + 2) % 3; // Start from player 3
          gameState.currentPlayerIndex = playerIndex;
          gameState.turnPhase = TurnPhase.discard;
          final anotherThree = PlayingCard(
            rank: CardRank.three,
            suit: Suit.values[(i + 1) % 4],
          );
          gameState.players[playerIndex].hand.add(anotherThree);
          gameState.discard(anotherThree);
        }

        // Should not have ended the round yet (reset happened)
        expect(gameState.phase, equals(GamePhase.playing));
      });

      test('should reset stalemate tracking when starting new round', () {
        // This test verifies that startRound() properly resets stalemate tracking
        // First set up a stalemate warning situation
        // Make deck very small
        while (gameState.deck.size > 9) {
          gameState.deck.drawCard();
        }

        // Add only 3s to discard pile
        gameState.discardPile.clear();
        gameState.discardPile.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
        );

        // Trigger warning state
        for (int i = 0; i < 3; i++) {
          gameState.currentPlayerIndex = i;
          gameState.turnPhase = TurnPhase.discard;
          final three = PlayingCard(rank: CardRank.three, suit: Suit.values[i]);
          gameState.players[i].hand.add(three);
          gameState.discard(three);
        }

        // One more discard to trigger warning
        gameState.currentPlayerIndex = 0;
        gameState.turnPhase = TurnPhase.discard;
        final extraThree = const PlayingCard(
          rank: CardRank.three,
          suit: Suit.diamonds,
        );
        player1.hand.add(extraThree);
        gameState.discard(extraThree);

        // Verify warning was shown
        final hasInitialWarning = gameState.recentActions.any(
          (action) => action.message.contains('WARNING'),
        );
        expect(hasInitialWarning, isTrue);

        // Now start a new round - this should reset stalemate tracking
        gameState.round = 2;
        gameState.startRound();
        // Note: startRound clears the discard pile

        // Clear actions to test fresh behavior
        gameState.recentActions.clear();

        // Set up players again (startRound clears their state)
        player1.hasPlayedDown = true;
        player2.hasPlayedDown = true;
        player3.hasPlayedDown = true;

        // Make deck small again
        while (gameState.deck.size > 9) {
          gameState.deck.drawCard();
        }

        // Make sure discard pile only has 3s
        gameState.discardPile.clear();
        gameState.discardPile.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.clubs),
        );

        // Should need full rotation before warning (proving it was reset)
        // First full rotation should not trigger warning
        // Start from player 0 (currentPlayerIndex should be 0 after startRound)
        expect(gameState.currentPlayerIndex, equals(0));

        // Player 0 discards
        gameState.turnPhase = TurnPhase.discard;
        player1.hand.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
        );
        // Now currentPlayerIndex = 1

        // Player 1 discards
        gameState.turnPhase = TurnPhase.discard;
        player2.hand.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
        );
        // Now currentPlayerIndex = 2

        // Player 2 discards
        gameState.turnPhase = TurnPhase.discard;
        player3.hand.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.spades),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.three, suit: Suit.spades),
        );
        // Now currentPlayerIndex = 0 (back to player 1)

        // Warning should appear after first full rotation (this is correct behavior)
        final hasWarningFirstRotation = gameState.recentActions.any(
          (action) => action.message.contains('WARNING'),
        );
        expect(
          hasWarningFirstRotation,
          isTrue,
          reason:
              'Warning should appear after first full rotation when conditions are met',
        );

        // Continue for SECOND full rotation to test if stalemate is properly triggered
        // (This tests that the counter was properly reset and is now counting correctly)

        // Player 0 discards again
        gameState.turnPhase = TurnPhase.discard;
        player1.hand.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.clubs),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.three, suit: Suit.clubs),
        );

        // Player 1 discards again
        gameState.turnPhase = TurnPhase.discard;
        player2.hand.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
        );

        // Player 2 discards again (second full rotation complete)
        gameState.turnPhase = TurnPhase.discard;
        player3.hand.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
        );
        gameState.discard(
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
        );

        // NOW stalemate should be detected and round should end
        final hasStalemate = gameState.recentActions.any(
          (action) => action.message.contains('STALEMATE'),
        );
        expect(
          hasStalemate,
          isTrue,
          reason: 'Stalemate should be detected after second full rotation',
        );
        expect(gameState.phase, GamePhase.roundEnd);
      });
    });

    group('Edge Cases', () {
      test('should handle stalemate with only 2 players', () {
        // Create 2-player game
        final twoPlayerGame = GameState(
          players: [player1, player2],
          deck: Deck.createHandAndFootDeck(2, seed: 54321),
        );
        twoPlayerGame.startRound();
        twoPlayerGame.dealCards();

        player1.hasPlayedDown = true;
        player2.hasPlayedDown = true;

        // Make deck very small
        while (twoPlayerGame.deck.size > 9) {
          twoPlayerGame.deck.drawCard();
        }

        // Add only 3s to discard pile
        twoPlayerGame.discardPile.clear();
        twoPlayerGame.discardPile.add(
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
        );

        // First rotation
        for (int i = 0; i < 2; i++) {
          twoPlayerGame.currentPlayerIndex = i;
          twoPlayerGame.turnPhase = TurnPhase.discard;
          final three = PlayingCard(rank: CardRank.three, suit: Suit.values[i]);
          twoPlayerGame.players[i].hand.add(three);
          twoPlayerGame.discard(three);
        }

        // Back to first player - should show warning
        twoPlayerGame.currentPlayerIndex = 0;
        twoPlayerGame.turnPhase = TurnPhase.discard;
        final three3 = const PlayingCard(
          rank: CardRank.three,
          suit: Suit.clubs,
        );
        player1.hand.add(three3);
        twoPlayerGame.discard(three3);

        final hasWarning = twoPlayerGame.recentActions.any(
          (action) => action.message.contains('WARNING'),
        );
        expect(hasWarning, isTrue);
      });

      test('should not trigger stalemate with mixed cards in discard pile', () {
        // Make deck very small
        while (gameState.deck.size > 9) {
          gameState.deck.drawCard();
        }

        // Add mixed cards (not only 3s) to discard pile
        gameState.discardPile.clear();
        gameState.discardPile.addAll([
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.king, suit: Suit.spades), // Not a 3!
          const PlayingCard(rank: CardRank.three, suit: Suit.clubs),
        ]);

        // Players discard 3s
        for (int i = 0; i < 3; i++) {
          gameState.currentPlayerIndex = i;
          gameState.turnPhase = TurnPhase.discard;
          final three = PlayingCard(rank: CardRank.three, suit: Suit.values[i]);
          gameState.players[i].hand.add(three);
          gameState.discard(three);
        }

        // Should NOT show warning because discard pile has non-3 cards
        final hasWarning = gameState.recentActions.any(
          (action) => action.message.contains('WARNING'),
        );
        expect(hasWarning, isFalse);
      });
    });
  });
}
