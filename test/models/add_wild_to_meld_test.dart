import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Add Wild Cards to Existing Melds', () {
    late GameState gameState;
    late Player player;

    setUp(() {
      player = Player(id: '1', name: 'Player 1', type: PlayerType.human);
      final players = [player];
      final deck = Deck();
      gameState = GameState(players: players, deck: deck);
    });

    test(
      'should allow adding wild card to existing meld when within limits',
      () {
        // Create an existing meld with 3 Kings
        final existingMeld = Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ]);

        expect(existingMeld, isNotNull);
        player.melds.add(existingMeld!);
        player.hasPlayedDown = true;

        // Add a wild card (2) to player's hand
        final wildCard = const PlayingCard(
          suit: Suit.spades,
          rank: CardRank.two,
        );
        player.hand.add(wildCard);

        // Set game state to meld phase
        gameState.turnPhase = TurnPhase.meld;

        // Try to add wild card to the existing meld
        final success = gameState.addToMeld(0, wildCard);

        expect(success, isTrue);
        expect(existingMeld.cards.length, equals(4));
        expect(existingMeld.cards.contains(wildCard), isTrue);
        expect(player.hand.contains(wildCard), isFalse);
      },
    );

    test('should allow adding Joker to existing meld when within limits', () {
      // Create an existing meld with 3 Queens
      final existingMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
      ]);

      expect(existingMeld, isNotNull);
      player.melds.add(existingMeld!);
      player.hasPlayedDown = true;

      // Add a Joker to player's hand
      final joker = const PlayingCard(rank: CardRank.joker);
      player.hand.add(joker);

      // Set game state to meld phase
      gameState.turnPhase = TurnPhase.meld;

      // Try to add Joker to the existing meld
      final success = gameState.addToMeld(0, joker);

      expect(success, isTrue);
      expect(existingMeld.cards.length, equals(4));
      expect(existingMeld.cards.contains(joker), isTrue);
      expect(player.hand.contains(joker), isFalse);
    });

    test('should allow adding wild when it equals natural cards', () {
      // Create an existing meld with 2 Jacks + 1 Wild (2)
      final existingMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // Wild
      ]);

      expect(existingMeld, isNotNull);
      player.melds.add(existingMeld!);
      player.hasPlayedDown = true;

      // Try to add another wild card (Joker) - this would make 2 wilds = 2 naturals
      final joker = const PlayingCard(rank: CardRank.joker);
      player.hand.add(joker);

      // Set game state to meld phase
      gameState.turnPhase = TurnPhase.meld;

      // This should succeed since wilds <= naturals (2 wilds <= 2 naturals)
      final success = gameState.addToMeld(0, joker);

      expect(success, isTrue);
      expect(existingMeld.cards.length, equals(4));
      expect(existingMeld.cards.contains(joker), isTrue);
      expect(player.hand.contains(joker), isFalse);
    });

    test('should allow adding wild when staying under natural count', () {
      // Create an existing meld with 4 Tens + 2 Wilds (wilds < naturals)
      final existingMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // Wild
        const PlayingCard(rank: CardRank.joker), // Wild
      ]);

      expect(existingMeld, isNotNull);
      player.melds.add(existingMeld!);
      player.hasPlayedDown = true;

      // Try to add one more wild (this would make 3 wilds vs 4 naturals, which should be allowed)
      final anotherWild = const PlayingCard(
        suit: Suit.diamonds,
        rank: CardRank.two,
      );
      player.hand.add(anotherWild);

      // Set game state to meld phase
      gameState.turnPhase = TurnPhase.meld;

      // This should succeed since wilds < naturals (3 wilds < 4 naturals)
      final success = gameState.addToMeld(0, anotherWild);

      expect(success, isTrue);
      expect(existingMeld.cards.length, equals(7));
      expect(existingMeld.cards.contains(anotherWild), isTrue);
      expect(player.hand.contains(anotherWild), isFalse);
    });

    test('should correctly count natural vs wild cards in existing meld', () {
      // Test the counting logic directly on a meld
      final meld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ]);

      expect(meld, isNotNull);

      // Should be able to add 1 wild (1 wild < 3 naturals)
      final wild1 = const PlayingCard(suit: Suit.spades, rank: CardRank.two);
      expect(meld!.canAddCard(wild1), isTrue);
      meld.addCard(wild1);

      // Should be able to add 2nd wild (2 wilds < 3 naturals)
      final wild2 = const PlayingCard(rank: CardRank.joker);
      expect(meld.canAddCard(wild2), isTrue);
      meld.addCard(wild2);

      // Should be able to add 3rd wild (3 wilds = 3 naturals, which is allowed)
      final wild3 = const PlayingCard(suit: Suit.hearts, rank: CardRank.two);
      expect(meld.canAddCard(wild3), isTrue);
      meld.addCard(wild3);

      // Should NOT be able to add 4th wild (4 wilds > 3 naturals, exceeds limit)
      final wild4 = const PlayingCard(suit: Suit.clubs, rank: CardRank.two);
      expect(meld.canAddCard(wild4), isFalse);
    });

    test('should reject adding wild when it would exceed naturals', () {
      // Create an existing meld with 2 Sevens + 2 Wilds (already at limit)
      final existingMeld = Meld.createMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // Wild
        const PlayingCard(rank: CardRank.joker), // Wild
      ]);

      expect(existingMeld, isNotNull);
      player.melds.add(existingMeld!);
      player.hasPlayedDown = true;

      // Try to add another wild - should fail (3 wilds > 2 naturals)
      final anotherWild = const PlayingCard(
        suit: Suit.hearts,
        rank: CardRank.two,
      );
      player.hand.add(anotherWild);

      gameState.turnPhase = TurnPhase.meld;
      final success = gameState.addToMeld(0, anotherWild);

      expect(success, isFalse);
      expect(existingMeld.cards.length, equals(4)); // Should remain unchanged
      expect(existingMeld.cards.contains(anotherWild), isFalse);
      expect(
        player.hand.contains(anotherWild),
        isTrue,
      ); // Should remain in hand
    });
  });
}
