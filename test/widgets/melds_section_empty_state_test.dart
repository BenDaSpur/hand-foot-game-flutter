import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/widgets/melds_section.dart';

void main() {
  group('MeldsSection.emptyStateSubtitle', () {
    test('draw phase tells players to draw first', () {
      expect(
        MeldsSection.emptyStateSubtitle(
          turnPhase: TurnPhase.draw,
          hasPlayedDown: false,
          playDownRequirement: 60,
        ),
        contains('Draw first'),
      );
    });

    test('meld phase before play-down mentions point requirement', () {
      final text = MeldsSection.emptyStateSubtitle(
        turnPhase: TurnPhase.meld,
        hasPlayedDown: false,
        playDownRequirement: 60,
      );
      expect(text, contains('60'));
      expect(text, contains('don’t count until laid'));
    });

    test('after play-down invites more melds', () {
      expect(
        MeldsSection.emptyStateSubtitle(
          turnPhase: TurnPhase.meld,
          hasPlayedDown: true,
          playDownRequirement: 60,
        ),
        contains('lay more melds'),
      );
    });
  });
}
