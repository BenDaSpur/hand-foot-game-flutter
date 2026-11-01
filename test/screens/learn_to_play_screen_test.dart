import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/screens/learn_to_play_screen.dart';
import 'package:hand_foot_game_flutter/screens/game_screen.dart';
import 'package:hand_foot_game_flutter/widgets/game_board_layout.dart';
import 'package:hand_foot_game_flutter/services/turn_coach_preferences.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';
import 'package:hand_foot_game_flutter/widgets/advanced_meld_selector.dart';
import 'package:hand_foot_game_flutter/widgets/learn_to_play_coach_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/learn_to_play_test_helpers.dart';

Future<void> _pumpLearnScreen(WidgetTester tester) async {
  configureLearnToPlayTestViewport(tester);
  await pumpLearnToPlayFrame(
    tester,
    MaterialApp(theme: BalatroTheme.testTheme, home: const LearnToPlayScreen()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('uses real game UI with coach banner and locked actions', (
    tester,
  ) async {
    await _pumpLearnScreen(tester);

    expect(find.text('HAND & FOOT'), findsOneWidget);
    expect(find.textContaining('Hand and a Foot'), findsOneWidget);
    expect(find.byType(LearnToPlayCoachBanner), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    final drawFinder = find.widgetWithText(ElevatedButton, 'Draw from deck');
    expect(drawFinder, findsOneWidget);
    expect(tester.widget<ElevatedButton>(drawFinder).onPressed, isNull);
  });

  testWidgets('draw step enables Draw from deck on the real action bar', (
    tester,
  ) async {
    await _pumpLearnScreen(tester);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('drawing 2 cards'), findsOneWidget);
    final drawFinder = find.widgetWithText(ElevatedButton, 'Draw from deck');
    expect(tester.widget<ElevatedButton>(drawFinder).onPressed, isNotNull);
  });

  testWidgets('meld step opens the advanced meld modal from Play Cards', (
    tester,
  ) async {
    await _pumpLearnScreen(tester);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Draw from deck'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('meld modal'), findsOneWidget);
    expect(find.byType(LearnToPlayCoachBanner), findsOneWidget);
    final playCards = find.widgetWithText(ElevatedButton, 'Play Cards');
    expect(tester.widget<ElevatedButton>(playCards).onPressed, isNotNull);

    await tester.tap(playCards);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(AdvancedMeldSelector), findsOneWidget);
  });

  testWidgets('lesson disables pile taps even at the draw step', (
    tester,
  ) async {
    await _pumpLearnScreen(tester);
    final controller = tester
        .widget<GameScreen>(find.byType(GameScreen))
        .gameController!;
    final originalDeckSize = controller.gameState.deck.size;
    var board = tester.widget<GameBoardLayout>(find.byType(GameBoardLayout));
    expect(board.onDeckTap, isNull);
    expect(board.onDiscardTap, isNull);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    board = tester.widget<GameBoardLayout>(find.byType(GameBoardLayout));
    expect(board.onDeckTap, isNull);
    expect(board.onDiscardTap, isNull);
    expect(controller.gameState.deck.size, originalDeckSize);
    expect(await TurnCoachPreferences.shouldShowCoach(), isTrue);
  });

  testWidgets('lesson play-down leaves the first-game coach available', (
    tester,
  ) async {
    await _pumpLearnScreen(tester);
    final session = tester
        .widget<GameScreen>(find.byType(GameScreen))
        .learnToPlaySession!;
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Draw from deck'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Play Cards'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('all_clean_melds_button')));
    await tester.pump();
    await tester.tap(find.text('Confirm Play-Down'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(session.human.hasPlayedDown, isTrue);
    expect(await TurnCoachPreferences.shouldShowCoach(), isTrue);
  });
}
