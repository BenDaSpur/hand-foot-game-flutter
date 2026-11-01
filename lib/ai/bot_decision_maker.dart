import '../game/game_controller.dart';
import '../models/player.dart';
import 'bot_decision.dart';
import 'bot_personality.dart';
import 'enhanced_bot_ai.dart';

/// Async decision interface for bot turns.
///
/// [BotTurnManager] awaits [beginTurn] once per seat turn, then [decide] for
/// each action until the turn ends. Implementations must not throw into game
/// logic — fall back to a safe [BotDecision] instead.
abstract class BotDecisionMaker {
  /// Underlying rule bot used for personalities, analytics, and fallbacks.
  EnhancedBotAI get ruleBot;

  /// Last turn-start intent string (for waiting UI); null if none.
  String? get lastTurnIntent;

  /// Plan + memory refresh at the start of a bot's turn.
  Future<void> beginTurn(Player bot, GameController controller);

  /// Next action for the current phase.
  Future<BotDecision> decide(Player bot, GameController controller);

  /// Called when the bot's turn has ended (discard / go-out / force-complete).
  void endTurn(Player bot);

  /// Clears per-seat strategic memory (new game / load).
  void clearMemory();

  void assignPersonality(String playerId, BotPersonality personality) {
    ruleBot.assignPersonality(playerId, personality);
  }

  BotPersonalityManager get personalityManager => ruleBot.personalityManager;
}
