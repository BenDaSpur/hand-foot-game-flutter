import '../game/game_controller.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/foundation_models_service.dart';
import '../utils/debug_logger.dart';
import 'bot_decision.dart';
import 'bot_decision_maker.dart';
import 'bot_discard_analyzer.dart';
import 'bot_game_context.dart';
import 'bot_meld_analyzer.dart';
import 'bot_strategic_memory.dart';
import 'enhanced_bot_ai.dart';
import 'planner/competitive_policy.dart';
import 'planner/legal_actions.dart';
import 'rule_bot_decision_maker.dart';
import 'turn_plan.dart';

/// On-device Apple Foundation Models bot with turn-start planning + memory.
///
/// Always constrained to [LegalActionGenerator] candidates. Falls back to
/// [RuleBotDecisionMaker] when the model is unavailable, times out, or picks
/// a stale/illegal step.
class AppleIntelligenceBot extends BotDecisionMaker {
  AppleIntelligenceBot({
    required EnhancedBotAI ruleBot,
    FoundationModelsService? foundationModels,
    Duration planTimeout = const Duration(seconds: 3),
  }) : _rule = RuleBotDecisionMaker(ruleBot),
       _foundationModels = foundationModels ?? FoundationModelsService.instance,
       _planTimeout = planTimeout,
       _meldAnalyzer = BotMeldAnalyzer(),
       _discardAnalyzer = BotDiscardAnalyzer() {
    _generator = LegalActionGenerator(
      meldAnalyzer: _meldAnalyzer,
      discardAnalyzer: _discardAnalyzer,
    );
  }

  final RuleBotDecisionMaker _rule;
  final FoundationModelsService _foundationModels;
  final Duration _planTimeout;
  final BotMeldAnalyzer _meldAnalyzer;
  final BotDiscardAnalyzer _discardAnalyzer;
  late final LegalActionGenerator _generator;
  final BotStrategicMemoryStore _memoryStore = BotStrategicMemoryStore();

  final Map<String, ActiveTurnPlan> _activePlans = {};
  String? _lastTurnIntent;
  TurnPhase? _lastPhase;

  @override
  EnhancedBotAI get ruleBot => _rule.ruleBot;

  @override
  String? get lastTurnIntent => _lastTurnIntent;

  @override
  Future<void> beginTurn(Player bot, GameController controller) async {
    _activePlans.remove(bot.id);
    await _planCurrentPhase(bot, controller, updateIntent: true);
    _lastPhase = controller.gameState.turnPhase;
  }

  @override
  Future<BotDecision> decide(Player bot, GameController controller) async {
    final context = BotGameContext(controller.gameState, controller);
    final phase = context.turnPhase;

    // Fresh legal candidates only exist for the live phase. Re-plan when the
    // phase advances so meld/discard steps have real candidate ids.
    if (_lastPhase != null && _lastPhase != phase) {
      final existing = _activePlans[bot.id];
      if (existing != null) {
        _skipCompletedPhase(existing, _lastPhase!);
      }
      await _planCurrentPhase(bot, controller, updateIntent: false);
      _lastPhase = phase;
    } else if (_lastPhase == null) {
      // decide() without beginTurn (tests / recovery) — plan once.
      await _planCurrentPhase(bot, controller, updateIntent: true);
      _lastPhase = phase;
    }

    final active = _activePlans[bot.id];
    if (active == null) {
      return _rule.decide(bot, controller);
    }

    final liveLabeled = _labelCandidates(bot, context);
    final liveByAction = <String, LabeledLegalCandidate>{};
    for (final c in liveLabeled) {
      liveByAction[_decisionKey(c.decision)] = c;
    }

    final phaseKinds = _kindsForPhase(phase);
    final planned = active.takeNextForPhase(phaseKinds);
    if (planned != null) {
      final match = _matchLiveCandidate(planned, liveLabeled, liveByAction);
      if (match != null) {
        return match.decision;
      }
    }

    // Prefer memory-guided discard/hold when rule fallback would otherwise run.
    if (phase == TurnPhase.discard) {
      final memoryPick = _memoryGuidedDiscard(bot, liveLabeled);
      if (memoryPick != null) {
        return memoryPick.decision;
      }
    }

    return _rule.decide(bot, controller);
  }

