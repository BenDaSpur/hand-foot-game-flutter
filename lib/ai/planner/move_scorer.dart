import '../../config/game_config.dart';
import '../../models/card.dart';
import '../../models/player.dart';
import '../bot_config.dart';
import '../bot_game_context.dart';
import 'competitive_policy.dart';
import 'legal_actions.dart';

/// A candidate plus its competitive score (higher is better).
class ScoredCandidate {
  final LegalCandidate candidate;
  final double score;

  const ScoredCandidate({required this.candidate, required this.score});
}

/// Planner score magnitudes. Personality weights multiply these.
class _MoveScores {
  static const takePileBase = 1000.0;
  static const denialBonus = 400.0;
  static const contestableTakeBonus = 200.0;
  static const drawDeckBase = 10.0;
  static const goOutSkipPile = 800.0;
  static const playDownBase = 900.0;
  static const contestablePlayDown = 250.0;
  static const playDownPointsFactor = 0.4;
  static const createMeldBase = 80.0;
  static const footCreateBonus = 120.0;
  static const addToMeldBase = 90.0;
  static const footAddBonus = 100.0;
  static const noMeldBase = 1.0;
  static const noMeldPrePlayDown = 20.0;
  static const goOut = 2000.0;
  static const endTurn = 500.0;
  static const discardBase = 50.0;
  static const discardGoOut = 300.0;
  static const error = -10000.0;
  static const burstBase = 220.0;
  static const burstPointsFactor = 0.5;
  static const burstPerCard = 12.0;
  static const burstEmptyBonus = 400.0;
  static const cleanLaneCreate = 300.0;
  static const dirtyAfterClean = 200.0;
  static const cleanBookComplete = 500.0;
  static const dirtyBookComplete = 300.0;
  static const addToMeldFlat = 40.0;
  static const completeCleanBookAdd = 400.0;
  static const completeDirtyBookAdd = 280.0;
}

/// Scores legal actions with personality-weighted features.
class MoveScorer {
  ScoredCandidate score({
    required LegalCandidate candidate,
    required Player bot,
    required BotGameContext context,
    required ScorerWeights weights,
    required bool humanCanUnlock,
    required bool goOutThisTurn,
  }) {
    var value = 0.0;
    final pileSize = context.discardPileSize;
    final handSize = bot.currentHand.length;
    final nearFoot =
        !bot.hasPickedUpFoot &&
        handSize <= BotConfig.emergencyTransitionThreshold;

    switch (candidate.kind) {
      case LegalActionKind.drawDiscard:
        {
          value += _MoveScores.takePileBase * weights.takePile;
          if (humanCanUnlock) {
            value += _MoveScores.denialBonus * weights.denial;
          }
          if (pileSize >= CompetitivePolicy.contestablePileSize) {
            value += _MoveScores.contestableTakeBonus * weights.takePile;
          }
        }
      case LegalActionKind.drawDeck:
        {
          value += _MoveScores.drawDeckBase;
          if (goOutThisTurn) {
            value += _MoveScores.goOutSkipPile * weights.goOut;
          }
        }
      case LegalActionKind.playDown:
        {
          value += _MoveScores.playDownBase * weights.playDown;
          if (pileSize >= CompetitivePolicy.contestablePileSize) {
            value += _MoveScores.contestablePlayDown * weights.takePile;
          }
          value +=
              _meldedPoints(candidate) *
              _MoveScores.playDownPointsFactor *
              weights.points;
        }
      case LegalActionKind.createMeld:
        {
          value += _MoveScores.createMeldBase * weights.bookProgress;
          value += _createMeldScore(candidate, bot, weights);
          if (nearFoot) {
            value += _MoveScores.footCreateBonus * weights.footTransition;
          }
        }
      case LegalActionKind.maximalBurst:
        {
          value += _maximalBurstScore(candidate, bot, weights);
        }
      case LegalActionKind.addToMeld:
        {
          value += _MoveScores.addToMeldBase * weights.bookProgress;
          value += _addToMeldScore(candidate, bot, weights);
          if (nearFoot) {
            value += _MoveScores.footAddBonus * weights.footTransition;
          }
        }
      case LegalActionKind.noMeld:
        {
          value += _MoveScores.noMeldBase;
          if (!bot.hasPlayedDown) {
            value += _MoveScores.noMeldPrePlayDown;
          }
        }
      case LegalActionKind.goOut:
        {
          value += _MoveScores.goOut * weights.goOut;
        }
      case LegalActionKind.endTurn:
        {
          value += _MoveScores.endTurn;
        }
      case LegalActionKind.discard:
        {
          value += _MoveScores.discardBase;
          if (goOutThisTurn) {
            value += _MoveScores.discardGoOut * weights.goOut;
          }
        }
      case LegalActionKind.error:
        {
          value += _MoveScores.error;
        }
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

  double _maximalBurstScore(
    LegalCandidate candidate,
    Player bot,
    ScorerWeights weights,
  ) {
    final points = _meldedPoints(candidate);
    final data = candidate.decision.data;
    var cardsUsed = 0;
    if (data is List<List<PlayingCard>>) {
      cardsUsed = data.fold<int>(0, (sum, meld) => sum + meld.length);
    }
    var score = _MoveScores.burstBase * weights.footTransition;
    score += points * _MoveScores.burstPointsFactor * weights.points;
    score += cardsUsed * _MoveScores.burstPerCard;
    if (cardsUsed >= bot.currentHand.length - 1) {
      score += _MoveScores.burstEmptyBonus * weights.footTransition;
    }
    return score;
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
      score += _MoveScores.cleanLaneCreate * weights.cleanBook;
    }
    if (!isClean && !bot.hasDirtyBook && bot.hasCleanBook) {
      score += _MoveScores.dirtyAfterClean * weights.bookProgress;
    }
    if (data.length >= GameConfig.bookSize) {
      score += isClean
          ? _MoveScores.cleanBookComplete * weights.cleanBook
          : _MoveScores.dirtyBookComplete * weights.bookProgress;
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
    var score = _MoveScores.addToMeldFlat;
    if (card is PlayingCard) {
      score += card.pointValue * weights.points;
    }
    if (meldIndex != null && meldIndex >= 0 && meldIndex < bot.melds.length) {
      final meld = bot.melds[meldIndex];
      final nextSize = meld.cards.length + 1;
      if (nextSize >= GameConfig.bookSize &&
          meld.cards.length < GameConfig.bookSize) {
        // Award clean-book only when the completed book stays natural.
        // Meld.isClean requires book size, so it is always false here.
        final completesCleanBook =
            !meld.cards.any((c) => c.isWild) &&
            card is PlayingCard &&
            !card.isWild;
        score += completesCleanBook
            ? _MoveScores.completeCleanBookAdd * weights.cleanBook
            : _MoveScores.completeDirtyBookAdd * weights.bookProgress;
      }
    }
    return score;
  }
}
