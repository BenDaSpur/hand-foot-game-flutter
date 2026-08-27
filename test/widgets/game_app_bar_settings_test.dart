@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/widgets/game_app_bar.dart';

void main() {
  group('GameAppBar settings', () {
    late GameState gameState;

    setUp(() {
      gameState = GameState(
        players: [Player(id: '1', name: 'You', type: PlayerType.human)],
        deck: Deck.createHandAndFootDeck(1, seed: 1),
      );
    });

    testWidgets('solo menu includes Settings when callback is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: GameAppBar(
              gameState: gameState,
              isMultiplayer: false,
              onHowToPlay: () {},
              onSettings: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.widgetWithText(PopupMenuItem<String>, 'Settings'),
        findsOneWidget,
      );
    });

    testWidgets(
      'multiplayer menu includes Settings when callback is provided',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: GameAppBar(
                gameState: gameState,
                isMultiplayer: true,
                onSettings: () {},
                onLeaveGame: () {},
              ),
            ),
          ),
        );

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.widgetWithText(PopupMenuItem<String>, 'Settings'),
          findsOneWidget,
        );
      },
    );
  });
}
