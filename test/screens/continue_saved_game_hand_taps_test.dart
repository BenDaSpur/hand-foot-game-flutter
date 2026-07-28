import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/events/game_event.dart';
import 'package:hand_foot_game_flutter/game/events/game_event_bus.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/providers/game_providers.dart';
import 'package:hand_foot_game_flutter/screens/game_screen.dart';
import 'package:hand_foot_game_flutter/widgets/game_hand_display.dart';
import 'package:hand_foot_game_flutter/widgets/playing_card_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Continuing a saved game hands [GameScreen] a controller that is often
/// parked on a bot's turn. The turn-ownership gate behind hand taps has to
/// follow play back to the human — when it stalled on the bot that owned the
/// turn at restore time, every tap was silently dropped for the rest of the
/// session while Play Cards and Discard stayed enabled.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('hand taps work after a continued game returns to the human', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 664);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final eventBus = GameEventBus();
    addTearDown(eventBus.dispose);

    final controller = GameController(
      players: [
        Player(id: '1', name: 'You', type: PlayerType.human),
        Player(id: '2', name: 'Sue', type: PlayerType.bot),
        Player(id: '3', name: 'Clara', type: PlayerType.bot),
      ],
      seed: 751533,
      eventBus: eventBus,
    );
    controller.initializeGame(dealCards: true);
    controller.gameState.turnPhase = TurnPhase.meld;
    // Resume parked on the last bot, like an autosave written right after the
    // human discarded.
    controller.gameState.currentPlayerIndex = 2;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameEventBusProvider.overrideWithValue(eventBus)],
        child: MaterialApp(home: GameScreen(gameController: controller)),
      ),
    );
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Play comes back around to the human.
    controller.gameState.currentPlayerIndex = 0;
    controller.gameState.turnPhase = TurnPhase.meld;
    eventBus.publish(
      TurnEndedEvent(
        turnNumber: 1,
        nextPlayer: controller.gameState.currentPlayer,
        player: controller.gameState.players[2],
      ),
    );
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final cards = find.descendant(
      of: find.byType(GameHandDisplay),
      matching: find.byType(PlayingCardWidget),
    );
    expect(cards, findsWidgets);

    var selected = 0;
    for (int index = 0; index < cards.evaluate().length && index < 6; index++) {
      await tester.tap(cards.at(index), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      selected = tester
          .widgetList<PlayingCardWidget>(cards)
          .where((card) => card.isSelected)
          .length;
      if (selected > 0) break;
    }

    expect(
      selected,
      greaterThan(0),
      reason: 'hand taps must select a card once the human owns the turn again',
    );
  });
}
