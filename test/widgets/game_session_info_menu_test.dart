import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/widgets/game_session_info_menu.dart';

void main() {
  group('GameSessionInfo', () {
    test('clipboardText includes multiplayer game Firestore path', () {
      const info = GameSessionInfo(gameId: 'ABCD', playerId: 'device-123');

      final text = info.clipboardText;

      expect(text, contains('Game ID: ABCD'));
      expect(text, contains('Firestore: games/ABCD'));
      expect(text, contains('Player: device-123'));
      expect(text, contains('App:'));
      expect(text, contains('Bot AI:'));
    });

    test('clipboardText includes solo session and seed', () {
      const info = GameSessionInfo(
        analyticsSessionId: 'session_1234567890',
        gameSeed: '42',
      );

      final text = info.clipboardText;

      expect(text, contains('Session: session_1234567890'));
      expect(text, contains('Firestore: game_sessions/session_1234567890'));
      expect(text, contains('Seed: 42'));
    });
  });
}
