import '../models/player.dart';
import '../models/card.dart';
import '../models/game_state.dart';

/// Represents analysis data for an opponent player.
class OpponentAnalysis {
  final int handSize;
  final int footSize;
  final int meldCount;
  final List<int> meldSizes;
  final bool hasPlayedDown;
  final bool hasPickedUpFoot;
  final int score;
  final int estimatedTurnsToWin;
  final List<CardRank> likelyNeededRanks;

  OpponentAnalysis({
    required this.handSize,
    required this.footSize,
    required this.meldCount,
    required this.meldSizes,
    required this.hasPlayedDown,
    required this.hasPickedUpFoot,
    required this.score,
    required this.estimatedTurnsToWin,
    required this.likelyNeededRanks,
  });

  /// Check if opponent is close to completing a book
  bool get hasNearCompleteBook => meldSizes.any((size) => size >= 6);

  /// Check if opponent is in dangerous position (close to going out)
  bool get isDangerous => estimatedTurnsToWin <= 2;

  /// Check if opponent is in winning position
  bool get isWinning => hasPlayedDown && hasPickedUpFoot && handSize <= 3;

  /// Check if opponent has book requirements met
  bool get hasBookRequirements => hasCleanBook && hasDirtyBook;

  /// Estimate if opponent has clean book (simplified check)
  bool get hasCleanBook => meldSizes.any((size) => size >= 7);

  /// Estimate if opponent has dirty book (simplified check)
  bool get hasDirtyBook => meldSizes.any((size) => size >= 7) && meldCount >= 2;
}

/// Analyzes game state and opponent behavior for bot strategic decisions.
///
/// This class handles game state assessment, opponent analysis, turn tracking,
/// hand quality evaluation, and strategic position assessment to inform
/// bot decision-making.
class BotGameAnalyzer {
  // Analysis constants
  static const int dangerousTurnThreshold = 2;
  static const int nearBookThreshold = 6;
  static const int bookSize = 7;
  static const double highHandQualityThreshold = 0.7;
  static const double lowHandQualityThreshold = 0.4;
  static const int emergencyHandSize = 20;
  static const int endGameHandSize = 5;

  // Tracking data
  final Map<String, int> _playerTurnCounts = {};
  final Map<String, OpponentAnalysis> _opponentAnalysis = {};

  BotGameAnalyzer();

  /// Get current opponent analysis data
  Map<String, OpponentAnalysis> get opponentAnalysis => _opponentAnalysis;

  /// Update analysis for all opponents based on current game state
  void updateOpponentAnalysis(GameState gameState, Player botPlayer) {
    for (final player in gameState.players) {
      if (player.id == botPlayer.id) continue; // Skip self

      final meldSizes = player.melds.map((meld) => meld.cards.length).toList();
      final estimatedTurns = _estimateTurnsToWin(player);
      final likelyNeeds = _analyzeLikelyNeededRanks(player);

      _opponentAnalysis[player.id] = OpponentAnalysis(
        handSize: player.currentHand.length,
        footSize: player.foot.length,
        meldCount: player.melds.length,
        meldSizes: meldSizes,
        hasPlayedDown: player.hasPlayedDown,
        hasPickedUpFoot: player.hasPickedUpFoot,
        score: player.score,
        estimatedTurnsToWin: estimatedTurns,
        likelyNeededRanks: likelyNeeds,
      );
    }
  }

  /// Estimate how many turns until opponent can go out
  int _estimateTurnsToWin(Player player) {
    // If not played down, need at least 4 turns minimum
    if (!player.hasPlayedDown) {
      return 4;
    }

    // If haven't picked up foot, need at least 2 turns
    if (!player.hasPickedUpFoot) {
      return 2;
    }

    // Check book requirements (simplified)
    final hasBooks = player.melds.any((meld) => meld.cards.length >= bookSize);
    final hasMultipleMelds = player.melds.length >= 2;

    int turnsNeeded = 0;

    // Add turns for missing book requirements
    if (!hasBooks || !hasMultipleMelds) {
      turnsNeeded += 2;
    }

    // Base turns needed based on hand size
    final handSize = player.currentHand.length;
    if (handSize <= 1) {
      turnsNeeded += 1; // Can go out next turn
    } else if (handSize <= 3) {
      turnsNeeded += 2; // Close to going out
    } else {
      turnsNeeded += (handSize / 3).ceil(); // Multiple turns needed
    }

    return turnsNeeded;
  }

