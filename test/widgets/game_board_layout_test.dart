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

    Widget buildBoard() {
      return GameBoardLayout(
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
      );
    }

    Future<void> pumpBoard(
      WidgetTester tester,
      Size size, {
      List<DisplayFeature> displayFeatures = const [],
      PreferredSizeWidget? appBar,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, displayFeatures: displayFeatures),
          child: MaterialApp(
            home: Scaffold(appBar: appBar, body: buildBoard()),
          ),
        ),
      );
      // Fold host measures its global origin in a post-frame callback.
      await tester.pump();
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
        const fold = Rect.fromLTWH(455, 0, 40, 669);
        await pumpBoard(
          tester,
          const Size(951, 669),
          displayFeatures: const [
            DisplayFeature(
              bounds: fold,
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

        final gap = tester.getRect(find.byKey(GameBoardLayout.foldGapKey));
        final play = tester.getRect(
          find.byKey(GameBoardLayout.foldPlaySurfaceKey),
        );
        final dock = tester.getRect(find.byKey(GameBoardLayout.bottomDockKey));
        expect(gap.left, closeTo(fold.left, 0.5));
        expect(gap.width, closeTo(fold.width, 0.5));
        expect(play.overlaps(fold), isFalse);
        expect(dock.overlaps(fold), isFalse);
      });

      testWidgets('partially open laptop pose splits around horizontal fold', (
        tester,
      ) async {
        const fold = Rect.fromLTWH(0, 300, 951, 40);
        await pumpBoard(
          tester,
          const Size(951, 669),
          displayFeatures: const [
            DisplayFeature(
              bounds: fold,
              type: DisplayFeatureType.fold,
              state: DisplayFeatureState.postureHalfOpened,
            ),
          ],
        );
        expect(find.byKey(GameBoardLayout.foldLaptopKey), findsOneWidget);
        expect(find.byKey(GameBoardLayout.bottomDockKey), findsOneWidget);
        expect(find.text('Hand'), findsOneWidget);
        expect(find.text('Melds'), findsOneWidget);

        final gap = tester.getRect(find.byKey(GameBoardLayout.foldGapKey));
        final play = tester.getRect(
          find.byKey(GameBoardLayout.foldPlaySurfaceKey),
        );
        final dock = tester.getRect(find.byKey(GameBoardLayout.bottomDockKey));
        expect(gap.top, closeTo(fold.top, 0.5));
        expect(gap.height, closeTo(fold.height, 0.5));
        expect(play.bottom, lessThanOrEqualTo(fold.top + 0.5));
        expect(dock.top, greaterThanOrEqualTo(fold.bottom - 0.5));
        expect(play.overlaps(fold), isFalse);
        expect(dock.overlaps(fold), isFalse);
      });

      testWidgets(
        'laptop fold stays clear of crease when board is below an AppBar',
        (tester) async {
          const fold = Rect.fromLTWH(0, 300, 951, 40);
          const toolbarHeight = 56.0;
          await pumpBoard(
            tester,
            const Size(951, 669),
            appBar: const PreferredSize(
              preferredSize: Size.fromHeight(toolbarHeight),
              child: SizedBox(
                height: toolbarHeight,
                child: ColoredBox(color: Colors.black),
              ),
            ),
            displayFeatures: const [
              DisplayFeature(
                bounds: fold,
                type: DisplayFeatureType.fold,
                state: DisplayFeatureState.postureHalfOpened,
              ),
            ],
          );
          expect(find.byKey(GameBoardLayout.foldLaptopKey), findsOneWidget);

          final gap = tester.getRect(find.byKey(GameBoardLayout.foldGapKey));
          final play = tester.getRect(
            find.byKey(GameBoardLayout.foldPlaySurfaceKey),
          );
          final dock = tester.getRect(
            find.byKey(GameBoardLayout.bottomDockKey),
          );
          // Gap must track the window-space crease, not a padding-only offset.
          expect(gap.top, closeTo(fold.top, 0.5));
          expect(gap.height, closeTo(fold.height, 0.5));
          expect(play.bottom, lessThanOrEqualTo(fold.top + 0.5));
          expect(dock.top, greaterThanOrEqualTo(fold.bottom - 0.5));
          expect(play.overlaps(fold), isFalse);
          expect(dock.overlaps(fold), isFalse);
        },
      );
    });
  });
}
