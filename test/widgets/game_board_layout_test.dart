@Tags(['widget'])
library;

import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/widgets/game_board_layout.dart';

void main() {
  group('GameBoardLayout', () {
    late GameState gameState;
    late GlobalKey deckKey;
    late GlobalKey discardKey;

    setUp(() {
      gameState = GameState(
        players: [
          Player(id: '1', name: 'You', type: PlayerType.human),
          Player(id: '2', name: 'Ben', type: PlayerType.bot),
          Player(id: '3', name: 'Tiana', type: PlayerType.bot),
        ],
        deck: Deck.createHandAndFootDeck(3, seed: 7),
      );
      deckKey = GlobalKey();
      discardKey = GlobalKey();
    });

    Future<void> pumpBoard(
      WidgetTester tester,
      Size size, {
      List<DisplayFeature> displayFeatures = const [],
    }) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, displayFeatures: displayFeatures),
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
                actionButtons: const SizedBox(
                  height: 48,
                  child: Center(child: Text('Actions')),
                ),
                handDisplay: const SizedBox(
                  height: 80,
                  child: Center(child: Text('Hand')),
                ),
                deckKey: deckKey,
                discardKey: discardKey,
                headerExpanded: true,
                onHeaderToggle: () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('uses narrow column layout on phone', (tester) async {
      await pumpBoard(tester, const Size(390, 844));
      expect(find.byKey(GameBoardLayout.narrowBoardKey), findsOneWidget);
      expect(find.byKey(GameBoardLayout.wideBoardKey), findsNothing);
      expect(find.byKey(GameBoardLayout.wideRailKey), findsNothing);
    });

    testWidgets('uses narrow column layout on iPad portrait', (tester) async {
      await pumpBoard(tester, const Size(768, 1024));
      expect(find.byKey(GameBoardLayout.narrowBoardKey), findsOneWidget);
      expect(find.byKey(GameBoardLayout.wideBoardKey), findsNothing);
    });

    testWidgets('uses two-pane rail layout when width is wide', (tester) async {
      await pumpBoard(tester, const Size(1024, 768));
      expect(find.byKey(GameBoardLayout.wideBoardKey), findsOneWidget);
      expect(find.byKey(GameBoardLayout.wideRailKey), findsOneWidget);
      expect(find.byKey(GameBoardLayout.narrowBoardKey), findsNothing);
      expect(find.text('Actions'), findsOneWidget);
      expect(find.text('Hand'), findsOneWidget);
      expect(find.text('Melds'), findsOneWidget);
    });

    group('iPhone Duo fixtures', () {
      testWidgets('cover portrait uses narrow phone board', (tester) async {
        await pumpBoard(tester, const Size(466, 678));
        expect(find.byKey(GameBoardLayout.narrowBoardKey), findsOneWidget);
        expect(find.byKey(GameBoardLayout.wideBoardKey), findsNothing);
        expect(find.byKey(GameBoardLayout.bottomDockKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('cover landscape ultra-short stays narrow without overflow', (
        tester,
      ) async {
        await pumpBoard(tester, const Size(678, 466));
        expect(find.byKey(GameBoardLayout.narrowBoardKey), findsOneWidget);
        expect(find.byKey(GameBoardLayout.bottomDockKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('inner portrait stays narrow with expansive chrome', (
        tester,
      ) async {
        await pumpBoard(tester, const Size(669, 951));
        expect(find.byKey(GameBoardLayout.narrowBoardKey), findsOneWidget);
        expect(find.byKey(GameBoardLayout.wideBoardKey), findsNothing);
        expect(find.text('Melds'), findsOneWidget);
      });

      testWidgets('inner landscape uses wide rail board', (tester) async {
        await pumpBoard(tester, const Size(951, 669));
        expect(find.byKey(GameBoardLayout.wideBoardKey), findsOneWidget);
        expect(find.byKey(GameBoardLayout.wideRailKey), findsOneWidget);
        expect(find.byKey(GameBoardLayout.narrowBoardKey), findsNothing);
      });

      testWidgets('partially open book pose splits around vertical fold', (
        tester,
      ) async {
        await pumpBoard(
          tester,
          const Size(951, 669),
          displayFeatures: const [
            DisplayFeature(
              bounds: Rect.fromLTWH(455, 0, 40, 669),
              type: DisplayFeatureType.fold,
              state: DisplayFeatureState.postureHalfOpened,
            ),
          ],
        );
        expect(find.byKey(GameBoardLayout.foldBookKey), findsOneWidget);
        expect(find.byKey(GameBoardLayout.narrowBoardKey), findsNothing);
        expect(find.byKey(GameBoardLayout.wideBoardKey), findsNothing);
        expect(find.byKey(GameBoardLayout.bottomDockKey), findsOneWidget);
        expect(find.text('Actions'), findsOneWidget);
        expect(find.text('Melds'), findsOneWidget);
      });

      testWidgets('partially open laptop pose splits around horizontal fold', (
        tester,
      ) async {
        await pumpBoard(
          tester,
          const Size(951, 669),
          displayFeatures: const [
            DisplayFeature(
              bounds: Rect.fromLTWH(0, 300, 951, 40),
              type: DisplayFeatureType.fold,
              state: DisplayFeatureState.postureHalfOpened,
            ),
          ],
        );
        expect(find.byKey(GameBoardLayout.foldLaptopKey), findsOneWidget);
        expect(find.byKey(GameBoardLayout.bottomDockKey), findsOneWidget);
        expect(find.text('Hand'), findsOneWidget);
        expect(find.text('Melds'), findsOneWidget);
      });
    });
  });
}
