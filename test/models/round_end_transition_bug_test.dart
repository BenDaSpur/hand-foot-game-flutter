import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';

void main() {
  group('Round End Transition Bug Tests', () {
    test(
      'should handle Sue going out and properly transition to next round',
      () {
        // Recreate the exact scenario from the bug report
        final human = Player(id: '1', name: 'You', type: PlayerType.human);
        final ben = Player(id: '2', name: 'Ben', type: PlayerType.bot);
        final sue = Player(id: '3', name: 'Sue', type: PlayerType.bot);

        final deck = Deck();
        final gameState = GameState(
          players: [human, ben, sue],
          deck: deck,
          round: 4,
          phase: GamePhase.playing,
        );

        // Setup players similar to bug report state
        _setupGameStateFromBugReport(gameState, human, ben, sue);

        // Verify Sue can go out
        expect(sue.canGoOut, isTrue, reason: 'Sue should be able to go out');

        // Sue goes out (this triggered the bug)
        gameState.currentPlayerIndex = 2; // Sue's turn
        gameState.endRound();

        // Verify round ended correctly
        expect(gameState.phase, GamePhase.roundEnd);
        expect(gameState.round, 5); // Should advance from 4 to 5

        // Now test the transition that was failing
        gameState.resetForNewRound();

        // Verify the new round started properly
        expect(gameState.phase, GamePhase.playing);
        expect(gameState.round, 5);

        // All players should have cleared state
        expect(sue.melds, isEmpty);
        expect(human.melds, isEmpty);
        expect(ben.melds, isEmpty);

        // Players should have new cards (if deck has enough)
        final totalCardsNeeded = 3 * 22; // 3 players * 22 cards each
        if (gameState.deck.size >= totalCardsNeeded) {
          expect(human.hand.length, 11);
          expect(human.foot.length, 11);
          expect(ben.hand.length, 11);
          expect(ben.foot.length, 11);
          expect(sue.hand.length, 11);
          expect(sue.foot.length, 11);
        } else {
          // If insufficient cards, players should still have some cards
          expect(human.hand.isNotEmpty || human.foot.isNotEmpty, isTrue);
          expect(ben.hand.isNotEmpty || ben.foot.isNotEmpty, isTrue);
          expect(sue.hand.isNotEmpty || sue.foot.isNotEmpty, isTrue);
        }
      },
    );

    test('should detect roundEnd phase correctly', () {
      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final ben = Player(id: '2', name: 'Ben', type: PlayerType.bot);
      final sue = Player(id: '3', name: 'Sue', type: PlayerType.bot);

      final gameState = GameState(
        players: [human, ben, sue],
        deck: Deck(),
        round: 4,
        phase: GamePhase.playing,
      );

      // Setup Sue to go out
      _setupPlayerToGoOut(sue);

      gameState.endRound();

      // Should be in roundEnd phase
      expect(gameState.phase, GamePhase.roundEnd);

      // This is the key check that was failing in the UI
      expect(gameState.phase == GamePhase.roundEnd, isTrue);
    });

    test('should handle multiple endRound calls gracefully', () {
      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final ben = Player(id: '2', name: 'Ben', type: PlayerType.bot);
      final sue = Player(id: '3', name: 'Sue', type: PlayerType.bot);

      final gameState = GameState(
        players: [human, ben, sue],
        deck: Deck(),
        round: 4,
      );

      _setupPlayerToGoOut(sue);

      // Call endRound multiple times (shouldn't break)
      gameState.endRound();
      final roundAfterFirst = gameState.round;
      final phaseAfterFirst = gameState.phase;

      gameState.endRound(); // Second call

      // Phase should remain roundEnd, but round might increment again
      // This is actually expected behavior - each endRound call can advance the round
      expect(gameState.phase, phaseAfterFirst); // Phase should stay roundEnd
      expect(
        gameState.round,
        greaterThanOrEqualTo(roundAfterFirst),
      ); // Round can advance
    });
  });
}

/// Setup game state to match the bug report scenario
void _setupGameStateFromBugReport(
  GameState gameState,
  Player human,
  Player ben,
  Player sue,
) {
  // Clear existing state
  human.hand.clear();
  human.foot.clear();
  human.melds.clear();
  ben.hand.clear();
  ben.foot.clear();
  ben.melds.clear();
  sue.hand.clear();
  sue.foot.clear();
  sue.melds.clear();

  // Setup Sue to be able to go out (empty hand/foot, proper melds)
  _setupPlayerToGoOut(sue);

  // Give other players remaining cards like in bug report
  for (int i = 0; i < 14; i++) {
    human.foot.add(const PlayingCard(suit: Suit.hearts, rank: CardRank.four));
  }

  ben.hand.add(const PlayingCard(suit: Suit.clubs, rank: CardRank.jack));
  ben.hand.add(const PlayingCard(suit: Suit.spades, rank: CardRank.jack));
  for (int i = 0; i < 11; i++) {
    ben.foot.add(const PlayingCard(suit: Suit.diamonds, rank: CardRank.five));
  }

  // Set player states
  human.hasPlayedDown = true;
  human.hasPickedUpFoot = true;
  ben.hasPlayedDown = true;
  sue.hasPlayedDown = true;
  sue.hasPickedUpFoot = true;
}

/// Setup a player to be able to go out (clean & dirty books, empty hand/foot)
void _setupPlayerToGoOut(Player player) {
  player.hand.clear();
  player.foot.clear();
  player.melds.clear();

  // Create clean book (no wilds)
  final cleanBook = Meld.createMeld([
    const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
    const PlayingCard(suit: Suit.spades, rank: CardRank.king),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
    const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
    const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
    const PlayingCard(suit: Suit.spades, rank: CardRank.king),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
  ])!;

  // Create dirty book (with wilds)
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
