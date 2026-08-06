import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  GameController buildController(Player human) {
    final players = [
      human,
      Player(id: 'bot', name: 'Bob', type: PlayerType.bot),
    ];
    final controller = GameController(players: players, seed: 42);
    controller.gameState.phase = GamePhase.playing;
    controller.gameState.turnPhase = TurnPhase.meld;
    controller.gameState.currentPlayerIndex = 0;
    return controller;
  }

  group('GameController meld undo', () {
    test('create meld then undo restores cards and removes meld', () {
      final human = Player(id: 'h', name: 'Alice', type: PlayerType.human);
      human.hasPlayedDown = true;
      human.hasPickedUpFoot = true;
      human.dealFoot(const [
        PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        PlayingCard(suit: Suit.clubs, rank: CardRank.four),
        PlayingCard(suit: Suit.hearts, rank: CardRank.five),
      ]);

      final controller = buildController(human);
      final cards = [human.foot[0], human.foot[1], human.foot[2]];

      expect(controller.createMeld(cards), isTrue);
      expect(human.melds, hasLength(1));
      expect(human.foot, hasLength(2));
      expect(controller.canUndoMeld, isTrue);

      expect(controller.undoLastMeld(), isTrue);
      expect(human.melds, isEmpty);
      expect(human.foot, hasLength(5));
      expect(controller.canUndoMeld, isFalse);
    });

    test('add to meld then undo restores the card', () {
      final human = Player(id: 'h', name: 'Alice', type: PlayerType.human);
      human.hasPlayedDown = true;
      human.hasPickedUpFoot = true;
      human.melds.add(
        Meld.createMeld(const [
          PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          PlayingCard(suit: Suit.spades, rank: CardRank.king),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        ])!,
      );
      human.dealFoot(const [
        PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        PlayingCard(suit: Suit.spades, rank: CardRank.five),
      ]);

      final controller = buildController(human);
      final card = human.foot.first;

      expect(controller.addCardToMeld(0, card), isTrue);
      expect(human.melds.first.cards, hasLength(4));
      expect(human.foot, hasLength(2));

      expect(controller.undoLastMeld(), isTrue);
      expect(human.melds.first.cards, hasLength(3));
      expect(human.foot, hasLength(3));
    });

    test('multiple undos apply in LIFO order', () {
      final human = Player(id: 'h', name: 'Alice', type: PlayerType.human);
      human.hasPlayedDown = true;
      human.hasPickedUpFoot = true;
      human.dealFoot(const [
        PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        PlayingCard(suit: Suit.spades, rank: CardRank.king),
        PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        PlayingCard(suit: Suit.clubs, rank: CardRank.four),
        PlayingCard(suit: Suit.hearts, rank: CardRank.five),
      ]);

      final controller = buildController(human);
      expect(
        controller.createMeld([human.foot[0], human.foot[1], human.foot[2]]),
        isTrue,
      );
      expect(
        controller.createMeld([human.foot[0], human.foot[1], human.foot[2]]),
        isTrue,
      );
      expect(human.melds, hasLength(2));

      expect(controller.undoLastMeld(), isTrue);
      expect(human.melds, hasLength(1));
      expect(controller.undoLastMeld(), isTrue);
      expect(human.melds, isEmpty);
      expect(human.foot, hasLength(8));
      expect(controller.undoLastMeld(), isFalse);
    });

    test('discard clears the undo stack', () {
      final human = Player(id: 'h', name: 'Alice', type: PlayerType.human);
      human.hasPlayedDown = true;
      human.hasPickedUpFoot = true;
      human.dealFoot(const [
        PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        PlayingCard(suit: Suit.clubs, rank: CardRank.four),
        PlayingCard(suit: Suit.hearts, rank: CardRank.five),
      ]);

      final controller = buildController(human);
      expect(
        controller.createMeld([human.foot[0], human.foot[1], human.foot[2]]),
        isTrue,
      );
      expect(controller.canUndoMeld, isTrue);

      expect(controller.discardCard(human.foot.first), isTrue);
      expect(controller.canUndoMeld, isFalse);
    });

    test(
      'multi-meld undo restores hand and clears foot pickup in one step',
      () {
        final human = Player(id: 'h', name: 'Alice', type: PlayerType.human);
        human.hasPlayedDown = false;
        human.hasPickedUpFoot = false;
        human.dealHand(const [
          PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          PlayingCard(suit: Suit.spades, rank: CardRank.king),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        ]);
        human.dealFoot(const [
          PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        ]);

        final controller = buildController(human);
        expect(
          controller.createMultipleMeldsFromIndices([
            [0, 1, 2],
            [3, 4, 5],
          ], skipPlayDownCheck: true),
          isTrue,
        );
        expect(human.melds, hasLength(2));
        expect(human.hasPlayedDown, isTrue);
        expect(human.hasPickedUpFoot, isTrue);
        expect(human.hand, isEmpty);
        expect(controller.canUndoMeld, isTrue);

        expect(controller.undoLastMeld(), isTrue);
        expect(human.melds, isEmpty);
        expect(human.hasPlayedDown, isFalse);
        expect(human.hasPickedUpFoot, isFalse);
        expect(human.hand, hasLength(6));
        expect(human.foot, hasLength(2));
        expect(controller.canUndoMeld, isFalse);
      },
    );
  });
}
