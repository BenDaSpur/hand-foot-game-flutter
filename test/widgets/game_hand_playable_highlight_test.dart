import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';
import 'package:hand_foot_game_flutter/widgets/game_hand_display.dart';
import 'package:hand_foot_game_flutter/widgets/playing_card_widget.dart';

void main() {
  testWidgets(
    'fan hand marks dirty-meld pairs including Jacks as playable without Opacity(1)',
    (tester) async {
      final controller = GameController(
        players: [
          Player(id: '1', name: 'You', type: PlayerType.human),
          Player(id: '2', name: 'Sue', type: PlayerType.bot),
          Player(id: '3', name: 'Clara', type: PlayerType.bot),
        ],
        seed: 791591,
      );
      controller.initializeGame(dealCards: false);
      final human = controller.gameState.players.first;
      controller.gameState.turnPhase = TurnPhase.meld;

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
            body: SizedBox(
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

      // Visible cards must not sit under Opacity(1) (clips outer glow).
      final opacityWidgets = tester.widgetList<Opacity>(find.byType(Opacity));
      for (final opacity in opacityWidgets) {
        expect(
          opacity.opacity,
          isNot(1.0),
          reason: 'Opacity(1) clips playable BoxShadows — use bare widget',
        );
      }
    },
  );
}
