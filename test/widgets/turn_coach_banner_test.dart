import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
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

  testWidgets('banner renders current phase and optional dismiss action', (
    tester,
  ) async {
    final player = Player(id: '1', name: 'You', type: PlayerType.human);
    final state = GameState(
      players: [player],
      deck: Deck.createHandAndFootDeck(1),
    );
    var dismissals = 0;
    Widget banner(VoidCallback? onDismiss) => MaterialApp(
      home: Scaffold(
        body: TurnCoachBanner(
          gameState: state,
          localPlayer: player,
          onDismiss: onDismiss,
        ),
      ),
    );
    await tester.pumpWidget(banner(() => dismissals++));
    expect(find.text('NEXT STEP'), findsOneWidget);
    expect(find.textContaining('draw 2 cards'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide tips'));
    expect(dismissals, 1);

    state.turnPhase = TurnPhase.meld;
    player.hasPlayedDown = true;
    await tester.pumpWidget(banner(null));
    expect(find.textContaining('discard one card'), findsOneWidget);
    expect(find.byTooltip('Hide tips'), findsNothing);
  });
}
