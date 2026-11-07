@Tags(['widget'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/widgets/game_action_buttons.dart';
import 'package:hand_foot_game_flutter/widgets/game_action_rail_scope.dart';
import 'package:hand_foot_game_flutter/widgets/game_board_layout.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late GameState gameState;
  late Player human;

  setUp(() {
    human = Player(id: '1', name: 'You', type: PlayerType.human);
    gameState = GameState(
      players: [
        human,
        Player(id: '2', name: 'Ben', type: PlayerType.bot),
      ],
      deck: Deck.createHandAndFootDeck(2, seed: 7),
    );
  });

  Future<void> pumpButtons(
    WidgetTester tester, {
    required Size size,
    required bool slim,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          home: Scaffold(
            body: GameActionRailScope(
              slim: slim,
              child: GameActionButtons(
                gameState: gameState,
                humanPlayer: human,
                selectedCardIndices: const [],
                onDrawFromDeck: () {},
                onUnlockDiscard: null,
                onShowAdvancedMeldSelector: () {},
                onDiscard: () {},
                onClearSelection: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('slim rail keeps the full action name in semantics', (
    tester,
  ) async {
    await pumpButtons(tester, size: const Size(466, 678), slim: true);

    expect(find.bySemanticsLabel('Draw from deck'), findsOneWidget);
    expect(find.text('Draw'), findsOneWidget);
    expect(find.text('Draw from deck'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone dock keeps the full action label visible', (tester) async {
    await pumpButtons(tester, size: const Size(390, 844), slim: false);

    expect(find.text('Draw from deck'), findsOneWidget);
    expect(find.text('Draw'), findsNothing);
  });

  testWidgets('cover board shows slim actions without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(466, 678);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(466, 678)),
        child: MaterialApp(
          home: Scaffold(
            body: GameBoardLayout(
              gameState: gameState,
              viewingPlayerMelds: null,
              onPlayerTap: (_) {},
              meldsSection: const ColoredBox(
                color: Colors.black26,
                child: Center(child: Text('Melds')),
              ),
              actionButtons: GameActionButtons(
                gameState: gameState,
                humanPlayer: human,
                selectedCardIndices: const [],
                onDrawFromDeck: () {},
                onUnlockDiscard: () {},
                onShowAdvancedMeldSelector: () {},
                onDiscard: () {},
                onClearSelection: () {},
              ),
              handDisplay: const SizedBox(
                height: 80,
                child: Center(child: Text('Hand')),
              ),
              deckKey: GlobalKey(),
              discardKey: GlobalKey(),
              headerExpanded: true,
              onHeaderToggle: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(GameBoardLayout.coverBoardKey), findsOneWidget);
    expect(find.bySemanticsLabel('Draw from deck'), findsOneWidget);
    expect(find.bySemanticsLabel('Take Discard'), findsOneWidget);
    final drawLabel = find.descendant(
      of: find.byKey(GameBoardLayout.trailingActionRailKey),
      matching: find.text('Draw'),
    );
    final takeLabel = find.descendant(
      of: find.byKey(GameBoardLayout.trailingActionRailKey),
      matching: find.text('Take'),
    );
    expect(drawLabel, findsOneWidget);
    expect(takeLabel, findsOneWidget);

    final rail = tester.getRect(
      find.byKey(GameBoardLayout.trailingActionRailKey),
    );
    final draw = tester.getRect(drawLabel);
    expect(draw.left, greaterThanOrEqualTo(rail.left - 0.5));
    expect(draw.bottom, lessThanOrEqualTo(rail.bottom + 0.5));
    expect(tester.takeException(), isNull);
  });
}
