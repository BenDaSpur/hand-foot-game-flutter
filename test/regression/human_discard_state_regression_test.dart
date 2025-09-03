import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

/// Regression test for the human player discard state handling bug.
///
/// This test ensures that human players receive the same post-discard
/// state handling as bot players, preventing the UI freeze issue where
/// discarding would appear to do nothing until the recent events dialog
/// was opened.
void main() {
  group('Human Discard State Regression Tests', () {
    late GameController gameController;
    late GameState gameState;
    late Player humanPlayer;

    setUp(() {
      gameController = GameController(
        players: [
          Player(id: 'human-1', name: 'TestHuman', type: PlayerType.human),
          Player(id: 'bot-1', name: 'Bot1', type: PlayerType.bot),
          Player(id: 'bot-2', name: 'Bot2', type: PlayerType.bot),
        ],
      );
      gameState = gameController.gameState;

      humanPlayer = gameState.players[0];
      gameState.startRound(); // Initialize the game properly
      gameState.currentPlayerIndex = 0;
      gameState.turnPhase = TurnPhase.discard;
      gameState.hasDrawnFromDeck = true;
    });

    test('human discard should trigger state transitions like bot players', () {
      // This is the core regression test - ensuring human discards trigger
      // the same state handling logic as bot discards

      // Setup: Human player with one card in hand and cards in foot
      humanPlayer.hand.clear();
      humanPlayer.foot.clear();

      final discardCard = PlayingCard(rank: CardRank.five, suit: Suit.hearts);
      humanPlayer.addCardToHand(discardCard);

      // Add cards to foot so foot pickup is meaningful
      humanPlayer.foot.add(PlayingCard(rank: CardRank.six, suit: Suit.hearts));
      humanPlayer.foot.add(
        PlayingCard(rank: CardRank.seven, suit: Suit.hearts),
      );

      expect(humanPlayer.hasPickedUpFoot, false);
      expect(humanPlayer.currentHand.length, 1);
      expect(humanPlayer.foot.length, 2);

      // Act: Discard the only card in hand
      final success = gameController.discardCard(discardCard);

      // Assert: Player should have picked up foot automatically
      expect(success, true);
      expect(
        humanPlayer.hasPickedUpFoot,
        true,
        reason:
            'Human discard should trigger foot pickup when hand becomes empty',
      );
      expect(
        humanPlayer.currentHand.length,
        2,
        reason: 'Player should have picked up foot after emptying hand',
      );
      expect(gameState.discardPile.last, discardCard);
    });

    test('human discard should advance turn to next player', () {
      // Setup: Human player with cards, not going out scenario
      humanPlayer.hand.clear();
      humanPlayer.addCardToHand(
        PlayingCard(rank: CardRank.nine, suit: Suit.diamonds),
      );
      humanPlayer.addCardToHand(
        PlayingCard(rank: CardRank.ten, suit: Suit.diamonds),
      );

      final discardCard = humanPlayer.currentHand.first;
      final initialPlayerIndex = gameState.currentPlayerIndex;

      expect(gameState.currentPlayerIndex, 0); // Human player index

      // Act: Discard a card (not going out)
      final success = gameController.discardCard(discardCard);

      // Assert: Turn should advance to next player
      expect(success, true);
      expect(
        gameState.currentPlayerIndex,
        (initialPlayerIndex + 1) % gameState.players.length,
        reason: 'Turn should advance to next player after human discard',
      );
      expect(
        gameState.turnPhase,
        TurnPhase.draw,
        reason: 'Next player should be in draw phase',
      );
    });

    test('human discard should not cause UI state inconsistency', () {
      // This test simulates the original bug scenario
      // Setup: Player ready to discard
      humanPlayer.hand.clear();
      final card1 = PlayingCard(rank: CardRank.seven, suit: Suit.hearts);
      final card2 = PlayingCard(rank: CardRank.eight, suit: Suit.hearts);
      humanPlayer.addCardToHand(card1);
      humanPlayer.addCardToHand(card2);

      final initialPhase = gameState.phase;
      final initialTurnPhase = gameState.turnPhase;

      expect(initialPhase, GamePhase.playing);
      expect(initialTurnPhase, TurnPhase.discard);

      // Act: Perform discard
      final success = gameController.discardCard(card1);

      // Assert: Game state should be properly updated
      expect(success, true);
      expect(
        gameState.phase,
        anyOf(GamePhase.playing, GamePhase.roundEnd),
        reason: 'Game phase should be in valid state after discard',
      );

      // Verify the discard actually happened
      expect(
        gameState.discardPile.contains(card1),
        true,
        reason: 'Discarded card should appear in discard pile',
      );
      expect(
        humanPlayer.currentHand.contains(card1),
        false,
        reason: 'Discarded card should no longer be in player hand',
      );

      // Verify turn progression occurred
      if (gameState.phase == GamePhase.playing) {
        expect(
          gameState.currentPlayerIndex != 0 ||
              gameState.turnPhase == TurnPhase.draw,
          true,
          reason: 'Either turn should advance or phase should change',
        );
      }
    });
  });
}
