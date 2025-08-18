import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';

void main() {
  group('Play Down Requirement Bug Fix', () {
    late Player player;

    setUp(() {
      player = Player(id: '1', name: 'Test Player', type: PlayerType.bot);
    });

    test('should NOT mark hasPlayedDown=true when requirement not met', () {
      // Give player cards worth only 30 points (requirement is 60)
      player.hand.addAll([
        const PlayingCard(suit: Suit.clubs, rank: CardRank.seven), // 5 pts
        const PlayingCard(suit: Suit.hearts, rank: CardRank.seven), // 5 pts
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.two,
        ), // 20 pts (wild)
      ]); // Total: 30 points

      // Attempt to create meld with 60-point requirement
      final success = player.createMeld([
        const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
      ], playDownRequirement: 60);

      // Should fail due to insufficient points
      expect(success, isFalse);
      expect(player.hasPlayedDown, isFalse);
      expect(player.melds.isEmpty, isTrue);
    });

    test('should mark hasPlayedDown=true when requirement is met', () {
      // Give player cards worth 60+ points
      player.hand.addAll([
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace), // 20 pts
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace), // 20 pts
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace), // 20 pts
      ]); // Total: 60 points

      // Create meld with 60-point requirement
      final success = player.createMeld([
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
      ], playDownRequirement: 60);

      // Should succeed and mark as played down
      expect(success, isTrue);
      expect(player.hasPlayedDown, isTrue);
      expect(player.melds.length, equals(1));
    });

    test('should NOT mark hasPlayedDown=true when using bypass mode', () {
      // Give player cards worth only 30 points
      player.hand.addAll([
        const PlayingCard(suit: Suit.clubs, rank: CardRank.seven), // 5 pts
        const PlayingCard(suit: Suit.hearts, rank: CardRank.seven), // 5 pts
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.two,
        ), // 20 pts (wild)
      ]); // Total: 30 points

      // Use bypass mode (playDownRequirement: 0)
      final success = player.createMeld(
        [
          const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        ],
        playDownRequirement: 0, // Bypass mode
      );

      // Should succeed but NOT mark as played down
      expect(success, isTrue);
      expect(player.hasPlayedDown, isFalse); // Key fix!
      expect(player.melds.length, equals(1));
    });

    test('should allow subsequent melds after proper play down', () {
      // First, establish proper play down
      player.hand.addAll([
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace), // 20 pts
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace), // 20 pts
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace), // 20 pts
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king), // 10 pts
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king), // 10 pts
        const PlayingCard(suit: Suit.spades, rank: CardRank.king), // 10 pts
      ]);

      // First meld - meets requirement
      final firstSuccess = player.createMeld([
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
      ], playDownRequirement: 60);

      expect(firstSuccess, isTrue);
      expect(player.hasPlayedDown, isTrue);

      // Second meld - should work without requirement check
      final secondSuccess = player.createMeld([
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      ], playDownRequirement: 60);

      expect(secondSuccess, isTrue);
      expect(player.melds.length, equals(2));
    });
  });
}
