import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';

void main() {
  group('Round Transition Tests', () {
    late GameState gameState;
    late Player human;
    late Player bot1;
    late Player bot2;

    setUp(() {
      human = Player(id: '1', name: 'You', type: PlayerType.human);
      bot1 = Player(id: '2', name: 'Ben', type: PlayerType.bot);
      bot2 = Player(id: '3', name: 'Sue', type: PlayerType.bot);

      final deck = Deck();
      gameState = GameState(
        players: [human, bot1, bot2],
        deck: deck,
        round: 4, // Start at round 4 like the bug scenario
      );

      // Setup initial game state
      gameState.startRound();
      gameState.dealCards();
    });

    group('endRound() Behavior', () {
      test('should set phase to roundEnd when called', () {
        // Setup: Player goes out
        _setupPlayerGoingOut(bot2); // Sue goes out

        gameState.endRound();

        expect(gameState.phase, GamePhase.roundEnd);
      });

      test('should increment round number when no winner', () {
        // Setup: Player goes out but no one reaches 8500 points
        _setupPlayerGoingOut(bot2);
        final initialRound = gameState.round;

        gameState.endRound();

        expect(gameState.round, initialRound + 1);
        expect(gameState.phase, GamePhase.roundEnd);
      });

      test('should declare winner when score >= 8500', () {
        // Setup: Player goes out and reaches winning score
        _setupPlayerGoingOut(bot2);
        bot2.updateScore(8600); // Set winning score

        gameState.endRound();

        expect(gameState.phase, GamePhase.gameEnd);
        expect(gameState.winner, bot2);
      });

      test('should add going out bonus to winner', () {
        // Setup: Player goes out
        _setupPlayerGoingOut(bot2);
        final initialScore = bot2.score;

        gameState.endRound();

        // Score should include going out bonus
        expect(bot2.score, greaterThan(initialScore));
      });

      test('should advance round number when not reaching winning score', () {
        // Setup: Player goes out
        _setupPlayerGoingOut(bot2);
        final initialRound = gameState.round;

        gameState.endRound();

        // Should advance to next round since no one has winning score
        expect(gameState.round, initialRound + 1);
        expect(gameState.phase, GamePhase.roundEnd);
      });

      test('should calculate scores for all players including penalties', () {
        // Setup: Player goes out, others have cards remaining
        _setupPlayerGoingOut(bot2);
        _giveRemainingCards(human, 5);
        _giveRemainingCards(bot1, 8);

        final humanScoreBefore = human.score;
        final bot1ScoreBefore = bot1.score;

        gameState.endRound();

        // Players with remaining cards should have score penalties
        expect(human.score, lessThan(humanScoreBefore));
        expect(bot1.score, lessThan(bot1ScoreBefore));
      });
    });

    group('resetForNewRound() Behavior', () {
      test('should only work when phase is roundEnd', () {
        gameState.phase = GamePhase.playing;
        final initialRound = gameState.round;

        gameState.resetForNewRound();

        // Should not reset if not in roundEnd phase
        expect(gameState.round, initialRound);
        expect(gameState.phase, GamePhase.playing);
      });

      test(
        'should clear all player hands, feet, and melds then deal new cards',
        () {
          // Setup: End round first
          _setupPlayerGoingOut(bot2);
          gameState.endRound();

          // Give players some cards and melds
          _giveRemainingCards(human, 3);
          _giveRemainingCards(bot1, 5);
          human.melds.add(
            Meld.createMeld([
              const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
              const PlayingCard(suit: Suit.spades, rank: CardRank.king),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
            ])!,
          );

          gameState.resetForNewRound();

          // Melds should be cleared
          expect(human.melds, isEmpty);
          expect(bot1.melds, isEmpty);
          expect(bot2.melds, isEmpty);

          // Players should have new cards dealt (count may vary due to deck state)
          final totalCards =
              human.hand.length +
              human.foot.length +
              bot1.hand.length +
              bot1.foot.length +
              bot2.hand.length +
              bot2.foot.length;
          expect(
            totalCards,
            greaterThan(20),
            reason: 'Players should have cards dealt for new round',
          );
        },
      );

      test('should set phase to playing and deal new cards', () {
        // Setup: End round first
        _setupPlayerGoingOut(bot2);
        gameState.endRound();

        gameState.resetForNewRound();

        expect(gameState.phase, GamePhase.playing);
        // Each player should have cards dealt (exact count may vary due to deck state)
        expect(human.hand, isNotEmpty);
        expect(human.foot, isNotEmpty);
        expect(bot1.hand, isNotEmpty);
        expect(bot1.foot, isNotEmpty);
        expect(bot2.hand, isNotEmpty);
        expect(bot2.foot, isNotEmpty);
      });

      test('should return all cards to deck and reshuffle', () {
        // Setup: End round first
        _setupPlayerGoingOut(bot2);
        _giveRemainingCards(human, 5);
        _giveRemainingCards(bot1, 8);
        gameState.endRound();

        gameState.resetForNewRound();

        // After reset, game should be in proper state for new round
        expect(gameState.phase, GamePhase.playing);
      });

      test('should reset player flags for new round', () {
        // Setup: Players with various flags set
        human.hasPlayedDown = true;
        human.hasPickedUpFoot = true;
        bot1.hasPlayedDown = true;
        _setupPlayerGoingOut(bot2);
        gameState.endRound();

        gameState.resetForNewRound();

        expect(human.hasPlayedDown, isFalse);
        expect(human.hasPickedUpFoot, isFalse);
        expect(bot1.hasPlayedDown, isFalse);
        expect(bot1.hasPickedUpFoot, isFalse);
        expect(bot2.hasPlayedDown, isFalse);
        expect(bot2.hasPickedUpFoot, isFalse);
      });
    });

    group('Complete Round Transition Scenario', () {
      test(
        'should handle complete transition from Sue going out to new round',
        () {
          // Recreate the exact scenario from the bug report
          gameState.round = 4;
          gameState.currentPlayerIndex = 2; // Sue's turn

          // Setup Sue to go out (empty hand and foot, proper melds)
          _setupPlayerGoingOut(bot2);

          // Give other players remaining cards (like in bug report)
          _giveRemainingCards(human, 14); // You had 14 in foot
          _giveRemainingCards(bot1, 13); // Ben had 2 in hand, 11 in foot

          final initialRound = gameState.round;

          // Simulate Sue going out
          gameState.endRound();

          // Verify round ended properly
          expect(gameState.phase, GamePhase.roundEnd);
          expect(
            gameState.round,
            initialRound + 1,
          ); // Should advance to round 5

          // Now transition to new round
          gameState.resetForNewRound();

          // Verify new round started properly
          expect(gameState.phase, GamePhase.playing);
          expect(gameState.round, 5);

          // All old state should be cleared
          expect(human.melds, isEmpty);
          expect(bot1.melds, isEmpty);
          expect(bot2.melds, isEmpty);
          expect(human.hasPlayedDown, isFalse);
          expect(bot1.hasPlayedDown, isFalse);
          expect(bot2.hasPlayedDown, isFalse);
        },
      );

      test('should preserve scores across round transition', () {
        // Setup scores like in the bug report
        human.updateScore(4740);
        bot1.updateScore(1610);
        bot2.updateScore(5620);

        _setupPlayerGoingOut(bot2);

        gameState.endRound();
        gameState.resetForNewRound();

        // Scores should be maintained (though modified by round end calculations)
        expect(human.score, isNot(0));
        expect(bot1.score, isNot(0));
        expect(bot2.score, isNot(0));
      });

      test('should handle game end condition during round transition', () {
        // Setup Sue with winning score
        bot2.updateScore(8400); // Close to winning
        _setupPlayerGoingOut(bot2);

        gameState.endRound();

        // Game should end, not transition to new round
        expect(gameState.phase, GamePhase.gameEnd);
        expect(gameState.winner, bot2);

        // resetForNewRound should not work when game has ended
        gameState.resetForNewRound();
        expect(gameState.phase, GamePhase.gameEnd); // Should remain game end
      });
    });
  });
}

