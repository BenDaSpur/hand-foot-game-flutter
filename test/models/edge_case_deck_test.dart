import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Edge Case Deck Tests', () {
    test(
      'Edge Case 1: Should only take available cards from discard pile when unlocking',
      () {
        final players = [
          Player(id: '1', name: 'Player 1', type: PlayerType.human),
          Player(id: '2', name: 'Player 2', type: PlayerType.bot),
        ];

        final deck = Deck(seed: 12345);
        final gameState = GameState(players: players, deck: deck);

        // Set up player with cards to unlock discard
        final player = gameState.currentPlayer;
        player.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        ]);

        // Player must have played down to unlock discard pile
        player.hasPlayedDown = true;

        // Set up discard pile with only 1 card (the unlock target)
        gameState.discardPile.clear();
        gameState.discardPile.add(
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        );

        final initialHandSize = player.currentHand.length;
        final initialDeckSize = gameState.deck.size;

        // Player should be able to unlock discard pile
        expect(gameState.canUnlockDiscard(), true);

        // Unlock the discard pile
        final success = gameState.unlockDiscard();
        expect(success, true);

        // Player should have:
        // - Lost 2 kings from hand (used to unlock)
        // - The king from discard pile goes directly to meld, not hand
        // - NO additional cards (per official rules: only from discard pile)
        final expectedHandSize = initialHandSize - 2;
        expect(player.currentHand.length, equals(expectedHandSize));

        // Deck should be unchanged (per official rules)
        expect(gameState.deck.size, equals(initialDeckSize));

        // Player should have a meld with 3 kings
        expect(player.melds.length, equals(1));
        expect(player.melds.first.cards.length, equals(3));
        expect(player.melds.first.rank, equals(CardRank.king));
      },
    );

    test(
      'Edge Case 2: Should reshuffle discard pile when deck is insufficient for draw',
      () {
        final players = [
          Player(id: '1', name: 'Player 1', type: PlayerType.human),
          Player(id: '2', name: 'Player 2', type: PlayerType.bot),
        ];

        final deck = Deck(seed: 12345);
        final gameState = GameState(players: players, deck: deck);

        // Empty most of the deck, leaving only 1 card
        while (gameState.deck.size > 1) {
          gameState.deck.drawCard();
        }

        // Add several cards to discard pile for reshuffling
        gameState.discardPile.clear();
        gameState.discardPile.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.three),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.five,
          ), // This will be kept as top card
        ]);

        expect(gameState.deck.size, equals(1));
        expect(gameState.discardPile.length, equals(5));

        final initialHandSize = gameState.currentPlayer.currentHand.length;

        // Try to draw from deck - should trigger reshuffle and succeed
        final success = gameState.drawFromDeck();
        expect(success, true);

        // Player should have drawn 2 cards
        expect(
          gameState.currentPlayer.currentHand.length,
          equals(initialHandSize + 2),
        );

        // Discard pile should only have the top card left
        expect(gameState.discardPile.length, equals(1));
        expect(gameState.discardPile.first.rank, equals(CardRank.five));

        // Deck should have the reshuffled cards minus what was drawn
        expect(gameState.deck.size, greaterThan(0));
      },
    );

    test('Edge Case 2: Should take available discard pile cards during unlock', () {
      final players = [
        Player(id: '1', name: 'Player 1', type: PlayerType.human),
        Player(id: '2', name: 'Player 2', type: PlayerType.bot),
      ];

      final deck = Deck(seed: 12345);
      final gameState = GameState(players: players, deck: deck);

      // Set up player with cards to unlock discard
      final player = gameState.currentPlayer;
      player.dealHand([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ]);

      // Player must have played down to unlock discard pile
      player.hasPlayedDown = true;

      // Empty most of the deck, leaving only 2 cards (not enough for the 5 needed)
      while (gameState.deck.size > 2) {
        gameState.deck.drawCard();
      }

      // Set up discard pile with unlock target and 4 additional cards (total 5)
      gameState.discardPile.clear();
      gameState.discardPile.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        const PlayingCard(suit: Suit.spades, rank: CardRank.three),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.king,
        ), // Unlock target
      ]);

      final initialHandSize = player.currentHand.length;
      expect(gameState.deck.size, equals(2));
      expect(gameState.discardPile.length, equals(5));

      // Unlock the discard pile
      final success = gameState.unlockDiscard();
      expect(success, true);

      // Per official rules: take only from discard pile, not deck
      // Should take unlock card (king) + 4 additional cards from discard
      expect(player.melds.length, equals(1)); // Meld was created

      // Player should have gained 4 cards from discard (lost 2 kings, gained 4)
      expect(player.currentHand.length, equals(initialHandSize - 2 + 4));

      // Discard pile should be empty now
      expect(gameState.discardPile.length, equals(0));
    });

    test(
      'Should draw 1 card, reshuffle, then draw 2nd card when deck has only 1 card',
      () {
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

        // Add several cards to discard pile for reshuffling
        gameState.discardPile.clear();
        gameState.discardPile.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.three),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.five,
          ), // This will be kept as top card
        ]);

        expect(gameState.deck.size, equals(1));
        expect(gameState.discardPile.length, equals(5));

        final initialHandSize = gameState.currentPlayer.currentHand.length;

        // Try to draw from deck - should draw 1, reshuffle, then draw second card
        final success = gameState.drawFromDeck();
        expect(success, true);

        // Player should have drawn 2 cards total
        expect(
          gameState.currentPlayer.currentHand.length,
          equals(initialHandSize + 2),
        );

        // Discard pile should only have the top card left
        expect(gameState.discardPile.length, equals(1));
        expect(gameState.discardPile.first.rank, equals(CardRank.five));

        // Deck should have the reshuffled cards minus what was drawn
        expect(gameState.deck.size, greaterThan(0));
      },
    );

    test('Should not reshuffle when discard pile has only 1 card', () {
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

      // Add only 1 card to discard pile
      gameState.discardPile.clear();
      gameState.discardPile.add(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
      );

      expect(gameState.deck.isEmpty, true);
      expect(gameState.discardPile.length, equals(1));

      // Try to draw from deck - should fail (no reshuffling possible)
      final success = gameState.drawFromDeck();
      expect(success, false);

      // Discard pile should remain unchanged
      expect(gameState.discardPile.length, equals(1));
      expect(gameState.deck.isEmpty, true);
    });
  });
}
