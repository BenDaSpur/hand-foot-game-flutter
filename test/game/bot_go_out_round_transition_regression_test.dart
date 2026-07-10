import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Bot go out round transition regression', () {
    test('endRoundForPlayer advances to roundEnd and increments round', () {
      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final rita = Player(id: '2', name: 'Rita', type: PlayerType.bot);
      final controller = GameController(players: [human, rita]);
      controller.initializeGame();

      _setupPlayerToGoOut(rita);
      controller.gameState.currentPlayerIndex = 1;

      controller.endRoundForPlayer(rita);

      expect(controller.gameState.phase, GamePhase.roundEnd);
      expect(controller.gameState.round, 2);
    });

    test('discardCard going out ends the round', () {
      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final rita = Player(id: '2', name: 'Rita', type: PlayerType.bot);
      final controller = GameController(players: [human, rita]);
      controller.initializeGame();

      _setupPlayerToGoOut(rita);
      rita.foot.add(const PlayingCard(suit: Suit.hearts, rank: CardRank.ace));
      controller.gameState.currentPlayerIndex = 1;
      controller.gameState.turnPhase = TurnPhase.discard;

      final success = controller.discardCard(rita.foot.first);

      expect(success, isTrue);
      expect(controller.gameState.phase, GamePhase.roundEnd);
    });

    test('nextRound clears melds and deals fresh cards after bot goes out', () {
      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final rita = Player(id: '2', name: 'Rita', type: PlayerType.bot);
      final alex = Player(id: '3', name: 'Alex', type: PlayerType.bot);
      final controller = GameController(players: [human, rita, alex]);
      controller.initializeGame();

      _setupPlayerToGoOut(rita);
      human.hasPlayedDown = true;
      human.hasPickedUpFoot = true;
      for (int i = 0; i < 11; i++) {
        human.foot.add(
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        );
      }

      controller.gameState.currentPlayerIndex = 1;
      controller.endRoundForPlayer(rita);

      expect(controller.gameState.phase, GamePhase.roundEnd);
      expect(controller.gameState.round, 2);
      expect(rita.melds, isNotEmpty);

      controller.nextRound();

      expect(controller.gameState.phase, GamePhase.playing);
      expect(controller.gameState.round, 2);
      expect(rita.melds, isEmpty);
      expect(human.melds, isEmpty);
      expect(rita.hand.length, 11);
      expect(rita.foot.length, 11);
      expect(rita.hasPlayedDown, isFalse);
      expect(rita.hasPickedUpFoot, isFalse);
    });

    test('endRoundForPlayer is idempotent when round already ended', () {
      final rita = Player(id: '2', name: 'Rita', type: PlayerType.bot);
      final controller = GameController(
        players: [
          Player(id: '1', name: 'You', type: PlayerType.human),
          rita,
        ],
      );
      controller.initializeGame();
      _setupPlayerToGoOut(rita);

      controller.endRoundForPlayer(rita);
      expect(controller.gameState.round, 2);

      controller.endRoundForPlayer(rita);
      expect(controller.gameState.round, 2);
    });
  });
}

void _setupPlayerToGoOut(Player player) {
  player.hand.clear();
  player.foot.clear();
  player.melds.clear();

  final cleanBook = Meld.createMeld([
    const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
    const PlayingCard(suit: Suit.spades, rank: CardRank.king),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
    const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
    const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
    const PlayingCard(suit: Suit.spades, rank: CardRank.king),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
  ])!;

  final dirtyBook = Meld.createMeld([
    const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
    const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
    const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
    const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
    const PlayingCard(suit: Suit.spades, rank: CardRank.two),
    const PlayingCard(rank: CardRank.joker),
  ])!;

  player.melds.add(cleanBook);
  player.melds.add(dirtyBook);
  player.hasPlayedDown = true;
  player.hasPickedUpFoot = true;
}
