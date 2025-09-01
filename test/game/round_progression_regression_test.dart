import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Round Progression Regression Tests', () {
    late GameController controller;
    late Player humanPlayer;
    late Player botPlayer;

    setUp(() {
      humanPlayer = Player(id: '1', name: 'Human', type: PlayerType.human);
      botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

      controller = GameController(players: [humanPlayer, botPlayer]);
      controller.initializeGame();
    });

    group('Round Increment Protection', () {
      test('should increment round by exactly 1 when player goes out', () {
        final gameState = controller.gameState;
        final initialRound = gameState.round;

        // Set up bot to go out
        _setupPlayerToGoOut(botPlayer);

        // Trigger round end
        gameState.endRound();

        // Round should increment by exactly 1
        expect(gameState.round, equals(initialRound + 1));
      });

      test(
        'should prevent multiple endRound calls from double incrementing',
        () {
          final gameState = controller.gameState;
          final initialRound = gameState.round;

          // Call endRound multiple times
          gameState.endRound();
          final firstCallRound = gameState.round;

          gameState.endRound(); // Second call should be ignored
          gameState.endRound(); // Third call should be ignored

          // Round should only increment once
          expect(firstCallRound, equals(initialRound + 1));
          expect(gameState.round, equals(initialRound + 1));
          expect(gameState.phase, equals(GamePhase.roundEnd));
        },
      );

      test('should not increment round again if already in roundEnd phase', () {
        final gameState = controller.gameState;

        // First endRound call
        gameState.endRound();
        final firstRound = gameState.round;
        expect(gameState.phase, equals(GamePhase.roundEnd));

        // Second endRound call should be ignored
        gameState.endRound();
        expect(gameState.round, equals(firstRound));
        expect(gameState.phase, equals(GamePhase.roundEnd));
      });
    });

    group('Round History Protection', () {
      test('should prevent duplicate round score entries', () {
        // Record round score for round 1
        botPlayer.recordRoundScoreBreakdown(round: 1, wentOut: false);
        final firstEntryCount = botPlayer.roundScoreHistory.length;

        // Try to record same round again
        botPlayer.recordRoundScoreBreakdown(round: 1, wentOut: true);

        // Should not add duplicate entry
        expect(botPlayer.roundScoreHistory.length, equals(firstEntryCount));

        // Original entry should be preserved
        final round1Entry = botPlayer.roundScoreHistory.firstWhere(
          (r) => r.round == 1,
        );
        expect(
          round1Entry.goingOutBonus,
          equals(0),
        ); // Original entry had wentOut: false
      });

      test('should allow different rounds to be recorded normally', () {
        // Record multiple different rounds
        botPlayer.recordRoundScoreBreakdown(round: 1, wentOut: false);
        botPlayer.recordRoundScoreBreakdown(round: 2, wentOut: true);
        botPlayer.recordRoundScoreBreakdown(round: 3, wentOut: false);

        // All should be recorded
        expect(botPlayer.roundScoreHistory.length, equals(3));
        expect(
          botPlayer.roundScoreHistory.map((r) => r.round).toList(),
          equals([1, 2, 3]),
        );
      });

      test('should handle concurrent round recording attempts', () {
        final initialCount = botPlayer.roundScoreHistory.length;

        // Simulate multiple rapid calls for same round
        for (int i = 0; i < 5; i++) {
          botPlayer.recordRoundScoreBreakdown(round: 5, wentOut: i.isEven);
        }

        // Only one entry should be added
        expect(botPlayer.roundScoreHistory.length, equals(initialCount + 1));

        final round5Entries = botPlayer.roundScoreHistory.where(
          (r) => r.round == 5,
        );
        expect(round5Entries.length, equals(1));
      });
    });

    group('Normal Round Progression Flow', () {
      test('should progress through rounds sequentially', () {
        final gameState = controller.gameState;

        // Start at round 1
        expect(gameState.round, equals(1));
        expect(gameState.playDownRequirement, equals(60));

        // End round 1
        _setupPlayerToGoOut(botPlayer);
        gameState.endRound();

        // Should be in round 2
        expect(gameState.round, equals(2));
        expect(gameState.playDownRequirement, equals(90));

        // Reset and setup round 2
        controller.nextRound();
        expect(gameState.phase, equals(GamePhase.playing));

        // End round 2
        _setupPlayerToGoOut(humanPlayer);
        gameState.endRound();

        // Should be in round 3
        expect(gameState.round, equals(3));
        expect(gameState.playDownRequirement, equals(120));
      });

      test('should maintain correct round history sequence', () {
        final gameState = controller.gameState;

        // Complete round 1
        _setupPlayerToGoOut(botPlayer);
        gameState.endRound();
        controller.nextRound();

        // Complete round 2
        _setupPlayerToGoOut(humanPlayer);
        gameState.endRound();
        controller.nextRound();

        // Check both players have sequential round history
        expect(
          humanPlayer.roundScoreHistory.map((r) => r.round).toList(),
          equals([1, 2]),
        );
        expect(
          botPlayer.roundScoreHistory.map((r) => r.round).toList(),
          equals([1, 2]),
        );

        // No gaps or duplicates
        expect(gameState.round, equals(3));
      });

      test('should handle game end at 8500+ points correctly', () {
        final gameState = controller.gameState;

        // Give a player high score (but not quite game-ending)
        humanPlayer.updateScore(8400);

        // Setup player to go out, which will add going out bonus to push over 8500
        _setupPlayerToGoOut(humanPlayer);
        gameState.endRound();

        // Should end game when total score exceeds 8500
        expect(gameState.phase, equals(GamePhase.gameEnd));
        expect(gameState.winner, equals(humanPlayer));
        expect(humanPlayer.score, greaterThan(8500));
      });
    });
  });
}

/// Helper function to set up a player to be able to go out
void _setupPlayerToGoOut(Player player) {
  // Clear current state
  player.hand.clear();
  player.foot.clear();
  player.melds.clear();

  // Add required books for going out
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
    const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
    const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
    const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
    const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
    const PlayingCard(suit: null, rank: CardRank.joker), // Wild card
    const PlayingCard(suit: null, rank: CardRank.joker), // Wild card
  ];

  player.melds.add(Meld.createMeld(cleanBook)!);
  player.melds.add(Meld.createMeld(dirtyBook)!);
  player.hasPlayedDown = true;
  player.hasPickedUpFoot = true;
}
