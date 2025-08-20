import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Deck Reshuffle Edge Cases', () {
    late GameState gameState;
    late List<Player> players;

    setUp(() {
      players = [
        Player(id: '1', name: 'Player 1', type: PlayerType.human),
        Player(id: '2', name: 'Bot 2', type: PlayerType.bot),
      ];
      final deck = Deck();
      gameState = GameState(players: players, deck: deck);
    });

    test('should handle deck empty with sufficient discard cards', () {
      // Empty the deck
      while (!gameState.deck.isEmpty) {
        gameState.deck.drawCard();
      }

      // Add cards to discard pile to simulate game progression
      gameState.discardPile.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
      ]);

      expect(gameState.deck.isEmpty, isTrue);
      expect(gameState.discardPile.length, equals(4));

      // Attempt to draw - should trigger reshuffle
      final drawSuccess = gameState.drawFromDeck();

      expect(drawSuccess, isTrue);
      expect(gameState.deck.isEmpty, isFalse);
      expect(
        gameState.discardPile.length,
        equals(1),
      ); // Should keep top discard
    });

    test('should handle deck empty with minimal discard cards (edge case)', () {
      // Empty the deck
      while (!gameState.deck.isEmpty) {
        gameState.deck.drawCard();
      }

      // Add exactly 3 cards to discard pile (allows reshuffle with 2 cards)
      gameState.discardPile.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
      ]);

      expect(gameState.deck.isEmpty, isTrue);
      expect(gameState.discardPile.length, equals(3));

      // Attempt to draw - should trigger emergency reshuffle
      final drawSuccess = gameState.drawFromDeck();

      expect(drawSuccess, isTrue);
      expect(
        gameState.discardPile.length,
        equals(1),
      ); // Should keep top discard
      // Deck might be empty again after drawing if we only had 2 cards to reshuffle
    });

    test(
      'should handle absolute edge case: deck empty with 1 discard card',
      () {
        // Empty the deck
        while (!gameState.deck.isEmpty) {
          gameState.deck.drawCard();
        }

        // Add exactly 1 card to discard pile (cannot reshuffle safely)
        gameState.discardPile.add(
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        );

        expect(gameState.deck.isEmpty, isTrue);
        expect(gameState.discardPile.length, equals(1));

        // Attempt to draw - should fail gracefully
        final drawSuccess = gameState.drawFromDeck();

        expect(drawSuccess, isFalse);
        expect(
          gameState.discardPile.length,
          equals(1),
        ); // Should preserve discard
      },
    );

    test('should handle completely empty deck and discard pile', () {
      // Empty both deck and discard pile
      while (!gameState.deck.isEmpty) {
        gameState.deck.drawCard();
      }
      gameState.discardPile.clear();

      expect(gameState.deck.isEmpty, isTrue);
      expect(gameState.discardPile.isEmpty, isTrue);

      // Attempt to draw - should fail gracefully
      final drawSuccess = gameState.drawFromDeck();

      expect(drawSuccess, isFalse);
    });

    test('should successfully draw multiple cards after reshuffle', () {
      // Empty the deck
      while (!gameState.deck.isEmpty) {
        gameState.deck.drawCard();
      }

      // Add plenty of cards to discard pile
      for (int i = 0; i < 10; i++) {
        gameState.discardPile.add(
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        );
      }

      expect(gameState.deck.isEmpty, isTrue);
      expect(gameState.discardPile.length, equals(10));

      // Should be able to draw required number of cards (usually 2)
      final drawSuccess = gameState.drawFromDeck();

      expect(drawSuccess, isTrue);
      expect(
        gameState.discardPile.length,
        equals(1),
      ); // Should keep top discard
      expect(gameState.deck.isEmpty, isFalse); // Should have cards left
    });

    test('should handle reshuffle during multi-card draw', () {
      // Set up deck with exactly 1 card
      while (!gameState.deck.isEmpty) {
        gameState.deck.drawCard();
      }
      gameState.deck.addCards([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
      ]);

      // Add cards to discard pile for reshuffling
      gameState.discardPile.addAll([
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
      ]);

      expect(gameState.deck.isEmpty, isFalse);
      expect(gameState.discardPile.length, equals(3));

      // Draw should succeed: 1 from deck, reshuffle, then 1 more from reshuffled deck
      final drawSuccess = gameState.drawFromDeck();

      expect(drawSuccess, isTrue);
    });
  });
}
