@Tags(['widget'])
library;

import 'package:flutter/material.dart';
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
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('collapsed hides detail chips at normal height', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        size: const Size(390, 844),
        expanded: false,
        onToggle: () {},
      );

      expect(find.textContaining('Play down'), findsNothing);
      expect(find.text('Deck'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
      expect(deckKey.currentContext, isNotNull);
      expect(discardKey.currentContext, isNotNull);
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
    });

    testWidgets('collapsed keeps pile anchors on short height', (tester) async {
      await pumpHeader(
        tester,
        size: const Size(390, 640),
        expanded: false,
        onToggle: () {},
      );

      expect(find.textContaining('Play down'), findsNothing);
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
  });
}
