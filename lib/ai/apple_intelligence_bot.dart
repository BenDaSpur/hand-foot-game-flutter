import '../game/game_controller.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/foundation_models_service.dart';
import '../utils/debug_logger.dart';
import 'apple_situation_brief.dart';
import 'bot_decision.dart';
import 'bot_decision_maker.dart';
import 'bot_meld_analyzer.dart';
import 'bot_strategic_memory.dart';
import 'enhanced_bot_ai.dart';
import 'planner/competitive_policy.dart';
import 'rule_bot_decision_maker.dart';
import 'turn_plan.dart';

/// On-device Apple Foundation Models bot.
///
/// The model is a once-per-turn posture advisor. Every action is the coded
/// [TurnPlanner] choice, optionally leaned by that posture. Draw does not
/// wait for the model and never applies the bias, so a slow or wrong plan
/// cannot skip a forced pile take.
class AppleIntelligenceBot extends BotDecisionMaker {
  AppleIntelligenceBot({
    required EnhancedBotAI ruleBot,
    FoundationModelsService? foundationModels,
    Duration planTimeout = const Duration(seconds: 3),
  }) : _rule = RuleBotDecisionMaker(ruleBot),
       _foundationModels = foundationModels ?? FoundationModelsService.instance,
       _planTimeout = planTimeout,
       _meldAnalyzer = BotMeldAnalyzer();

  final RuleBotDecisionMaker _rule;
  final FoundationModelsService _foundationModels;
  final Duration _planTimeout;
  final BotMeldAnalyzer _meldAnalyzer;
  final BotStrategicMemoryStore _memoryStore = BotStrategicMemoryStore();

  final Map<String, Future<void>> _inflight = {};
  final Map<String, int> _planGeneration = {};
  final Map<String, bool> _planApplied = {};

  String? _lastTurnIntent;

  @override
  EnhancedBotAI get ruleBot => _rule.ruleBot;

  @override
  String? get lastTurnIntent => _lastTurnIntent;

  /// Completes when the in-flight posture request for [playerId] finishes.
  ///
  /// Draw does not wait on this. Tests and the meld/discard phases do.
  Future<void> pendingPlanFor(String playerId) {
    return _inflight[playerId] ?? Future<void>.value();
  }

  @override
  Future<void> beginTurn(Player bot, GameController controller) async {
    _lastTurnIntent = null;
    _planApplied[bot.id] = false;
    _inflight[bot.id] = _requestPlan(bot, controller);
  }

  @override
  Future<BotDecision> decide(Player bot, GameController controller) async {
    final phase = controller.gameState.turnPhase;
    _inflight.putIfAbsent(bot.id, () => _requestPlan(bot, controller));
    if (phase != TurnPhase.draw) {
      try {
        await _inflight[bot.id];
      } catch (e) {
        DebugLogger.warning('AppleIntelligenceBot plan await failed: $e');
        _planApplied[bot.id] = false;
        _lastTurnIntent = null;
      }
    }

    final bias = phase == TurnPhase.draw ? null : _biasFor(bot, controller);
    return _rule.ruleBot.makeDecision(bot, controller, bias: bias);
  }

  @override
  void endTurn(Player bot) {
    _planGeneration[bot.id] = (_planGeneration[bot.id] ?? 0) + 1;
    _inflight.remove(bot.id);
    _planApplied.remove(bot.id);
    _lastTurnIntent = null;
  }

  @override
  void clearMemory() {
    _memoryStore.clear();
    _inflight.clear();
    _planGeneration.clear();
    _planApplied.clear();
    _lastTurnIntent = null;
  }

  AppleTurnBias? _biasFor(Player bot, GameController controller) {
    if (_planApplied[bot.id] != true) {
      return null;
    }
    final memory = _memoryStore.forPlayer(bot.id);
    final posture = ApplePosture.parse(memory.posture);
    final holds = BotStrategicMemory.parseRanks(memory.holdRanks);
    if (posture == ApplePosture.holdKeys) {
      holds.addAll(CompetitivePolicy.liveKeyRanks(controller.gameState));
    }
    final feeds = BotStrategicMemory.parseRanks(memory.avoidFeedRanks);
    if (posture == null && holds.isEmpty && feeds.isEmpty) {
      return null;
    }
    return AppleTurnBias(
      posture: posture,
      holdRanks: holds,
      avoidFeedRanks: feeds,
    );
  }

  Future<void> _requestPlan(Player bot, GameController controller) async {
    final generation = (_planGeneration[bot.id] ?? 0) + 1;
    _planGeneration[bot.id] = generation;

    Map<String, dynamic>? raw;
    try {
      final prompt = _buildPrompt(bot, controller);
      raw = await _foundationModels.planTurn(prompt).timeout(_planTimeout);
    } catch (e) {
      DebugLogger.warning('AppleIntelligenceBot plan timeout/error: $e');
      raw = null;
    }

    if (_planGeneration[bot.id] != generation) {
      return;
    }

    if (raw == null) {
      _planApplied[bot.id] = false;
      _lastTurnIntent = null;
      return;
    }

    final plan = BotTurnPlan.fromJson(raw);
    final memory = _memoryStore.forPlayer(bot.id);
    memory.mergeUpdate(plan.memoryUpdate);
    // An omitted posture keeps the last valid one. stall and any other
    // unparseable value clear it so this turn does not reuse that bias.
    final parsed = plan.posture ?? ApplePosture.parse(memory.posture);
    memory.posture = parsed?.wireName ?? '';
    if (plan.intent.isNotEmpty) {
      memory.lastTurnSummary = plan.intent;
      _lastTurnIntent = plan.intent;
    } else {
      _lastTurnIntent = null;
    }
    if (plan.thinkingAhead.isNotEmpty) {
      memory.thinkingAhead
        ..clear()
        ..addAll(plan.thinkingAhead.take(3));
    }
    memory.updatedAtRound = controller.gameState.round;
    memory.updatedAtTurn = controller.gameState.currentPlayerIndex;
    _planApplied[bot.id] = true;
    DebugLogger.debug(
      'AppleIntelligenceBot ${bot.name} posture=${memory.posture.isEmpty ? 'none' : memory.posture}',
    );
  }

  Map<String, dynamic> _buildPrompt(Player bot, GameController controller) {
    final expert = _rule.ruleBot.previewPlannerAction(bot, controller);
    return AppleSituationBrief.build(
      bot: bot,
      controller: controller,
      memory: _memoryStore.forPlayer(bot.id),
      expert: expert,
      meldAnalyzer: _meldAnalyzer,
    );
  }
}
