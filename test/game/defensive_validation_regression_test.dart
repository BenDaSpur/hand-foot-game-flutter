import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';

/// Regression tests for defensive validation after endRound() calls.
///
/// These tests target the specific bug where defensive checks after endRound()
/// expected GamePhase.roundEnd but got GamePhase.gameEnd when someone won,
/// causing "ERROR endRound() called but phase is still gameEnd" messages.
void main() {
  group('Defensive Validation Regression Tests', () {
    test(
      'should not throw exceptions when endRound() sets phase to gameEnd',
      () {
        final players = [
          Player(id: '1', name: 'Winner', type: PlayerType.human),
          Player(id: '2', name: 'Bot', type: PlayerType.bot),
        ];

        final controller = GameController(players: players, seed: 12345);

        // Set up winning scenario
        players[0].updateScore(8600);
        players[1].updateScore(3000);

        // Set up a game state that would trigger defensive validation
        final gameState = controller.gameState;
        gameState.phase = GamePhase.playing; // Start in playing phase

        // This should complete without throwing exceptions
        expect(
          () => gameState.endRound(),
          returnsNormally,
          reason: 'endRound() should not throw when transitioning to gameEnd',
        );

        // Verify the game ended properly
        expect(gameState.phase, equals(GamePhase.gameEnd));
        expect(gameState.winner, isNotNull);
      },
    );

    test('should handle defensive validation in playMeld when game ends', () {
      final players = [
        Player(id: '1', name: 'MeldWinner', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      final controller = GameController(players: players, seed: 12345);

      // Set up a scenario where player will win after melding
      players[0].updateScore(8400); // Close to winning
      players[1].updateScore(2000);

      final gameState = controller.gameState;
      gameState.currentPlayerIndex = 0; // Set to winning player
      gameState.phase = GamePhase.playing;
      gameState.turnPhase = TurnPhase.meld;

      // Set up player for going out
      players[0].hasPlayedDown = true;
      players[0].hasPickedUpFoot = true;

      // Create required books for going out
      final cleanBook = [
        PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
        PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
        PlayingCard(rank: CardRank.ace, suit: Suit.clubs),
        PlayingCard(rank: CardRank.ace, suit: Suit.spades),
        PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
        PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
        PlayingCard(rank: CardRank.ace, suit: Suit.clubs),
      ];

      final dirtyBook = [
        PlayingCard(rank: CardRank.jack, suit: Suit.hearts),
        PlayingCard(rank: CardRank.jack, suit: Suit.diamonds),
        PlayingCard(rank: CardRank.jack, suit: Suit.clubs),
        PlayingCard(rank: CardRank.two, suit: Suit.spades), // Wild
        PlayingCard(rank: CardRank.jack, suit: Suit.hearts),
        PlayingCard(rank: CardRank.jack, suit: Suit.diamonds),
        PlayingCard(rank: CardRank.jack, suit: Suit.clubs),
      ];

      final cleanMeld = Meld.createMeld(cleanBook);
      final dirtyMeld = Meld.createMeld(dirtyBook);

      if (cleanMeld != null) players[0].melds.add(cleanMeld);
      if (dirtyMeld != null) players[0].melds.add(dirtyMeld);

      // Give player a high-value meld that will push score over winning threshold
      final winningCards = [
        PlayingCard(rank: CardRank.king, suit: Suit.hearts),
        PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
        PlayingCard(rank: CardRank.king, suit: Suit.clubs),
      ];

      // Add cards to player's hand for the meld
      for (final card in winningCards) {
        players[0].hand.add(card);
      }

      // This should trigger game end but not throw exceptions in defensive validation
      expect(
        () => gameState.playMeld(winningCards),
        returnsNormally,
        reason: 'playMeld should not throw when triggering game end',
      );
    });

    test('should handle defensive validation in addToMeld when game ends', () {
      final players = [
        Player(id: '1', name: 'AddWinner', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      final controller = GameController(players: players, seed: 12345);

      // Set up near-winning scenario
      players[0].updateScore(8450);
      players[1].updateScore(2000);

      final gameState = controller.gameState;
      gameState.currentPlayerIndex = 0;
      gameState.phase = GamePhase.playing;
      gameState.turnPhase = TurnPhase.meld;

      // Set up player for going out
      players[0].hasPlayedDown = true;
      players[0].hasPickedUpFoot = true;

      // Create books and an existing meld to add to
      final cleanBook = Meld.createMeld([
        PlayingCard(rank: CardRank.ten, suit: Suit.hearts),
        PlayingCard(rank: CardRank.ten, suit: Suit.diamonds),
        PlayingCard(rank: CardRank.ten, suit: Suit.clubs),
        PlayingCard(rank: CardRank.ten, suit: Suit.spades),
        PlayingCard(rank: CardRank.ten, suit: Suit.hearts),
        PlayingCard(rank: CardRank.ten, suit: Suit.diamonds),
        PlayingCard(rank: CardRank.ten, suit: Suit.clubs),
      ]);

      final dirtyBook = Meld.createMeld([
        PlayingCard(rank: CardRank.nine, suit: Suit.hearts),
        PlayingCard(rank: CardRank.nine, suit: Suit.diamonds),
        PlayingCard(rank: CardRank.nine, suit: Suit.clubs),
        PlayingCard(rank: CardRank.two, suit: Suit.spades), // Wild
        PlayingCard(rank: CardRank.nine, suit: Suit.hearts),
        PlayingCard(rank: CardRank.nine, suit: Suit.diamonds),
        PlayingCard(rank: CardRank.nine, suit: Suit.clubs),
      ]);

      // Add an existing meld to add cards to
      final existingMeld = Meld.createMeld([
        PlayingCard(rank: CardRank.eight, suit: Suit.hearts),
        PlayingCard(rank: CardRank.eight, suit: Suit.diamonds),
        PlayingCard(rank: CardRank.eight, suit: Suit.clubs),
      ]);

      if (cleanBook != null) players[0].melds.add(cleanBook);
      if (dirtyBook != null) players[0].melds.add(dirtyBook);
      if (existingMeld != null) players[0].melds.add(existingMeld);

      // Add a high-value card to hand that will trigger winning when added to meld
      final cardToAdd = PlayingCard(rank: CardRank.eight, suit: Suit.spades);
      players[0].hand.add(cardToAdd);

      // Find the index of the meld to add to (should be the last one added)
      final meldIndex = players[0].melds.length - 1;

      // This should trigger game end but not throw exceptions
      expect(
        () => gameState.addToMeld(meldIndex, cardToAdd),
        returnsNormally,
        reason: 'addToMeld should not throw when triggering game end',
      );
    });

    test(
      'should gracefully handle defensive validation errors without crashing',
      () {
        final players = [
          Player(id: '1', name: 'TestPlayer', type: PlayerType.human),
          Player(id: '2', name: 'Bot', type: PlayerType.bot),
        ];

        final controller = GameController(players: players, seed: 12345);

        // Set up various game end scenarios
        final testScenarios = [
          {'score': 8500, 'expectedPhase': GamePhase.gameEnd},
          {'score': 9000, 'expectedPhase': GamePhase.gameEnd},
          {'score': 10000, 'expectedPhase': GamePhase.gameEnd},
          {
            'score': 15000,
            'expectedPhase': GamePhase.gameEnd,
          }, // Very high score
        ];

        for (final scenario in testScenarios) {
          // Reset game state
          controller.gameState.phase = GamePhase.playing;
          controller.gameState.winner = null;

          // Set test score
          final score = scenario['score'] as int;
          final expectedPhase = scenario['expectedPhase'] as GamePhase;

          players[0].score = score;
          players[1].score = 1000;

          // Should handle any score without crashing
          expect(
            () => controller.gameState.endRound(),
            returnsNormally,
            reason: 'Should handle score $score without crashing',
          );

          expect(
            controller.gameState.phase,
            equals(expectedPhase),
            reason: 'Should reach expected phase for score $score',
          );
        }
      },
    );

    test('should handle concurrent endRound calls gracefully', () {
      final players = [
        Player(id: '1', name: 'Concurrent', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      final controller = GameController(players: players, seed: 12345);

      // Set winning score
      players[0].updateScore(8800);
      players[1].updateScore(3000);

      final gameState = controller.gameState;

      // First call should work normally
      gameState.endRound();
      expect(gameState.phase, equals(GamePhase.gameEnd));

      // Subsequent calls should be handled gracefully (no-op)
      expect(
        () => gameState.endRound(),
        returnsNormally,
        reason: 'Multiple endRound calls should not crash',
      );
      expect(
        gameState.phase,
        equals(GamePhase.gameEnd),
        reason: 'Phase should remain gameEnd after multiple calls',
      );
    });

    test(
      'should maintain game state consistency after defensive validation',
      () {
        final players = [
          Player(id: '1', name: 'Consistency', type: PlayerType.human),
          Player(id: '2', name: 'Test', type: PlayerType.bot),
        ];

        final controller = GameController(players: players, seed: 12345);

        // Set up winning scenario
        players[0].updateScore(9500);
        players[1].updateScore(4000);

        final gameState = controller.gameState;
        final originalWinnerScore = players[0].score;

        // Trigger game end
        gameState.endRound();

        // Verify game state remains consistent after defensive validation
        expect(gameState.phase, equals(GamePhase.gameEnd));
        expect(gameState.winner, isNotNull);
        expect(
          gameState.winner!.score,
          greaterThanOrEqualTo(originalWinnerScore),
        );
        expect(controller.isGameOver, isTrue);

        // Verify all game state properties are still valid
        expect(gameState.players.length, equals(2));
        expect(gameState.currentPlayer, isNotNull);
        expect(gameState.deck, isNotNull);
        expect(gameState.discardPile, isNotNull);
      },
    );
  });
}
