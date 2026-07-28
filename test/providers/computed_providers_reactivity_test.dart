import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/events/game_event.dart';
import 'package:hand_foot_game_flutter/game/events/game_event_bus.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/providers/computed_providers.dart';
import 'package:hand_foot_game_flutter/providers/game_providers.dart';

/// The controller mutates one long-lived GameState instance, so any provider
/// that derives from a value-identical GameState silently freezes: Riverpod
/// suppresses the update and every later `read` returns the first snapshot.
/// That stale read is what made hand taps stop working after continuing a
/// saved game — `_onCardTap` believed a bot still owned the turn.
void main() {
  /// Mirrors what the controller emits when play moves to the next seat. The
  /// bus is a broadcast stream, so delivery lands a microtask later.
  Future<void> publishTurnEnded(
    GameEventBus eventBus,
    GameController controller,
  ) async {
    eventBus.publish(
      TurnEndedEvent(
        turnNumber: controller.gameState.round,
        nextPlayer: controller.gameState.currentPlayer,
        player: controller.gameState.currentPlayer,
      ),
    );
    await Future<void>.delayed(Duration.zero);
  }

  GameController buildController(GameEventBus eventBus) {
    final controller = GameController(
      players: [
        Player(id: '1', name: 'You', type: PlayerType.human),
        Player(id: '2', name: 'Sue', type: PlayerType.bot),
        Player(id: '3', name: 'Clara', type: PlayerType.bot),
      ],
      seed: 751533,
      eventBus: eventBus,
    );
    controller.initializeGame(dealCards: false);
    return controller;
  }

  group('computed provider reactivity', () {
    late GameEventBus eventBus;
    late ProviderContainer container;

    setUp(() {
      eventBus = GameEventBus();
      container = ProviderContainer(
        overrides: [gameEventBusProvider.overrideWithValue(eventBus)],
      );
    });

    tearDown(() {
      container.dispose();
      eventBus.dispose();
    });

    test(
      'currentPlayerProvider follows the turn after a bot-turn read',
      () async {
        final controller = buildController(eventBus);
        container
            .read(gameControllerProvider.notifier)
            .setController(controller, eventBus);

        // Resume mid-game on a bot's turn, exactly like continuing a save that
        // was written after the human discarded.
        controller.gameState.currentPlayerIndex = 2;
        await publishTurnEnded(eventBus, controller);
        expect(container.read(currentPlayerProvider)?.name, 'Clara');
        expect(container.read(isHumanTurnProvider), isFalse);

        // Play passes back to the human.
        controller.gameState.currentPlayerIndex = 0;
        await publishTurnEnded(eventBus, controller);

        expect(container.read(currentPlayerProvider)?.name, 'You');
        expect(container.read(currentPlayerProvider)?.type, PlayerType.human);
        expect(container.read(isHumanTurnProvider), isTrue);
        expect(container.read(isBotTurnProvider), isFalse);
      },
    );

    test('gameStatusProvider reports the live round and phase', () async {
      final controller = buildController(eventBus);
      container
          .read(gameControllerProvider.notifier)
          .setController(controller, eventBus);

      expect(container.read(gameStatusProvider)['round'], 1);

      controller.gameState.round = 4;
      await publishTurnEnded(eventBus, controller);

      expect(container.read(gameStatusProvider)['round'], 4);
      expect(
        container.read(playDownRequirementProvider),
        controller.gameState.playDownRequirement,
      );
    });

    test('swapping in a restored controller re-derives every value', () async {
      final first = buildController(eventBus);
      container
          .read(gameControllerProvider.notifier)
          .setController(first, eventBus);
      first.gameState.currentPlayerIndex = 1;
      await publishTurnEnded(eventBus, first);
      expect(container.read(currentPlayerProvider)?.name, 'Sue');

      final restored = buildController(eventBus);
      restored.gameState.currentPlayerIndex = 0;
      container
          .read(gameControllerProvider.notifier)
          .setController(restored, eventBus);

      expect(container.read(currentPlayerProvider)?.name, 'You');
      expect(
        container.read(humanPlayerProvider),
        same(restored.gameState.players.first),
      );
      expect(container.read(botPlayersProvider).length, 2);
    });
  });
}
