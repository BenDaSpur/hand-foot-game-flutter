import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Round Transition UI Logic Tests', () {
    test('should provide nextRound() method that calls resetForNewRound()', () {
      // Create test game state
      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final ben = Player(id: '2', name: 'Ben', type: PlayerType.bot);
      final sue = Player(id: '3', name: 'Sue', type: PlayerType.bot);

      final gameController = GameController(players: [human, ben, sue]);

      // Set up the scenario and properly end the round
      gameController.gameState.round = 4;
      _setupPlayerToGoOut(gameController.gameState.players[2]); // Sue

      // Properly end the round (this sets phase to roundEnd)
      gameController.gameState.endRound();

      // Verify round ended correctly
      expect(gameController.gameState.phase, GamePhase.roundEnd);
      expect(gameController.gameState.round, 5); // endRound increments round

      // This is what the UI should call to start the new round
      gameController.nextRound();

      // Verify it worked - new round started
      expect(gameController.gameState.phase, GamePhase.playing);
      expect(gameController.gameState.round, 5); // Same round, but now playing
    });

    test('should handle game end vs round advance correctly', () {
      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final ben = Player(id: '2', name: 'Ben', type: PlayerType.bot);
      final sue = Player(id: '3', name: 'Sue', type: PlayerType.bot);

      final gameController = GameController(players: [human, ben, sue]);

      // Set up winning scenario
      sue.updateScore(8600); // Winning score
      _setupPlayerToGoOut(gameController.gameState.players[2]);

      gameController.gameState.endRound();

      // Should end game, not advance round
      expect(gameController.gameState.phase, GamePhase.gameEnd);
      expect(gameController.gameState.winner, sue);

      // nextRound should not work when game has ended
      final finalRound = gameController.gameState.round;
      gameController.nextRound();
      expect(
        gameController.gameState.phase,
        GamePhase.gameEnd,
      ); // Still game end
      expect(gameController.gameState.round, finalRound); // Round unchanged
    });
  });
}

/// Helper to setup a player that can go out
void _setupPlayerToGoOut(Player player) {
  player.hand.clear();
  player.foot.clear();
  player.melds.clear();

  // Create clean book (7+ naturals, no wilds)
  final cleanBook = Meld.createMeld([
    const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
    const PlayingCard(suit: Suit.spades, rank: CardRank.king),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
    const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
    const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
    const PlayingCard(suit: Suit.spades, rank: CardRank.king),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
  ])!;

  // Create dirty book (7+ with wilds)
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
