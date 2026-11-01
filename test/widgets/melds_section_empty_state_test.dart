import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/widgets/melds_section.dart';

void main() {
  group('MeldsSection.emptyStateSubtitle', () {
    test('draw phase tells players to draw first when they can act', () {
      expect(
        MeldsSection.emptyStateSubtitle(
          turnPhase: TurnPhase.draw,
          hasPlayedDown: false,
          playDownRequirement: 60,
          canAct: true,
          viewingOwnMelds: true,
        ),
        contains('Draw first'),
      );
    });

    test('meld phase before play-down mentions point requirement', () {
      final text = MeldsSection.emptyStateSubtitle(
        turnPhase: TurnPhase.meld,
        hasPlayedDown: false,
        playDownRequirement: 60,
        canAct: true,
        viewingOwnMelds: true,
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
          canAct: true,
          viewingOwnMelds: true,
        ),
        contains('lay more melds'),
      );
    });

    test('uses informational copy when it is not the local turn', () {
      expect(
        MeldsSection.emptyStateSubtitle(
          turnPhase: TurnPhase.draw,
          hasPlayedDown: false,
          playDownRequirement: 60,
          canAct: false,
          viewingOwnMelds: true,
        ),
        contains('Melds you lay will show up here'),
      );
    });

    test('uses informational copy when viewing another player', () {
      expect(
        MeldsSection.emptyStateSubtitle(
          turnPhase: TurnPhase.meld,
          hasPlayedDown: false,
          playDownRequirement: 60,
          canAct: true,
          viewingOwnMelds: false,
        ),
        contains('This player has not laid any melds yet'),
      );
    });
  });
}
