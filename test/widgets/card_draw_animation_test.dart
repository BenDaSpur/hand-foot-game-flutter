import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/widgets/card_back_widget.dart';
import 'package:hand_foot_game_flutter/widgets/card_draw_animation_overlay.dart';
import 'package:hand_foot_game_flutter/widgets/game_piles_row.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';

void main() {
  group('Card draw animation widgets', () {
    testWidgets('CardBackWidget renders face-down card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CardBackWidget())),
      );

      expect(find.byType(CardBackWidget), findsOneWidget);
      expect(find.byIcon(Icons.style), findsOneWidget);
    });

    testWidgets('GamePilesRow renders deck and discard anchors', (
      tester,
    ) async {
      final deckKey = GlobalKey();
      final discardKey = GlobalKey();
      final players = [
        Player(id: 'human', name: 'You', type: PlayerType.human),
      ];
      final gameState = GameState(
        players: players,
        deck: Deck.createHandAndFootDeck(1, seed: 42),
      );
      gameState.discardPile.add(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GamePilesRow(
              gameState: gameState,
              deckKey: deckKey,
              discardKey: discardKey,
            ),
          ),
        ),
      );

      expect(find.text('Deck'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
      expect(deckKey.currentContext, isNotNull);
      expect(discardKey.currentContext, isNotNull);
    });

    testWidgets('CardDrawAnimationOverlay completes deck draw animation', (
      tester,
    ) async {
      final deckKey = GlobalKey();
      final discardKey = GlobalKey();
      final handStackKey = GlobalKey();
      final meldAreaKey = GlobalKey();
      final scrollController = ScrollController();
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Row(
                  children: [
                    SizedBox(key: deckKey, width: 60, height: 80),
                    SizedBox(key: discardKey, width: 60, height: 80),
                  ],
                ),
                SizedBox(key: handStackKey, width: 300, height: 120),
                SizedBox(key: meldAreaKey, width: 300, height: 200),
                CardDrawAnimationOverlay(
                  request: CardAnimationRequest(
                    type: CardDrawAnimationType.deckDraw,
                    handCards: const [
                      PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
                      PlayingCard(suit: Suit.spades, rank: CardRank.king),
                    ],
                    handTargetIndices: const [0, 1],
                  ),
                  deckKey: deckKey,
                  discardKey: discardKey,
                  handStackKey: handStackKey,
                  meldAreaKey: meldAreaKey,
                  handScrollController: scrollController,
                  onComplete: () {
                    completed = true;
                  },
                  onSkip: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(completed, isTrue);
      scrollController.dispose();
    });
  });
}
