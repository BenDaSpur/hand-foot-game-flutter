import '../game/game_controller.dart';
import '../models/player.dart';
import 'bot_decision.dart';
import 'bot_decision_maker.dart';
import 'enhanced_bot_ai.dart';

/// Thin async wrapper around synchronous [EnhancedBotAI].
class RuleBotDecisionMaker extends BotDecisionMaker {
  RuleBotDecisionMaker(this._ruleBot);

  final EnhancedBotAI _ruleBot;

  @override
  EnhancedBotAI get ruleBot => _ruleBot;

  @override
  String? get lastTurnIntent => null;

  @override
  Future<void> beginTurn(Player bot, GameController controller) async {}

  @override
  Future<BotDecision> decide(Player bot, GameController controller) async {
    return _ruleBot.makeDecision(bot, controller);
  }

  @override
  void endTurn(Player bot) {}

  @override
  void clearMemory() {}
}
