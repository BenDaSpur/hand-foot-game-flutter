import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/constants/ui_constants.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/widgets/playing_card_widget.dart';

import '../../helpers/game_controller_test_helpers.dart';

void main() {
  group('getPlayableCardIndices', () {
    late GameController controller;
    late Player human;

    setUp(() {
      final setup = createMeldPhaseTestController();
      controller = setup.controller;
      human = setup.human;
    });

    test(
      'marks leftmost pair of fives with wilds when hand is rank-sorted',
      () {
        // Recreates the reported hand shape: low pair sits at indices 0–1
        // after sort; 8s and wilds further right. Both pairs must light up.
        human.hand
          ..clear()
          ..addAll([
            PlayingCard(suit: Suit.hearts, rank: CardRank.five),
            PlayingCard(suit: Suit.spades, rank: CardRank.five),
            PlayingCard(suit: Suit.hearts, rank: CardRank.six),
            PlayingCard(suit: Suit.spades, rank: CardRank.six),
            PlayingCard(suit: Suit.spades, rank: CardRank.six),
            PlayingCard(suit: Suit.spades, rank: CardRank.seven),
            PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
            PlayingCard(suit: Suit.diamonds, rank: CardRank.eight),
            PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
            PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
            PlayingCard(suit: Suit.diamonds, rank: CardRank.jack),
            PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
            PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
            PlayingCard(suit: Suit.clubs, rank: CardRank.king),
            PlayingCard(suit: Suit.clubs, rank: CardRank.two),
            PlayingCard(suit: Suit.spades, rank: CardRank.two),
            PlayingCard(suit: Suit.hearts, rank: CardRank.two),
          ]);

        final indices = controller.getPlayableCardIndices(human);

        // 5s/8s/Jacks/Kings (dirty with wilds), clean 6s, all wilds.
        // Not playable: lone 7, 10, and Q.
        expect(
          indices,
          equals({0, 1, 2, 3, 4, 6, 7, 9, 10, 12, 13, 14, 15, 16}),
        );
        expect(indices.contains(5), isFalse, reason: 'lone 7 not playable');
        expect(indices.contains(8), isFalse, reason: 'lone 10 not playable');
        expect(indices.contains(11), isFalse, reason: 'lone Q not playable');
      },
      tags: ['meld'],
    );

    test(
      'marks wilds playable when findPossibleMelds only returns clean 3+',
      () {
        // Three kings → clean-only candidate; wild still legal for a dirty meld.
        human.hand
          ..clear()
          ..addAll([
            PlayingCard(suit: Suit.hearts, rank: CardRank.king),
            PlayingCard(suit: Suit.spades, rank: CardRank.king),
            PlayingCard(suit: Suit.clubs, rank: CardRank.king),
            PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
            PlayingCard(suit: Suit.hearts, rank: CardRank.two),
            PlayingCard(suit: Suit.spades, rank: CardRank.two),
          ]);

        final melds = controller.findPossibleMelds(human);
        expect(melds.any((m) => m.any((c) => c.isWild)), isFalse);

        final indices = controller.getPlayableCardIndices(human);
        expect(indices, equals({0, 1, 2, 4, 5}));
        expect(indices.contains(3), isFalse, reason: 'lone ace not playable');
      },
      tags: ['meld'],
    );

    test('returns empty set outside meld phase', () {
      human.hand.addAll([
        PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        PlayingCard(suit: Suit.spades, rank: CardRank.king),
        PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ]);
      controller.gameState.turnPhase = TurnPhase.draw;

      expect(controller.getPlayableCardIndices(human), isEmpty);
    }, tags: ['meld']);
  });

  test('handGlowPadding covers default playable glow blur', () {
    const playableGlowExtent =
        PlayingCardWidget.playableOuterGlowBlur +
        PlayingCardWidget.playableOuterGlowSpread;
    expect(
      UIConstants.handGlowPadding,
      greaterThanOrEqualTo(playableGlowExtent),
    );
  });
}