  /// Analyze likely needed ranks based on existing melds
  List<CardRank> _analyzeLikelyNeededRanks(Player player) {
    final neededRanks = <CardRank>[];

    // Look for melds that are close to becoming books (6+ cards)
    for (final meld in player.melds) {
      if (meld.cards.length >= nearBookThreshold) {
        // Find the natural cards to determine rank
        final naturalCard = meld.cards.firstWhere(
          (card) => !card.isWild,
          orElse: () => meld.cards.first,
        );
        neededRanks.add(naturalCard.rank);
      }
    }

    return neededRanks;
  }

  /// Assess the quality of a player's hand (0.0 to 1.0)
  double assessHandQuality(Player player) {
    if (player.currentHand.isEmpty) return 0.0;

    final hand = player.currentHand;
    double qualityScore = 0.0;
    final rankCounts = <CardRank, int>{};

    for (final card in hand) {
      rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;

      // High value cards
      if (card.isWild) {
        qualityScore += 0.15; // Wilds are very valuable
      } else if (card.rank.index >= CardRank.jack.index) {
        qualityScore += 0.08; // High ranks are good
      } else if (card.rank == CardRank.three) {
        qualityScore -= 0.05; // 3s are penalty cards
      } else {
        qualityScore += 0.02; // Basic value for other cards
      }
    }

    // Bonus for potential melds (multiple cards of same rank)
    for (final count in rankCounts.values) {
      if (count >= 3) {
        qualityScore += 0.1; // Strong meld potential
      } else if (count >= 2) {
        qualityScore += 0.05; // Some meld potential
      }
    }

    // Normalize to 0.0-1.0 range
    return (qualityScore / hand.length).clamp(0.0, 1.0);
  }

  /// Get turn count for a specific player
  int getTurnCount(String playerId) {
    return _playerTurnCounts[playerId] ?? 0;
  }

  /// Increment turn count for a player
  void incrementTurnCount(String playerId) {
    _playerTurnCounts[playerId] = (_playerTurnCounts[playerId] ?? 0) + 1;
  }

  /// Check if any opponent is in a dangerous position (close to winning)
  bool isAnyOpponentDangerous() {
    return _opponentAnalysis.values.any((analysis) => analysis.isDangerous);
  }

  /// Find the most dangerous opponent (closest to winning)
  OpponentAnalysis? getMostDangerousOpponent() {
    if (_opponentAnalysis.isEmpty) return null;

    final sortedOpponents = _opponentAnalysis.values.toList()
      ..sort((a, b) => a.estimatedTurnsToWin.compareTo(b.estimatedTurnsToWin));

    return sortedOpponents.first;
  }

  /// Assess current competitive pressure level (0.0 to 1.0)
  double assessCompetitivePressure(Player botPlayer) {
    if (_opponentAnalysis.isEmpty) return 0.0;

    double pressure = 0.0;
    int opponentCount = 0;

    for (final analysis in _opponentAnalysis.values) {
      opponentCount++;

      // Pressure from opponents close to winning
      if (analysis.isDangerous) {
        pressure += 0.4;
      } else if (analysis.estimatedTurnsToWin <= 4) {
        pressure += 0.2;
      }

      // Pressure from opponents ahead in development
      if (analysis.hasPickedUpFoot && !botPlayer.hasPickedUpFoot) {
        pressure += 0.15;
      }

      if (analysis.hasPlayedDown && !botPlayer.hasPlayedDown) {
        pressure += 0.1;
      }

      // Pressure from opponents with book advantages
      if (analysis.hasNearCompleteBook) {
        pressure += 0.1;
      }
    }

    // Average pressure across opponents
    return opponentCount > 0 ? (pressure / opponentCount).clamp(0.0, 1.0) : 0.0;
  }

