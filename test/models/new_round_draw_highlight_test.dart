import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/game_config.dart';
import 'package:hand_foot_game_flutter/game/events/game_event.dart';
import 'package:hand_foot_game_flutter/game/events/game_event_bus.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('New-round deck draw highlights', () {
    test(
      'first draw of a new round highlights only the cards just drawn',
      () async {
        final eventBus = GameEventBus();
        final capturedEvents = <GameEvent>[];
        final subscription = eventBus.subscribe(capturedEvents.add);
        addTearDown(subscription.cancel);

        final human = Player(id: '1', name: 'You', type: PlayerType.human);
        final bot = Player(id: '2', name: 'Carl', type: PlayerType.bot);
        final controller = GameController(
          players: [human, bot],
          seed: 864877,
          eventBus: eventBus,
        );
        controller.initializeGame();
        await Future<void>.delayed(Duration.zero);

        expect(controller.drawFromDeck(), isTrue);
        expect(
          human.newlyDrawnCardIndices,
          hasLength(GameConfig.requiredDrawCount),
        );

        // Plant leftover highlights in the dealt-hand index range so a
        // missed clear would inflate the next draw to 4 cards.
        human.newlyDrawnCardIndices
          ..clear()
          ..addAll({0, 1});

        controller.gameState.phase = GamePhase.roundEnd;
        controller.prepareNewRoundDeal();
        controller.completeRoundStart(earnedPerfectGrabBonus: false);
        await Future<void>.delayed(Duration.zero);

        expect(human.currentHand, hasLength(11));
        expect(
          human.newlyDrawnCardIndices,
          isEmpty,
          reason:
              'New-round deal must drop previous-turn newly-drawn highlights',
        );

        capturedEvents.clear();
        final deckSizeBeforeDraw = controller.gameState.deck.size;
        expect(controller.drawFromDeck(), isTrue);
        await Future<void>.delayed(Duration.zero);

        expect(human.currentHand, hasLength(13));
        expect(
          controller.gameState.deck.size,
          deckSizeBeforeDraw - GameConfig.requiredDrawCount,
        );
        expect(
          human.newlyDrawnCardIndices,
          hasLength(GameConfig.requiredDrawCount),
        );

        final drawEvents = capturedEvents.whereType<CardDrawnEvent>().toList();
        expect(drawEvents, hasLength(1));
        expect(drawEvents.first.cards, hasLength(GameConfig.requiredDrawCount));
        expect(drawEvents.first.fromDeck, isTrue);
      },
    );

    test('nextRound also clears leftover highlights before the first draw', () {
      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final bot = Player(id: '2', name: 'Carl', type: PlayerType.bot);
      final controller = GameController(players: [human, bot], seed: 864877);
      controller.initializeGame();

      expect(controller.drawFromDeck(), isTrue);
      human.newlyDrawnCardIndices
        ..clear()
        ..addAll({0, 1});

      controller.gameState.phase = GamePhase.roundEnd;
      controller.nextRound();

      expect(human.newlyDrawnCardIndices, isEmpty);
      expect(controller.drawFromDeck(), isTrue);
      expect(human.currentHand, hasLength(13));
      expect(
        human.newlyDrawnCardIndices,
        hasLength(GameConfig.requiredDrawCount),
      );
    });

    test(
      '3-player opening draw leaves 147 cards, matching the reported screenshot',
      () {
        final players = [
          Player(id: '1', name: 'You', type: PlayerType.human),
          Player(id: '2', name: 'Carl', type: PlayerType.bot),
          Player(id: '3', name: 'Alex', type: PlayerType.bot),
        ];
        final controller = GameController(players: players, seed: 864877);
        controller.initializeGame();

        // 4 decks * 54 = 216; 3*(11+11)+1 = 67 dealt; 149 remain.
        expect(controller.gameState.deck.size, 149);
        expect(controller.drawFromDeck(), isTrue);
        expect(controller.gameState.deck.size, 147);
        expect(players.first.currentHand, hasLength(13));
        expect(
          players.first.newlyDrawnCardIndices,
          hasLength(GameConfig.requiredDrawCount),
        );
      },
    );
  });
}
