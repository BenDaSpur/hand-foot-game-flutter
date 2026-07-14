import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

/// Shared solo-game setup for playable-highlight regression tests.
({GameController controller, Player human}) createMeldPhaseTestController({
  int seed = 791591,
}) {
  final controller = GameController(
    players: [
      Player(id: '1', name: 'You', type: PlayerType.human),
      Player(id: '2', name: 'Sue', type: PlayerType.bot),
      Player(id: '3', name: 'Clara', type: PlayerType.bot),
    ],
    seed: seed,
  );
  controller.initializeGame(dealCards: false);
  final human = controller.gameState.players.first;
  controller.gameState.turnPhase = TurnPhase.meld;
  return (controller: controller, human: human);
}
