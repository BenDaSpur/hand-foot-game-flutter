import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/config/solo_game_settings.dart';
import 'package:hand_foot_game_flutter/game/events/game_event.dart';
import 'package:hand_foot_game_flutter/game/events/game_event_bus.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

final _immediateRoundEndSettings = SoloGameSettings(
  botCount: 1,
  botPersonalities: [BotPersonality.adaptive],
  enableGoingOutBonus: true,
  enableFinalTurnAfterGoingOut: false,
);

final _threePlayerImmediateRoundEndSettings = SoloGameSettings(
  botCount: 2,
  botPersonalities: [BotPersonality.adaptive, BotPersonality.conservative],
  enableGoingOutBonus: true,
  enableFinalTurnAfterGoingOut: false,
);

final _threePlayerFinalTurnSettings = SoloGameSettings(
  botCount: 2,
  botPersonalities: [BotPersonality.adaptive, BotPersonality.conservative],
  enableGoingOutBonus: true,
  enableFinalTurnAfterGoingOut: true,
);

void main() {
  group('GameController round transition regression', () {
    test(
      'endRoundForPlayer advances to roundEnd and publishes RoundEndedEvent',
      () async {
        final eventBus = GameEventBus();
        final roundEndedEvents = <RoundEndedEvent>[];
        final subscription = eventBus.subscribe((event) {
          if (event is RoundEndedEvent) {
            roundEndedEvents.add(event);
          }
        });
        addTearDown(subscription.cancel);

        final human = Player(id: '1', name: 'You', type: PlayerType.human);
        final rita = Player(id: '2', name: 'Rita', type: PlayerType.bot);
        final controller = GameController(
          players: [human, rita],
          eventBus: eventBus,
          soloSettings: _immediateRoundEndSettings,
        );
        controller.initializeGame();

        _setupPlayerToGoOut(rita);
        controller.gameState.currentPlayerIndex = 1;

        controller.endRoundForPlayer(rita);
        await Future<void>.delayed(Duration.zero);

        expect(controller.gameState.phase, GamePhase.roundEnd);
        expect(controller.gameState.round, 2);
        expect(roundEndedEvents, hasLength(1));
        expect(roundEndedEvents.single.roundNumber, 1);
        expect(roundEndedEvents.single.roundScores[rita], rita.score);
        expect(roundEndedEvents.single.roundScores[human], human.score);
      },
    );

    test(
      'discardCard going out ends the round and publishes RoundEndedEvent',
      () async {
        final eventBus = GameEventBus();
        final roundEndedEvents = <RoundEndedEvent>[];
        final subscription = eventBus.subscribe((event) {
          if (event is RoundEndedEvent) {
            roundEndedEvents.add(event);
          }
        });
        addTearDown(subscription.cancel);

        final human = Player(id: '1', name: 'You', type: PlayerType.human);
        final rita = Player(id: '2', name: 'Rita', type: PlayerType.bot);
        final controller = GameController(
          players: [human, rita],
          eventBus: eventBus,
          soloSettings: _immediateRoundEndSettings,
        );
        controller.initializeGame();

        _setupPlayerToGoOut(rita);
        rita.foot.add(const PlayingCard(suit: Suit.hearts, rank: CardRank.ace));
        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.discard;

        final success = controller.discardCard(rita.foot.first);
        await Future<void>.delayed(Duration.zero);

        expect(success, isTrue);
        expect(controller.gameState.phase, GamePhase.roundEnd);
        expect(roundEndedEvents, hasLength(1));
        expect(roundEndedEvents.single.roundNumber, 1);
        expect(roundEndedEvents.single.roundScores[rita], rita.score);
      },
    );

    test('nextRound clears melds and deals fresh cards for all players', () {
      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final rita = Player(id: '2', name: 'Rita', type: PlayerType.bot);
      final alex = Player(id: '3', name: 'Alex', type: PlayerType.bot);
      final controller = GameController(
        players: [human, rita, alex],
        soloSettings: _threePlayerImmediateRoundEndSettings,
      );
      controller.initializeGame();

      _setupPlayerToGoOut(rita);
      human.hasPlayedDown = true;
      human.hasPickedUpFoot = true;
      human.hand.clear();
      human.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
        ])!,
      );
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
      expect(human.melds, isNotEmpty);

      controller.nextRound();

      expect(controller.gameState.phase, GamePhase.playing);
      expect(controller.gameState.round, 2);
      expect(rita.melds, isEmpty);
      expect(human.melds, isEmpty);
      expect(rita.hand.length, 11);
      expect(rita.foot.length, 11);
      expect(human.hand.length, 11);
      expect(human.foot.length, 11);
      expect(rita.hasPlayedDown, isFalse);
      expect(rita.hasPickedUpFoot, isFalse);
      expect(human.hasPlayedDown, isFalse);
      expect(human.hasPickedUpFoot, isFalse);
    });

    test('endRoundForPlayer is idempotent when round already ended', () async {
      final eventBus = GameEventBus();
      final roundEndedEvents = <RoundEndedEvent>[];
      final subscription = eventBus.subscribe((event) {
        if (event is RoundEndedEvent) {
          roundEndedEvents.add(event);
        }
      });
      addTearDown(subscription.cancel);

      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final rita = Player(id: '2', name: 'Rita', type: PlayerType.bot);
      final controller = GameController(
        players: [human, rita],
        eventBus: eventBus,
        soloSettings: _immediateRoundEndSettings,
      );
      controller.initializeGame();
      _setupPlayerToGoOut(rita);
      controller.gameState.currentPlayerIndex = 1;
      controller.gameState.turnPhase = TurnPhase.discard;

      controller.endRoundForPlayer(rita);
      await Future<void>.delayed(Duration.zero);

      final snapshot = _RoundEndSnapshot.capture(controller, roundEndedEvents);

      controller.endRoundForPlayer(rita);
      await Future<void>.delayed(Duration.zero);

      snapshot.assertUnchanged(controller, roundEndedEvents);
    });

    test(
      'final-turn completion credits original go-out player in PlayerWentOutEvent',
      () async {
        final eventBus = GameEventBus();
        final wentOutEvents = <PlayerWentOutEvent>[];
        final subscription = eventBus.subscribe((event) {
          if (event is PlayerWentOutEvent) {
            wentOutEvents.add(event);
          }
        });
        addTearDown(subscription.cancel);

        final human = Player(id: '1', name: 'You', type: PlayerType.human);
        final rita = Player(id: '2', name: 'Rita', type: PlayerType.bot);
        final alex = Player(id: '3', name: 'Alex', type: PlayerType.bot);
        final controller = GameController(
          players: [human, rita, alex],
          eventBus: eventBus,
          soloSettings: _threePlayerFinalTurnSettings,
        );
        controller.initializeGame();

        _setupPlayerToGoOut(human);
        controller.gameState.currentPlayerIndex = 0;
        controller.endRoundForPlayer(human);

        expect(controller.gameState.finalTurnPhaseActive, isTrue);
        expect(controller.gameState.currentPlayer.id, rita.id);

        controller.advanceTurnAfterAction(rita);
        expect(controller.gameState.currentPlayer.id, alex.id);

        controller.advanceTurnAfterAction(alex);
        await Future<void>.delayed(Duration.zero);

        expect(controller.gameState.phase, GamePhase.roundEnd);
        expect(wentOutEvents, hasLength(1));
        expect(wentOutEvents.single.player, isNotNull);
        expect(wentOutEvents.single.player!.id, human.id);
      },
    );
  });
}

