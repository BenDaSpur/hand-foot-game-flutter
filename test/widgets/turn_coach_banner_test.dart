import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/widgets/turn_coach_banner.dart';

void main() {
  group('TurnCoachBanner.messageFor', () {
    test('draw phase', () {
      expect(
        TurnCoachBanner.messageFor(
          phase: TurnPhase.draw,
          hasPlayedDown: false,
          playDownRequirement: 60,
        ),
        contains('draw 2 cards'),
      );
    });

    test('meld phase before play-down', () {
      final text = TurnCoachBanner.messageFor(
        phase: TurnPhase.meld,
        hasPlayedDown: false,
        playDownRequirement: 90,
      );
      expect(text, contains('Play Cards'));
      expect(text, contains('90'));
    });

    test('meld phase after play-down', () {
      expect(
        TurnCoachBanner.messageFor(
          phase: TurnPhase.meld,
          hasPlayedDown: true,
          playDownRequirement: 60,
        ),
        contains('discard one card'),
      );
    });

    test('discard phase', () {
      expect(
        TurnCoachBanner.messageFor(
          phase: TurnPhase.discard,
          hasPlayedDown: true,
          playDownRequirement: 60,
        ),
        contains('Discard'),
      );
    });
  });
}
