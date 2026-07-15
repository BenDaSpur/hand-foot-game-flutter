import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';
import 'package:hand_foot_game_flutter/widgets/card_animation_host.dart';
import 'package:hand_foot_game_flutter/widgets/game_hand_display.dart';
import 'package:hand_foot_game_flutter/widgets/playing_card_widget.dart';

import '../helpers/game_controller_test_helpers.dart';

void main() {
  testWidgets(
    'fan hand marks dirty-meld pairs including Jacks as playable without Opacity(1)',
    (tester) async {
      final setup = createMeldPhaseTestController();
      final controller = setup.controller;
      final human = setup.human;

      human.hand
        ..clear()
        ..addAll([
          PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          PlayingCard(suit: Suit.spades, rank: CardRank.five),
          PlayingCard(suit: Suit.hearts, rank: CardRank.six),
          PlayingCard(suit: Suit.spades, rank: CardRank.six),
          PlayingCard(suit: Suit.clubs, rank: CardRank.six),
          PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.eight),
          PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
          PlayingCard(suit: Suit.clubs, rank: CardRank.two),
          PlayingCard(suit: Suit.spades, rank: CardRank.two),
        ]);

      final playable = controller.getPlayableCardIndices(human);

      await tester.pumpWidget(
        MaterialApp(
          theme: BalatroTheme.testTheme,
          home: Scaffold(
            body: CardAnimationScope(
              isAnimating: true,
              // Hide one hand card so GameHandDisplay wraps it in Opacity(0),
              // proving we never use Opacity(1) for visible cards.
              hiddenHandIndices: const {0},
              child: SizedBox(
                width: 800,
                height: 200,
                child: GameHandDisplay(
                  player: human,
                  selectedCardIndices: const [],
                  playableCardIndices: playable,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cards = tester
          .widgetList<PlayingCardWidget>(find.byType(PlayingCardWidget))
          .toList();
      expect(cards, hasLength(human.hand.length));

      PlayingCardWidget cardAt(int i) => cards[i];

      expect(cardAt(0).isPlayable, isTrue, reason: '5♥ dirty meld');
      expect(cardAt(5).isPlayable, isTrue, reason: '8♥ dirty meld');
      expect(cardAt(7).isPlayable, isTrue, reason: 'J♥ mid-hand dirty meld');
      expect(cardAt(8).isPlayable, isTrue, reason: 'J♦ dirty meld');
      expect(cardAt(2).isPlayable, isTrue, reason: 'clean 6s');

      // Mid-hand playable cards must keep an in-face stripe — outer glow is
      // buried under the fan (session: first 8 looked unhighlighted).
      expect(
        find.byKey(PlayingCardWidget.playableFaceStripeKey).evaluate().length,
        playable.length,
      );

      final opacityFinder = find.descendant(
        of: find.byType(GameHandDisplay),
        matching: find.byType(Opacity),
      );
      expect(opacityFinder, findsOneWidget);
      expect(
        tester.widget<Opacity>(opacityFinder).opacity,
        0.0,
        reason: 'hidden animating card uses Opacity(0), never Opacity(1)',
      );
    },
    tags: ['widget'],
  );

  testWidgets('hand card taps are ignored while draw animation is active', (
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
            isAnimating: true,
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

    expect(tapCount, 0);
  });
}