class _RoundEndSnapshot {
  final GamePhase phase;
  final int round;
  final List<int> scores;
  final int currentPlayerIndex;
  final TurnPhase turnPhase;
  final int recentActionCount;
  final int roundEndedEventCount;

  _RoundEndSnapshot({
    required this.phase,
    required this.round,
    required this.scores,
    required this.currentPlayerIndex,
    required this.turnPhase,
    required this.recentActionCount,
    required this.roundEndedEventCount,
  });

  factory _RoundEndSnapshot.capture(
    GameController controller,
    List<RoundEndedEvent> roundEndedEvents,
  ) {
    final gameState = controller.gameState;
    return _RoundEndSnapshot(
      phase: gameState.phase,
      round: gameState.round,
      scores: gameState.players.map((player) => player.score).toList(),
      currentPlayerIndex: gameState.currentPlayerIndex,
      turnPhase: gameState.turnPhase,
      recentActionCount: gameState.recentActions.length,
      roundEndedEventCount: roundEndedEvents.length,
    );
  }

  void assertUnchanged(
    GameController controller,
    List<RoundEndedEvent> roundEndedEvents,
  ) {
    final gameState = controller.gameState;
    expect(gameState.phase, phase);
    expect(gameState.round, round);
    expect(gameState.players.map((player) => player.score).toList(), scores);
    expect(gameState.currentPlayerIndex, currentPlayerIndex);
    expect(gameState.turnPhase, turnPhase);
    expect(gameState.recentActions.length, recentActionCount);
    expect(roundEndedEvents.length, roundEndedEventCount);
  }
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
