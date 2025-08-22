import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Atomic Multi-Meld Creation Tests', () {
    test('should create multiple melds atomically without index shifting', () {
      // Setup
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      final controller = GameController(players: players, seed: 12345);
      // Don't initialize game to avoid dealing cards

      final humanPlayer = players[0];
      humanPlayer.currentHand.addAll([
        PlayingCard(rank: CardRank.king, suit: Suit.hearts), // Index 0
        PlayingCard(rank: CardRank.king, suit: Suit.diamonds), // Index 1
        PlayingCard(rank: CardRank.king, suit: Suit.clubs), // Index 2
        PlayingCard(rank: CardRank.queen, suit: Suit.hearts), // Index 3
        PlayingCard(rank: CardRank.queen, suit: Suit.diamonds), // Index 4
        PlayingCard(rank: CardRank.queen, suit: Suit.clubs), // Index 5
        PlayingCard(rank: CardRank.jack, suit: Suit.hearts), // Index 6
        PlayingCard(rank: CardRank.jack, suit: Suit.diamonds), // Index 7
        PlayingCard(rank: CardRank.jack, suit: Suit.clubs), // Index 8
        PlayingCard(rank: CardRank.two, suit: Suit.hearts), // Index 9 (wild)
      ]);

      // Create multiple melds with overlapping indices
      final meldIndices = [
        [0, 1, 2], // Kings meld (indices 0, 1, 2)
        [3, 4, 5], // Queens meld (indices 3, 4, 5)
        [6, 7, 8, 9], // Jacks meld with wild (indices 6, 7, 8, 9)
      ];

      // Act
      final success = controller.createMultipleMeldsFromIndices(
        meldIndices,
        skipPlayDownCheck: true,
      );

      // Assert
      expect(
        success,
        isTrue,
        reason: 'Should successfully create multiple melds',
      );
      expect(
        humanPlayer.melds.length,
        equals(3),
        reason: 'Should have created 3 melds',
      );
      expect(
        humanPlayer.currentHand.isEmpty,
        isTrue,
        reason: 'All cards should be removed from hand',
      );
      expect(
        humanPlayer.hasPlayedDown,
        isTrue,
        reason: 'Should mark as played down',
      );

      // Verify meld contents
      final kingsMeld = humanPlayer.melds[0];
      final queensMeld = humanPlayer.melds[1];
      final jacksMeld = humanPlayer.melds[2];

      expect(kingsMeld.cards.length, equals(3));
      expect(queensMeld.cards.length, equals(3));
      expect(jacksMeld.cards.length, equals(4));

      expect(kingsMeld.cards.every((c) => c.rank == CardRank.king), isTrue);
      expect(queensMeld.cards.every((c) => c.rank == CardRank.queen), isTrue);
      expect(
        jacksMeld.cards.where((c) => c.rank == CardRank.jack).length,
        equals(3),
      );
      expect(jacksMeld.cards.where((c) => c.isWild).length, equals(1));
    });

    test('should handle play-down requirement validation', () {
      // Setup
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      final controller = GameController(players: players, seed: 12345);
      // Don't initialize game to avoid dealing cards

      final humanPlayer = players[0];
      humanPlayer.currentHand.addAll([
        PlayingCard(rank: CardRank.four, suit: Suit.hearts), // 5 points
        PlayingCard(rank: CardRank.four, suit: Suit.diamonds), // 5 points
        PlayingCard(rank: CardRank.four, suit: Suit.clubs), // 5 points
        // Total: 15 points (less than 60 required)
      ]);

      final meldIndices = [
        [0, 1, 2],
      ]; // One meld with 15 points

      // Act
      final success = controller.createMultipleMeldsFromIndices(
        meldIndices,
        skipPlayDownCheck: false,
      );

      // Assert
      expect(
        success,
        isFalse,
        reason: 'Should fail due to insufficient points',
      );
      expect(
        humanPlayer.melds.isEmpty,
        isTrue,
        reason: 'No melds should be created',
      );
      expect(
        humanPlayer.currentHand.length,
        equals(3),
        reason: 'Cards should remain in hand',
      );
    });

    test('should handle invalid melds gracefully', () {
      // Setup
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      final controller = GameController(players: players, seed: 12345);
      // Don't initialize game to avoid dealing cards

      final humanPlayer = players[0];
      humanPlayer.currentHand.addAll([
        PlayingCard(rank: CardRank.king, suit: Suit.hearts),
        PlayingCard(rank: CardRank.queen, suit: Suit.diamonds),
        PlayingCard(rank: CardRank.jack, suit: Suit.clubs),
      ]);

      final meldIndices = [
        [0, 1, 2],
      ]; // Invalid meld with mixed ranks

      // Act
      final success = controller.createMultipleMeldsFromIndices(
        meldIndices,
        skipPlayDownCheck: true,
      );

      // Assert
      expect(success, isFalse, reason: 'Should fail due to invalid meld');
      expect(
        humanPlayer.melds.isEmpty,
        isTrue,
        reason: 'No melds should be created',
      );
      expect(
        humanPlayer.currentHand.length,
        equals(3),
        reason: 'Cards should remain in hand',
      );
    });
  });
}
