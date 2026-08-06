import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/game_action_feedback.dart';
import 'package:hand_foot_game_flutter/game/go_out_guards.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  Player buildFootPlayer({required List<PlayingCard> foot, List<Meld>? melds}) {
    final player = Player(id: 'p1', name: 'Alice', type: PlayerType.human);
    player.dealFoot(foot);
    player.hasPickedUpFoot = true;
    player.hasPlayedDown = true;
    if (melds != null) {
      player.melds.addAll(melds);
    }
    return player;
  }

  Meld cleanBookOfKings() {
    return Meld.createMeld([
      const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
      const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
      const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
      const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
    ])!;
  }

  Meld dirtyBookOfQueens() {
    return Meld.createMeld([
      const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
      const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
      const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
      const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
      const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
      const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
      const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
    ])!;
  }

  group('GoOutGuards.wouldCreateMeldLeaveUnfinishable', () {
    test('refuses a meld that empties the foot without books', () {
      final player = buildFootPlayer(
        foot: const [
          PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        ],
      );

      expect(
        GoOutGuards.wouldCreateMeldLeaveUnfinishable(player, player.foot),
        isTrue,
      );
    });

    test('refuses a meld that leaves one card without books', () {
      final player = buildFootPlayer(
        foot: const [
          PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          PlayingCard(suit: Suit.clubs, rank: CardRank.four),
        ],
      );

      expect(
        GoOutGuards.wouldCreateMeldLeaveUnfinishable(player, [
          player.foot[0],
          player.foot[1],
          player.foot[2],
        ]),
        isTrue,
      );
    });

    test('allows a meld that completes both books and empties the hand', () {
      final player = buildFootPlayer(
        foot: const [
          PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        ],
        melds: [dirtyBookOfQueens()],
      );

      expect(
        GoOutGuards.wouldCreateMeldLeaveUnfinishable(player, player.foot),
        isFalse,
      );
    });

    test('allows an ordinary meld leaving two or more cards', () {
      final player = buildFootPlayer(
        foot: const [
          PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        ],
      );

      expect(
        GoOutGuards.wouldCreateMeldLeaveUnfinishable(player, [
          player.foot[0],
          player.foot[1],
          player.foot[2],
        ]),
        isFalse,
      );
    });
  });

  group('GoOutGuards.wouldMultiMeldLeaveUnfinishable', () {
    test('refuses a batch that would leave one card without books', () {
      final player = buildFootPlayer(
        foot: const [
          PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          PlayingCard(suit: Suit.spades, rank: CardRank.king),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          PlayingCard(suit: Suit.clubs, rank: CardRank.four),
        ],
      );

      expect(
        GoOutGuards.wouldMultiMeldLeaveUnfinishable(player, [
          [player.foot[0], player.foot[1], player.foot[2]],
          [player.foot[3], player.foot[4], player.foot[5]],
        ]),
        isTrue,
      );
    });
  });

  group('GoOutGuards.isHumanStuckWithoutGoOut', () {
    GameState buildState(Player human) {
      final players = [
        human,
        Player(id: 'p2', name: 'Bob', type: PlayerType.bot),
      ];
      return GameState(
        players: players,
        deck: Deck.createHandAndFootDeck(players.length, seed: 1),
        phase: GamePhase.playing,
      )..turnPhase = TurnPhase.meld;
    }

    test('detects empty foot without books', () {
      final human = buildFootPlayer(foot: const []);
      final state = buildState(human);

      expect(
        GoOutGuards.isHumanStuckWithoutGoOut(
          gameState: state,
          humanPlayer: human,
          currentPlayer: human,
        ),
        isTrue,
      );
    });

    test('detects single undiscardable card without books', () {
      final human = buildFootPlayer(
        foot: const [PlayingCard(suit: Suit.hearts, rank: CardRank.four)],
      );
      final state = buildState(human);

      expect(
        GoOutGuards.isHumanStuckWithoutGoOut(
          gameState: state,
          humanPlayer: human,
          currentPlayer: human,
        ),
        isTrue,
      );
    });

    test('is false when the player has both books', () {
      final human = buildFootPlayer(
        foot: const [],
        melds: [cleanBookOfKings(), dirtyBookOfQueens()],
      );
      final state = buildState(human);

      expect(
        GoOutGuards.isHumanStuckWithoutGoOut(
          gameState: state,
          humanPlayer: human,
          currentPlayer: human,
        ),
        isFalse,
      );
    });
  });

  group('GameState playMeld unfinishable guard', () {
    test('refuses emptying the foot without books', () {
      final human = buildFootPlayer(
        foot: const [
          PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        ],
      );
      final players = [
        human,
        Player(id: 'p2', name: 'Bob', type: PlayerType.bot),
      ];
      final state = GameState(
        players: players,
        deck: Deck.createHandAndFootDeck(players.length, seed: 2),
        phase: GamePhase.playing,
      )..turnPhase = TurnPhase.meld;

      final cards = List<PlayingCard>.from(human.foot);
      expect(state.playMeld(cards), isFalse);
      expect(human.foot.length, 3);
      expect(human.melds, isEmpty);
    });
  });

  group('GameActionFeedback unfinishable meld message', () {
    test('tells the player to keep two cards', () {
      final player = buildFootPlayer(
        foot: const [
          PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        ],
      );

      final message = GameActionFeedback.unfinishableMeldBlockerMessage(player);
      expect(message, contains('clean book'));
      expect(message, contains('dirty book'));
      expect(message, contains('two cards'));
    });
  });
}
