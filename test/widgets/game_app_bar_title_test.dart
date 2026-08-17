@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/utils/game_responsive_layout.dart';
import 'package:hand_foot_game_flutter/widgets/game_app_bar.dart';

void main() {
  group('GameAppBar titles', () {
    late GameState gameState;

    setUp(() {
      gameState = GameState(
        players: [Player(id: '1', name: 'You', type: PlayerType.human)],
        deck: Deck.createHandAndFootDeck(1, seed: 1),
      );
    });

    Future<void> pumpAppBar(WidgetTester tester, {required Size size}) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: MaterialApp(
            home: Scaffold(
              appBar: GameAppBar(gameState: gameState, isMultiplayer: false),
            ),
          ),
        ),
      );
    }

    testWidgets('phone width shows H&F title', (tester) async {
      await pumpAppBar(
        tester,
        size: const Size(GameResponsiveLayout.normalPhoneBreakpoint, 800),
      );

      expect(find.text('H&F'), findsOneWidget);
      expect(find.text('HAND & FOOT'), findsNothing);
    });

    testWidgets('wider layout shows HAND & FOOT title', (tester) async {
      await pumpAppBar(tester, size: const Size(800, 800));

      expect(find.text('HAND & FOOT'), findsOneWidget);
      expect(find.text('H&F'), findsNothing);
    });
  });
}