  /// Ask Foundation Models for a plan using the current phase's legal set.
  Future<void> _planCurrentPhase(
    Player bot,
    GameController controller, {
    required bool updateIntent,
  }) async {
    final context = BotGameContext(controller.gameState, controller);
    final labeled = _labelCandidates(bot, context);
    final memory = _memoryStore.forPlayer(bot.id);
    final prompt = _buildPrompt(
      bot: bot,
      controller: controller,
      memory: memory,
      candidates: labeled,
      phase: context.turnPhase,
    );

    Map<String, dynamic>? raw;
    try {
      raw = await _foundationModels.planTurn(prompt).timeout(_planTimeout);
    } catch (e) {
      DebugLogger.warning('AppleIntelligenceBot plan timeout/error: $e');
      raw = null;
    }

    if (raw == null) {
      if (updateIntent) {
        _lastTurnIntent = null;
      }
      // Keep any prior plan; decide() will fall back to the rule bot.
      return;
    }

    final plan = BotTurnPlan.fromJson(raw);
    if (updateIntent || (plan.intent.isNotEmpty && _lastTurnIntent == null)) {
      _lastTurnIntent = plan.intent.isEmpty ? null : plan.intent;
    }

    memory.mergeUpdate(plan.memoryUpdate);
    if (plan.thinkingAhead.isNotEmpty) {
      memory.thinkingAhead
        ..clear()
        ..addAll(plan.thinkingAhead.take(3));
    }
    memory.updatedAtRound = controller.gameState.round;
    memory.updatedAtTurn = controller.gameState.currentPlayerIndex;

    final byId = {for (final c in labeled) c.id: c};
    _activePlans[bot.id] = ActiveTurnPlan(plan: plan, candidatesById: byId);
  }

  @override
  void endTurn(Player bot) {
    final active = _activePlans.remove(bot.id);
    if (active == null) {
      return;
    }
    final memory = _memoryStore.forPlayer(bot.id);
    memory.mergeUpdate(active.plan.memoryUpdate);
    if (active.plan.intent.isNotEmpty) {
      memory.lastTurnSummary = active.plan.intent;
    }
    _lastTurnIntent = null;
    _lastPhase = null;
  }

  @override
  void clearMemory() {
    _memoryStore.clear();
    _activePlans.clear();
    _lastTurnIntent = null;
    _lastPhase = null;
  }

  void _skipCompletedPhase(ActiveTurnPlan active, TurnPhase completed) {
    final kinds = _kindsForPhase(completed);
    while (true) {
      final next = active.takeNextForPhase(kinds);
      if (next == null) {
        break;
      }
    }
  }

  Set<LegalActionKind> _kindsForPhase(TurnPhase phase) {
    switch (phase) {
      case TurnPhase.draw:
        return {LegalActionKind.drawDeck, LegalActionKind.drawDiscard};
      case TurnPhase.meld:
        return {
          LegalActionKind.playDown,
          LegalActionKind.createMeld,
          LegalActionKind.maximalBurst,
          LegalActionKind.addToMeld,
          LegalActionKind.noMeld,
          LegalActionKind.goOut,
          LegalActionKind.endTurn,
        };
      case TurnPhase.discard:
        return {LegalActionKind.discard};
    }
  }

