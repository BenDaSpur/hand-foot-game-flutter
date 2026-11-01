import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';
import 'package:hand_foot_game_flutter/widgets/stuck_go_out_recovery_banner.dart';

void main() {
  testWidgets('phone width collapses stuck banner until expanded', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: MaterialApp(
          theme: BalatroTheme.testTheme,
          home: Scaffold(
            body: StuckGoOutRecoveryBanner(
              humanPlayer: Player(id: '1', name: 'You', type: PlayerType.human),
              onSkipTurn: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('tap for details'), findsOneWidget);
    expect(find.text('Skip Turn (Emergency Recovery)'), findsNothing);

    await tester.tap(find.textContaining('tap for details'));
    await tester.pumpAndSettle();

    expect(find.text('Skip Turn (Emergency Recovery)'), findsOneWidget);

    await tester.tap(find.text('CAN’T GO OUT'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tap for details'), findsOneWidget);
    expect(find.text('Skip Turn (Emergency Recovery)'), findsNothing);
  });

  testWidgets('wide banner exposes recovery actions and calls each once', (
    tester,
  ) async {
    var undoCount = 0;
    var skipCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.testTheme,
        home: Scaffold(
          body: StuckGoOutRecoveryBanner(
            humanPlayer: Player(id: '1', name: 'You', type: PlayerType.human),
            onUndo: () => undoCount++,
            onSkipTurn: () => skipCount++,
          ),
        ),
      ),
    );
    expect(find.textContaining('tap for details'), findsNothing);
    await tester.tap(find.text('Undo Meld'));
    await tester.tap(find.text('Skip Turn (Emergency Recovery)'));
    expect(undoCount, 1);
    expect(skipCount, 1);
  });
}
