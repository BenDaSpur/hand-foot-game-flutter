import '../../models/game_state.dart';
import '../../models/player.dart';
import '../bot_decision.dart';
import '../bot_discard_analyzer.dart';
import '../bot_game_context.dart';
import '../bot_meld_analyzer.dart';
import '../bot_personality.dart';
import 'competitive_policy.dart';
import 'legal_actions.dart';
import 'move_scorer.dart';

/// One-turn competitive planner: generate legal actions, apply hard
/// constraints, then pick the highest-scoring remainder.
class TurnPlanner {
  final LegalActionGenerator _generator;
  final BotMeldAnalyzer _meldAnalyzer;
  final MoveScorer _scorer;
  final BotPersonality Function(String playerId) _personalityOf;

  Map<String, dynamic> lastAnalytics = const {};

  TurnPlanner({
    required BotMeldAnalyzer meldAnalyzer,
    required BotDiscardAnalyzer discardAnalyzer,
    required BotPersonality Function(String playerId) personalityOf,
  }) : _meldAnalyzer = meldAnalyzer,
       _generator = LegalActionGenerator(
         meldAnalyzer: meldAnalyzer,
         discardAnalyzer: discardAnalyzer,
       ),
       _scorer = MoveScorer(),
       _personalityOf = personalityOf;

  BotDecision plan(Player bot, BotGameContext context) {
    final gameState = context.gameState;
    final liveTop = CompetitivePolicy.liveTopRank(gameState);
    final liveKeys = CompetitivePolicy.liveKeyRanks(gameState);
    final keyCount = CompetitivePolicy.keyCount(bot, liveTop);
    final goOutThisTurn = CompetitivePolicy.canEmptyThisTurn(
      bot,
      context: context,
      meldAnalyzer: _meldAnalyzer,
    );
    final canUnlock = context.canUnlockDiscard();
    final skipThrees = CompetitivePolicy.shouldSkipUnlockForThrees(
      bot,
      gameState,
    );
    final pickupThrees = CompetitivePolicy.pickupThreeCount(gameState);
    final threeDumpTurns = CompetitivePolicy.threeDumpTurns(bot, gameState);
    final topUnlockable = liveTop != null && !gameState.discardPileFrozen;
    final humanCanUnlock = CompetitivePolicy.humanLikelyCanUnlock(
      gameState,
      bot.id,
    );
    final personality = _personalityOf(bot.id);
    final weights = CompetitivePolicy.weightsFor(personality);
    final emptyHandPile = CompetitivePolicy.shouldEmptyHandPile(
      bot,
      gameState,
      personality: personality,
    );

    final skipReason = CompetitivePolicy.drawSkipReason(
      hasPlayedDown: bot.hasPlayedDown,
      topUnlockable: topUnlockable,
      naturalTopCount: keyCount,
      goOutThisTurn: goOutThisTurn,
      toxicThrees: skipThrees,
    );

    final forceSpendKeys =
        gameState.discardPileFrozen ||
        liveTop == null ||
        (canUnlock && goOutThisTurn) ||
        emptyHandPile;

    final candidates = _generator.generate(
      bot,
      context,
      liveKeyRanks: liveKeys,
      liveTop: liveTop,
      forceSpendKeys: forceSpendKeys,
    );

    if (candidates.isEmpty) {
      lastAnalytics = _analytics(
        couldUnlock: canUnlock,
        keyCount: keyCount,
        skipReason: skipReason,
        chosen: 'fallback',
        pickupThrees: pickupThrees,
        threeDumpTurns: threeDumpTurns,
      );
      return _withAnalytics(_fallback(context.turnPhase), lastAnalytics);
    }

    final constrained = _applyHardConstraints(
      bot: bot,
      context: context,
      candidates: candidates,
      canUnlock: canUnlock,
      goOutThisTurn: goOutThisTurn,
      skipThrees: skipThrees,
      emptyHandPile: emptyHandPile,
    );

    ScoredCandidate? best;
    for (final candidate in constrained) {
      final scored = _scorer.score(
        candidate: candidate,
        bot: bot,
        context: context,
        weights: weights,
        humanCanUnlock: humanCanUnlock,
        goOutThisTurn: goOutThisTurn,
      );
      if (best == null || scored.score > best.score) {
        best = scored;
      }
    }

    final chosen = best?.candidate ?? candidates.first;
    lastAnalytics = _analytics(
      couldUnlock: canUnlock,
      keyCount: keyCount,
      skipReason: chosen.kind == LegalActionKind.drawDeck ? skipReason : null,
      chosen: chosen.kind.name,
      pickupThrees: pickupThrees,
      threeDumpTurns: threeDumpTurns,
    );
    return _withAnalytics(chosen.decision, lastAnalytics);
  }

  List<LegalCandidate> _applyHardConstraints({
    required Player bot,
    required BotGameContext context,
    required List<LegalCandidate> candidates,
    required bool canUnlock,
    required bool goOutThisTurn,
    required bool skipThrees,
    required bool emptyHandPile,
  }) {
    if (context.turnPhase == TurnPhase.draw) {
      if (canUnlock && !goOutThisTurn && !skipThrees) {
        final take = candidates
            .where((candidate) => candidate.kind == LegalActionKind.drawDiscard)
            .toList();
        if (take.isNotEmpty) {
          return take;
        }
      }
      return candidates
          .where((candidate) => candidate.kind == LegalActionKind.drawDeck)
          .toList();
    }

    if (context.turnPhase == TurnPhase.meld && !bot.hasPlayedDown) {
      final playDown = candidates
          .where((candidate) => candidate.kind == LegalActionKind.playDown)
          .toList();
      if (playDown.isNotEmpty) {
        return playDown;
      }
    }

    if (context.turnPhase == TurnPhase.meld && emptyHandPile) {
      final emptying = candidates
          .where(
            (candidate) =>
                candidate.kind == LegalActionKind.addToMeld ||
                candidate.kind == LegalActionKind.createMeld ||
                candidate.kind == LegalActionKind.maximalBurst ||
                candidate.kind == LegalActionKind.playDown,
          )
          .toList();
      if (emptying.isNotEmpty) {
        return emptying;
      }
    }

    return candidates;
  }

  BotDecision _fallback(TurnPhase phase) {
    switch (phase) {
      case TurnPhase.draw:
        {
          return BotDecision(action: 'drawFromDeck');
        }
      case TurnPhase.meld:
        {
          return BotDecision(action: 'noMeld');
        }
      case TurnPhase.discard:
        {
          return BotDecision(action: 'endTurn');
        }
    }
  }

  Map<String, dynamic> _analytics({
    required bool couldUnlock,
    required int keyCount,
    required String? skipReason,
    required String chosen,
    required int pickupThrees,
    required int threeDumpTurns,
  }) {
    return {
      'couldUnlock': couldUnlock,
      'keyCount': keyCount,
      if (skipReason != null) 'skipReason': skipReason,
      'chosenKind': chosen,
      'pickupThrees': pickupThrees,
      'threeDumpTurns': threeDumpTurns,
    };
  }

  BotDecision _withAnalytics(
    BotDecision decision,
    Map<String, dynamic> analytics,
  ) {
    return BotDecision(
      action: decision.action,
      data: decision.data,
      skipPlayDownCheck: decision.skipPlayDownCheck,
      analyticsContext: analytics,
    );
  }
}
