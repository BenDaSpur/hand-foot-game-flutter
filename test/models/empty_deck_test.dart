import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Empty Deck Tests', () {
    test('should prevent drawing when deck is completely empty', () {
      final players = [
        Player(id: '1', name: 'Player 1', type: PlayerType.human),
        Player(id: '2', name: 'Player 2', type: PlayerType.bot),
      ];

      final deck = Deck(seed: 12345);
      final gameState = GameState(players: players, deck: deck);

      // Empty the deck completely
      while (!gameState.deck.isEmpty) {
        gameState.deck.drawCard();
      }

      expect(gameState.deck.isEmpty, true);
      expect(gameState.deck.size, equals(0));

      // Try to draw from empty deck - should fail
      final result = gameState.drawFromDeck();
      expect(result, false);

      // Player should not have drawn any cards
      expect(gameState.hasDrawnFromDeck, false);
    });

    test('should prevent drawing when deck has only 1 card remaining', () {
      final players = [
        Player(id: '1', name: 'Player 1', type: PlayerType.human),
        Player(id: '2', name: 'Player 2', type: PlayerType.bot),
      ];

      final deck = Deck(seed: 12345);
      final gameState = GameState(players: players, deck: deck);

      // Leave only 1 card in deck
      while (gameState.deck.size > 1) {
        gameState.deck.drawCard();
      }

      expect(gameState.deck.size, equals(1));
      expect(gameState.deck.isEmpty, false);

      // Try to draw from deck with insufficient cards - should fail
      final result = gameState.drawFromDeck();
      expect(result, false);

      // Player should not have drawn any cards
      expect(gameState.hasDrawnFromDeck, false);
      expect(gameState.deck.size, equals(1)); // Card should still be in deck
    });

    test('should successfully draw when deck has exactly 2 cards', () {
      final players = [
        Player(id: '1', name: 'Player 1', type: PlayerType.human),
        Player(id: '2', name: 'Player 2', type: PlayerType.bot),
      ];

      final deck = Deck(seed: 12345);
      final gameState = GameState(players: players, deck: deck);

      // Leave exactly 2 cards in deck
      while (gameState.deck.size > 2) {
        gameState.deck.drawCard();
      }

      expect(gameState.deck.size, equals(2));

      final initialHandSize = gameState.currentPlayer.currentHand.length;

      // Try to draw from deck with exactly 2 cards - should succeed
      final result = gameState.drawFromDeck();
      expect(result, true);

      // Player should have drawn both cards
      expect(gameState.hasDrawnFromDeck, true);
      expect(
        gameState.currentPlayer.currentHand.length,
        equals(initialHandSize + 2),
      );
      expect(gameState.deck.isEmpty, true);
    });

    test('should successfully draw when deck has more than 2 cards', () {
      final players = [
        Player(id: '1', name: 'Player 1', type: PlayerType.human),
        Player(id: '2', name: 'Player 2', type: PlayerType.bot),
      ];

      final deck = Deck(seed: 12345);
      final gameState = GameState(players: players, deck: deck);

      // Ensure deck has more than 2 cards (it should by default)
      expect(gameState.deck.size, greaterThan(2));

      final initialHandSize = gameState.currentPlayer.currentHand.length;
      final initialDeckSize = gameState.deck.size;

      // Try to draw from deck - should succeed
      final result = gameState.drawFromDeck();
      expect(result, true);

      // Player should have drawn exactly 2 cards
      expect(gameState.hasDrawnFromDeck, true);
      expect(
        gameState.currentPlayer.currentHand.length,
        equals(initialHandSize + 2),
      );
      expect(gameState.deck.size, equals(initialDeckSize - 2));
    });
  });
}
