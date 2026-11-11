@Tags(['widget'])
library;

import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/utils/game_responsive_layout.dart';
import 'package:hand_foot_game_flutter/widgets/game_action_buttons.dart';
import 'package:hand_foot_game_flutter/widgets/game_board_layout.dart';

void _expectTrailingActions(WidgetTester tester) {
  final rail = tester.getRect(
    find.byKey(GameBoardLayout.trailingActionRailKey),
  );
  final melds = tester.getRect(find.text('Melds'));
  final dock = tester.getRect(find.byKey(GameBoardLayout.bottomDockKey));
  final hand = tester.getRect(find.text('Hand'));
  final actions = tester.getRect(find.text('Actions'));
  expect(rail.left, greaterThanOrEqualTo(melds.right - 0.5));
  expect(dock.right, lessThanOrEqualTo(rail.left + 0.5));
  expect(dock.overlaps(hand), isTrue);
  expect(actions.left, greaterThanOrEqualTo(rail.left - 0.5));
  expect(actions.right, lessThanOrEqualTo(rail.right + 0.5));
}

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

    Widget buildBoard({Widget? actionButtons}) {
      return GameBoardLayout(
        gameState: gameState,
        viewingPlayerMelds: null,
        onPlayerTap: (_) {},
        meldsSection: const ColoredBox(
          color: Colors.black26,
          child: Center(child: Text('Melds')),
        ),
        actionButtons:
            actionButtons ??
            const SizedBox(height: 48, child: Center(child: Text('Actions'))),
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
      EdgeInsets padding = EdgeInsets.zero,
      Widget? actionButtons,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      final viewPadding = FakeViewPadding(
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom,
      );
      tester.view.padding = viewPadding;
      tester.view.viewPadding = viewPadding;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: padding,
            viewPadding: padding,
            displayFeatures: displayFeatures,
          ),
          child: MaterialApp(
            home: Scaffold(
              appBar: appBar,
              body: buildBoard(actionButtons: actionButtons),
            ),
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
      expect(find.byKey(GameBoardLayout.trailingActionRailKey), findsNothing);
      final dock = tester.getRect(find.byKey(GameBoardLayout.bottomDockKey));
      final actions = tester.getRect(find.text('Actions'));
      expect(dock.overlaps(actions), isTrue);
    });

    testWidgets('uses narrow column layout on iPad portrait', (tester) async {
      await pumpBoard(tester, const Size(768, 1024));
      expect(find.byKey(GameBoardLayout.narrowBoardKey), findsOneWidget);
      expect(find.byKey(GameBoardLayout.wideBoardKey), findsNothing);
      expect(find.byKey(GameBoardLayout.trailingActionRailKey), findsNothing);
      final dock = tester.getRect(find.byKey(GameBoardLayout.bottomDockKey));
      final actions = tester.getRect(find.text('Actions'));
      expect(dock.overlaps(actions), isTrue);
    });

    testWidgets('uses two-pane rail layout when width is wide', (tester) async {
      await pumpBoard(tester, const Size(1024, 768));
      expect(find.byKey(GameBoardLayout.wideBoardKey), findsOneWidget);
      expect(find.byKey(GameBoardLayout.wideRailKey), findsOneWidget);
      expect(find.byKey(GameBoardLayout.narrowBoardKey), findsNothing);
      expect(find.text('Actions'), findsOneWidget);
      expect(find.text('Hand'), findsOneWidget);
      expect(find.text('Melds'), findsOneWidget);
      final rail = tester.getRect(find.byKey(GameBoardLayout.wideRailKey));
      final melds = tester.getRect(find.text('Melds'));
      expect(rail.left, lessThan(melds.left));
    });

    group('iPhone Duo fixtures', () {
      testWidgets('cover portrait parks actions in a trailing rail', (
        tester,
      ) async {
        await pumpBoard(tester, const Size(466, 678));
        expect(find.byKey(GameBoardLayout.coverBoardKey), findsOneWidget);
        expect(find.byKey(GameBoardLayout.narrowBoardKey), findsNothing);
        expect(find.byKey(GameBoardLayout.wideBoardKey), findsNothing);
        expect(find.byKey(GameBoardLayout.bottomDockKey), findsOneWidget);
        _expectTrailingActions(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('cover landscape parks actions in a trailing rail', (
        tester,
      ) async {
        await pumpBoard(tester, const Size(678, 466));
        expect(find.byKey(GameBoardLayout.coverBoardKey), findsOneWidget);
        expect(find.byKey(GameBoardLayout.narrowBoardKey), findsNothing);
        expect(find.byKey(GameBoardLayout.bottomDockKey), findsOneWidget);
        _expectTrailingActions(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'cover portrait puts the action rail in the trailing status strip',
        (tester) async {
          const size = Size(466, 678);
          const statusStrip = 84.0;
          await pumpBoard(
            tester,
            size,
            padding: const EdgeInsets.only(right: statusStrip),
          );
          expect(find.byKey(GameBoardLayout.coverBoardKey), findsOneWidget);
          _expectTrailingActions(tester);

          final rail = tester.getRect(
            find.byKey(GameBoardLayout.trailingActionRailKey),
          );
          final dock = tester.getRect(
            find.byKey(GameBoardLayout.bottomDockKey),
          );
          // The rail is the strip itself, flush with the screen edge. The
          // hand keeps the full safe width instead of losing another 84pt.
          expect(rail.right, closeTo(size.width, 0.5));
          expect(rail.left, closeTo(size.width - statusStrip, 0.5));
          expect(rail.width, closeTo(statusStrip, 0.5));
          expect(dock.right, closeTo(rail.left, 0.5));
          expect(dock.left, closeTo(0, 0.5));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'cover rail grows with a wider status strip and clears the home indicator',
        (tester) async {
          const size = Size(678, 466);
          const statusStrip = 100.0;
          const homeIndicator = 34.0;
          await pumpBoard(
            tester,
            size,
            padding: const EdgeInsets.only(
              right: statusStrip,
              bottom: homeIndicator,
            ),
          );
          expect(find.byKey(GameBoardLayout.coverBoardKey), findsOneWidget);
          final rail = tester.getRect(
            find.byKey(GameBoardLayout.trailingActionRailKey),
          );
          final dock = tester.getRect(
            find.byKey(GameBoardLayout.bottomDockKey),
          );
          final actions = tester.getRect(find.text('Actions'));
          expect(rail.right, closeTo(size.width, 0.5));
          expect(rail.width, closeTo(statusStrip, 0.5));
          expect(rail.bottom, closeTo(size.height - homeIndicator, 0.5));
          expect(dock.right, closeTo(rail.left, 0.5));
          expect(actions.bottom, lessThanOrEqualTo(rail.bottom + 0.5));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('phone keeps actions inside a trailing safe inset', (
        tester,
      ) async {
        const size = Size(390, 844);
        const inset = 47.0;
        await pumpBoard(
          tester,
          size,
          padding: const EdgeInsets.only(right: inset),
        );
        expect(find.byKey(GameBoardLayout.narrowBoardKey), findsOneWidget);
        expect(find.byKey(GameBoardLayout.trailingActionRailKey), findsNothing);
        final dock = tester.getRect(find.byKey(GameBoardLayout.bottomDockKey));
        final actions = tester.getRect(find.text('Actions'));
        expect(dock.right, lessThanOrEqualTo(size.width - inset + 0.5));
        expect(dock.overlaps(actions), isTrue);
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

      testWidgets('inner landscape puts the wide rail on the trailing edge', (
        tester,
      ) async {
        await pumpBoard(tester, const Size(951, 669));
        expect(find.byKey(GameBoardLayout.wideBoardKey), findsOneWidget);
        expect(find.byKey(GameBoardLayout.wideRailKey), findsOneWidget);
        expect(find.byKey(GameBoardLayout.narrowBoardKey), findsNothing);
        expect(find.byKey(GameBoardLayout.trailingActionRailKey), findsNothing);
        final rail = tester.getRect(find.byKey(GameBoardLayout.wideRailKey));
        final melds = tester.getRect(find.text('Melds'));
        expect(rail.left, greaterThan(melds.right));
      });

      testWidgets('inner landscape keeps Discard above the home indicator', (
        tester,
      ) async {
        const size = Size(951, 669);
        const homeIndicator = 34.0;
        gameState.turnPhase = TurnPhase.meld;
        final human = gameState.players.first;
        await pumpBoard(
          tester,
          size,
          padding: const EdgeInsets.only(bottom: homeIndicator),
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
        );

        final discard = tester.getRect(
          find.ancestor(
            of: find.text('Discard'),
            matching: find.byType(ElevatedButton),
          ),
        );
        final safeBottom = size.height - homeIndicator;
        expect(
          discard.bottom,
          lessThanOrEqualTo(
            safeBottom - GameResponsiveLayout.actionDockBottomTouchInset + 0.5,
          ),
        );
        expect(
          discard.height,
          greaterThanOrEqualTo(
            GameResponsiveLayout.railActionButtonHeight - 0.5,
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('short wide rail keeps every meld button reachable', (
        tester,
      ) async {
        gameState.turnPhase = TurnPhase.meld;
        final human = gameState.players.first;
        await pumpBoard(
          tester,
          const Size(1024, 360),
          actionButtons: GameActionButtons(
            gameState: gameState,
            humanPlayer: human,
            selectedCardIndices: const [0],
            onDrawFromDeck: () {},
            onUnlockDiscard: () {},
            onShowAdvancedMeldSelector: () {},
            onDiscard: () {},
            onClearSelection: () {},
            onUndoMeld: () {},
            canUndoMeld: true,
          ),
        );

        expect(tester.takeException(), isNull);
        for (final label in ['Play Cards', 'Undo', 'Discard', 'Clear']) {
          final button = find.descendant(
            of: find.byType(ElevatedButton),
            matching: find.text(label),
          );
          expect(button, findsOneWidget);
          await tester.ensureVisible(button);
        }
        expect(tester.takeException(), isNull);
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
        expect(dock.left, greaterThanOrEqualTo(gap.right - 0.5));
        final rail = tester.getRect(
          find.byKey(GameBoardLayout.trailingActionRailKey),
        );
        expect(rail.left, greaterThanOrEqualTo(dock.right - 0.5));
        expect(rail.overlaps(fold), isFalse);
      });

      testWidgets(
        'book pose puts the action rail in the trailing status strip',
        (tester) async {
          const size = Size(951, 669);
          const statusStrip = 84.0;
          const fold = Rect.fromLTWH(455, 0, 40, 669);
          await pumpBoard(
            tester,
            size,
            padding: const EdgeInsets.only(right: statusStrip),
            displayFeatures: const [
              DisplayFeature(
                bounds: fold,
                type: DisplayFeatureType.fold,
                state: DisplayFeatureState.postureHalfOpened,
              ),
            ],
          );
          expect(find.byKey(GameBoardLayout.foldBookKey), findsOneWidget);

          final gap = tester.getRect(find.byKey(GameBoardLayout.foldGapKey));
          final play = tester.getRect(
            find.byKey(GameBoardLayout.foldPlaySurfaceKey),
          );
          final dock = tester.getRect(
            find.byKey(GameBoardLayout.bottomDockKey),
          );
          final rail = tester.getRect(
            find.byKey(GameBoardLayout.trailingActionRailKey),
          );
          expect(gap.left, closeTo(fold.left, 0.5));
          expect(gap.width, closeTo(fold.width, 0.5));
          expect(play.overlaps(fold), isFalse);
          expect(dock.overlaps(fold), isFalse);
          expect(rail.overlaps(fold), isFalse);
          expect(rail.right, closeTo(size.width, 0.5));
          expect(rail.width, closeTo(statusStrip, 0.5));
          expect(dock.right, closeTo(rail.left, 0.5));
          expect(dock.left, greaterThanOrEqualTo(gap.right - 0.5));
          expect(tester.takeException(), isNull);
        },
      );

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