  List<LabeledLegalCandidate> _labelCandidates(
    Player bot,
    BotGameContext context,
  ) {
    final gameState = context.gameState;
    final liveTop = CompetitivePolicy.liveTopRank(gameState);
    final liveKeys = CompetitivePolicy.liveKeyRanks(gameState);
    final personality = ruleBot.personalityManager.getPersonality(bot.id);
    final emptyHandPile = CompetitivePolicy.shouldEmptyHandPile(
      bot,
      gameState,
      personality: personality,
    );
    final canUnlock = context.canUnlockDiscard();
    final goOutThisTurn = CompetitivePolicy.canEmptyThisTurn(
      bot,
      context: context,
      meldAnalyzer: _meldAnalyzer,
    );
    final forceSpendKeys =
        gameState.discardPileFrozen ||
        liveTop == null ||
        (canUnlock && goOutThisTurn) ||
        (emptyHandPile && context.turnPhase != TurnPhase.discard) ||
        (emptyHandPile && bot.bookCount >= 1);
    final humanCanUnlock = CompetitivePolicy.humanLikelyCanUnlock(
      gameState,
      bot.id,
    );
    final skipThrees = CompetitivePolicy.shouldSkipUnlockForThrees(
      bot,
      gameState,
    );

    final raw = _generator.generate(
      bot,
      context,
      liveKeyRanks: liveKeys,
      liveTop: liveTop,
      forceSpendKeys: forceSpendKeys,
      emptyHandPile: emptyHandPile,
      allowWildFreeze:
          bot.hasPlayedDown &&
          humanCanUnlock &&
          !canUnlock &&
          !goOutThisTurn &&
          !skipThrees,
    );

    final labeled = <LabeledLegalCandidate>[];
    for (var i = 0; i < raw.length; i++) {
      final candidate = raw[i];
      labeled.add(
        LabeledLegalCandidate(
          id: 'c$i',
          label: _labelFor(candidate),
          kind: candidate.kind,
          decision: candidate.decision,
        ),
      );
    }
    return labeled;
  }

  String _labelFor(LegalCandidate candidate) {
    final decision = candidate.decision;
    switch (candidate.kind) {
      case LegalActionKind.drawDeck:
        return 'Draw from deck';
      case LegalActionKind.drawDiscard:
        return 'Take discard pile';
      case LegalActionKind.noMeld:
        return 'Stop melding / go to discard';
      case LegalActionKind.goOut:
        return 'Go out';
      case LegalActionKind.endTurn:
        return 'End turn';
      case LegalActionKind.discard:
        if (decision.data is PlayingCard) {
          return 'Discard ${(decision.data as PlayingCard).compactName}';
        }
        return 'Discard';
      case LegalActionKind.addToMeld:
        final data = decision.data;
        if (data is Map && data['card'] is PlayingCard) {
          return 'Add ${(data['card'] as PlayingCard).compactName} to meld';
        }
        return 'Add to meld';
      case LegalActionKind.createMeld:
      case LegalActionKind.playDown:
        if (decision.data is List<PlayingCard>) {
          final cards = decision.data as List<PlayingCard>;
          return 'Meld ${cards.map((c) => c.compactName).join(', ')}';
        }
        return 'Create meld';
      case LegalActionKind.maximalBurst:
        if (decision.data is List) {
          return 'Play down multiple melds';
        }
        return 'Maximal burst';
      case LegalActionKind.error:
        return 'Error recovery';
    }
  }

  LabeledLegalCandidate? _matchLiveCandidate(
    LabeledLegalCandidate planned,
    List<LabeledLegalCandidate> live,
    Map<String, LabeledLegalCandidate> liveByAction,
  ) {
    // Exact decision fingerprint.
    final exact = liveByAction[_decisionKey(planned.decision)];
    if (exact != null) {
      return exact;
    }

    // Same kind + same action string (draw/noMeld/goOut).
    for (final c in live) {
      if (c.kind == planned.kind &&
          c.decision.action == planned.decision.action) {
        if (planned.kind == LegalActionKind.drawDeck ||
            planned.kind == LegalActionKind.drawDiscard ||
            planned.kind == LegalActionKind.noMeld ||
            planned.kind == LegalActionKind.goOut ||
            planned.kind == LegalActionKind.endTurn) {
          return c;
        }
      }
    }

    // Discard: match by rank if the exact card identity changed.
    if (planned.kind == LegalActionKind.discard &&
        planned.decision.data is PlayingCard) {
      final rank = (planned.decision.data as PlayingCard).rank;
      for (final c in live) {
        if (c.kind == LegalActionKind.discard &&
            c.decision.data is PlayingCard &&
            (c.decision.data as PlayingCard).rank == rank) {
          return c;
        }
      }
    }

    return null;
  }

