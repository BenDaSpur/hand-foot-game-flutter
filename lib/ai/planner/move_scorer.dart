import '../../config/game_config.dart';
import '../../models/card.dart';
import '../../models/player.dart';
import '../bot_game_context.dart';
import 'competitive_policy.dart';
import 'legal_actions.dart';

/// A candidate plus its competitive score (higher is better).
class ScoredCandidate {
  final LegalCandidate candidate;
  final double score;

  const ScoredCandidate({required this.candidate, required this.score});
}

/// Scores legal actions with personality-weighted features.
class MoveScorer {
  ScoredCandidate score({
    required LegalCandidate candidate,
    required Player bot,
    required BotGameContext context,
    required ScorerWeights weights,
    required bool humanCanUnlock,
    required CardRank? liveTop,
  }) {
    var value = 0.0;
    final kind = candidate.kind;
    final pileSize = context.discardPileSize;
    final handSize = bot.currentHand.length;

    switch (kind) {
      case 'drawDiscard':
        value += 1000 * weights.takePile;
        if (humanCanUnlock) {
          value += 400 * weights.denial;
        }
        if (pileSize >= CompetitivePolicy.contestablePileSize) {
          value += 200 * weights.takePile;
        }
      case 'drawDeck':
        value += 10;
        if (CompetitivePolicy.canEmptyThisTurn(bot)) {
          value += 800 * weights.goOut;
        }
      case 'playDown':
        value += 900 * weights.playDown;
        if (pileSize >= CompetitivePolicy.contestablePileSize) {
          value += 250 * weights.takePile;
        }
        value += _meldedPoints(candidate) * 0.4 * weights.points;
      case 'createMeld':
        value += 80 * weights.bookProgress;
        value += _createMeldScore(candidate, bot, weights);
        if (!bot.hasPickedUpFoot && handSize <= 8) {
          value += 120 * weights.footTransition;
        }
      case 'addToMeld':
        value += 90 * weights.bookProgress;
        value += _addToMeldScore(candidate, bot, weights);
        if (!bot.hasPickedUpFoot && handSize <= 8) {
          value += 100 * weights.footTransition;
        }
      case 'noMeld':
        value += 1;
        if (!bot.hasPlayedDown) {
          value += 20;
        }
      case 'goOut':
        value += 2000 * weights.goOut;
      case 'endTurn':
        value += 500;
      case 'discard':
        value += 50;
        if (CompetitivePolicy.canEmptyThisTurn(bot)) {
          value += 300 * weights.goOut;
        }
      case 'error':
        value -= 10000;
      default:
        value += 0;
    }

    return ScoredCandidate(candidate: candidate, score: value);
  }

  double _meldedPoints(LegalCandidate candidate) {
    final data = candidate.decision.data;
    if (data is List<PlayingCard>) {
      return data.fold<double>(0, (sum, card) => sum + card.pointValue);
    }
    if (data is List<List<PlayingCard>>) {
      return data.fold<double>(
        0,
        (sum, meld) =>
            sum +
            meld.fold<double>(0, (inner, card) => inner + card.pointValue),
      );
    }
    return 0;
  }

  double _createMeldScore(
    LegalCandidate candidate,
    Player bot,
    ScorerWeights weights,
  ) {
    final data = candidate.decision.data;
    if (data is! List<PlayingCard> || data.isEmpty) {
      return 0;
    }
    var score = data.fold<double>(0, (sum, card) => sum + card.pointValue);
    final isClean = !data.any((c) => c.isWild);
    if (isClean && !bot.hasCleanBook) {
      score += 300 * weights.cleanBook;
    }
    if (!isClean && !bot.hasDirtyBook && bot.hasCleanBook) {
      score += 200 * weights.bookProgress;
    }
    if (data.length >= GameConfig.bookSize) {
      score += isClean ? 500 * weights.cleanBook : 300 * weights.bookProgress;
    }
    return score;
  }

  double _addToMeldScore(
    LegalCandidate candidate,
    Player bot,
    ScorerWeights weights,
  ) {
    final data = candidate.decision.data;
    if (data is! Map<String, dynamic>) {
      return 0;
    }
    final card = data['card'];
    final meldIndex = data['meldIndex'] as int?;
    var score = 40.0;
    if (card is PlayingCard) {
      score += card.pointValue * weights.points;
    }
    if (meldIndex != null && meldIndex >= 0 && meldIndex < bot.melds.length) {
      final meld = bot.melds[meldIndex];
      final nextSize = meld.cards.length + 1;
      if (nextSize >= GameConfig.bookSize &&
          meld.cards.length < GameConfig.bookSize) {
        score += meld.isClean || (card is PlayingCard && !card.isWild)
            ? 400 * weights.cleanBook
            : 280 * weights.bookProgress;
      }
    }
    return score;
  }
}
