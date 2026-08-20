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
  final MoveScorer _scorer;
  final BotPersonality Function(String playerId) _personalityOf;

  Map<String, dynamic> lastAnalytics = const {};

  TurnPlanner({
    required BotMeldAnalyzer meldAnalyzer,
    required BotDiscardAnalyzer discardAnalyzer,
    required BotPersonality Function(String playerId) personalityOf,
  }) : _generator = LegalActionGenerator(
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
      meldAnalyzer: _generator.meldAnalyzer,
    );
    final canUnlock = context.canUnlockDiscard();
    final topUnlockable = liveTop != null && !gameState.discardPileFrozen;
    final humanCanUnlock = CompetitivePolicy.humanLikelyCanUnlock(
      gameState,
      bot.id,
    );
    final weights = CompetitivePolicy.weightsFor(_personalityOf(bot.id));

    final skipReason = CompetitivePolicy.drawSkipReason(
      hasPlayedDown: bot.hasPlayedDown,
      topUnlockable: topUnlockable,
      naturalTopCount: keyCount,
      goOutThisTurn: goOutThisTurn,
    );

    final forceSpendKeys =
        gameState.discardPileFrozen ||
        liveTop == null ||
        (canUnlock && goOutThisTurn);

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
      );
      return _withAnalytics(_fallback(context.turnPhase), lastAnalytics);
    }

    final constrained = _applyHardConstraints(
      bot: bot,
      context: context,
      candidates: candidates,
      canUnlock: canUnlock,
      goOutThisTurn: goOutThisTurn,
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
    );
    return _withAnalytics(chosen.decision, lastAnalytics);
  }

  List<LegalCandidate> _applyHardConstraints({
    required Player bot,
    required BotGameContext context,
    required List<LegalCandidate> candidates,
    required bool canUnlock,
    required bool goOutThisTurn,
  }) {
    if (context.turnPhase == TurnPhase.draw) {
      if (canUnlock && !goOutThisTurn) {
        final take = candidates
            .where((c) => c.kind == LegalActionKind.drawDiscard)
            .toList();
        if (take.isNotEmpty) {
          return take;
        }
      }
      return candidates
          .where((c) => c.kind == LegalActionKind.drawDeck)
          .toList();
    }

    if (context.turnPhase == TurnPhase.meld && !bot.hasPlayedDown) {
      final playDown = candidates
          .where((c) => c.kind == LegalActionKind.playDown)
          .toList();
      if (playDown.isNotEmpty) {
        return playDown;
      }
    }

    return candidates;
  }

  BotDecision _fallback(TurnPhase phase) {
    switch (phase) {
      case TurnPhase.draw:
        return BotDecision(action: 'drawFromDeck');
      case TurnPhase.meld:
        return BotDecision(action: 'noMeld');
      case TurnPhase.discard:
        return BotDecision(action: 'endTurn');
    }
  }

  Map<String, dynamic> _analytics({
    required bool couldUnlock,
    required int keyCount,
    required String? skipReason,
    required String chosen,
  }) {
    return {
      'couldUnlock': couldUnlock,
      'keyCount': keyCount,
      if (skipReason != null) 'skipReason': skipReason,
      'chosenKind': chosen,
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
