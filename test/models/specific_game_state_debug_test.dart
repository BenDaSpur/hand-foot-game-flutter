import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Specific Game State Debug Tests', () {
    test('should end round when reproducing exact JSON state scenario', () {
      // Create the exact game state from the provided JSON
      final player = Player(
        id: '1',
        name: 'Test Player',
        type: PlayerType.human,
      );
      final players = [player];
      final deck = Deck();
      final gameState = GameState(players: players, deck: deck);

      // Set up game state to match JSON
      gameState.phase = GamePhase.playing;
      gameState.turnPhase = TurnPhase.meld;
      gameState.hasDrawnFromDeck = true;
      gameState.round = 1;

      // Set up player state to match JSON
      player.hasPlayedDown = true;
      player.hasPickedUpFoot = true;
      player.score = 205;

      // Create the exact melds from JSON
      // Meld 1: Clean book of Kings (7 cards)
      final cleanBook = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.king,
        ), // Second deck
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.king,
        ), // Second deck
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king), // Second deck
      ])!;

      // Meld 2: Dirty book with wilds (7+ cards)
      final dirtyBook = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.queen,
        ), // Second deck
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.queen,
        ), // Second deck
        const PlayingCard(suit: Suit.clubs, rank: CardRank.two), // Wild card
      ])!;

      // Meld 3: Incomplete meld that will be completed
      final incompleteMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ])!;

      player.melds.addAll([cleanBook, dirtyBook, incompleteMeld]);

      // Verify player meets going out requirements BEFORE adding final card
      expect(
        player.hasCleanBook,
        isTrue,
        reason: 'Player should have clean book',
      );
      expect(
        player.hasDirtyBook,
        isTrue,
        reason: 'Player should have dirty book',
      );
      expect(
        player.canGoOutWithBooks,
        isTrue,
        reason: 'Player should be able to go out with books',
      );

      // Player has exactly 1 card left in foot (the final card to add)
      final finalCard = const PlayingCard(
        suit: Suit.spades,
        rank: CardRank.ace,
      );
      player.foot.add(finalCard);

      // Verify initial state
      expect(
        player.foot.length,
        equals(1),
        reason: 'Player should have 1 card in foot',
      );
      expect(
        player.currentHand.length,
        equals(1),
        reason: 'Current hand size should be 1',
      );
      expect(
        player.canGoOutWithBooks,
        isTrue,
        reason: 'Player should have required books to go out',
      );
      expect(
        gameState.phase,
        equals(GamePhase.playing),
        reason: 'Game should be in playing phase initially',
      );

      print('Before addToMeld:');
      print('  - Player canGoOut: ${player.canGoOut}');
      print('  - Player foot size: ${player.foot.length}');
      print('  - Player has clean book: ${player.hasCleanBook}');
      print('  - Player has dirty book: ${player.hasDirtyBook}');
      print('  - Game phase: ${gameState.phase}');

      // Add the final card to the incomplete meld - this should end the round
      final success = gameState.addToMeld(
        2,
        finalCard,
      ); // Add to third meld (index 2)

      print('After addToMeld:');
      print('  - Success: $success');
      print('  - Player foot size: ${player.foot.length}');
      print('  - Player canGoOut: ${player.canGoOut}');
      print('  - Game phase: ${gameState.phase}');

      // Verify the operation succeeded
      expect(success, isTrue, reason: 'Adding card to meld should succeed');
      expect(
        player.foot.isEmpty,
        isTrue,
        reason: 'Player foot should be empty after adding last card',
      );
      expect(
        player.canGoOut,
        isTrue,
        reason: 'Player should still be able to go out',
      );

      // CRITICAL CHECK: Round should have ended
      expect(
        gameState.phase,
        equals(GamePhase.roundEnd),
        reason: 'Round should have ended when player went out',
      );
    });

    test('should debug addToMeld method execution flow', () {
      // Create a minimal test case to debug the method execution
      final player = Player(
        id: '1',
        name: 'Test Player',
        type: PlayerType.human,
      );
      final players = [player];
      final deck = Deck();
      final gameState = GameState(players: players, deck: deck);

      // Set up minimal state
      gameState.phase = GamePhase.playing;
      gameState.turnPhase = TurnPhase.meld;
      gameState.hasDrawnFromDeck = true;
      player.hasPlayedDown = true;
      player.hasPickedUpFoot = true;

      // Create required books
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

      final incompleteMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ])!;

      player.melds.addAll([cleanBook, dirtyBook, incompleteMeld]);

      // Add exactly one card to foot
      final finalCard = const PlayingCard(
        suit: Suit.spades,
        rank: CardRank.ace,
      );
      player.foot.add(finalCard);

      // Verify preconditions
      expect(player.canGoOutWithBooks, isTrue);
      expect(gameState.phase, equals(GamePhase.playing));

      // Call addToMeld and verify it triggers round end
      final result = gameState.addToMeld(2, finalCard);

      expect(result, isTrue);
      expect(player.foot.isEmpty, isTrue);
      expect(gameState.phase, equals(GamePhase.roundEnd));
    });
  });
}
