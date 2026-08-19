import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/config/solo_game_settings.dart';
import 'package:hand_foot_game_flutter/game/events/game_event.dart';
import 'package:hand_foot_game_flutter/game/events/game_event_bus.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

/// Regression for session_17871159981788178:
/// Human melded out (no discard). The bot appeared stuck on her final turn,
/// and exiting/resuming restored the pre-go-out discard save.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'multi-meld go-out starts the bot final turn and autosaves so resume keeps it',
    () async {
      final eventBus = GameEventBus();
      final turnEndedEvents = <TurnEndedEvent>[];
      final subscription = eventBus.subscribe((event) {
        if (event is TurnEndedEvent) {
          turnEndedEvents.add(event);
        }
      });
      addTearDown(subscription.cancel);

      final human = Player(id: '1', name: 'You', type: PlayerType.human);
      final rita = Player(id: '2', name: 'Rita', type: PlayerType.bot);
      final controller = GameController(
        players: [human, rita],
        seed: 771212,
        eventBus: eventBus,
        soloSettings: SoloGameSettings(
          botCount: 1,
          botPersonalities: [BotPersonality.aggressive],
          enableGoingOutBonus: true,
          enableFinalTurnAfterGoingOut: true,
        ),
      );
      controller.autosaveEnabled = false;
      controller.initializeGame();
      controller.autosaveEnabled = true;

      _setupHumanReadyToMeldOut(human);
      rita.hasPlayedDown = true;
      controller.gameState.phase = GamePhase.playing;
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;
      controller.gameState.currentPlayerIndex = 0;

      expect(human.currentHand.length, 3);
      expect(human.canGoOutWithBooks, isTrue);

      final success = controller.createMultipleMeldsFromIndices([
        [0, 1, 2],
      ], skipPlayDownCheck: true);
      expect(success, isTrue);
      expect(human.currentHand, isEmpty);
      expect(controller.gameState.phase, GamePhase.playing);
      expect(controller.gameState.finalTurnPhaseActive, isTrue);
      expect(controller.gameState.playerWhoWentOutIndex, 0);
      expect(controller.gameState.currentPlayerIndex, 1);
      expect(controller.gameState.currentPlayer.id, rita.id);

      await Future<void>.delayed(Duration.zero);
      expect(turnEndedEvents, isNotEmpty);
      expect(turnEndedEvents.last.player?.id, human.id);
      expect(turnEndedEvents.last.nextPlayer?.id, rita.id);

      var saved = false;
      for (var i = 0; i < 20 && !saved; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        saved = await GameController.hasSavedGame();
      }
      expect(saved, isTrue, reason: 'Meld-phase go-out must autosave');

      final restored = await GameController.loadSavedGame();
      expect(restored, isNotNull);
      expect(restored!.gameState.finalTurnPhaseActive, isTrue);
      expect(restored.gameState.playerWhoWentOutIndex, 0);
      expect(restored.gameState.playersAwaitingFinalTurn, {1});
      expect(restored.gameState.currentPlayerIndex, 1);
      expect(restored.gameState.players.first.currentHand, isEmpty);
      expect(restored.gameState.players.first.canGoOut, isTrue);
      expect(restored.gameState.players.first.hasCleanBook, isTrue);
      expect(restored.gameState.players.first.hasDirtyBook, isTrue);
    },
  );
}

void _setupHumanReadyToMeldOut(Player player) {
  player.hand.clear();
  player.foot.clear();
  player.melds.clear();
  player.hasPlayedDown = true;
  player.hasPickedUpFoot = true;

  player.melds.addAll([
    Meld.createMeld([
      const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
      const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
      const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
      const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
      const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
      const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
      const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
    ])!,
    Meld.createMeld([
      const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
      const PlayingCard(suit: Suit.spades, rank: CardRank.four),
      const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
      const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
      const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
      const PlayingCard(suit: Suit.spades, rank: CardRank.four),
      const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
    ])!,
  ]);

  player.foot.addAll([
    const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
    const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
  ]);
}
