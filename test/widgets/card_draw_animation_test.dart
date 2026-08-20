@Tags(['card_animation'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/game_config.dart';
import 'package:hand_foot_game_flutter/game/events/game_event.dart';
import 'package:hand_foot_game_flutter/game/events/game_event_bus.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';
import 'package:hand_foot_game_flutter/widgets/card_animation_host.dart';
import 'package:hand_foot_game_flutter/widgets/card_back_widget.dart';
import 'package:hand_foot_game_flutter/widgets/card_draw_animation_overlay.dart';
import 'package:hand_foot_game_flutter/widgets/game_hand_display.dart';
import 'package:hand_foot_game_flutter/widgets/game_piles_row.dart';
import 'package:hand_foot_game_flutter/widgets/playing_card_widget.dart';

import '../helpers/game_controller_test_helpers.dart';

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
      'CardDrawAnimationOverlay blocks input on first frame before fly starts',
      (tester) async {
        final deckKey = GlobalKey();
        final discardKey = GlobalKey();
        final handStackKey = GlobalKey();
        final meldAreaKey = GlobalKey();
        final scrollController = ScrollController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: Stack(
                  children: [
                    SizedBox(key: deckKey, width: 60, height: 80),
                    CardDrawAnimationOverlay(
                      request: const CardAnimationRequest(
                        type: CardDrawAnimationType.deckDraw,
                        handCards: [
                          PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
                        ],
                        handTargetIndices: [0],
                      ),
                      deckKey: deckKey,
                      discardKey: discardKey,
                      handStackKey: handStackKey,
                      meldAreaKey: meldAreaKey,
                      handScrollController: scrollController,
                      onComplete: () {},
                      onSkip: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Before the post-frame animation callback: full-screen blocker exists.
        expect(
          find.descendant(
            of: find.byType(CardDrawAnimationOverlay),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is GestureDetector &&
                  widget.behavior == HitTestBehavior.opaque,
            ),
          ),
          findsOneWidget,
        );

        await tester.pump();
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.color != null &&
                widget.color!.a > 0,
          ),
          findsOneWidget,
        );

        scrollController.dispose();
      },
    );

    testWidgets('CardDrawAnimationOverlay clears flying cards when skipped', (
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
          type: CardDrawAnimationType.deckDraw,
          handCards: [PlayingCard(suit: Suit.diamonds, rank: CardRank.seven)],
          handTargetIndices: [0],
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
          // Mirror CardAnimationHost: skip completes the gate.
          completed = true;
        },
      );

      await tester.pump();
      await tester.pump(GameConfig.cardRevealDuration ~/ 2);
      expect(find.byType(PlayingCardWidget), findsOneWidget);

      await tester.tapAt(const Offset(400, 300));
      await tester.pump();

      expect(skipped, isTrue);
      expect(completed, isTrue);
      expect(find.byType(PlayingCardWidget), findsNothing);
      scrollController.dispose();
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
            completed = true;
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
          completed = true;
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

    testWidgets(
      'spectator discard unlock shows actor name and face-up pickup cards',
      (tester) async {
        final deckKey = GlobalKey();
        final discardKey = GlobalKey();
        final handStackKey = GlobalKey();
        final meldAreaKey = GlobalKey();
        final scrollController = ScrollController();

        await pumpOverlayHarness(
          tester,
          request: const CardAnimationRequest(
            type: CardDrawAnimationType.discardUnlock,
            isSpectator: true,
            actorName: 'Clara',
            fromDiscardCount: 3,
            handCards: [
              PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
              PlayingCard(suit: Suit.spades, rank: CardRank.king),
              PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
              PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
              PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            ],
            handTargetIndices: [],
          ),
          deckKey: deckKey,
          discardKey: discardKey,
          handStackKey: handStackKey,
          meldAreaKey: meldAreaKey,
          scrollController: scrollController,
          onComplete: () {},
          onSkip: () {},
        );

        await tester.pump();
        await tester.pump(GameConfig.cardFlyDuration);

        expect(find.text('Clara took the discard'), findsOneWidget);
        expect(find.byType(PlayingCardWidget), findsNWidgets(3));
        expect(find.byType(CardBackWidget), findsNWidgets(2));

        scrollController.dispose();
      },
    );
  });

  group('CardAnimationHost interaction gates', () {
    /// Upper bound for a 2-card deck-draw overlay (scroll + reveal + fly-in).
    Duration twoCardDrawDrainWindow() {
      return GameConfig.cardRevealDuration +
          (GameConfig.cardFlyDuration * 4) +
          (GameConfig.cardStaggerDelay * 2) +
          GameConfig.cardRevealPause +
          const Duration(milliseconds: 200);
    }

    testWidgets('dispose notifies animation inactive so parent gates clear', (
      tester,
    ) async {
      final eventBus = GameEventBus();
      final deckKey = GlobalKey();
      final discardKey = GlobalKey();
      final handStackKey = GlobalKey();
      final meldAreaKey = GlobalKey();
      final scrollController = ScrollController();
      final animationStates = <bool>[];

      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final cardA = PlayingCard(suit: Suit.hearts, rank: CardRank.five);
      final cardB = PlayingCard(suit: Suit.spades, rank: CardRank.six);
      human.hand.addAll([cardA, cardB]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardAnimationHost(
              eventBus: eventBus,
              deckKey: deckKey,
              discardKey: discardKey,
              handStackKey: handStackKey,
              meldAreaKey: meldAreaKey,
              handScrollController: scrollController,
              onAnimationStateChanged: animationStates.add,
              child: Column(
                children: [
                  SizedBox(key: deckKey, width: 60, height: 80),
                  SizedBox(key: discardKey, width: 60, height: 80),
                  SizedBox(key: handStackKey, width: 300, height: 120),
                  SizedBox(key: meldAreaKey, width: 300, height: 200),
                  const Text('child'),
                ],
              ),
            ),
          ),
        ),
      );

      eventBus.publish(
        CardDrawnEvent(cards: [cardA, cardB], fromDeck: true, player: human),
      );
      await tester.pump();
      expect(animationStates, contains(true));
      expect(
        CardAnimationScope.animationActive(tester.element(find.text('child'))),
        isTrue,
      );

      // Remount without the host while animating — reproduces the production
      // desync where the screen-level flag stayed true after host disposal.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('gone'))),
      );
      await tester.pump();

      expect(animationStates.last, isFalse);

      // Drain any leftover scroll/fly-in futures from the disposed overlay
      // before tearing down controllers.
      await tester.pump(twoCardDrawDrainWindow());
      await tester.pumpAndSettle();

      scrollController.dispose();
      eventBus.dispose();
    });

    testWidgets('safety timeout unlocks UI if overlay never completes', (
      tester,
    ) async {
      final eventBus = GameEventBus();
      final deckKey = GlobalKey();
      final discardKey = GlobalKey();
      final handStackKey = GlobalKey();
      final meldAreaKey = GlobalKey();
      final scrollController = ScrollController();
      var isAnimating = false;

      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final cards = [
        PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ];
      human.hand.addAll(cards);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardAnimationHost(
              eventBus: eventBus,
              deckKey: deckKey,
              discardKey: discardKey,
              handStackKey: handStackKey,
              meldAreaKey: meldAreaKey,
              handScrollController: scrollController,
              safetyTimeout: const Duration(milliseconds: 40),
              onAnimationStateChanged: (value) => isAnimating = value,
              child: Column(
                children: [
                  SizedBox(key: deckKey, width: 60, height: 80),
                  SizedBox(key: discardKey, width: 60, height: 80),
                  SizedBox(key: handStackKey, width: 300, height: 120),
                  SizedBox(key: meldAreaKey, width: 300, height: 200),
                  const Text('board'),
                ],
              ),
            ),
          ),
        ),
      );

      eventBus.publish(
        CardDrawnEvent(cards: cards, fromDeck: true, player: human),
      );
      await tester.pump();
      expect(isAnimating, isTrue);

      // Advance only the safety timer — not enough for the full fly-in.
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump();

      expect(isAnimating, isFalse);

      // Finish scroll/stagger/pause work so teardown has no pending animation.
      await tester.pump(twoCardDrawDrainWindow());
      await tester.pumpAndSettle();

      scrollController.dispose();
      eventBus.dispose();
    });

    testWidgets('CardAnimationHost reveals discard unlocks for bots', (
      tester,
    ) async {
      final eventBus = GameEventBus();
      final deckKey = GlobalKey();
      final discardKey = GlobalKey();
      final handStackKey = GlobalKey();
      final meldAreaKey = GlobalKey();
      final scrollController = ScrollController();
      var isAnimating = false;

      final bot = Player(id: 'bot', name: 'Clara', type: PlayerType.bot);
      const pickup = [
        PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        PlayingCard(suit: Suit.spades, rank: CardRank.king),
        PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
        PlayingCard(suit: Suit.hearts, rank: CardRank.four),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardAnimationHost(
              eventBus: eventBus,
              deckKey: deckKey,
              discardKey: discardKey,
              handStackKey: handStackKey,
              meldAreaKey: meldAreaKey,
              handScrollController: scrollController,
              onAnimationStateChanged: (value) => isAnimating = value,
              child: Column(
                children: [
                  SizedBox(key: deckKey, width: 60, height: 80),
                  SizedBox(key: discardKey, width: 60, height: 80),
                  SizedBox(key: handStackKey, width: 300, height: 120),
                  SizedBox(key: meldAreaKey, width: 300, height: 200),
                  const Text('board'),
                ],
              ),
            ),
          ),
        ),
      );

      eventBus.publish(
        DiscardPileUnlockedEvent(
          handPickupCards: pickup,
          meldedCards: const [
            PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
            PlayingCard(suit: Suit.spades, rank: CardRank.nine),
            PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
          ],
          meldIndex: 0,
          fromDiscardCount: 5,
          player: bot,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(isAnimating, isTrue);
      expect(find.text('Clara took the discard'), findsOneWidget);
      expect(
        CardAnimationScope.maybeOf(
          tester.element(find.text('board')),
        )?.hiddenHandIndices,
        isEmpty,
      );

      await tester.tap(find.text('Clara took the discard'));
      await tester.pump();
      expect(isAnimating, isFalse);

      scrollController.dispose();
      eventBus.dispose();
    });

    testWidgets('CardAnimationHost still skips deck draws for bots', (
      tester,
    ) async {
      final eventBus = GameEventBus();
      final deckKey = GlobalKey();
      final discardKey = GlobalKey();
      final handStackKey = GlobalKey();
      final meldAreaKey = GlobalKey();
      final scrollController = ScrollController();
      var isAnimating = false;

      final bot = Player(id: 'bot', name: 'Clara', type: PlayerType.bot);
      const cards = [
        PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ];
      bot.hand.addAll(cards);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardAnimationHost(
              eventBus: eventBus,
              deckKey: deckKey,
              discardKey: discardKey,
              handStackKey: handStackKey,
              meldAreaKey: meldAreaKey,
              handScrollController: scrollController,
              onAnimationStateChanged: (value) => isAnimating = value,
              child: Column(
                children: [
                  SizedBox(key: deckKey, width: 60, height: 80),
                  SizedBox(key: discardKey, width: 60, height: 80),
                  SizedBox(key: handStackKey, width: 300, height: 120),
                  SizedBox(key: meldAreaKey, width: 300, height: 200),
                  const Text('board'),
                ],
              ),
            ),
          ),
        ),
      );

      eventBus.publish(
        CardDrawnEvent(cards: cards, fromDeck: true, player: bot),
      );
      await tester.pump();

      expect(isAnimating, isFalse);
      expect(find.text('Clara took the discard'), findsNothing);

      scrollController.dispose();
      eventBus.dispose();
    });

    testWidgets('hand taps work when CardAnimationScope is idle', (
      tester,
    ) async {
      final setup = createMeldPhaseTestController();
      final human = setup.human;
      human.hand
        ..clear()
        ..addAll([
          PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          PlayingCard(suit: Suit.spades, rank: CardRank.six),
        ]);
      var tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.testTheme,
          home: Scaffold(
            body: CardAnimationScope(
              isAnimating: false,
              hiddenHandIndices: const {},
              child: SizedBox(
                width: 800,
                height: 200,
                child: GameHandDisplay(
                  player: human,
                  selectedCardIndices: const [],
                  onCardTap: (_) => tapCount++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PlayingCardWidget).first);
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('draw animation hand target accounts for AppBar offset', (
      tester,
    ) async {
      final deckKey = GlobalKey();
      final discardKey = GlobalKey();
      final handStackKey = GlobalKey();
      final meldAreaKey = GlobalKey();
      final scrollController = ScrollController();
      final player = Player(id: '1', name: 'You', type: PlayerType.human)
        ..currentHand.add(
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('HAND')),
            body: SizedBox.expand(
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    left: 8,
                    child: SizedBox(key: deckKey, width: 56, height: 78),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: GameHandDisplay(
                      player: player,
                      selectedCardIndices: const [],
                      handStackKey: handStackKey,
                      handScrollController: scrollController,
                    ),
                  ),
                  CardDrawAnimationOverlay(
                    request: const CardAnimationRequest(
                      type: CardDrawAnimationType.deckDraw,
                      handCards: [
                        PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
                      ],
                      handTargetIndices: [0],
                    ),
                    deckKey: deckKey,
                    discardKey: discardKey,
                    handStackKey: handStackKey,
                    meldAreaKey: meldAreaKey,
                    handScrollController: scrollController,
                    onComplete: () {},
                    onSkip: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Drive the async animation timeline to near the end of fly-to-hand.
      await tester.pump(); // schedule post-frame start
      await tester.pump(); // start animation / possible hand scroll
      await tester.pump(GameConfig.cardRevealDuration);
      await tester.pump(GameConfig.cardFlyDuration); // pile -> reveal
      await tester.pump(GameConfig.cardRevealPause);
      await tester.pump(
        GameConfig.cardFlyDuration - const Duration(milliseconds: 40),
      );

      final overlayFinder = find.byType(CardDrawAnimationOverlay);
      final overlayBox = tester.renderObject<RenderBox>(overlayFinder);

      final handCardBox = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(GameHandDisplay),
          matching: find.byType(PlayingCardWidget),
        ),
      );
      final handCenterGlobal =
          handCardBox.localToGlobal(Offset.zero) +
          handCardBox.size.center(Offset.zero);
      final handCenterLocal = overlayBox.globalToLocal(handCenterGlobal);

      final flyingCards = find.descendant(
        of: overlayFinder,
        matching: find.byType(PlayingCardWidget),
      );
      expect(flyingCards, findsWidgets);

      final flyingBox = tester.renderObject<RenderBox>(flyingCards.last);
      final flyingCenterGlobal =
          flyingBox.localToGlobal(Offset.zero) +
          flyingBox.size.center(Offset.zero);
      final flyingCenterLocal = overlayBox.globalToLocal(flyingCenterGlobal);

      // Before the fix, AppBar offset left this ~56–100px too low.
      expect(flyingCenterLocal.dy, closeTo(handCenterLocal.dy, 20));

      scrollController.dispose();
    });
  });
}