  /// Assess bot's strategic position relative to opponents
  Map<String, dynamic> assessStrategicPosition(
    Player botPlayer,
    GameState gameState,
  ) {
    final position = <String, dynamic>{};

    // Development stage assessment
    if (!botPlayer.hasPlayedDown) {
      position['stage'] = 'early';
    } else if (!botPlayer.hasPickedUpFoot) {
      position['stage'] = 'middle';
    } else {
      position['stage'] = 'late';
    }

    // Relative position assessment
    final opponentsAhead = _opponentAnalysis.values.where((analysis) {
      if (!botPlayer.hasPlayedDown && analysis.hasPlayedDown) return true;
      if (!botPlayer.hasPickedUpFoot && analysis.hasPickedUpFoot) return true;
      return false;
    }).length;

    position['opponentsAhead'] = opponentsAhead;
    position['isLeading'] = opponentsAhead == 0;
    position['isBehind'] = opponentsAhead >= _opponentAnalysis.length / 2;

    // Urgency assessment
    final competitivePressure = assessCompetitivePressure(botPlayer);
    position['competitivePressure'] = competitivePressure;
    position['isUrgent'] = competitivePressure > 0.6;

    // Hand assessment
    final handQuality = assessHandQuality(botPlayer);
    position['handQuality'] = handQuality;
    position['hasGoodHand'] = handQuality > highHandQualityThreshold;
    position['hasPoorHand'] = handQuality < lowHandQualityThreshold;

    return position;
  }

  /// Calculate risk tolerance based on game state and position
  double calculateRiskTolerance(GameState gameState, Player botPlayer) {
    double riskTolerance = 1.0; // Base tolerance

    // Round-based adjustments
    final round = gameState.round;
    if (round >= 3) {
      riskTolerance *= 1.3; // More aggressive in later rounds
    }

    // Turn pressure
    final turnCount = getTurnCount(botPlayer.id);
    if (turnCount >= 6) {
      riskTolerance *= 1.5; // Must take more risks after many turns
    } else if (turnCount >= 4) {
      riskTolerance *= 1.2; // Some pressure to play down
    }

    // Competitive pressure
    final competitivePressure = assessCompetitivePressure(botPlayer);
    riskTolerance *= (1.0 + competitivePressure * 0.5);

    // Hand quality adjustment
    final handQuality = assessHandQuality(botPlayer);
    if (handQuality > highHandQualityThreshold) {
      riskTolerance *= 0.8; // Can be more patient with good hands
    } else if (handQuality < lowHandQualityThreshold) {
      riskTolerance *= 1.4; // Need to take chances with poor hands
    }

    return riskTolerance.clamp(0.5, 2.0);
  }

  /// Clear all analysis data (call when game ends)
  void clearAnalysisData() {
    _playerTurnCounts.clear();
    _opponentAnalysis.clear();
  }

  /// Get summary of current game state for logging/debugging
  Map<String, dynamic> getGameStateSummary(
    Player botPlayer,
    GameState gameState,
  ) {
    return {
      'round': gameState.round,
      'turnPhase': gameState.turnPhase.name,
      'botTurnCount': getTurnCount(botPlayer.id),
      'botStage': !botPlayer.hasPlayedDown
          ? 'pre-playdown'
          : !botPlayer.hasPickedUpFoot
          ? 'hand'
          : 'foot',
      'opponentCount': _opponentAnalysis.length,
      'dangerousOpponents': _opponentAnalysis.values
          .where((a) => a.isDangerous)
          .length,
      'competitivePressure': assessCompetitivePressure(botPlayer),
      'handQuality': assessHandQuality(botPlayer),
      'riskTolerance': calculateRiskTolerance(gameState, botPlayer),
    };
  }
}
