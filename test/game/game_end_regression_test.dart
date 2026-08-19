import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/game_config.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';

/// Regression tests for game end logic issues.
///
/// These tests target the specific bug where winning the game (reaching 8500+ points)
/// caused defensive validation errors because endRound() set phase to GamePhase.gameEnd
/// but the checks expected GamePhase.roundEnd.
void main() {
  group('Game End Regression Tests', () {
    test(
      'should set phase to GamePhase.gameEnd when player reaches winning score',
      () {
        final players = [
          Player(id: '1', name: 'Winner', type: PlayerType.human),
          Player(id: '2', name: 'Bot', type: PlayerType.bot),
        ];

        final controller = GameController(players: players, seed: 12345);

        // Manually set up a winning scenario by setting high scores
        players[0].updateScore(8600); // Above the 8500 threshold
        players[1].updateScore(2000);

        // Simulate game end conditions
        final gameState = controller.gameState;
        gameState.endRound(); // This should trigger game end logic

        // Verify the game ended correctly
        expect(
          gameState.phase,
          equals(GamePhase.gameEnd),
          reason: 'Game should end when player reaches 8500+ points',
        );
        expect(
          gameState.winner,
          isNotNull,
          reason: 'Winner should be set when game ends',
        );
        expect(
          gameState.winner!.name,
          equals('Winner'),
          reason: 'Correct player should be marked as winner',
        );
      },
    );

    test(
      'should handle multiple players reaching winning score simultaneously',
      () {
        final players = [
          Player(id: '1', name: 'Player1', type: PlayerType.human),
          Player(id: '2', name: 'Player2', type: PlayerType.bot),
          Player(id: '3', name: 'Player3', type: PlayerType.bot),
        ];

        final controller = GameController(players: players, seed: 12345);

        // Set up scenario where multiple players exceed threshold
        players[0].updateScore(8700); // Highest
        players[1].updateScore(8600); // Also above threshold
        players[2].updateScore(4000); // Below threshold

        final gameState = controller.gameState;
        gameState.endRound();

        // Verify game ends and highest scorer wins
        expect(gameState.phase, equals(GamePhase.gameEnd));
        expect(gameState.winner, isNotNull);
        expect(
          gameState.winner!.name,
          equals('Player1'),
          reason: 'Highest scoring player should win',
        );
      },
    );

    test(
      'should continue to next round when no player reaches winning score',
      () {
        final players = [
          Player(id: '1', name: 'Player1', type: PlayerType.human),
          Player(id: '2', name: 'Bot', type: PlayerType.bot),
        ];

        final controller = GameController(players: players, seed: 12345);
        final initialRound = controller.currentRound;

        // Set scores below winning threshold
        players[0].updateScore(7000); // Below 8500
        players[1].updateScore(6500); // Below 8500

        final gameState = controller.gameState;
        gameState.endRound();

        // Verify game continues to next round
        expect(
          gameState.phase,
          equals(GamePhase.roundEnd),
          reason: 'Game should be in roundEnd phase when continuing',
        );
        expect(
          gameState.winner,
          isNull,
          reason: 'No winner should be set when game continues',
        );
        expect(
          gameState.round,
          equals(initialRound + 1),
          reason: 'Round should increment when game continues',
        );
      },
    );

    test('should handle going out with exact winning score', () {
      final players = [
        Player(id: '1', name: 'ExactWinner', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      final controller = GameController(players: players, seed: 12345);

      // Set up exact winning score scenario
      players[0].updateScore(8500); // Exactly at threshold
      players[1].updateScore(3000);

      final gameState = controller.gameState;
      gameState.endRound();

      // Verify game ends at exact threshold
      expect(gameState.phase, equals(GamePhase.gameEnd));
      expect(gameState.winner, isNotNull);
      expect(gameState.winner!.score, equals(8500));
    });

    test(
      'should not crash when defensive checks encounter GamePhase.gameEnd',
      () {
        final players = [
          Player(id: '1', name: 'Winner', type: PlayerType.human),
          Player(id: '2', name: 'Bot', type: PlayerType.bot),
        ];

        final controller = GameController(players: players, seed: 12345);

        // Set up winning scenario
        players[0].updateScore(9000);
        players[1].updateScore(2000);

        // Set up player with required books for going out
        players[0].hasPlayedDown = true;
        players[0].hasPickedUpFoot = true;

        // Add required books (clean and dirty)
        final cleanBook = [
          PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.king, suit: Suit.clubs),
          PlayingCard(rank: CardRank.king, suit: Suit.spades),
          PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.king, suit: Suit.clubs),
        ];

        final dirtyBook = [
          PlayingCard(rank: CardRank.queen, suit: Suit.hearts),
          PlayingCard(rank: CardRank.queen, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.queen, suit: Suit.clubs),
          PlayingCard(rank: CardRank.two, suit: Suit.spades), // Wild card
          PlayingCard(rank: CardRank.queen, suit: Suit.hearts),
          PlayingCard(rank: CardRank.queen, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.queen, suit: Suit.clubs),
        ];

        // Create melds programmatically (bypass normal validation for test)
        final cleanMeld = Meld.createMeld(cleanBook);
        final dirtyMeld = Meld.createMeld(dirtyBook);

        if (cleanMeld != null) players[0].melds.add(cleanMeld);
        if (dirtyMeld != null) players[0].melds.add(dirtyMeld);

        // This should NOT throw any exceptions despite game ending
        expect(
          () => controller.gameState.endRound(),
          returnsNormally,
          reason: 'endRound() should not crash when setting phase to gameEnd',
        );

        // Verify the defensive checks pass
        expect(controller.gameState.phase, equals(GamePhase.gameEnd));
      },
    );

    test('should handle game end during different turn phases', () {
      final players = [
        Player(id: '1', name: 'Winner', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      final controller = GameController(players: players, seed: 12345);

      // Test game ending during different phases
      final testCases = [TurnPhase.draw, TurnPhase.meld, TurnPhase.discard];

      for (final phase in testCases) {
        // Reset game state
        controller.gameState.phase = GamePhase.playing;
        controller.gameState.turnPhase = phase;
        controller.gameState.winner = null;

        // Set winning score
        players[0].score = 8800;
        players[1].score = 3000;

        // Should handle game end regardless of turn phase
        expect(
          () => controller.gameState.endRound(),
          returnsNormally,
          reason: 'Should handle game end during $phase phase',
        );

        expect(
          controller.gameState.phase,
          equals(GamePhase.gameEnd),
          reason: 'Should end game during $phase phase',
        );
      }
    });

    test('should maintain correct winner reference throughout game end', () {
      final players = [
        Player(id: '1', name: 'Champion', type: PlayerType.human),
        Player(id: '2', name: 'Runner-up', type: PlayerType.bot),
        Player(id: '3', name: 'Third', type: PlayerType.bot),
      ];

      final controller = GameController(players: players, seed: 12345);

      // Set up scores with clear winner
      players[0].updateScore(10000); // Clear winner
      players[1].updateScore(7500); // High but not winning
      players[2].updateScore(4000); // Lower score

      controller.gameState.endRound();

      // Verify winner is correctly identified and maintained
      expect(controller.gameState.winner, isNotNull);
      expect(controller.gameState.winner!.id, equals('1'));
      expect(controller.gameState.winner!.name, equals('Champion'));
      expect(controller.gameState.winner!.score, equals(10000));

      // Verify winner reference is consistent
      expect(controller.winner, equals(controller.gameState.winner));
      expect(controller.isGameOver, isTrue);
    });

    test('should handle edge case of exactly 8500 with tie scores', () {
      final players = [
        Player(id: '1', name: 'Tie1', type: PlayerType.human),
        Player(id: '2', name: 'Tie2', type: PlayerType.bot),
      ];

      final controller = GameController(players: players, seed: 12345);

      // Set up tie at exact winning threshold
      players[0].updateScore(8500);
      players[1].updateScore(8500);

      controller.gameState.endRound();

      // Verify game ends and first player with highest score wins (tie-breaking)
      expect(controller.gameState.phase, equals(GamePhase.gameEnd));
      expect(controller.gameState.winner, isNotNull);
      expect(controller.gameState.winner!.score, equals(8500));
    });

    test(
      '8310 after scoring stays under the win line and can start the next round',
      () {
        // Session 17870997145344534: You were at 8310 after R3. That is below
        // 8500, so Round 4 is legal. This documents the real threshold.
        final players = [
          Player(id: '1', name: 'You', type: PlayerType.human),
          Player(id: '2', name: 'Rita', type: PlayerType.bot),
        ];
        final controller = GameController(players: players, seed: 971981);
        for (final player in players) {
          player.hand.clear();
          player.foot.clear();
          player.melds.clear();
        }
        players[0].score = 8310;
        players[1].score = 6770;

        controller.gameState.phase = GamePhase.playing;
        controller.gameState.endRound();

        expect(players[0].score, 8310);
        expect(players[0].score, lessThan(GameConfig.winningScore));
        expect(controller.gameState.phase, GamePhase.roundEnd);
        expect(controller.gameState.winner, isNull);

        controller.nextRound(dealCards: false);
        expect(controller.gameState.phase, GamePhase.playing);
      },
    );

    test(
      'score at or above 8500 ends the game; nextRound and deal are no-ops',
      () {
        final players = [
          Player(id: '1', name: 'You', type: PlayerType.human),
          Player(id: '2', name: 'Rita', type: PlayerType.bot),
        ];
        final controller = GameController(players: players, seed: 971981);
        for (final player in players) {
          player.hand.clear();
          player.foot.clear();
          player.melds.clear();
        }
        players[0].score = GameConfig.winningScore;
        players[1].score = 6770;

        controller.gameState.phase = GamePhase.playing;
        controller.gameState.endRound();

        expect(controller.gameState.phase, GamePhase.gameEnd);
        expect(controller.gameState.winner, players[0]);
        final scoreAfterWin = players[0].score;
        final roundAfterWin = controller.gameState.round;

        controller.nextRound();
        controller.prepareNewRoundDeal();
        controller.gameState.resetForNewRound();
        controller.gameState.endRound();

        expect(controller.gameState.phase, GamePhase.gameEnd);
        expect(controller.gameState.round, roundAfterWin);
        expect(players[0].score, scoreAfterWin);
        expect(players[0].hand, isEmpty);
      },
    );
  });
}
