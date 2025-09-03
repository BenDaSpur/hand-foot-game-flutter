import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';

void main() {
  group('Compression Benchmark Tests', () {
    test('realistic game state compression benchmark', () {
      // Create a more realistic game state with multiple players and game progress
      final players = [
        Player(id: '1', name: 'Human Player', type: PlayerType.human),
        Player(id: '2', name: 'Bot Alpha', type: PlayerType.bot),
        Player(id: '3', name: 'Bot Beta', type: PlayerType.bot),
        Player(id: '4', name: 'Bot Gamma', type: PlayerType.bot),
      ];

      // Simulate a game in progress
      // Player 1 has played down and has melds
      players[0].hasPlayedDown = true;
      players[0].hasPickedUpFoot = false;
      players[0].score = 145;

      // Add a realistic hand
      players[0].hand.addAll([
        const PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.ace, suit: Suit.spades),
        const PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
        const PlayingCard(rank: CardRank.queen, suit: Suit.clubs),
        const PlayingCard(rank: CardRank.jack, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.ten, suit: Suit.spades),
        const PlayingCard(rank: CardRank.nine, suit: Suit.diamonds),
        const PlayingCard(rank: CardRank.eight, suit: Suit.clubs),
        const PlayingCard(rank: CardRank.joker),
        const PlayingCard(rank: CardRank.two, suit: Suit.hearts),
      ]);

      // Add foot cards
      players[0].foot.addAll([
        const PlayingCard(rank: CardRank.seven, suit: Suit.spades),
        const PlayingCard(rank: CardRank.six, suit: Suit.diamonds),
        const PlayingCard(rank: CardRank.five, suit: Suit.clubs),
        const PlayingCard(rank: CardRank.four, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.three, suit: Suit.spades),
        const PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
        const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
        const PlayingCard(rank: CardRank.queen, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.jack, suit: Suit.spades),
        const PlayingCard(rank: CardRank.ten, suit: Suit.diamonds),
        const PlayingCard(rank: CardRank.nine, suit: Suit.clubs),
      ]);

      // Add some melds
      final aceMeld = Meld(
        rank: CardRank.ace,
        cards: [
          const PlayingCard(rank: CardRank.ace, suit: Suit.clubs),
          const PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.two, suit: Suit.spades), // Wild card
        ],
        type: MeldType.mixed,
      );
      players[0].melds.add(aceMeld);

      final kingMeld = Meld(
        rank: CardRank.king,
        cards: [
          const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.king, suit: Suit.spades),
          const PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
          const PlayingCard(rank: CardRank.joker), // Wild card
        ],
        type: MeldType.mixed,
      );
      players[0].melds.add(kingMeld);

      // Player 2 has also played down
      players[1].hasPlayedDown = true;
      players[1].hasPickedUpFoot = true;
      players[1].score = 89;

      // Add cards for other players too
      for (int i = 1; i < players.length; i++) {
        // Add some hand cards
        for (int j = 0; j < 8; j++) {
          players[i].hand.add(
            PlayingCard(
              rank: CardRank.values[j + 2], // Start from three
              suit: Suit.values[j % 4],
            ),
          );
        }

        // Add foot cards
        for (int j = 0; j < 11; j++) {
          players[i].foot.add(
            PlayingCard(
              rank: CardRank.values[(j + 5) % CardRank.values.length],
              suit: Suit.values[j % 4],
            ),
          );
        }
      }

      final controller = GameController(players: players, seed: 98765);

      // Simulate some game state changes
      controller.gameState.round = 2;
      controller.gameState.currentPlayerIndex = 1;

      // Add some discard pile
      controller.gameState.discardPile.addAll([
        const PlayingCard(rank: CardRank.five, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.seven, suit: Suit.clubs),
        const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
      ]);

      // Export with maximum compression
      final compressedExport = controller.exportGameState();

      // For comparison, create a legacy-style verbose export
      final verboseExport = {
        'gameSeed': 98765,
        'timestamp': DateTime.now().toIso8601String(),
        'gameState': {
          'phase': 'playing',
          'turnPhase': 'draw',
          'round': 2,
          'currentPlayerIndex': 1,
          'discardPileFrozen': false,
          'hasDrawnFromDeck': false,
          'hasMelded': false,
          'playDownRequirement': 90,
        },
        'players': players
            .map(
              (player) => {
                'id': player.id,
                'name': player.name,
                'type': player.type.name,
                'score': player.score,
                'hasPlayedDown': player.hasPlayedDown,
                'hasPickedUpFoot': player.hasPickedUpFoot,
                'hand': player.hand
                    .map(
                      (card) => {
                        'rank': card.rank.name,
                        'suit': card.suit?.name,
                        'pointValue': card.pointValue,
                        'isWild': card.isWild,
                      },
                    )
                    .toList(),
                'foot': player.foot
                    .map(
                      (card) => {
                        'rank': card.rank.name,
                        'suit': card.suit?.name,
                        'pointValue': card.pointValue,
                        'isWild': card.isWild,
                      },
                    )
                    .toList(),
                'melds': player.melds
                    .map(
                      (meld) => {
                        'rank': meld.rank.name,
                        'type': meld.type.name,
                        'pointValue': meld.pointValue,
                        'isClean': meld.isClean,
                        'cards': meld.cards
                            .map(
                              (card) => {
                                'rank': card.rank.name,
                                'suit': card.suit?.name,
                                'pointValue': card.pointValue,
                                'isWild': card.isWild,
                              },
                            )
                            .toList(),
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
        'deckSize': controller.gameState.deck.size,
        'discardPile': controller.gameState.discardPile
            .map(
              (card) => {
                'rank': card.rank.name,
                'suit': card.suit?.name,
                'pointValue': card.pointValue,
                'isWild': card.isWild,
              },
            )
            .toList(),
        'additionalMetadata': {
          'totalCards': players.fold(
            0,
            (sum, p) => sum + p.hand.length + p.foot.length,
          ),
          'totalMelds': players.fold(0, (sum, p) => sum + p.melds.length),
          'gameComplexity': 'high',
          'compressionVersion': 'uncompressed',
        },
      };

      final verboseJson = const JsonEncoder.withIndent(
        '  ',
      ).convert(verboseExport);
      final compactVerboseJson = jsonEncode(verboseExport);

      // Decode our compressed export for comparison
      final compressedBytes = base64Decode(compressedExport);
      final decompressedBytes = gzip.decode(compressedBytes);
      final optimizedJson = utf8.decode(decompressedBytes);

      print('=== REALISTIC GAME STATE COMPRESSION BENCHMARK ===');
      print('Verbose JSON (pretty): ${verboseJson.length} bytes');
      print('Verbose JSON (compact): ${compactVerboseJson.length} bytes');
      print('Optimized JSON (compact): ${optimizedJson.length} bytes');
      print('Final compressed + base64: ${compressedExport.length} bytes');
      print('');
      print('Compression ratios:');
      print(
        'vs Verbose Pretty: ${(compressedExport.length / verboseJson.length * 100).toStringAsFixed(1)}%',
      );
      print(
        'vs Verbose Compact: ${(compressedExport.length / compactVerboseJson.length * 100).toStringAsFixed(1)}%',
      );
      print(
        'vs Optimized JSON: ${(compressedExport.length / optimizedJson.length * 100).toStringAsFixed(1)}%',
      );
      print('');
      print('Space savings:');
      print(
        'vs Verbose Pretty: ${verboseJson.length - compressedExport.length} bytes saved',
      );
      print(
        'vs Verbose Compact: ${compactVerboseJson.length - compressedExport.length} bytes saved',
      );

      // Test that import still works correctly
      final importResult = GameController.fromExportJson(compressedExport);
      expect(importResult, isNotNull);
      final importedController = importResult!.controller;
      expect(importedController.gameSeed, equals(98765));
      expect(importedController.gameState.players, hasLength(4));
      expect(
        importedController.gameState.players[0].name,
        equals('Human Player'),
      );
      expect(importedController.gameState.players[0].melds, hasLength(2));
      expect(
        importedController.gameState.players[0].melds[0].cards,
        hasLength(4),
      );
      expect(importedController.gameState.round, equals(2));

      // Should achieve significant compression on realistic data
      expect(
        compressedExport.length / verboseJson.length,
        lessThan(0.3),
      ); // < 30% of verbose
      expect(
        compressedExport.length / compactVerboseJson.length,
        lessThan(0.5),
      ); // < 50% of compact
    });
  });
}
