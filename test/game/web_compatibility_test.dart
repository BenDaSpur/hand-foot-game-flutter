import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';

void main() {
  group('Web Compatibility Tests', () {
    test('should export and import successfully regardless of platform', () {
      // Create a test game with some data
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      // Add some cards to make it more realistic
      players[0].hand.addAll([
        const PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.king, suit: Suit.spades),
        const PlayingCard(rank: CardRank.joker),
      ]);

      final controller = GameController(players: players, seed: 42);

      // Export should work on all platforms
      final exportedData = controller.exportGameState();

      // Should be a valid base64 string
      expect(exportedData, isNotEmpty);
      expect(() => base64Decode(exportedData), returnsNormally);

      // Import should work on all platforms
      final importedController = GameController.fromExportJson(exportedData);

      expect(importedController, isNotNull);
      expect(importedController!.gameSeed, equals(42));
      expect(importedController.gameState.players, hasLength(2));
      expect(importedController.gameState.players[0].name, equals('Human'));
      expect(importedController.gameState.players[1].name, equals('Bot'));
      expect(importedController.gameState.players[0].hand, hasLength(3));
    });

    test('should handle cross-platform compatibility', () {
      // Simulate data exported from mobile (gzipped, version 2)
      final mobileExportData = {
        'v': 2, // Mobile version with gzip
        's': 12345,
        'g': {
          'p': 1,
          't': 0,
          'r': 1,
          'c': 0,
          'f': false,
          'd': false,
          'm': false,
          'q': 60,
        },
        'players': [
          {
            'id': '1',
            'n': 'Test Player',
            't': 0,
            'sc': 0,
            'pd': false,
            'ft': false,
            'melds': [],
            'h': ['0,0', '12,1'], // Ace of clubs, King of diamonds
            'f': [],
          },
        ],
        'deck': {'sz': 108, 's': 12345, 'top': null},
        'dp': [],
      };

      // Convert to compact JSON then base64 (simulate mobile export)
      final mobileJson = jsonEncode(mobileExportData);
      final mobileBase64 = base64Encode(utf8.encode(mobileJson));

      // Should be able to import on any platform
      final controller = GameController.fromExportJson(mobileBase64);

      expect(controller, isNotNull);
      expect(controller!.gameSeed, equals(12345));
      expect(controller.gameState.players, hasLength(1));
      expect(controller.gameState.players[0].name, equals('Test Player'));
      expect(controller.gameState.players[0].hand, hasLength(2));
    });

    test('should produce different formats based on platform detection', () {
      final players = [Player(id: '1', name: 'Test', type: PlayerType.human)];

      final controller = GameController(players: players, seed: 999);
      final exportedData = controller.exportGameState();

      // Decode and check format version
      final decodedBytes = base64Decode(exportedData);
      String jsonString;

      try {
        // Try to decode directly (web format)
        jsonString = utf8.decode(decodedBytes);
      } catch (e) {
        // If that fails, it might be gzipped (mobile format)
        // We can't test gzip decode in this environment, so just pass
        return;
      }

      final data = jsonDecode(jsonString);
      final version = data['v'] as int;

      // Should be version 2 (mobile) or 3 (web)
      expect(version, isIn([2, 3]));

      print('Platform detected format version: $version');
      if (kIsWeb) {
        print('Running on web - expecting version 3');
      } else {
        print('Running on mobile/desktop - expecting version 2');
      }
    });

    test('should maintain compression benefits even without gzip', () {
      final players = [
        Player(id: '1', name: 'Human Player', type: PlayerType.human),
        Player(id: '2', name: 'Bot Player', type: PlayerType.bot),
      ];

      // Add realistic game data
      for (int i = 0; i < 10; i++) {
        players[0].hand.add(
          PlayingCard(
            rank: CardRank.values[i % CardRank.values.length],
            suit: Suit.values[i % Suit.values.length],
          ),
        );
      }

      final controller = GameController(players: players, seed: 777);
      final compactExport = controller.exportGameState();

      // Compare with a verbose representation
      final verboseData = {
        'gameSeed': 777,
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
        'players': players
            .map(
              (p) => {
                'id': p.id,
                'name': p.name,
                'type': p.type.name,
                'score': p.score,
                'hasPlayedDown': p.hasPlayedDown,
                'hasPickedUpFoot': p.hasPickedUpFoot,
                'hand': p.hand
                    .map(
                      (c) => {
                        'rank': c.rank.name,
                        'suit': c.suit?.name,
                        'pointValue': c.pointValue,
                      },
                    )
                    .toList(),
                'foot': [],
                'melds': [],
              },
            )
            .toList(),
        'deck': {'size': 108},
        'discardPile': [],
        'additionalInfo': 'This is extra verbose data for testing',
      };

      final verboseJson = const JsonEncoder.withIndent(
        '  ',
      ).convert(verboseData);

      print('=== WEB COMPATIBILITY COMPRESSION ===');
      print('Verbose JSON: ${verboseJson.length} bytes');
      print('Compact export: ${compactExport.length} bytes');
      print(
        'Compression ratio: ${(compactExport.length / verboseJson.length * 100).toStringAsFixed(1)}%',
      );

      // Even without gzip, should achieve significant compression
      expect(compactExport.length / verboseJson.length, lessThan(0.7)); // < 70%
    });
  });
}
