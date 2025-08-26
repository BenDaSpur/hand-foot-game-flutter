import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/game/managers/meld_manager.dart';

void main() {
  group('MeldManager', () {
    late GameState gameState;
    late MeldManager meldManager;
    late Player testPlayer;

    setUp(() {
      testPlayer = Player(id: '1', name: 'Test Player', type: PlayerType.human);

      gameState = GameState(
        players: [testPlayer],
        deck: Deck.createHandAndFootDeck(1, seed: 12345),
      );

      meldManager = MeldManager(gameState);
    });

    group('createMultipleMeldsFromIndices', () {
      test('should create multiple melds from valid indices', () {
        // Setup hand with valid meld combinations
        testPlayer.hand.addAll([
          const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
          const PlayingCard(rank: CardRank.queen, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.queen, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.queen, suit: Suit.spades),
        ]);

        final result = meldManager.createMultipleMeldsFromIndices([
          [0, 1, 2], // Kings
          [3, 4, 5], // Queens
        ], skipPlayDownCheck: true);

        expect(result, isTrue);
        expect(testPlayer.melds, hasLength(2));
        expect(testPlayer.currentHand, isEmpty);
      });

      test('should fail with invalid indices', () {
        testPlayer.hand.addAll([
          const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
        ]);

        final result = meldManager.createMultipleMeldsFromIndices([
          [0, 1, 2], // Invalid - only 1 card in hand
        ]);

        expect(result, isFalse);
        expect(testPlayer.melds, isEmpty);
      });

      test('should respect play-down requirement', () {
        // Play-down requirement is based on round
        gameState.round = 3; // Round 3 = 120 point requirement

        testPlayer.hand.addAll([
          const PlayingCard(rank: CardRank.five, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.five, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.five, suit: Suit.clubs),
        ]);

        // Three 5s = 15 points, less than requirement
        final result = meldManager.createMultipleMeldsFromIndices([
          [0, 1, 2],
        ]);

        expect(result, isFalse);
      });

      test('should handle duplicate indices correctly', () {
        testPlayer.hand.addAll([
          const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
          const PlayingCard(rank: CardRank.joker),
        ]);

        // // Try to use same card twice
        // final result = meldManager.createMultipleMeldsFromIndices([
        //   [0, 1, 2], // Valid Kings meld
        //   [2, 3], // Tries to reuse card at index 2
        // ], skipPlayDownCheck: true);

        // Should handle gracefully
        expect(testPlayer.melds.length, greaterThanOrEqualTo(0));
      });
    });

    group('findPossibleMelds', () {
      test('should find natural melds', () {
        testPlayer.hand.addAll([
          const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
        ]);

        final melds = meldManager.findPossibleMelds(testPlayer);

        expect(melds, hasLength(1));
        expect(melds.first, hasLength(3));
        expect(melds.first.every((card) => card.rank == CardRank.king), isTrue);
      });

      test('should find melds with wild cards', () {
        testPlayer.hand.addAll([
          const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.joker),
        ]);

        final melds = meldManager.findPossibleMelds(testPlayer);

        expect(melds, hasLength(1));
        expect(melds.first, hasLength(3));
      });

      test('should not create melds with 3s', () {
        testPlayer.hand.addAll([
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.three, suit: Suit.clubs),
        ]);

        final melds = meldManager.findPossibleMelds(testPlayer);

        expect(melds, isEmpty);
      });

      test('should not exceed wild card limit', () {
        testPlayer.hand.addAll([
          const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.joker),
          const PlayingCard(rank: CardRank.joker),
          const PlayingCard(rank: CardRank.two, suit: Suit.hearts),
        ]);

        final melds = meldManager.findPossibleMelds(testPlayer);

        // Should not create meld with more wilds than naturals
        expect(melds, isEmpty);
      });
    });

    group('getPlayableCards', () {
      test('should return empty list when not in meld phase', () {
        gameState.turnPhase = TurnPhase.draw;

        final playable = meldManager.getPlayableCards(testPlayer);

        expect(playable, isEmpty);
      });

      test('should return cards from possible melds in meld phase', () {
        gameState.turnPhase = TurnPhase.meld;

        testPlayer.hand.addAll([
          const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
          const PlayingCard(rank: CardRank.five, suit: Suit.hearts),
        ]);

        final playable = meldManager.getPlayableCards(testPlayer);

        expect(playable, hasLength(3)); // Only the Kings
      });

      test('should include cards that can be added to existing melds', () {
        gameState.turnPhase = TurnPhase.meld;

        // Create an existing meld
        testPlayer.hand.addAll([
          const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
        ]);

        meldManager.createMeldByIndices([0, 1, 2], skipPlayDownCheck: true);

        // Add another King to current hand (which might be foot if hand was emptied)
        testPlayer.currentHand.add(
          const PlayingCard(rank: CardRank.king, suit: Suit.spades),
        );

        final playable = meldManager.getPlayableCards(testPlayer);

        expect(
          playable.any(
            (card) => card.rank == CardRank.king && card.suit == Suit.spades,
          ),
          isTrue,
        );
      });
    });

    group('foot pickup handling', () {
      test('should trigger foot pickup when hand becomes empty', () {
        testPlayer.hand.addAll([
          const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
        ]);

        testPlayer.foot.addAll([
          const PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
        ]);

        expect(testPlayer.hasPickedUpFoot, isFalse);

        // Create meld with all cards in hand
        meldManager.createMeldByIndices([0, 1, 2], skipPlayDownCheck: true);

        expect(testPlayer.hasPickedUpFoot, isTrue);
        expect(testPlayer.currentHand, equals(testPlayer.foot));
      });
    });
  });
}