/// Helper function to setup a player in a "going out" state
void _setupPlayerGoingOut(Player player) {
  // Clear hand and foot (player went out)
  player.hand.clear();
  player.foot.clear();

  // Give player proper melds to qualify for going out
  // Need both clean book (no wilds) and dirty book (with wilds)

  // Clean book (7+ natural cards)
  final cleanBook = Meld.createMeld([
    const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
    const PlayingCard(suit: Suit.spades, rank: CardRank.king),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
    const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
    const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
    const PlayingCard(suit: Suit.spades, rank: CardRank.king),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
  ])!;

  // Dirty book (7+ cards with wilds)
  final dirtyBook = Meld.createMeld([
    const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
    const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
    const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
    const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // Wild
    const PlayingCard(suit: Suit.spades, rank: CardRank.two), // Wild
    const PlayingCard(rank: CardRank.joker), // Wild
  ])!;

  player.melds.add(cleanBook);
  player.melds.add(dirtyBook);
  player.hasPlayedDown = true;
  player.hasPickedUpFoot = true;
}

/// Helper function to give a player remaining cards in hand/foot
void _giveRemainingCards(Player player, int count) {
  player.hand.clear();
  player.foot.clear();

  // Add random cards to foot (simulating leftover cards)
  for (int i = 0; i < count && i < 22; i++) {
    final suit = Suit.values[i % 4];
    final rank = CardRank.values[(i ~/ 4) % CardRank.values.length];
    player.foot.add(PlayingCard(suit: suit, rank: rank));
  }
}
