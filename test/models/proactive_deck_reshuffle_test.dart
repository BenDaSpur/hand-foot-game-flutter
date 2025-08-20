import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Proactive Deck Reshuffle Tests', () {
    late GameState gameState;
    late Player player;

    setUp(() {
      player = Player(id: '1', name: 'Test Player', type: PlayerType.human);
      final players = [player];
      final deck = Deck();
      gameState = GameState(players: players, deck: deck);

      // Clear deck and discard to start with known state
      gameState.deck.replaceCards([]);
      gameState.discardPile.clear();
    });

    test('should reshuffle when deck has exactly 1 card and needs 2', () {
      // Set up: 1 card in deck, several cards in discard pile
      final deckCard = const PlayingCard(suit: Suit.hearts, rank: CardRank.ace);
      gameState.deck.addCard(deckCard);

      // Add multiple cards to discard pile for reshuffling
      final discardCards = [
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
      ];
      for (final card in discardCards) {
        gameState.discardPile.add(card);
      }

      expect(gameState.deck.size, equals(1));
      expect(gameState.discardPile.length, equals(4));

      // Set game state to allow drawing
      gameState.turnPhase = TurnPhase.draw;
      gameState.hasDrawnFromDeck = false;

      // Attempt to draw 2 cards
      final success = gameState.drawFromDeck();

      // Should succeed - reshuffle should have occurred
      expect(success, isTrue);
      expect(player.hand.length, equals(2));
      // Verify reshuffle occurred - deck should have cards from discard pile
      // (minus the top discard card that remains)
      expect(gameState.discardPile.length, equals(1)); // Top card remains
      expect(
        gameState.deck.size,
        greaterThan(0),
      ); // Should have reshuffled cards
    });

    test('should reshuffle when deck has exactly 0 cards and needs 2', () {
      // Set up: empty deck, several cards in discard pile
      expect(gameState.deck.isEmpty, isTrue);

      // Add multiple cards to discard pile for reshuffling
      final discardCards = [
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
        const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
      ];
      for (final card in discardCards) {
        gameState.discardPile.add(card);
      }

      expect(gameState.deck.size, equals(0));
      expect(gameState.discardPile.length, equals(5));

      // Set game state to allow drawing
      gameState.turnPhase = TurnPhase.draw;
      gameState.hasDrawnFromDeck = false;

      // Attempt to draw 2 cards
      final success = gameState.drawFromDeck();

      // Should succeed - reshuffle should have occurred
      expect(success, isTrue);
      expect(player.hand.length, equals(2));
      // Verify reshuffle occurred - deck should have cards from discard pile
      expect(gameState.discardPile.length, equals(1)); // Top card remains
      expect(
        gameState.deck.size,
        greaterThan(0),
      ); // Should have reshuffled cards
    });

    test('should NOT need to reshuffle when deck has 2 or more cards', () {
      // Set up: 3 cards in deck (more than required)
      final deckCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
      ];
      for (final card in deckCards) {
        gameState.deck.addCard(card);
      }

      // Add cards to discard pile (should remain untouched)
      final discardCards = [
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
      ];
      for (final card in discardCards) {
        gameState.discardPile.add(card);
      }

      expect(gameState.deck.size, equals(3));
      expect(gameState.discardPile.length, equals(2));

      // Set game state to allow drawing
      gameState.turnPhase = TurnPhase.draw;
      gameState.hasDrawnFromDeck = false;

      // Attempt to draw 2 cards
      final success = gameState.drawFromDeck();

      // Should succeed without reshuffling
      expect(success, isTrue);
      expect(player.hand.length, equals(2));
      // Verify NO reshuffle occurred - discard pile should be unchanged
      expect(gameState.discardPile.length, equals(2)); // Unchanged
      expect(gameState.deck.size, equals(1)); // 3 - 2 drawn = 1 remaining
    });

    test(
      'should fail gracefully when insufficient cards even after reshuffle',
      () {
        // Set up: empty deck, only 1 card in discard (cannot reshuffle safely)
        expect(gameState.deck.isEmpty, isTrue);

        final onlyDiscardCard = const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.ace,
        );
        gameState.discardPile.add(onlyDiscardCard);

        expect(gameState.deck.size, equals(0));
        expect(gameState.discardPile.length, equals(1));

        // Set game state to allow drawing
        gameState.turnPhase = TurnPhase.draw;
        gameState.hasDrawnFromDeck = false;

        // Attempt to draw 2 cards
        final success = gameState.drawFromDeck();

        // Should fail - cannot reshuffle with only 1 discard card
        expect(success, isFalse);
        expect(player.hand.length, equals(0)); // No cards drawn
        expect(gameState.discardPile.length, equals(1)); // Unchanged
        expect(gameState.deck.size, equals(0)); // Still empty
      },
    );

    test('should reshuffle exactly when deck has 2 cards and needs 2', () {
      // Edge case: deck has exactly the required amount
      final deckCards = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      ];
      for (final card in deckCards) {
        gameState.deck.addCard(card);
      }

      // Add cards to discard pile (should remain untouched since deck is sufficient)
      final discardCards = [
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
      ];
      for (final card in discardCards) {
        gameState.discardPile.add(card);
      }

      expect(gameState.deck.size, equals(2));
      expect(gameState.discardPile.length, equals(3));

      // Set game state to allow drawing
      gameState.turnPhase = TurnPhase.draw;
      gameState.hasDrawnFromDeck = false;

      // Attempt to draw 2 cards
      final success = gameState.drawFromDeck();

      // Should succeed without reshuffling (deck has exactly enough)
      expect(success, isTrue);
      expect(player.hand.length, equals(2));
      // Verify NO reshuffle occurred - discard pile should be unchanged
      expect(gameState.discardPile.length, equals(3)); // Unchanged
      expect(gameState.deck.size, equals(0)); // All cards drawn
    });
  });
}
