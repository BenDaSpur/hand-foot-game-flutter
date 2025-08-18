import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';

void main() {
  group('Foot pickup during melding', () {
    late GameState gameState;
    late Player testPlayer;

    setUp(() {
      testPlayer = Player(id: '1', name: 'Test Player', type: PlayerType.human);

      final players = [testPlayer];
      final deck = Deck.createHandAndFootDeck(players.length);

      gameState = GameState(players: players, deck: deck);

      // Set up game state for melding
      gameState.startRound();
      gameState.drawFromDeck(); // Move to meld phase
    });

    test(
      'should automatically pick up foot when hand becomes empty during meld creation',
      () {
        // Player has already played down to bypass requirement
        testPlayer.hasPlayedDown = true;

        // Give player exactly 3 cards in hand (enough for one meld)
        testPlayer.hand.clear();
        testPlayer.hand.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ]);

        // Add some cards to foot
        testPlayer.foot.clear();
        testPlayer.foot.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        ]);

        // Verify initial state
        expect(testPlayer.hasPickedUpFoot, isFalse);
        expect(testPlayer.isHandEmpty, isFalse);
        expect(testPlayer.currentHand.length, equals(3));

        // Create meld that empties the hand
        final success = gameState.playMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ]);

        // Verify meld was successful
        expect(success, isTrue);
        expect(testPlayer.melds.length, equals(1));

        // Verify hand is empty
        expect(testPlayer.hand.isEmpty, isTrue);

        // Verify foot was automatically picked up
        expect(testPlayer.hasPickedUpFoot, isTrue);
        expect(testPlayer.currentHand.length, equals(3)); // Now using foot
        expect(testPlayer.currentHand, equals(testPlayer.foot));

        // Verify action was logged
        final footPickupAction = gameState.recentActions
            .where((action) => action.message.contains('picked up foot pile'))
            .toList();
        expect(footPickupAction.length, equals(1));
      },
    );

    test(
      'should automatically pick up foot when hand becomes empty during add to meld',
      () {
        // Set up player with existing meld and one card in hand
        testPlayer.hand.clear();
        testPlayer.hand.add(
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        );

        // Create initial meld
        testPlayer.melds.clear();
        testPlayer.melds.add(
          Meld(
            rank: CardRank.king,
            cards: [
              const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
            ],
            type: MeldType.natural,
          ),
        );
        testPlayer.hasPlayedDown = true;

        // Add foot cards
        testPlayer.foot.clear();
        testPlayer.foot.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        ]);

        // Verify initial state
        expect(testPlayer.hasPickedUpFoot, isFalse);
        expect(testPlayer.hand.length, equals(1));

        // Add card to existing meld, which empties hand
        final success = gameState.addToMeld(
          0,
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        );

        // Verify card was added successfully
        expect(success, isTrue);
        expect(testPlayer.melds[0].cards.length, equals(4));

        // Verify hand is empty
        expect(testPlayer.hand.isEmpty, isTrue);

        // Verify foot was automatically picked up
        expect(testPlayer.hasPickedUpFoot, isTrue);
        expect(testPlayer.currentHand.length, equals(2)); // Now using foot
        expect(testPlayer.currentHand, equals(testPlayer.foot));
      },
    );

    test('should not pick up foot if hand is not empty after melding', () {
      // Player has already played down
      testPlayer.hasPlayedDown = true;

      // Give player more than 3 cards
      testPlayer.hand.clear();
      testPlayer.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.queen,
        ), // Extra card
      ]);

      // Create meld with 3 cards, leaving 1 in hand
      final success = gameState.playMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ]);

      // Verify meld was successful
      expect(success, isTrue);

      // Verify hand still has 1 card
      expect(testPlayer.hand.length, equals(1));

      // Verify foot was NOT picked up
      expect(testPlayer.hasPickedUpFoot, isFalse);
    });

    test('should not pick up foot if already picked up', () {
      // Player already using foot and has played down
      testPlayer.hasPickedUpFoot = true;
      testPlayer.hasPlayedDown = true;
      testPlayer.hand.clear(); // Empty original hand
      testPlayer.foot.clear();
      testPlayer.foot.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ]);

      // Create meld that empties the foot (current hand)
      final success = gameState.playMeld([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ]);

      // Verify meld was successful
      expect(success, isTrue);

      // Verify foot is empty (they used all foot cards)
      expect(testPlayer.foot.isEmpty, isTrue);

      // Verify state remains consistent
      expect(testPlayer.hasPickedUpFoot, isTrue);

      // Should not have any additional "picked up foot" messages
      final footPickupActions = gameState.recentActions
          .where((action) => action.message.contains('picked up foot pile'))
          .toList();
      expect(footPickupActions.length, equals(0));
    });
  });
}
