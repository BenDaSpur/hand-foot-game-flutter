import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';

void main() {
  group('Base64 Export/Import Tests', () {
    test('should export game state as base64 and import successfully', () {
      // Create a test game controller
      final players = [
        Player(id: '1', name: 'Player 1', type: PlayerType.human),
        Player(id: '2', name: 'Bot 1', type: PlayerType.bot),
      ];

      final controller = GameController(players: players, seed: 12345);

      // Export the game state (should be base64 encoded)
      final exportedBase64 = controller.exportGameState();

      // Verify it's base64 encoded (should not start with { or [)
      expect(exportedBase64.startsWith('{'), isFalse);
      expect(exportedBase64.startsWith('['), isFalse);

      // Verify we can decode the base64 and decompress to get valid JSON
      final decodedBytes = base64Decode(exportedBase64);
      final decompressedBytes = gzip.decode(decodedBytes);
      final jsonString = utf8.decode(decompressedBytes);
      final jsonData = jsonDecode(jsonString);

      expect(jsonData, isA<Map<String, dynamic>>());
      expect(jsonData['s'], equals(12345)); // 's' = seed in optimized format
      expect(jsonData['players'], hasLength(2));

      // Test importing the base64 encoded data
      final importedController = GameController.fromExportJson(exportedBase64);

      expect(importedController, isNotNull);
      expect(importedController!.gameSeed, equals(12345));
      expect(importedController.gameState.players, hasLength(2));
      expect(importedController.gameState.players[0].name, equals('Player 1'));
      expect(importedController.gameState.players[1].name, equals('Bot 1'));
    });

    test('should handle legacy JSON format for backward compatibility', () {
      // Create a legacy JSON export (non-base64)
      final legacyJson = jsonEncode({
        'gameSeed': 54321,
        'gameState': {
          'phase': 'playing',
          'turnPhase': 'draw',
          'round': 1,
          'currentPlayerIndex': 0,
          'discardPileFrozen': false,
          'hasDrawnFromDeck': false,
          'hasMelded': false,
          'playDownRequirement': 60,
        },
        'players': [
          {
            'id': '1',
            'name': 'Legacy Player',
            'type': 'human',
            'score': 0,
            'hasPlayedDown': false,
            'roundScore': 0,
            'handSize': 11,
            'footSize': 11,
            'currentHandSize': 11,
            'usingFoot': false,
            'canGoOut': false,
            'melds': [],
            'hand': [],
            'foot': [],
          },
        ],
        'deck': {'size': 86, 'seed': 54321, 'topCard': null},
        'discardPile': [],
        'recentActions': [],
        'exportedAt': DateTime.now().toIso8601String(),
        'debugInfo': {},
      });

      // Test importing legacy JSON format
      final importedController = GameController.fromExportJson(legacyJson);

      expect(importedController, isNotNull);
      expect(importedController!.gameSeed, equals(54321));
      expect(importedController.gameState.players, hasLength(1));
      expect(
        importedController.gameState.players[0].name,
        equals('Legacy Player'),
      );
    });

    test('should handle invalid base64 gracefully', () {
      const invalidBase64 = 'this-is-not-valid-base64!!!';

      // Should not throw an exception, but should return null
      final result = GameController.fromExportJson(invalidBase64);
      expect(result, isNull);
    });

    test('gzip + optimized format should achieve maximum compression', () {
      final players = [
        Player(id: '1', name: 'Player 1', type: PlayerType.human),
        Player(id: '2', name: 'Bot 1', type: PlayerType.bot),
      ];

      // Add some cards to make the test more realistic
      players[0].hand.addAll([
        const PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.king, suit: Suit.spades),
        const PlayingCard(rank: CardRank.queen, suit: Suit.diamonds),
        const PlayingCard(rank: CardRank.jack, suit: Suit.clubs),
        const PlayingCard(rank: CardRank.joker), // Joker has no suit
      ]);

      final controller = GameController(players: players, seed: 12345);
      final compressedExport = controller.exportGameState();

      // Decode to see the compressed vs uncompressed sizes
      final compressedBytes = base64Decode(compressedExport);
      final decompressedBytes = gzip.decode(compressedBytes);
      final jsonString = utf8.decode(decompressedBytes);
      final jsonData = jsonDecode(jsonString);
      final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonData);

      // Test compression effectiveness
      expect(compressedExport.length, lessThan(prettyJson.length));
      expect(compressedExport.length, lessThan(jsonString.length));

      print('=== COMPRESSION COMPARISON ===');
      print('Pretty JSON length: ${prettyJson.length}');
      print('Compact JSON length: ${jsonString.length}');
      print('Gzipped + Base64 length: ${compressedExport.length}');
      print('');
      print(
        'Compression vs Pretty JSON: ${(compressedExport.length / prettyJson.length * 100).toStringAsFixed(1)}%',
      );
      print(
        'Compression vs Compact JSON: ${(compressedExport.length / jsonString.length * 100).toStringAsFixed(1)}%',
      );

      // Verify format version is 2 or 3 (optimized formats)
      expect(jsonData['v'], isIn([2, 3]));

      // Should achieve significant compression (expect < 50% of original size)
      expect(compressedExport.length / prettyJson.length, lessThan(0.5));
    });
  });
}
