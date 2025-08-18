import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';

void main() {
  group('GameController findPossibleMelds', () {
    late GameController gameController;

    setUp(() {
      final players = [
        Player(id: '1', name: 'Test Player', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];
      gameController = GameController(players: players, seed: 12345);
    });

    test('should not include 3s in possible melds', () {
      final player = gameController.gameState.players.first;

      // Give player 5 threes - this should not be considered a valid meld
      player.hand.clear();
      player.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.three),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.three),
        const PlayingCard(suit: Suit.spades, rank: CardRank.three),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
        // Add some valid cards too
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ]);

      final possibleMelds = gameController.findPossibleMelds(player);

      // Should only find the King meld, not the 3s
      expect(possibleMelds.length, equals(1));
      expect(possibleMelds.first.length, equals(3));
      expect(
        possibleMelds.first.every((card) => card.rank == CardRank.king),
        isTrue,
      );
    });

    test('should return empty list when only 3s are available for melding', () {
      final player = gameController.gameState.players.first;

      // Give player only 3s and some other insufficient cards
      player.hand.clear();
      player.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.three),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.three),
        const PlayingCard(suit: Suit.spades, rank: CardRank.three),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
        // Only 2 kings - not enough for a meld
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        // Random single cards
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
      ]);

      final possibleMelds = gameController.findPossibleMelds(player);

      // Should be empty - no valid melds available
      expect(possibleMelds, isEmpty);
    });

    test('should still find valid melds with other ranks', () {
      final player = gameController.gameState.players.first;

      // Mix of 3s (invalid) and valid melds
      player.hand.clear();
      player.hand.addAll([
        // 3s that cannot be melded
        const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.three),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.three),
        // Valid King meld
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        // Valid Queen meld
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
      ]);

      final possibleMelds = gameController.findPossibleMelds(player);

      // Should find 2 melds: Kings and Queens, but not 3s
      expect(possibleMelds.length, equals(2));

      final kingMeld = possibleMelds.firstWhere(
        (meld) => meld.first.rank == CardRank.king,
      );
      final queenMeld = possibleMelds.firstWhere(
        (meld) => meld.first.rank == CardRank.queen,
      );

      expect(kingMeld.length, equals(4));
      expect(queenMeld.length, equals(3));
      expect(kingMeld.every((card) => card.rank == CardRank.king), isTrue);
      expect(queenMeld.every((card) => card.rank == CardRank.queen), isTrue);
    });
  });
}
