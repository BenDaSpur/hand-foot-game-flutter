@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';
import 'package:hand_foot_game_flutter/widgets/game_hand_display.dart';

void main() {
  Player human({required bool onFoot, int cardCount = 3}) {
    final cards = List<PlayingCard>.generate(
      cardCount,
      (i) => PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
    );
    return Player(
      id: '1',
      name: 'You',
      type: PlayerType.human,
      hand: onFoot ? [] : cards,
      foot: onFoot ? cards : [],
      hasPickedUpFoot: onFoot,
    );
  }

  Future<void> pumpHand(
    WidgetTester tester, {
    required Player player,
    Player? viewingPlayerMelds,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.testTheme,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 200,
            child: GameHandDisplay(
              player: player,
              selectedCardIndices: const [],
              viewingPlayerMelds: viewingPlayerMelds,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows Your Hand with card count while still on hand pile', (
    tester,
  ) async {
    await pumpHand(tester, player: human(onFoot: false, cardCount: 4));

    expect(find.text('Your Hand (4)'), findsOneWidget);
    expect(find.textContaining('Your Foot'), findsNothing);
  });

  testWidgets('shows Your Foot with card count after picking up the foot', (
    tester,
  ) async {
    await pumpHand(tester, player: human(onFoot: true, cardCount: 7));

    expect(find.text('Your Foot (7)'), findsOneWidget);
    expect(find.textContaining('Your Hand'), findsNothing);
  });

  testWidgets('keeps viewing-other-player label even when on foot', (
    tester,
  ) async {
    final opponent = Player(id: '2', name: 'Sue', type: PlayerType.bot);
    await pumpHand(
      tester,
      player: human(onFoot: true, cardCount: 5),
      viewingPlayerMelds: opponent,
    );

    expect(find.text('Viewing Sue — tap to return'), findsOneWidget);
    expect(find.textContaining('Your Foot'), findsNothing);
    expect(find.textContaining('Your Hand'), findsNothing);
  });
}
