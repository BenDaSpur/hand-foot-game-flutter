import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Multiple Meld Going Out Tests', () {
    test(
      'should end round when player goes out via createMultipleMeldsFromIndices',
      () {
        // Create scenario like user's game state: player with books who goes out by adding cards to melds
        final player = Player(id: '1', name: 'You', type: PlayerType.human);
        final players = [player];
        final gameController = GameController(players: players);
        final gameState = gameController.gameState;

        // Set up game state for melding phase
        gameState.phase = GamePhase.playing;
        gameState.turnPhase = TurnPhase.meld;
        gameState.hasDrawnFromDeck = true;

        // Set up player who has already played down and picked up foot
        player.hasPlayedDown = true;
        player.hasPickedUpFoot = true;

        // Create existing clean and dirty books to meet going out requirements
        final cleanBook = Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ])!;

        final dirtyBook = Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two), // Wild card
        ])!;

        // Add an ace meld to add cards to
        final aceMeld = Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        ])!;

        player.melds.addAll([cleanBook, dirtyBook, aceMeld]);

        // Clear foot and add only the cards that will be melded (simulating last cards)
        player.foot.clear();
        player.foot.addAll([
          const PlayingCard(
            suit: Suit.spades,
            rank: CardRank.ace,
          ), // Will be added to ace meld
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.ace,
          ), // Will be added to ace meld
          const PlayingCard(
            suit: Suit.spades,
            rank: CardRank.two,
          ), // Wild, will be added to ace meld
        ]);

        // Verify setup
        expect(player.currentHand.length, equals(3));
        expect(player.canGoOutWithBooks, isTrue);
        expect(gameState.phase, equals(GamePhase.playing));

        // Create indices for the cards to add to the ace meld (all 3 cards in hand)
        final meldIndices = [0, 1, 2]; // All cards in hand

        // Act: Create multiple melds (in this case, adding all cards to existing ace meld)
        final success = gameController.createMultipleMeldsFromIndices([
          meldIndices,
        ]);

        // Assert: Should succeed and end the round
        expect(success, isTrue);
        expect(
          player.currentHand.isEmpty,
          isTrue,
        ); // All cards should be melded
        expect(
          gameState.phase,
          equals(GamePhase.roundEnd),
          reason:
              'Round should have ended when player went out by melding last cards',
        );

        // Verify going out message was logged
        final hasGoingOutMessage = gameState.recentActions.any(
          (action) => action.message.contains('went out and ended the round'),
        );
        expect(hasGoingOutMessage, isTrue);
      },
    );

    test('should end round when player goes out via single addCardToMeld', () {
      // Test the single card addition path
      final player = Player(id: '1', name: 'You', type: PlayerType.human);
      final players = [player];
      final gameController = GameController(players: players);
      final gameState = gameController.gameState;

      // Set up game state
      gameState.phase = GamePhase.playing;
      gameState.turnPhase = TurnPhase.meld;
      gameState.hasDrawnFromDeck = true;

      // Set up player
      player.hasPlayedDown = true;
      player.hasPickedUpFoot = true;

      // Create books
      final cleanBook = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ])!;

      final dirtyBook = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.two), // Wild
      ])!;

      player.melds.addAll([cleanBook, dirtyBook]);

      // Give player exactly one card in foot
      player.foot.clear();
      player.foot.add(
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      );

      // Verify setup
      expect(player.currentHand.length, equals(1));
      expect(player.canGoOutWithBooks, isTrue);

      // Act: Add the last card to the existing king meld (index 0)
      final success = gameController.addCardToMeld(0, player.currentHand.first);

      // Assert: Should succeed and end the round
      expect(success, isTrue);
      expect(player.currentHand.isEmpty, isTrue);
      expect(
        gameState.phase,
        equals(GamePhase.roundEnd),
        reason:
            'Round should have ended when player added their last card to a meld',
      );

      // Verify going out message was logged
      final hasGoingOutMessage = gameState.recentActions.any(
        (action) => action.message.contains('went out and ended the round'),
      );
      expect(hasGoingOutMessage, isTrue);
    });
  });
}
