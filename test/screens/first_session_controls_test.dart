import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/events/game_event_bus.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/providers/game_providers.dart';
import 'package:hand_foot_game_flutter/screens/game_screen.dart';
import 'package:hand_foot_game_flutter/services/turn_coach_preferences.dart';
import 'package:hand_foot_game_flutter/widgets/game_board_layout.dart';
import 'package:hand_foot_game_flutter/widgets/game_hand_display.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameController> pumpGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final eventBus = GameEventBus();
    addTearDown(eventBus.dispose);
    final controller = GameController(
      players: [
        Player(id: '1', name: 'You', type: PlayerType.human),
        Player(id: '2', name: 'Sue', type: PlayerType.bot),
        Player(id: '3', name: 'Clara', type: PlayerType.bot),
      ],
      seed: 42,
      eventBus: eventBus,
    );
    controller.initializeGame(dealCards: true);
    controller.gameState.currentPlayerIndex = 0;
    controller.gameState.turnPhase = TurnPhase.draw;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameEventBusProvider.overrideWithValue(eventBus)],
        child: MaterialApp(home: GameScreen(gameController: controller)),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return controller;
  }

  testWidgets('deck tap draws once and disables pile taps after drawing', (
    tester,
  ) async {
    final controller = await pumpGame(tester);
    final deckSize = controller.gameState.deck.size;
    final handSize = controller.gameState.currentPlayer.currentHand.length;
    expect(find.text('NEXT STEP'), findsOneWidget);
    expect(
      tester.widget<GameBoardLayout>(find.byType(GameBoardLayout)).onDeckTap,
      isNotNull,
    );

    await tester.tap(find.text('Deck'));
    await tester.pump();
    expect(controller.gameState.deck.size, deckSize - 2);
    expect(controller.gameState.currentPlayer.currentHand.length, handSize + 2);
    expect(controller.gameState.turnPhase, TurnPhase.meld);
    final board = tester.widget<GameBoardLayout>(find.byType(GameBoardLayout));
    expect(board.onDeckTap, isNull);
    expect(board.onDiscardTap, isNull);
    // Let the draw animation finish before the test disposes the screen.
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('discard pile explains why an empty pile cannot be taken', (
    tester,
  ) async {
    final controller = await pumpGame(tester);
    controller.gameState.discardPile.clear();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('The discard pile is empty.'), findsOneWidget);
    expect(controller.gameState.turnPhase, TurnPhase.draw);
  });

  testWidgets('selecting multiple cards before drawing shows one nudge', (
    tester,
  ) async {
    await pumpGame(tester);
    void selectCard(int index) {
      tester.widget<GameHandDisplay>(find.byType(GameHandDisplay)).onCardTap!(
        index,
      );
    }

    selectCard(0);
    await tester.pump();
    expect(find.text('Draw before you can play or discard.'), findsNothing);
    selectCard(1);
    await tester.pump();
    expect(find.text('Draw before you can play or discard.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Draw before you can play or discard.'), findsNothing);
    selectCard(2);
    await tester.pump();
    expect(find.text('Draw before you can play or discard.'), findsNothing);
  });

  testWidgets('hiding the coach persists the preference', (tester) async {
    await pumpGame(tester);
    expect(find.byTooltip('Hide tips'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide tips'));
    await tester.pump();
    expect(find.text('NEXT STEP'), findsNothing);
    expect(await TurnCoachPreferences.shouldShowCoach(), isFalse);
  });
}
