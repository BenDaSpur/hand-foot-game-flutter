@Tags(['widget'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/widgets/game_action_buttons.dart';
import 'package:hand_foot_game_flutter/widgets/game_board_layout.dart';
import 'package:hand_foot_game_flutter/widgets/game_hand_display.dart';
import 'package:hand_foot_game_flutter/widgets/playing_card_widget.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // Inner landscape logical size. A trailing inset matches the OS status
  // cluster that sits on the right of that screen.
  const duoInnerLandscape = Size(951, 669);
  const trailingStatusInset = 80.0;

  group('Duo inner landscape hand', () {
    Future<ScrollController> pumpHand(
      WidgetTester tester, {
      required int cardCount,
      double trailingInset = 0,
      bool foot = false,
    }) async {
      final human = Player(
        id: '1',
        name: 'You',
        type: PlayerType.human,
        hasPickedUpFoot: foot,
      );
      final pile = foot ? human.foot : human.hand;
      for (var i = 0; i < cardCount; i++) {
        pile.add(
          PlayingCard(
            suit: i.isEven ? Suit.hearts : Suit.spades,
            rank: CardRank.values[i % (CardRank.values.length - 1)],
          ),
        );
      }
      final gameState = GameState(
        players: [
          human,
          Player(id: '2', name: 'Rita', type: PlayerType.bot),
          Player(id: '3', name: 'Tiana', type: PlayerType.bot),
        ],
        deck: Deck.createHandAndFootDeck(3, seed: 7),
        phase: GamePhase.playing,
        turnPhase: TurnPhase.meld,
      );
      gameState.discardPile.add(
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
      );

      final scroll = ScrollController();
      addTearDown(scroll.dispose);

      tester.view.physicalSize = duoInnerLandscape;
      tester.view.devicePixelRatio = 1.0;
      final inset = FakeViewPadding(right: trailingInset);
      tester.view.padding = inset;
      tester.view.viewPadding = inset;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: duoInnerLandscape,
            padding: EdgeInsets.only(right: trailingInset),
            viewPadding: EdgeInsets.only(right: trailingInset),
          ),
          child: MaterialApp(
            home: Scaffold(
              appBar: const PreferredSize(
                preferredSize: Size.fromHeight(kToolbarHeight),
                child: SizedBox(height: kToolbarHeight),
              ),
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
                handDisplay: GameHandDisplay(
                  player: human,
                  selectedCardIndices: const [],
                  handScrollController: scroll,
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
      return scroll;
    }

    List<Rect> handCardRects(WidgetTester tester) {
      final rects = <Rect>[];
      for (final element in find.byType(PlayingCardWidget).evaluate()) {
        final key = element.widget.key;
        if (key is! ValueKey || !key.value.toString().startsWith('hand-')) {
          continue;
        }
        final box = element.renderObject! as RenderBox;
        rects.add(box.localToGlobal(Offset.zero) & box.size);
      }
      rects.sort((a, b) => a.left.compareTo(b.left));
      return rects;
    }

    Rect buttonRect(WidgetTester tester, String label) {
      return tester.getRect(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(ElevatedButton),
        ),
      );
    }

    void expectHandClearsRail(WidgetTester tester) {
      final rail = tester.getRect(find.byKey(GameBoardLayout.wideRailKey));
      final dock = tester.getRect(find.byKey(GameBoardLayout.bottomDockKey));
      final play = buttonRect(tester, 'Play Cards');
      final discard = buttonRect(tester, 'Discard');
      final cards = handCardRects(tester);

      expect(cards, isNotEmpty);
      expect(find.byKey(GameBoardLayout.wideBoardKey), findsOneWidget);
      final board = tester.getRect(find.byKey(GameBoardLayout.wideBoardKey));
      expect(dock.right, closeTo(rail.left - 1, 1));
      expect(dock.left, closeTo(board.left, 1));
      expect(rail.right, closeTo(board.right, 1));
      for (final card in cards) {
        expect(card.right, lessThanOrEqualTo(rail.left + 0.5));
        expect(card.left, greaterThanOrEqualTo(dock.left - 0.5));
        expect(card.overlaps(play), isFalse);
        expect(card.overlaps(discard), isFalse);
      }
      expect(play.left, greaterThanOrEqualTo(rail.left - 0.5));
      expect(play.bottom, lessThanOrEqualTo(duoInnerLandscape.height + 0.5));
      expect(discard.bottom, lessThanOrEqualTo(duoInnerLandscape.height + 0.5));
      expect(tester.takeException(), isNull);
    }

    testWidgets('one-card foot and three-card hand use the same card width', (
      tester,
    ) async {
      await pumpHand(tester, cardCount: 1, foot: true);
      expect(find.text('Your Foot (1)'), findsOneWidget);
      final footWidth = handCardRects(tester).single.width;

      await pumpHand(tester, cardCount: 3);
      expect(find.text('Your Hand (3)'), findsOneWidget);
      final handWidths = handCardRects(tester)
          .map((rect) => rect.width)
          .toSet();

      expect(handWidths, hasLength(1));
      expect(handWidths.single, closeTo(footWidth, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('13-card hand stays clear of the trailing rail', (
      tester,
    ) async {
      final scroll = await pumpHand(tester, cardCount: 13);

      expectHandClearsRail(tester);
      expect(scroll.position.maxScrollExtent, lessThanOrEqualTo(1));
    });

    testWidgets('13-card hand stays clear of the rail beside a status inset', (
      tester,
    ) async {
      final scroll = await pumpHand(
        tester,
        cardCount: 13,
        trailingInset: trailingStatusInset,
      );

      expectHandClearsRail(tester);
      expect(scroll.position.maxScrollExtent, lessThanOrEqualTo(1));

      // Drawing scrolls toward the new cards. The fan must still not cover
      // the rail when that scroll has nowhere to go.
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      expectHandClearsRail(tester);
    });

    testWidgets('a hand that still overflows is clipped to the dock', (
      tester,
    ) async {
      final scroll = await pumpHand(
        tester,
        cardCount: 40,
        trailingInset: trailingStatusInset,
      );

      expect(scroll.position.maxScrollExtent, greaterThan(1));
      final scroller = tester.widget<SingleChildScrollView>(
        find.byKey(GameHandDisplay.scrollerKey),
      );
      expect(scroller.clipBehavior, Clip.hardEdge);

      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();

      final viewport = tester.renderObject(
        find.byKey(GameHandDisplay.scrollerKey),
      );
      Rect? clip;
      void visit(RenderObject node) {
        node.visitChildren((child) {
          if (node.runtimeType.toString().contains('Viewport')) {
            clip = node.describeApproximatePaintClip(child);
          }
          visit(child);
        });
      }

      visit(viewport);
      expect(clip, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });
}
