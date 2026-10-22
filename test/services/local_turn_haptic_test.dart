import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/services/local_turn_haptic.dart';

void main() {
  const me = 'you';
  const them = 'bot';

  group('shouldPulseForLocalTurn', () {
    test('pulses when this device first sees the local player leading', () {
      expect(
        shouldPulseForLocalTurn(
          localPlayerId: me,
          currentPlayerId: me,
          previousPlayerId: null,
          phase: GamePhase.playing,
          previousPhase: null,
          round: 1,
          previousRound: null,
        ),
        isTrue,
      );
    });

    test('pulses when a new round starts on the local player', () {
      expect(
        shouldPulseForLocalTurn(
          localPlayerId: me,
          currentPlayerId: me,
          previousPlayerId: me,
          phase: GamePhase.playing,
          previousPhase: GamePhase.roundEnd,
          round: 2,
          previousRound: 1,
        ),
        isTrue,
      );
    });

    test('pulses when play returns to the local player', () {
      expect(
        shouldPulseForLocalTurn(
          localPlayerId: me,
          currentPlayerId: me,
          previousPlayerId: them,
          phase: GamePhase.playing,
          previousPhase: GamePhase.playing,
          round: 1,
          previousRound: 1,
        ),
        isTrue,
      );
    });

    test('stays quiet during the rest of the local turn', () {
      expect(
        shouldPulseForLocalTurn(
          localPlayerId: me,
          currentPlayerId: me,
          previousPlayerId: me,
          phase: GamePhase.playing,
          previousPhase: GamePhase.playing,
          round: 1,
          previousRound: 1,
        ),
        isFalse,
      );
    });

    test('stays quiet on someone else\'s turn and outside play', () {
      expect(
        shouldPulseForLocalTurn(
          localPlayerId: me,
          currentPlayerId: them,
          previousPlayerId: me,
          phase: GamePhase.playing,
          previousPhase: GamePhase.playing,
          round: 1,
          previousRound: 1,
        ),
        isFalse,
      );
      expect(
        shouldPulseForLocalTurn(
          localPlayerId: me,
          currentPlayerId: me,
          previousPlayerId: them,
          phase: GamePhase.roundEnd,
          previousPhase: GamePhase.playing,
          round: 1,
          previousRound: 1,
        ),
        isFalse,
      );
    });
  });
}
