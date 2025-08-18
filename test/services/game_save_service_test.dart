import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hand_foot_game_flutter/services/game_save_service.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/card.dart';

void main() {
  group('GameSaveService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'should preserve GameAction timestamps when saving and loading',
      () async {
        final players = [
          Player(id: '1', name: 'Test Player', type: PlayerType.human),
          Player(id: '2', name: 'Bot', type: PlayerType.bot),
        ];

        final gameController = GameController(players: players, seed: 12345);
        gameController.initializeGame();

        // Add a custom action with a specific timestamp
        final originalTimestamp = DateTime(2025, 1, 1, 12, 0, 0);
        gameController.gameState.recentActions.add(
          GameAction.withTimestamp(
            message: 'Test action',
            playerName: 'Test Player',
            timestamp: originalTimestamp,
          ),
        );

        // Save the game
        await GameSaveService.saveGame(gameController.gameState, 12345);

        // Load the game back
        final restoredController = await GameController.loadSavedGame();

        expect(restoredController, isNotNull);
        expect(restoredController!.gameState.recentActions.length, equals(1));

        final restoredAction = restoredController.gameState.recentActions.first;
        expect(restoredAction.message, equals('Test action'));
        expect(restoredAction.playerName, equals('Test Player'));
        expect(restoredAction.timestamp, equals(originalTimestamp));
      },
    );

    test('should use clean enum names in serialized JSON', () async {
      final players = [
        Player(id: '1', name: 'Test Player', type: PlayerType.human),
      ];

      final gameController = GameController(players: players);
      gameController.initializeGame();

      // Get the serialized data
      final serializedData = await GameSaveService.loadGame();

      if (serializedData != null) {
        // Check that enums are serialized with .name (clean) not .toString()
        expect(
          serializedData['phase'],
          equals('setup'),
        ); // not 'GamePhase.setup'
        expect(
          serializedData['turnPhase'],
          equals('draw'),
        ); // not 'TurnPhase.draw'

        final playerData = serializedData['players'][0] as Map<String, dynamic>;
        expect(playerData['type'], equals('human')); // not 'PlayerType.human'

        // Check card serialization
        if (gameController.gameState.discardPile.isNotEmpty) {
          final cardData =
              serializedData['discardPile'][0] as Map<String, dynamic>;
          expect(cardData['rank'], isA<String>());
          expect(cardData['suit'], anyOf([isA<String>(), isNull]));
          // Should not contain 'CardRank.' or 'Suit.' prefixes
          expect(cardData['rank'], isNot(contains('CardRank.')));
          if (cardData['suit'] != null) {
            expect(cardData['suit'], isNot(contains('Suit.')));
          }
        }
      }
    });

    test('should handle joker cards correctly in serialization', () async {
      final players = [
        Player(id: '1', name: 'Test Player', type: PlayerType.human),
      ];

      final gameController = GameController(players: players);

      // Add a joker to the player's hand
      players[0].hand.add(const PlayingCard(rank: CardRank.joker));

      // Save the game
      await GameSaveService.saveGame(gameController.gameState, null);

      // Load the game back
      final restoredController = await GameController.loadSavedGame();

      expect(restoredController, isNotNull);

      final restoredPlayer = restoredController!.gameState.players.first;
      final jokerCard = restoredPlayer.hand.firstWhere(
        (card) => card.rank == CardRank.joker,
      );

      expect(jokerCard.rank, equals(CardRank.joker));
      expect(jokerCard.suit, isNull); // Jokers have no suit
    });
  });
}