  LabeledLegalCandidate? _memoryGuidedDiscard(
    Player bot,
    List<LabeledLegalCandidate> live,
  ) {
    final memory = _memoryStore.forPlayer(bot.id);
    if (memory.safeDiscards.isEmpty && memory.holdRanks.isEmpty) {
      return null;
    }

    final hold = memory.holdRanks.map((r) => r.toLowerCase()).toSet();
    final prefer = memory.safeDiscards.map((r) => r.toLowerCase()).toSet();

    LabeledLegalCandidate? preferred;
    for (final c in live) {
      if (c.kind != LegalActionKind.discard ||
          c.decision.data is! PlayingCard) {
        continue;
      }
      final rank = (c.decision.data as PlayingCard).rank.name.toLowerCase();
      if (hold.contains(rank)) {
        continue;
      }
      if (prefer.contains(rank)) {
        preferred = c;
        break;
      }
    }
    return preferred;
  }

  String _decisionKey(BotDecision decision) {
    final buffer = StringBuffer(decision.action);
    final data = decision.data;
    if (data is PlayingCard) {
      buffer.write(':${data.rank.name}:${data.suit?.name ?? 'j'}');
    } else if (data is List<PlayingCard>) {
      buffer.write(
        ':${data.map((c) => '${c.rank.name}${c.suit?.name ?? 'j'}').join(',')}',
      );
    } else if (data is List) {
      buffer.write(':multi:${data.length}');
    } else if (data is Map) {
      buffer.write(':${data['meldIndex']}:${data['card']}');
    }
    return buffer.toString();
  }

  Map<String, dynamic> _buildPrompt({
    required Player bot,
    required GameController controller,
    required BotStrategicMemory memory,
    required List<LabeledLegalCandidate> candidates,
    TurnPhase? phase,
  }) {
    final state = controller.gameState;
    final hand = bot.currentHand
        .map((c) => c.compactName)
        .toList(growable: false);
    final melds = bot.melds
        .map(
          (m) => {
            'size': m.cards.length,
            'ranks': m.cards.map((c) => c.rank.name).toSet().toList(),
            'isClean': m.isClean,
            'isBook': m.isBook,
          },
        )
        .toList(growable: false);

    final opponents = state.players
        .where((p) => p.id != bot.id)
        .map(
          (p) => {
            'name': p.name,
            'isHuman': p.type == PlayerType.human,
            'handSize': p.currentHand.length,
            'hasPlayedDown': p.hasPlayedDown,
            'hasPickedUpFoot': p.hasPickedUpFoot,
            'bookCount': p.bookCount,
            'score': p.score,
          },
        )
        .toList(growable: false);

    final phaseName = (phase ?? state.turnPhase).name;
    return {
      'instructions':
          'You are playing Hand & Foot in the $phaseName phase. Choose only '
          'from the provided candidate ids for this phase. Think ahead 1-3 '
          'turns via memory fields. Update goals, holdRanks, safeDiscards, '
          'and thinkingAhead for later turns. Prefer legal book progress, '
          'foot transition, and denying opponent unlocks when relevant.',
      'game': {
        'round': state.round,
        'phase': phaseName,
        'playDownRequirement': state.playDownRequirement,
        'deckSize': state.deck.size,
        'discardSize': state.discardPile.length,
        'topDiscard': state.topDiscard?.compactName,
        'discardFrozen': state.discardPileFrozen,
      },
      'self': {
        'name': bot.name,
        'hand': hand,
        'handSize': hand.length,
        'hasPlayedDown': bot.hasPlayedDown,
        'hasPickedUpFoot': bot.hasPickedUpFoot,
        'score': bot.score,
        'melds': melds,
        'bookCount': bot.bookCount,
      },
      'opponents': opponents,
      'memory': memory.toJson(),
      'candidates': candidates.map((c) => c.toPromptJson()).toList(),
    };
  }
}
