import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/constants/ui_constants.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('getPlayableCardIndices', () {
    late GameController controller;
    late Player human;

    setUp(() {
      controller = GameController(
        players: [
          Player(id: '1', name: 'You', type: PlayerType.human),
          Player(id: '2', name: 'Sue', type: PlayerType.bot),
          Player(id: '3', name: 'Clara', type: PlayerType.bot),
        ],
        seed: 791591,
      );
      controller.initializeGame(dealCards: false);
      human = controller.gameState.players.first;
      controller.gameState.turnPhase = TurnPhase.meld;
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

        expect(
          indices.contains(0),
          isTrue,
          reason: 'leftmost 5♥ must be playable',
        );
        expect(indices.contains(1), isTrue, reason: '5♠ must be playable');
        expect(indices.contains(6), isTrue, reason: '8♥ must be playable');
        expect(indices.contains(7), isTrue, reason: '8♦ must be playable');
        // All wilds usable for dirty melds (not only the first take())
        expect(indices.contains(14), isTrue);
        expect(indices.contains(15), isTrue);
        expect(indices.contains(16), isTrue);
      },
    );

    test('returns empty set outside meld phase', () {
      human.hand.addAll([
        PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        PlayingCard(suit: Suit.spades, rank: CardRank.king),
        PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ]);
      controller.gameState.turnPhase = TurnPhase.draw;

      expect(controller.getPlayableCardIndices(human), isEmpty);
    });
  });

  test('handGlowPadding is large enough for playable glow blur', () {
    // Guards the UX regression where ~12–16px soft shadows were clipped
    // by the hand scroller's tiny horizontal inset.
    const playableGlowBlur = 16.0;
    expect(UIConstants.handGlowPadding, greaterThanOrEqualTo(playableGlowBlur));
  });
}
