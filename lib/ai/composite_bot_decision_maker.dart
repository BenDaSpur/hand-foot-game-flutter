import '../game/game_controller.dart';
import '../models/player.dart';
import 'apple_intelligence_bot.dart';
import 'bot_decision.dart';
import 'bot_decision_maker.dart';
import 'enhanced_bot_ai.dart';
import 'rule_bot_decision_maker.dart';

/// Routes per-seat decisions to Apple Intelligence or the classic rule bot.
class CompositeBotDecisionMaker extends BotDecisionMaker {
  CompositeBotDecisionMaker({
    required EnhancedBotAI ruleBot,
    AppleIntelligenceBot? appleBot,
    Set<String>? applePlayerIds,
  }) : _rule = RuleBotDecisionMaker(ruleBot),
       _apple = appleBot ?? AppleIntelligenceBot(ruleBot: ruleBot),
       _applePlayerIds = {...?applePlayerIds};

  final RuleBotDecisionMaker _rule;
  final AppleIntelligenceBot _apple;
  final Set<String> _applePlayerIds;

  /// Replace which seats use the Apple path (typically the first bot).
  void setApplePlayerIds(Iterable<String> ids) {
    _applePlayerIds
      ..clear()
      ..addAll(ids);
  }

  bool usesAppleIntelligence(String playerId) =>
      _applePlayerIds.contains(playerId);

  /// Waiting-UI intent for [playerId], or null when that seat is not Apple.
  ///
  /// Prefer this over [lastTurnIntent] when rendering a specific turn owner —
  /// the shared Apple intent can briefly linger after the seat’s turn ends.
  String? lastTurnIntentFor(String playerId) {
    if (!usesAppleIntelligence(playerId)) {
      return null;
    }
    return _apple.lastTurnIntent;
  }

  @override
  EnhancedBotAI get ruleBot => _rule.ruleBot;

  @override
  String? get lastTurnIntent {
    if (_applePlayerIds.isEmpty) {
      return null;
    }
    return _apple.lastTurnIntent;
  }

  BotDecisionMaker _makerFor(Player bot) {
    if (_applePlayerIds.contains(bot.id)) {
      return _apple;
    }
    return _rule;
  }

  @override
  Future<void> beginTurn(Player bot, GameController controller) {
    return _makerFor(bot).beginTurn(bot, controller);
  }

  @override
  Future<BotDecision> decide(Player bot, GameController controller) {
    return _makerFor(bot).decide(bot, controller);
  }

  @override
  void endTurn(Player bot) {
    _makerFor(bot).endTurn(bot);
  }

  @override
  void clearMemory() {
    _apple.clearMemory();
    _rule.clearMemory();
  }
}
