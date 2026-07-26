import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/services/firebase_service.dart';

void main() {
  group('Mid-game leave gameState transforms', () {
    test('removing current player advances seat and resets turn flags', () {
      final gameState = <String, dynamic>{
        'players': [
          {'id': 'p1', 'name': 'Alice'},
          {'id': 'p2', 'name': 'Bob'},
          {'id': 'p3', 'name': 'Carol'},
        ],
        'currentPlayerIndex': 1,
        'turnPhase': 'meld',
        'hasDrawnFromDeck': true,
        'hasMelded': true,
        'hasTakenDiscardThisTurn': true,
        'playersAwaitingFinalTurn': [0, 1, 2],
        'playerWhoWentOutIndex': 2,
      };

      final updated =
          FirebaseService.removePlayerFromSerializedGameStateForTest(
            gameState,
            'p2',
          );

      expect(updated, isNotNull);
      expect((updated!['players'] as List).length, 2);
      expect(updated['currentPlayerIndex'], 1); // Carol slides into index 1
      expect(updated['turnPhase'], 'draw');
      expect(updated['hasDrawnFromDeck'], isFalse);
      expect(updated['hasMelded'], isFalse);
      expect(updated['hasTakenDiscardThisTurn'], isFalse);
      expect(updated['playersAwaitingFinalTurn'], [0, 1]);
      expect(updated['playerWhoWentOutIndex'], 1);
    });

    test('removing earlier player decrements current index', () {
      final gameState = <String, dynamic>{
        'players': [
          {'id': 'p1', 'name': 'Alice'},
          {'id': 'p2', 'name': 'Bob'},
          {'id': 'p3', 'name': 'Carol'},
        ],
        'currentPlayerIndex': 2,
        'turnPhase': 'draw',
        'hasDrawnFromDeck': false,
        'hasMelded': false,
        'hasTakenDiscardThisTurn': false,
        'playersAwaitingFinalTurn': <int>[],
        'playerWhoWentOutIndex': null,
      };

      final updated =
          FirebaseService.removePlayerFromSerializedGameStateForTest(
            gameState,
            'p1',
          );

      expect(updated, isNotNull);
      expect(updated!['currentPlayerIndex'], 1); // Carol was 2, now 1
      expect((updated['players'] as List).map((p) => p['id']).toList(), [
        'p2',
        'p3',
      ]);
    });

    test('removing last remaining player returns null', () {
      final gameState = <String, dynamic>{
        'players': [
          {'id': 'solo', 'name': 'Solo'},
        ],
        'currentPlayerIndex': 0,
        'turnPhase': 'draw',
        'playersAwaitingFinalTurn': <int>[],
      };

      final updated =
          FirebaseService.removePlayerFromSerializedGameStateForTest(
            gameState,
            'solo',
          );
      expect(updated, isNull);
    });
  });
}
