import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';

void main() {
  group('Deck Tests', () {
    test('should return card to deck correctly', () {
      final deck = Deck(seed: 12345);

      // Draw a card first
      final initialSize = deck.size;
      final drawnCard = deck.drawCard();
      expect(drawnCard, isNotNull);
      expect(deck.size, equals(initialSize - 1));

      // Return the card
      deck.returnCard(drawnCard!);
      expect(deck.size, equals(initialSize));

      // Draw again - should get the same card back since it was added to end (draw position)
      final reDrawnCard = deck.drawCard();
      expect(reDrawnCard, equals(drawnCard));
    });

    test('should maintain draw order when returning cards', () {
      final deck = Deck(seed: 12345);

      // Draw two cards
      final firstCard = deck.drawCard();
      final secondCard = deck.drawCard();
      expect(firstCard, isNotNull);
      expect(secondCard, isNotNull);

      // Return them in reverse order
      deck.returnCard(secondCard!);
      deck.returnCard(firstCard!);

      // Draw them back - should get firstCard first (it was returned last)
      final redrawFirst = deck.drawCard();
      final redrawSecond = deck.drawCard();

      expect(redrawFirst, equals(firstCard));
      expect(redrawSecond, equals(secondCard));
    });
  });
}
