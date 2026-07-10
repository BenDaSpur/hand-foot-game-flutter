@Tags(['card_animation'])
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/game_config.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/widgets/card_back_widget.dart';
import 'package:hand_foot_game_flutter/widgets/card_draw_animation_overlay.dart';
import 'package:hand_foot_game_flutter/widgets/game_piles_row.dart';
import 'package:hand_foot_game_flutter/widgets/playing_card_widget.dart';

void main() {
  group('Card draw animation widgets', () {
    Future<void> pumpOverlayHarness(
      WidgetTester tester, {
      required CardAnimationRequest request,
      required GlobalKey deckKey,
      required GlobalKey discardKey,
      required GlobalKey handStackKey,
      required GlobalKey meldAreaKey,
      required ScrollController scrollController,
      required VoidCallback onComplete,
      required VoidCallback onSkip,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: Stack(
                children: [
                  Row(
                    children: [
                      SizedBox(key: deckKey, width: 60, height: 80),
                      SizedBox(key: discardKey, width: 60, height: 80),
                    ],
                  ),
                  Positioned(
                    left: 40,
                    bottom: 40,
                    child: SizedBox(key: handStackKey, width: 300, height: 120),
                  ),
                  Positioned(
                    top: 80,
                    left: 40,
                    child: SizedBox(key: meldAreaKey, width: 300, height: 200),
                  ),
                  CardDrawAnimationOverlay(
                    request: request,
                    deckKey: deckKey,
                    discardKey: discardKey,
                    handStackKey: handStackKey,
                    meldAreaKey: meldAreaKey,
                    handScrollController: scrollController,
                    onComplete: onComplete,
                    onSkip: onSkip,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

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

    testWidgets(
      'CardDrawAnimationOverlay shows scrim and cards during deck draw',
      (tester) async {
        final deckKey = GlobalKey();
        final discardKey = GlobalKey();
        final handStackKey = GlobalKey();
        final meldAreaKey = GlobalKey();
        final scrollController = ScrollController();
        var completed = false;
        var skipped = false;

        await pumpOverlayHarness(
          tester,
          request: const CardAnimationRequest(
            type: CardDrawAnimationType.deckDraw,
            handCards: [
              PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
              PlayingCard(suit: Suit.spades, rank: CardRank.king),
            ],
            handTargetIndices: [0, 1],
          ),
          deckKey: deckKey,
          discardKey: discardKey,
          handStackKey: handStackKey,
          meldAreaKey: meldAreaKey,
          scrollController: scrollController,
          onComplete: () {
            completed = true;
          },
          onSkip: () {
            skipped = true;
          },
        );

        await tester.pump();
        expect(find.byType(CardBackWidget), findsNWidgets(2));

        // Hand scroll runs before the staggered fly-in loop.
        await tester.pump(GameConfig.cardRevealDuration);
        await tester.pump();

        await tester.pump(GameConfig.cardFlyDuration ~/ 2);

        await tester.pump(
          GameConfig.cardFlyDuration * 2 + GameConfig.cardStaggerDelay,
        );
        await tester.pump();

        await tester.pump(GameConfig.cardRevealPause);
        await tester.pump();

        expect(find.byType(PlayingCardWidget), findsNWidgets(2));

        await tester.tapAt(const Offset(400, 300));
        await tester.pump();

        expect(skipped, isTrue);
        expect(completed, isTrue);
        scrollController.dispose();
      },
    );

    testWidgets('CardDrawAnimationOverlay runs discard unlock meld beat', (
      tester,
    ) async {
      final deckKey = GlobalKey();
      final discardKey = GlobalKey();
      final handStackKey = GlobalKey();
      final meldAreaKey = GlobalKey();
      final scrollController = ScrollController();
      var completed = false;
      var skipped = false;

      await pumpOverlayHarness(
        tester,
        request: const CardAnimationRequest(
          type: CardDrawAnimationType.discardUnlock,
          handCards: [
            PlayingCard(suit: Suit.clubs, rank: CardRank.five),
            PlayingCard(suit: Suit.diamonds, rank: CardRank.six),
          ],
          handTargetIndices: [2, 3],
          meldedCards: [
            PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
            PlayingCard(suit: Suit.spades, rank: CardRank.nine),
            PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
          ],
          meldIndex: 0,
        ),
        deckKey: deckKey,
        discardKey: discardKey,
        handStackKey: handStackKey,
        meldAreaKey: meldAreaKey,
        scrollController: scrollController,
        onComplete: () {
          completed = true;
        },
        onSkip: () {
          skipped = true;
        },
      );

      await tester.pump(GameConfig.cardMeldFlyDuration ~/ 2);
      expect(find.byType(PlayingCardWidget), findsNWidgets(3));

      await tester.tapAt(const Offset(400, 300));
      await tester.pump();

      expect(skipped, isTrue);
      expect(completed, isTrue);
      scrollController.dispose();
    });
  });
}
