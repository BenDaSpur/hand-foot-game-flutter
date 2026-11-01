@Tags(['widget'])
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/widgets/game_compact_header.dart';

void main() {
  group('GameCompactHeader', () {
    late GameState gameState;
    late GlobalKey deckKey;
    late GlobalKey discardKey;

    setUp(() {
      gameState = GameState(
        players: [Player(id: '1', name: 'You', type: PlayerType.human)],
        deck: Deck.createHandAndFootDeck(1, seed: 2),
      );
      gameState.discardPile.add(
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.three),
      );
      deckKey = GlobalKey();
      discardKey = GlobalKey();
    });

    Future<void> pumpHeader(
      WidgetTester tester, {
      required Size size,
      required bool expanded,
      required VoidCallback onToggle,
      List<Widget> persistentHeaderExtras = const [],
      String? localPlayerId,
      VoidCallback? onDeckTap,
      VoidCallback? onDiscardTap,
    }) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: MaterialApp(
            home: Scaffold(
              body: GameCompactHeader(
                gameState: gameState,
                deckKey: deckKey,
                discardKey: discardKey,
                isExpanded: expanded,
                onToggleExpand: onToggle,
                persistentHeaderExtras: persistentHeaderExtras,
                localPlayerId: localPlayerId,
                onDeckTap: onDeckTap,
                onDiscardTap: onDiscardTap,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('collapsed keeps play-down chip and mini piles', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        size: const Size(390, 844),
        expanded: false,
        onToggle: () {},
      );

      // First play-down requirement stays visible without expanding.
      expect(find.textContaining('Play down'), findsOneWidget);
      expect(find.text('Deck'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
      expect(deckKey.currentContext, isNotNull);
      expect(discardKey.currentContext, isNotNull);
    });

    testWidgets('deck and discard piles invoke tap callbacks', (tester) async {
      var deckTaps = 0;
      var discardTaps = 0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: MaterialApp(
            home: Scaffold(
              body: GameCompactHeader(
                gameState: gameState,
                deckKey: deckKey,
                discardKey: discardKey,
                isExpanded: true,
                onToggleExpand: () {},
                onDeckTap: () => deckTaps++,
                onDiscardTap: () => discardTaps++,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Deck'));
      await tester.tap(find.text('Discard'));
      expect(deckTaps, 1);
      expect(discardTaps, 1);
    });

    testWidgets('collapsed pile taps work and null callbacks are inert', (
      tester,
    ) async {
      var deckTaps = 0;
      await pumpHeader(
        tester,
        size: const Size(390, 844),
        expanded: false,
        onToggle: () {},
        onDeckTap: () => deckTaps++,
      );
      await tester.tap(find.text('Deck'));
      await tester.tap(find.text('Discard'));
      expect(deckTaps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('collapsed requirement follows the selected local player', (
      tester,
    ) async {
      gameState.players.first.hasPlayedDown = true;
      gameState.players.add(
        Player(id: '2', name: 'Remote', type: PlayerType.human),
      );
      await pumpHeader(
        tester,
        size: const Size(390, 844),
        expanded: false,
        onToggle: () {},
        localPlayerId: '2',
      );
      expect(
        find.text('Play down ${gameState.playDownRequirement}'),
        findsOneWidget,
      );

      gameState.players.last.hasPlayedDown = true;
      await pumpHeader(
        tester,
        size: const Size(390, 844),
        expanded: false,
        onToggle: () {},
        localPlayerId: '2',
      );
      expect(find.textContaining('Play down'), findsNothing);

      await pumpHeader(
        tester,
        size: const Size(390, 844),
        expanded: false,
        onToggle: () {},
        localPlayerId: 'missing',
      );
      expect(find.textContaining('Play down'), findsNothing);
    });

    testWidgets('expanded shows detail chips at normal height', (tester) async {
      await pumpHeader(
        tester,
        size: const Size(390, 844),
        expanded: true,
        onToggle: () {},
      );

      expect(find.textContaining('Play down'), findsOneWidget);
      expect(find.textContaining('Deck '), findsWidgets);
      expect(deckKey.currentContext, isNotNull);
      expect(discardKey.currentContext, isNotNull);
    });

    testWidgets('expanded shows detail chips on short height', (tester) async {
      await pumpHeader(
        tester,
        size: const Size(390, 640),
        expanded: true,
        onToggle: () {},
      );

      expect(find.textContaining('Play down'), findsOneWidget);
      expect(find.textContaining('Deck '), findsWidgets);
      expect(deckKey.currentContext, isNotNull);
      expect(discardKey.currentContext, isNotNull);
    });

    testWidgets('collapsed keeps pile anchors on short height', (tester) async {
      await pumpHeader(
        tester,
        size: const Size(390, 640),
        expanded: false,
        onToggle: () {},
      );

      expect(find.textContaining('Play down'), findsOneWidget);
      expect(deckKey.currentContext, isNotNull);
      expect(discardKey.currentContext, isNotNull);
    });

    testWidgets('toggle button invokes callback', (tester) async {
      var toggled = false;
      await pumpHeader(
        tester,
        size: const Size(390, 844),
        expanded: false,
        onToggle: () => toggled = true,
      );

      await tester.tap(find.byTooltip('Show deck & details'));
      expect(toggled, isTrue);
    });

    testWidgets(
      'persistent extras stay visible on Duo cover when piles are collapsed',
      (tester) async {
        await pumpHeader(
          tester,
          size: const Size(466, 678),
          expanded: false,
          onToggle: () {},
          persistentHeaderExtras: const [
            KeyedSubtree(
              key: ValueKey('persistent-timer'),
              child: Text('TIMER'),
            ),
          ],
        );

        expect(find.byKey(const ValueKey('persistent-timer')), findsOneWidget);
        expect(find.text('TIMER'), findsOneWidget);
        expect(find.textContaining('Play down'), findsOneWidget);
      },
    );
  });
}
