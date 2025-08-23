import 'dart:math';
import '../models/card.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../game/game_controller.dart';

class BotDecision {
  final String action;
  final dynamic data;
  final bool skipPlayDownCheck;

  BotDecision({
    required this.action,
    this.data,
    this.skipPlayDownCheck = false,
  });
}

/// Bot personality types that influence strategic decision-making
enum BotPersonality {
  conservative, // Cautious play, holds cards longer, minimal risks
  aggressive, // Quick play-downs, frequent discard pile unlocks, high risks
  bookBuilder, // Focuses on completing books for maximum points
  adaptive, // Switches strategy based on game state and opponents
}

/// Opponent analysis data for strategic decisions
class OpponentAnalysis {
  final int handSize;
  final int footSize;
  final int meldCount;
  final List<int> meldSizes;
  final bool hasPlayedDown;
  final bool hasPickedUpFoot;
  final int score;
  final int estimatedTurnsToWin;
  final List<CardRank> likelyNeededRanks; // Cards they probably need

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
}

/// Personality-based strategic modifiers
class PersonalityConstants {
  final int strategicBufferPoints;
  final int minCardsForAggressiveUnlock;
  final int valuablePileThreshold;
  final int largePileThreshold;
  final int footPileValueThreshold;
  final int footPileSizeThreshold;
  final int handPileValueThreshold;
  final int handPileSizeThreshold;
  final double highValuePairBreakChance;
  final int maxTurnsBeforeForcePlayDown;
  final int playDownRiskThreshold;
  final int bookCompletionPriority; // New for book builder personality
  final double aggressivenessMultiplier; // Overall aggression modifier

  const PersonalityConstants({
    required this.strategicBufferPoints,
    required this.minCardsForAggressiveUnlock,
    required this.valuablePileThreshold,
    required this.largePileThreshold,
    required this.footPileValueThreshold,
    required this.footPileSizeThreshold,
    required this.handPileValueThreshold,
    required this.handPileSizeThreshold,
    required this.highValuePairBreakChance,
    required this.maxTurnsBeforeForcePlayDown,
    required this.playDownRiskThreshold,
    required this.bookCompletionPriority,
    required this.aggressivenessMultiplier,
  });

  /// Get personality-based constants
  static PersonalityConstants forPersonality(BotPersonality personality) {
    switch (personality) {
      case BotPersonality.conservative:
        return const PersonalityConstants(
          strategicBufferPoints: 30, // +50% buffer
          minCardsForAggressiveUnlock: 4, // Need more cards
          valuablePileThreshold: 140, // +40% threshold
          largePileThreshold: 8, // +33% threshold
          footPileValueThreshold: 70, // +40% threshold
          footPileSizeThreshold: 4, // +33% threshold
          handPileValueThreshold: 160, // +33% threshold
          handPileSizeThreshold: 9, // +29% threshold
          highValuePairBreakChance: 0.1, // 50% less likely
          maxTurnsBeforeForcePlayDown: 7, // +40% more patient
          playDownRiskThreshold: -200, // More risk averse
          bookCompletionPriority: 50, // Moderate book focus
          aggressivenessMultiplier: 0.7, // 30% less aggressive
        );

      case BotPersonality.aggressive:
        return const PersonalityConstants(
          strategicBufferPoints: 10, // 50% less buffer
          minCardsForAggressiveUnlock: 2, // Need fewer cards
          valuablePileThreshold: 70, // 30% lower threshold
          largePileThreshold: 4, // 33% lower threshold
          footPileValueThreshold: 35, // 30% lower threshold
          footPileSizeThreshold: 2, // 33% lower threshold
          handPileValueThreshold: 85, // 29% lower threshold
          handPileSizeThreshold: 5, // 29% lower threshold
          highValuePairBreakChance: 0.35, // 75% more likely
          maxTurnsBeforeForcePlayDown: 3, // 40% less patient
          playDownRiskThreshold: -400, // More risk tolerant
          bookCompletionPriority: 30, // Lower book focus
          aggressivenessMultiplier: 1.4, // 40% more aggressive
        );

      case BotPersonality.bookBuilder:
        return const PersonalityConstants(
          strategicBufferPoints: 25, // Moderate buffer
          minCardsForAggressiveUnlock: 3, // Standard
          valuablePileThreshold: 100, // Standard
          largePileThreshold: 6, // Standard
          footPileValueThreshold: 50, // Standard
          footPileSizeThreshold: 3, // Standard
          handPileValueThreshold: 120, // Standard
          handPileSizeThreshold: 7, // Standard
          highValuePairBreakChance: 0.15, // Less likely to break pairs
          maxTurnsBeforeForcePlayDown: 6, // More patient for book building
          playDownRiskThreshold: -250, // Moderate risk
          bookCompletionPriority: 100, // High book completion focus
          aggressivenessMultiplier: 1.0, // Standard aggression
        );

      case BotPersonality.adaptive:
        return const PersonalityConstants(
          strategicBufferPoints: 20, // Standard (will be modified dynamically)
          minCardsForAggressiveUnlock: 3, // Standard
          valuablePileThreshold: 100, // Standard
          largePileThreshold: 6, // Standard
          footPileValueThreshold: 50, // Standard
          footPileSizeThreshold: 3, // Standard
          handPileValueThreshold: 120, // Standard
          handPileSizeThreshold: 7, // Standard
          highValuePairBreakChance: 0.2, // Standard
          maxTurnsBeforeForcePlayDown: 5, // Standard
          playDownRiskThreshold:
              -300, // Standard (will be modified dynamically)
          bookCompletionPriority: 60, // Moderate (will be modified)
          aggressivenessMultiplier: 1.0, // Will be modified dynamically
        );
    }
  }
}

/// Strategic constants for bot decision making
class BotStrategicConstants {
  // Risk tolerance bounds
  static const double minRiskTolerance = 0.1;
  static const double maxRiskTolerance = 3.0;
  static const double emergencyRiskMultiplier =
      2.0; // More conservative multiplier
  static const double maxEmergencyRiskTolerance =
      6.0; // Absolute maximum to prevent erratic behavior

  // Turn timing constants
  static const int minAdjustedTurns = 2;
  static const int maxAdjustedTurns = 8;

  // Hand quality assessment
  static const double minHandQuality = 0.0;
  static const double maxHandQuality = 1.0;

  // Opponent analysis
  static const int minEstimatedTurns = 1;
  static const int maxEstimatedTurns = 6;
  static const int handSizeInflationThreshold = 10;
  static const int handSizeInflationPenalty = 2;

  // Emergency thresholds
  static const int emergencyHandSize = 20;
  static const int endGameHandSize = 5;
}

class BotAI {
  final Random _random;

  // Per-player personality assignments
  final Map<String, BotPersonality> _playerPersonalities = {};
  final Map<String, PersonalityConstants> _playerConstants = {};

  // Multi-meld play-down state tracking
  List<List<PlayingCard>>? _plannedMelds;
  int _currentMeldIndex = 0;
  bool _inMultiMeldSequence = false;

  // Turn tracking for strategic play-down timing
  final Map<String, int> _playerTurnCounts = {};

  // Performance optimization - cache possible melds during decision cycle
  List<List<PlayingCard>>? _cachedPossibleMelds;
  String? _cachedPlayerId;

  // Opponent analysis for enhanced decision making
  final Map<String, OpponentAnalysis> _opponentAnalysis = {};

  // Initialize with optional seed for test reproducibility
  BotAI({int? seed}) : _random = seed != null ? Random(seed) : Random();

  /// Clear all cached data and analysis - call this when games end or players disconnect
  void clearGameData() {
    _playerPersonalities.clear();
    _playerConstants.clear();
    _playerTurnCounts.clear();
    _opponentAnalysis.clear();
    _cachedPossibleMelds = null;
    _cachedPlayerId = null;
    _plannedMelds = null;
    _currentMeldIndex = 0;
    _inMultiMeldSequence = false;
  }

  /// Clear data for a specific player - call when player disconnects
  void clearPlayerData(String playerId) {
    _playerPersonalities.remove(playerId);
    _playerConstants.remove(playerId);
    _playerTurnCounts.remove(playerId);
    _opponentAnalysis.remove(playerId);

    // Clear cache if it was for this player
    if (_cachedPlayerId == playerId) {
      _cachedPossibleMelds = null;
      _cachedPlayerId = null;
    }
  }

  /// Assign a personality to a specific bot player
  void assignPersonality(String playerId, BotPersonality personality) {
    _playerPersonalities[playerId] = personality;
    _playerConstants[playerId] = PersonalityConstants.forPersonality(
      personality,
    );
  }

  /// Get constants for a specific player (falls back to adaptive if not assigned)
  PersonalityConstants _getConstants(String playerId) {
    return _playerConstants[playerId] ??
        PersonalityConstants.forPersonality(BotPersonality.adaptive);
  }

  /// Get personality for a specific player
  BotPersonality _getPersonality(String playerId) {
    return _playerPersonalities[playerId] ?? BotPersonality.adaptive;
  }

  /// Current player constants cache for method scope usage
  PersonalityConstants? _currentConstants;

  /// Set current player context for this decision cycle
  void _setCurrentPlayerContext(String playerId) {
    _currentConstants = _getConstants(playerId);
  }

  /// Get current constants (for use within decision methods)
  PersonalityConstants get _constants =>
      _currentConstants ??
      PersonalityConstants.forPersonality(BotPersonality.adaptive);

  // Public getters for debugging (test use only)
  List<List<PlayingCard>>? get plannedMelds => _plannedMelds;
  int get currentMeldIndex => _currentMeldIndex;
  bool get inMultiMeldSequence => _inMultiMeldSequence;
  Map<String, OpponentAnalysis> get opponentAnalysis => _opponentAnalysis;

  // Public test methods
  void setCurrentPlayerContextForTest(String playerId) =>
      _setCurrentPlayerContext(playerId);
  PersonalityConstants get constantsForTest => _constants;

  // Personality-based strategic constants (now use _constants directly)
  int get strategicBufferPoints => _constants.strategicBufferPoints;
  int get minCardsForAggressiveUnlock => _constants.minCardsForAggressiveUnlock;
  int get valuablePileThreshold => _constants.valuablePileThreshold;
  int get largePileThreshold => _constants.largePileThreshold;
  int get footPileValueThreshold => _constants.footPileValueThreshold;
  int get footPileSizeThreshold => _constants.footPileSizeThreshold;
  int get handPileValueThreshold => _constants.handPileValueThreshold;
  int get handPileSizeThreshold => _constants.handPileSizeThreshold;
  static const int lowHandCardThreshold = 3;
  static const int meldRetentionThreshold = 5;
  static const int postPlaydownMeldValue = 50;
  static const int postPlaydownHandSize = 8;
  double get highValuePairBreakChance => _constants.highValuePairBreakChance;

  // New strategic constants
  int get maxTurnsBeforeForcePlayDown => _constants.maxTurnsBeforeForcePlayDown;
  static const int minimalPlayDownBuffer =
      5; // Just meet requirement + small buffer

  /// Helper method to safely divide by risk tolerance, preventing division by zero
  double _safeRiskDivision(double numerator, double riskTolerance) {
    // Ensure risk tolerance is never zero or negative
    final safeDivisor = riskTolerance <= 0.0
        ? BotStrategicConstants.minRiskTolerance
        : riskTolerance;
    return numerator / safeDivisor;
  }

  /// Dynamic risk tolerance based on game state and opponent analysis
  double calculateRiskTolerance(GameState gameState, Player botPlayer) {
    final personality = _getPersonality(botPlayer.id);
    final constants = _getConstants(botPlayer.id);

    // Base risk tolerance from personality
    double baseRisk = constants.aggressivenessMultiplier;

    // Situational adjustments
    double riskModifier = 1.0;

    // 1. Score position pressure
    final scores = gameState.players.map((p) => p.score).toList()..sort();
    final botScore = botPlayer.score;
    final isLeading = botScore >= scores.last;
    final isFarBehind = botScore < scores[scores.length ~/ 2];

    if (isLeading && personality == BotPersonality.conservative) {
      riskModifier *= 0.7; // Play even more conservatively when leading
    } else if (isFarBehind) {
      riskModifier *= 1.5; // Take more risks when behind
    }

    // 2. Opponent threat assessment
    bool hasHighThreat = false;
    bool hasImmediateThreat = false;

    for (final analysis in _opponentAnalysis.values) {
      if (analysis.isDangerous) {
        hasImmediateThreat = true;
      } else if (analysis.estimatedTurnsToWin <= 3) {
        hasHighThreat = true;
      }
    }

    if (hasImmediateThreat) {
      // Emergency mode - must take risks to prevent opponent win
      riskModifier *= 2.0;
    } else if (hasHighThreat) {
      riskModifier *= 1.3;
    }

    // 3. Round progression pressure
    final turnCount = _getTurnCount(botPlayer.id);
    if (turnCount >= maxTurnsBeforeForcePlayDown - 1) {
      riskModifier *= 1.8; // Must play down soon
    } else if (turnCount >= maxTurnsBeforeForcePlayDown / 2) {
      riskModifier *= 1.2; // Getting pressure to play down
    }

    // 4. Hand quality assessment
    final handQuality = _assessHandQuality(botPlayer);
    if (handQuality > 0.7) {
      riskModifier *= 0.6; // Good hand, can afford to be very patient
    } else if (handQuality < 0.4) {
      riskModifier *= 1.6; // Poor hand, need to take more chances
    }

    // 5. Book completion opportunity
    if (personality == BotPersonality.bookBuilder) {
      final nearBooks = botPlayer.melds
          .where((m) => m.cards.length >= 6)
          .length;
      if (nearBooks > 0) {
        riskModifier *= 0.6; // Very conservative when close to books
      }
    }

    // 6. Foot transition considerations
    if (botPlayer.hasPickedUpFoot && botPlayer.currentHand.length <= 5) {
      riskModifier *= 1.5; // End game approaching, more aggressive
    }

    // Allow higher risk tolerance in emergency situations, but cap at reasonable maximum
    final maxRisk =
        (botPlayer.currentHand.length >=
            BotStrategicConstants.emergencyHandSize)
        ? BotStrategicConstants.maxEmergencyRiskTolerance
        : BotStrategicConstants.maxRiskTolerance;

    return (baseRisk * riskModifier).clamp(
      BotStrategicConstants.minRiskTolerance,
      maxRisk,
    );
  }

  /// Assess overall hand quality for risk calculations
  double _assessHandQuality(Player player) {
    if (player.currentHand.isEmpty) return 0.0;

    final hand = player.currentHand;

    // Count valuable cards (high ranks, wilds, matching cards)
    double qualityScore = 0.0;
    final rankCounts = <CardRank, int>{};

    for (final card in hand) {
      rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;

      // High value cards
      if (card.isWild) {
        qualityScore += 0.15; // Wilds are very valuable
      } else if (card.rank.index >= CardRank.jack.index) {
        qualityScore += 0.1; // High ranks valuable
      } else if (card.rank == CardRank.ace) {
        qualityScore += 0.08; // Aces versatile
      }
    }

    // Bonus for pairs and trips (meld potential) - increased impact
    for (final count in rankCounts.values) {
      if (count >= 3) {
        qualityScore += 0.3; // Trip = meld ready (increased)
      } else if (count == 2) {
        qualityScore += 0.15; // Pair = meld potential (increased)
      }
    }

    return (qualityScore / hand.length).clamp(
      BotStrategicConstants.minHandQuality,
      BotStrategicConstants.maxHandQuality,
    );
  }

  // Risk management thresholds
  int get playDownRiskThreshold => _constants.playDownRiskThreshold;
  static const int footTransitionRiskThreshold = -200;
  static const int wildCardDiscardThreshold =
      10; // Much higher - wilds are valuable
  static const int strongPlayDownBuffer = 10;

  // Discard decision thresholds
  static const int veryLowValuePairThreshold = 5;
  static const int lowValuePairThreshold = 10;
  static const int emergencyMeldBreakThreshold =
      10; // Break small melds if needed

  // High round detection and thresholds
  static const int highRoundHandSizeThreshold = 15;
  static const int highRoundPlayDownThreshold = 120; // Round 3+
  static const int emergencyHandSizeThreshold = 20;
  static const int emergencyFootSizeThreshold = 15;
  static const int lowValueCardThreshold = 5;
  static const int mediumValueCardThreshold = 10;
  static const int highValueCardThreshold = 15;
  static const int smallMeldPointThreshold = 50;
  static const int meldBreakSafetyBuffer = 20;

  // NEW: Foot transition constants for improved strategy
  static const int aggressiveFootTransitionThreshold =
      6; // Cards or fewer (increased from 3)
  static const int handSizePressureThreshold =
      7; // Too many cards after playdown (reduced from 8)
  static const int lateRoundTransitionRound = 3; // Round 3+ be more aggressive
  static const int lateRoundHandSizeThreshold =
      6; // Cards to trigger late round transition
  static const int postPlaydownTransitionThreshold =
      5; // Cards to consider transition
  static const int handQualityNegativeThreshold = -40; // Poor hand value
  static const int handQualityThreeCountThreshold = 3; // Too many 3s
  static const int handQualityAvgValueThreshold = 5; // Low average card value
  static const int improvedEmergencyThreshold =
      -60; // Less conservative than -100
  static const int handSizeQualityThreshold =
      6; // Hand size for quality assessment
  static const int handSizePressureNegativeThreshold = -30; // For large hands
  static const int lateRoundModerateNegativeThreshold =
      -20; // For late round transitions
  static const double mostCardsPlayableThreshold = 0.6; // Reduced from 0.7
  static const double someCardsPlayableThreshold =
      0.5; // New threshold for aggressive play

  // Game rule constants
  static const int minCardsToUnlockDiscard = 2;
  static const int minCardsForFootTransition = 2;
  static const int bookMinSize = 7;
  static const int naturalBookBonus = 500;
  static const int mixedBookBonus = 300;
  static const int wildBookBonus = 1000;
  static const int minWildCardsForWildBook = 3;

  BotDecision makeDecision(Player bot, GameController controller) {
    final gameState = controller.gameState;

    // Set current player context for personality-based decisions
    _setCurrentPlayerContext(bot.id);

    // Track turn counts for strategic play-down timing
    _trackPlayerTurn(bot.id, gameState);

    // Update opponent analysis for strategic awareness
    _updateOpponentAnalysis(gameState, bot);

    // Clear cached melds if this is a different player or if hand might have changed
    // Cache should be invalidated after draws (when hand changes) and during meld phase
    if (_cachedPlayerId != bot.id ||
        gameState.turnPhase == TurnPhase.meld ||
        (gameState.turnPhase == TurnPhase.discard &&
            gameState.hasDrawnFromDeck)) {
      _cachedPossibleMelds = null;
      _cachedPlayerId = bot.id;
    }

    switch (gameState.turnPhase) {
      case TurnPhase.draw:
        return _makeDrawDecision(bot, controller);
      case TurnPhase.meld:
        return _makeMeldDecision(bot, controller);
      case TurnPhase.discard:
        return _makeDiscardDecision(bot, controller);
    }
  }

  void _trackPlayerTurn(String playerId, GameState gameState) {
    // Reset turn count when new round starts (when player hasn't played down)
    final currentPlayer = gameState.players.firstWhere((p) => p.id == playerId);
    if (!currentPlayer.hasPlayedDown) {
      _playerTurnCounts[playerId] = (_playerTurnCounts[playerId] ?? 0) + 1;
    } else {
      _playerTurnCounts[playerId] = 0; // Reset after playing down
    }
  }

  int _getTurnCount(String playerId) {
    return _playerTurnCounts[playerId] ?? 0;
  }

  /// Analyze all opponents and update strategic awareness
  void _updateOpponentAnalysis(GameState gameState, Player botPlayer) {
    for (final player in gameState.players) {
      if (player.id == botPlayer.id) continue; // Skip self

      // Analyze opponent's current state
      final meldSizes = player.melds.map((meld) => meld.cards.length).toList();

      // Estimate turns to win based on hand size, melds, and requirements
      int estimatedTurns = _estimateTurnsToWin(player);

      // Analyze likely needed ranks based on existing melds
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
    // If not played down, need at least 2-3 turns minimum
    if (!player.hasPlayedDown) return 4;

    // If haven't picked up foot, need at least 1-2 turns
    if (!player.hasPickedUpFoot) return 2;

    // Check book requirements
    bool hasCleanBook = player.hasCleanBook;
    bool hasDirtyBook = player.hasDirtyBook;

    int turnsNeeded = 0;

    // Add turns for missing books
    if (!hasCleanBook) turnsNeeded += 2;
    if (!hasDirtyBook) turnsNeeded += 2;

    // Factor in hand size
    if (player.currentHand.length > BotStrategicConstants.endGameHandSize) {
      turnsNeeded += 1;
    }
    if (player.currentHand.length >
        BotStrategicConstants.handSizeInflationThreshold) {
      turnsNeeded += BotStrategicConstants.handSizeInflationPenalty;
    }

    return turnsNeeded.clamp(
      BotStrategicConstants.minEstimatedTurns,
      BotStrategicConstants.maxEstimatedTurns,
    );
  }

  /// Analyze which card ranks opponent likely needs
  List<CardRank> _analyzeLikelyNeededRanks(Player player) {
    final neededRanks = <CardRank>[];

    // Look for melds that are close to becoming books (6+ cards)
    for (final meld in player.melds) {
      if (meld.cards.length >= 6) {
        neededRanks.add(meld.rank);
      }
    }

    return neededRanks;
  }

  /// Get possible melds with caching for performance optimization
  List<List<PlayingCard>> _getPossibleMelds(
    Player bot,
    GameController controller,
  ) {
    if (_cachedPossibleMelds == null || _cachedPlayerId != bot.id) {
      _cachedPossibleMelds = controller.findPossibleMelds(bot);
      _cachedPlayerId = bot.id;
    }
    return _cachedPossibleMelds!;
  }

  BotDecision _makeDrawDecision(Player bot, GameController controller) {
    final gameState = controller.gameState;

    // Calculate current risk tolerance for dynamic decision making
    final riskTolerance = calculateRiskTolerance(gameState, bot);

    // STRATEGIC CHANGE: Only unlock discard pile if we haven't played down yet
    // AND we can unlock, OR if already played down and it's very valuable
    if (gameState.canDrawFromDiscard) {
      final topDiscard = gameState.topDiscard!;

      // Count how many matching natural cards we have
      final matchingNaturals = bot.currentHand
          .where((card) => card.rank == topDiscard.rank && !card.isWild)
          .length;

      if (matchingNaturals >= minCardsToUnlockDiscard) {
        final discardPileValue = _calculateDiscardPileValue(
          gameState.discardPile,
        );
        final discardPileSize = gameState.discardPile.length;

        // Apply risk tolerance to thresholds
        final adjustedValueThreshold = _safeRiskDivision(
          valuablePileThreshold.toDouble(),
          riskTolerance,
        ).round();
        final adjustedSizeThreshold = _safeRiskDivision(
          largePileThreshold.toDouble(),
          riskTolerance,
        ).round();

        // If we haven't played down, be VERY conservative - only take exceptional piles
        if (!bot.hasPlayedDown) {
          // Risk tolerance affects willingness to unlock pile before play-down
          final conservativeMultiplier = riskTolerance > 1.0 ? 1.2 : 1.5;
          if (discardPileValue >
                  adjustedValueThreshold * conservativeMultiplier ||
              discardPileSize >=
                  adjustedSizeThreshold +
                      _safeRiskDivision(3.0, riskTolerance).round()) {
            return BotDecision(action: 'drawFromDiscard');
          }
        } else {
          // After playing down, more willing to take good piles for book building
          if (bot.hasPickedUpFoot) {
            // On foot - focus on book completion, adjusted by risk tolerance
            final adjustedFootValueThreshold = _safeRiskDivision(
              footPileValueThreshold.toDouble(),
              riskTolerance,
            ).round();
            final adjustedFootSizeThreshold = _safeRiskDivision(
              footPileSizeThreshold.toDouble(),
              riskTolerance,
            ).round();

            if (discardPileValue > adjustedFootValueThreshold ||
                discardPileSize >= adjustedFootSizeThreshold) {
              return BotDecision(action: 'drawFromDiscard');
            }
          } else {
            // Still on hand after playing down - moderate threshold, adjusted by risk
            final adjustedHandValueThreshold = _safeRiskDivision(
              handPileValueThreshold.toDouble(),
              riskTolerance,
            ).round();
            final adjustedHandSizeThreshold = _safeRiskDivision(
              handPileSizeThreshold.toDouble(),
              riskTolerance,
            ).round();

            if (discardPileValue > adjustedHandValueThreshold ||
                discardPileSize >= adjustedHandSizeThreshold) {
              return BotDecision(action: 'drawFromDiscard');
            }
          }
        }
      }
    }

    return BotDecision(action: 'drawFromDeck');
  }

  BotDecision _makeMeldDecision(Player bot, GameController controller) {
    final handSize = bot.currentHand.length;

    // EMERGENCY OVERRIDE: If hand is critically large (>15), skip ALL meld logic and discard
    // This prevents the 18-card problem while preserving normal bot behavior
    if (handSize > 15 && bot.hasPlayedDown) {
      final cardToDiscard = _chooseCardToDiscard(bot, controller.gameState);
      return BotDecision(action: 'discard', data: cardToDiscard);
    }

    // Check if we're in the middle of a multi-meld play-down sequence
    if (_plannedMelds != null && _currentMeldIndex < _plannedMelds!.length) {
      final nextMeld = _plannedMelds![_currentMeldIndex];
      _currentMeldIndex++;

      // If this was the last meld in the sequence, clear the state
      if (_currentMeldIndex >= _plannedMelds!.length) {
        _plannedMelds = null;
        _currentMeldIndex = 0;
        _inMultiMeldSequence = false;
      }

      return BotDecision(
        action: 'createMeld',
        data: nextMeld,
        skipPlayDownCheck: true,
      );
    }

    // New strategic decision tree: 1. Play down, 2. Go to foot, 3. Go out

    BotDecision result;

    // Priority 1: If not played down yet, check if we can/should play down
    if (!bot.hasPlayedDown) {
      result = _handlePlayDownDecision(bot, controller);
      if (result.action != 'error') {
        return result;
      }
    }

    // Priority 2: If on hand pile, check if we should transition to foot
    if (!bot.hasPickedUpFoot) {
      result = _handleFootTransitionDecision(bot, controller);
      if (result.action != 'error') {
        return result;
      }
    }

    // Priority 3: If on foot pile, check if we can go out
    result = _handleGoOutDecision(bot, controller);
    if (result.action != 'error') {
      return result;
    }

    // FAILSAFE: If all strategies fail/return error, discard if possible, otherwise error
    if (bot.currentHand.isEmpty) {
      return BotDecision(action: 'error'); // Cannot discard from empty hand
    }
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  BotDecision _makeDiscardDecision(Player bot, GameController controller) {
    final hand = bot.currentHand;
    if (hand.isEmpty) {
      return BotDecision(action: 'error');
    }

    final cardToDiscard = _chooseCardToDiscard(bot, controller.gameState);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  int _calculateDiscardPileValue(List<PlayingCard> discardPile) {
    int value = 0;
    for (final card in discardPile) {
      value += card.pointValue;
    }
    return value;
  }

  List<Map<String, dynamic>> _findCardsToAddToExistingMelds(Player bot) {
    final cardsToAdd = <Map<String, dynamic>>[];

    for (int i = 0; i < bot.melds.length; i++) {
      final meld = bot.melds[i];
      for (final card in bot.currentHand) {
        if (meld.canAddCard(card)) {
          cardsToAdd.add({
            'meldIndex': i,
            'card': card,
            'priority': card.pointValue,
          });
        }
      }
    }

    cardsToAdd.sort((a, b) => b['priority'].compareTo(a['priority']));
    return cardsToAdd;
  }

  PlayingCard _chooseCardToDiscard(Player bot, [GameState? gameState]) {
    final riskTolerance = gameState != null
        ? calculateRiskTolerance(gameState, bot)
        : 1.0;
    final hand = List<PlayingCard>.from(bot.currentHand);
    final wildCards = hand.where((c) => c.isWild).toList();
    final naturalCards = hand.where((c) => !c.isWild).toList();

    // Group natural cards by rank for analysis
    final cardsByRank = <CardRank, List<PlayingCard>>{};
    for (final card in naturalCards) {
      cardsByRank.putIfAbsent(card.rank, () => []).add(card);
    }

    // Try discard priorities in order
    PlayingCard? result;

    // Priority 1: Discard 3s strategically
    result = _tryDiscardThrees(bot, naturalCards);
    if (result != null) return result;

    // Priority 2-5: Handle natural cards by frequency, adjusted by risk tolerance
    result = _tryDiscardNaturalCards(bot, cardsByRank, riskTolerance);
    if (result != null) return result;

    // Last resort: discard wild cards (adjusted by risk - higher risk = more willing)
    result = _tryDiscardWildCards(bot, wildCards, riskTolerance);
    if (result != null) return result;

    // Fallback (should never happen) - but check for empty hand
    if (hand.isEmpty) {
      throw StateError('Bot has no cards to discard');
    }
    return hand.first;
  }

  /// Try to discard 3s strategically (ALWAYS priority - they're negative/penalty)
  PlayingCard? _tryDiscardThrees(Player bot, List<PlayingCard> naturalCards) {
    final threeCards = naturalCards
        .where((c) => c.rank == CardRank.three)
        .toList();

    if (threeCards.isEmpty) return null;

    // Sort by point value - discard black 3s first (most negative)
    threeCards.sort((a, b) => a.pointValue.compareTo(b.pointValue));
    return threeCards.first;
  }

  /// Try to discard natural cards - Adaptive based on game situation and risk tolerance
  PlayingCard? _tryDiscardNaturalCards(
    Player bot,
    Map<CardRank, List<PlayingCard>> cardsByRank,
    double riskTolerance,
  ) {
    final cardCategories = _categorizeCardsByFrequency(cardsByRank);
    final singletons = cardCategories['singletons']!;
    final pairs = cardCategories['pairs']!;
    final handSize = bot.currentHand.length;
    final isHighRound = _isHighRoundSituation(bot, handSize);

    // Priority 2: Try to discard low-value singletons first
    final singletonResult = _tryDiscardSingletons(
      singletons,
      isHighRound,
      riskTolerance,
    );
    if (singletonResult != null) return singletonResult;

    // Priority 3: Try to break up pairs based on situation and risk tolerance
    final pairResult = _tryDiscardPairs(bot, pairs, isHighRound, riskTolerance);
    if (pairResult != null) return pairResult;

    // Priority 4: Emergency discard if too many cards (risk affects threshold)
    final emergencyResult = _tryEmergencyDiscard(
      singletons,
      handSize,
      riskTolerance,
    );
    if (emergencyResult != null) return emergencyResult;

    return null; // Usually hold onto valuable cards
  }

  /// Check if we're in a high round situation requiring more flexible strategy
  bool _isHighRoundSituation(Player bot, int handSize) {
    return !bot.hasPlayedDown && handSize > highRoundHandSizeThreshold;
  }

  /// Try to discard singleton cards with appropriate value thresholds
  PlayingCard? _tryDiscardSingletons(
    List<PlayingCard> singletons,
    bool isHighRound,
    double riskTolerance,
  ) {
    final baseThreshold = isHighRound
        ? mediumValueCardThreshold
        : lowValueCardThreshold;

    // Risk tolerance affects willingness to discard higher value cards
    final adjustedThreshold = (baseThreshold * riskTolerance).round();

    final lowValueSingletons = singletons
        .where((card) => card.pointValue <= adjustedThreshold)
        .toList();
    if (lowValueSingletons.isNotEmpty) {
      lowValueSingletons.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return lowValueSingletons.first;
    }
    return null;
  }

  /// Try to discard from pairs based on game state and round
  PlayingCard? _tryDiscardPairs(
    Player bot,
    List<PlayingCard> pairs,
    bool isHighRound,
    double riskTolerance,
  ) {
    if (!bot.hasPlayedDown) {
      return _tryDiscardPairsBeforePlayDown(pairs, isHighRound, riskTolerance);
    } else {
      return _tryDiscardPairsAfterPlayDown(pairs, riskTolerance);
    }
  }

  /// Try to discard from pairs before playing down (more conservative)
  PlayingCard? _tryDiscardPairsBeforePlayDown(
    List<PlayingCard> pairs,
    bool isHighRound,
    double riskTolerance,
  ) {
    if (isHighRound) {
      // Higher rounds: be more willing to break up medium-value pairs
      final mediumPairs = pairs
          .where((card) => card.pointValue <= highValueCardThreshold)
          .toList();
      if (mediumPairs.isNotEmpty) {
        mediumPairs.sort((a, b) => a.pointValue.compareTo(b.pointValue));
        return mediumPairs.first;
      }
    } else {
      // Early rounds: only very low value pairs, adjusted by risk tolerance
      final threshold = (lowValueCardThreshold * riskTolerance).round();
      final veryLowPairs = pairs
          .where((card) => card.pointValue <= threshold)
          .toList();
      final shouldBreak = _shouldBreakUpHighValuePair() || riskTolerance > 1.5;
      if (veryLowPairs.isNotEmpty && shouldBreak) {
        veryLowPairs.sort((a, b) => a.pointValue.compareTo(b.pointValue));
        return veryLowPairs.first;
      }
    }
    return null;
  }

  /// Try to discard from pairs after playing down (more liberal)
  PlayingCard? _tryDiscardPairsAfterPlayDown(
    List<PlayingCard> pairs,
    double riskTolerance,
  ) {
    final threshold = (mediumValueCardThreshold * riskTolerance).round();
    final lowPairs = pairs
        .where((card) => card.pointValue <= threshold)
        .toList();
    if (lowPairs.isNotEmpty) {
      lowPairs.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return lowPairs.first;
    }
    return null;
  }

  /// Emergency discard when hand is too large
  PlayingCard? _tryEmergencyDiscard(
    List<PlayingCard> singletons,
    int handSize,
    double riskTolerance,
  ) {
    // Risk tolerance affects emergency threshold - higher risk = trigger emergency sooner
    final adjustedThreshold = _safeRiskDivision(
      emergencyHandSizeThreshold.toDouble(),
      riskTolerance,
    ).round();
    if (handSize >= adjustedThreshold && singletons.isNotEmpty) {
      singletons.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return singletons.first;
    }
    return null;
  }

  /// Try to discard wild cards (EXTREMELY conservative - absolute last resort)
  PlayingCard? _tryDiscardWildCards(
    Player bot,
    List<PlayingCard> wildCards,
    double riskTolerance,
  ) {
    if (wildCards.isEmpty) return null;

    // Risk tolerance affects willingness to discard wilds
    // Higher risk = more willing to discard wilds in pressure situations

    final handSize = bot.currentHand.length;
    final isOnFoot = bot.hasPickedUpFoot;

    // Adjust thresholds based on risk tolerance
    final adjustedWildThreshold = _safeRiskDivision(
      wildCardDiscardThreshold.toDouble(),
      riskTolerance,
    ).round();
    final adjustedFootThreshold = _safeRiskDivision(
      emergencyFootSizeThreshold.toDouble(),
      riskTolerance,
    ).round();

    // Emergency case 1: Excessive wild hoarding (lowered threshold with high risk)
    if (wildCards.length >= adjustedWildThreshold) {
      wildCards.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return wildCards.first;
    }

    // Emergency case 2: Must discard last card but can't go out
    if (handSize == 1 && !bot.canGoOut) {
      return wildCards.first;
    }

    // Emergency case 3: On foot with huge hand and no meld opportunities
    if (isOnFoot && handSize >= adjustedFootThreshold) {
      // Only if we really can't use the wilds anywhere
      wildCards.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return wildCards.first;
    }

    return null; // Almost never discard wilds
  }

  bool _shouldBreakUpHighValuePair() {
    // Strategic chance to break up high-value pairs when no other options
    return _random.nextDouble() < highValuePairBreakChance;
  }

  /// Calculate total point value of cards in hand (negative for penalty cards)
  int _calculateHandValue(List<PlayingCard> hand) {
    int totalValue = 0;
    for (final card in hand) {
      totalValue += card.pointValue;
    }
    return totalValue;
  }

  /// Categorize cards by frequency for discard decision
  Map<String, List<PlayingCard>> _categorizeCardsByFrequency(
    Map<CardRank, List<PlayingCard>> cardsByRank,
  ) {
    final singletons = <PlayingCard>[];
    final pairs = <PlayingCard>[];
    final triples = <PlayingCard>[];

    for (final entry in cardsByRank.entries) {
      if (entry.key == CardRank.three) continue; // Skip 3s (handled elsewhere)

      if (entry.value.length == 1) {
        singletons.addAll(entry.value);
      } else if (entry.value.length == 2) {
        pairs.addAll(entry.value);
      } else if (entry.value.length >= 3) {
        triples.addAll(entry.value);
      }
    }

    return {'singletons': singletons, 'pairs': pairs, 'triples': triples};
  }

  /// Handle play-down decision with new strategic approach
  BotDecision _handlePlayDownDecision(Player bot, GameController controller) {
    final possibleMelds = _getPossibleMelds(bot, controller);
    final gameState = controller.gameState;
    final playDownRequirement = gameState.playDownRequirement;
    final turnCount = _getTurnCount(bot.id);
    final riskTolerance = calculateRiskTolerance(gameState, bot);

    // STRATEGIC CHANGE: Hold cards until turn threshold, adjusted by risk tolerance
    // High risk tolerance = play down sooner, low risk tolerance = wait longer
    final adjustedMaxTurns =
        _safeRiskDivision(
          maxTurnsBeforeForcePlayDown.toDouble(),
          riskTolerance,
        ).round().clamp(
          BotStrategicConstants.minAdjustedTurns,
          BotStrategicConstants.maxAdjustedTurns,
        );

    if (turnCount < adjustedMaxTurns) {
      return _handleEarlyGamePlayDown(
        bot,
        controller,
        possibleMelds,
        playDownRequirement,
        riskTolerance,
      );
    } else {
      return _handleLateGamePlayDown(
        possibleMelds,
        playDownRequirement,
        controller,
        riskTolerance,
      );
    }
  }

  /// Handle early game play-down (before turn threshold) - conservative strategy
  BotDecision _handleEarlyGamePlayDown(
    Player bot,
    GameController controller,
    List<List<PlayingCard>> possibleMelds,
    int playDownRequirement,
    double riskTolerance,
  ) {
    // Priority 1: Forced play-down after unlocking discard pile
    final forcedResult = _tryForcedPlayDown(
      bot,
      controller,
      possibleMelds,
      playDownRequirement,
    );
    if (forcedResult != null) return forcedResult;

    // Priority 2: Natural meld opportunity - play minimal points needed
    final naturalResult = _tryNaturalMeldPlayDown(
      possibleMelds,
      playDownRequirement,
    );
    if (naturalResult != null) return naturalResult;

    // Priority 3: HIGH ROUND STRATEGY - break up existing small melds if needed
    if (playDownRequirement > highRoundPlayDownThreshold) {
      // Later rounds (Round 3+)
      final meldBreakResult = _tryHighPointWildMeldForHighRounds(
        bot,
        controller,
        possibleMelds,
        playDownRequirement,
      );
      if (meldBreakResult != null) return meldBreakResult;
    }

    // Priority 4: Exceptional opportunity (way over requirement), adjusted by risk
    final adjustedExceptionalThreshold = _safeRiskDivision(
      (playDownRequirement + strategicBufferPoints * 2).toDouble(),
      riskTolerance,
    );
    final exceptionalResult = _tryExceptionalPlayDown(
      possibleMelds,
      adjustedExceptionalThreshold.round(),
    );
    if (exceptionalResult != null) return exceptionalResult;

    // Otherwise, HOLD cards and discard strategically
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Handle late game play-down (turn threshold+) - forced minimal play-down
  BotDecision _handleLateGamePlayDown(
    List<List<PlayingCard>> possibleMelds,
    int playDownRequirement,
    GameController controller,
    double riskTolerance,
  ) {
    // Late game: Play down with minimal points to unlock discard pile ability
    // Risk tolerance doesn't affect much here since this is forced play-down

    // Try single meld first
    final minimalResult = _tryMinimalPlayDown(
      possibleMelds,
      playDownRequirement,
    );
    if (minimalResult != null) return minimalResult;

    // BUGFIX: If no single meld works, try multi-meld combinations
    final multiMeldResult = _findBestMeldCombination(
      possibleMelds,
      playDownRequirement,
      controller,
    );
    if (multiMeldResult.isNotEmpty) {
      return _executePlayDown(multiMeldResult);
    }

    // Emergency fallback - must discard to complete turn
    // This should rarely happen since late game usually forces play-down
    return BotDecision(action: 'error'); // Will be caught by failsafe
  }

  /// Try forced play-down after unlocking discard pile
  BotDecision? _tryForcedPlayDown(
    Player bot,
    GameController controller,
    List<List<PlayingCard>> possibleMelds,
    int playDownRequirement,
  ) {
    final gameState = controller.gameState;
    final justUnlockedDiscard =
        gameState.hasDrawnFromDeck == false && gameState.discardPile.isNotEmpty;

    if (!justUnlockedDiscard) return null;

    // Forced to play down after unlocking discard pile
    final strategicPlayDown = _findStrategicPlayDown(
      bot,
      controller,
      possibleMelds,
    );
    if (strategicPlayDown.isNotEmpty) {
      return _executePlayDown(strategicPlayDown);
    }

    // Fallback: Find any meld that meets play-down requirement
    for (final meld in possibleMelds) {
      final meldPoints = meld.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      if (meldPoints >= playDownRequirement) {
        return BotDecision(action: 'createMeld', data: meld);
      }
    }

    return null;
  }

  /// Try natural meld play-down (no wilds) - play minimal points needed to unlock discard pickup
  BotDecision? _tryNaturalMeldPlayDown(
    List<List<PlayingCard>> possibleMelds,
    int playDownRequirement,
  ) {
    // Find all natural melds (no wild cards)
    final naturalMelds = possibleMelds
        .where((meld) => !meld.any((card) => card.isWild))
        .toList();

    if (naturalMelds.isEmpty) return null;

    // First try single natural melds that meet the requirement
    List<PlayingCard>? bestSingleMeld;
    int closestSinglePoints = playDownRequirement + 1000; // Start high

    for (final meld in naturalMelds) {
      final meldPoints = meld.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );

      // Must meet requirement and be closer to requirement than current best
      if (meldPoints >= playDownRequirement &&
          meldPoints < closestSinglePoints) {
        bestSingleMeld = meld;
        closestSinglePoints = meldPoints;
      }
    }

    // If we found a single natural meld that works, use it
    if (bestSingleMeld != null) {
      return BotDecision(action: 'createMeld', data: bestSingleMeld);
    }

    // If no single natural meld meets requirement, try natural multi-meld combinations
    final naturalMultiMeld = _findBestNaturalMeldCombination(
      naturalMelds,
      playDownRequirement,
    );

    if (naturalMultiMeld.isNotEmpty) {
      return _executePlayDown(naturalMultiMeld);
    }

    return null;
  }

  /// Try exceptional play-down (way over requirement)
  BotDecision? _tryExceptionalPlayDown(
    List<List<PlayingCard>> possibleMelds,
    int playDownRequirement,
  ) {
    final exceptionalThreshold = playDownRequirement + 100; // Very high bar

    for (final meld in possibleMelds) {
      final meldPoints = meld.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      if (meldPoints >= exceptionalThreshold) {
        return BotDecision(action: 'createMeld', data: meld);
      }
    }

    return null;
  }

  /// Try minimal play-down (just enough to meet requirement)
  BotDecision? _tryMinimalPlayDown(
    List<List<PlayingCard>> possibleMelds,
    int playDownRequirement,
  ) {
    // Find the meld closest to (but meeting) the requirement
    List<PlayingCard>? bestMeld;
    int closestPoints = playDownRequirement + 1000; // Start high

    for (final meld in possibleMelds) {
      final meldPoints = meld.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );

      // Must meet requirement and be closer to requirement than current best
      if (meldPoints >= playDownRequirement && meldPoints < closestPoints) {
        bestMeld = meld;
        closestPoints = meldPoints;
      }
    }

    if (bestMeld != null) {
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    return null;
  }

  /// NEW: Try high-value wild card melds for high round requirements
  ///
  /// NOTE: This method analyzes small existing melds that could theoretically be broken up
  /// but actually tries to create new wild-heavy melds to meet high point requirements.
  /// It does NOT actually break existing melds - that would require game controller support.
  BotDecision? _tryHighPointWildMeldForHighRounds(
    Player bot,
    GameController controller,
    List<List<PlayingCard>> possibleMelds,
    int playDownRequirement,
  ) {
    // Only consider this in higher rounds where requirements are tough
    if (bot.melds.isEmpty) return null;

    // Find small, low-value melds that we could break up
    final breakableMelds = <int>[];
    int totalBreakablePoints = 0;

    for (int i = 0; i < bot.melds.length; i++) {
      final meld = bot.melds[i];
      final meldPoints = meld.pointValue;

      // Only break up small melds (not books) and relatively low point value
      if (meld.cards.length < bookMinSize &&
          meldPoints <= smallMeldPointThreshold) {
        breakableMelds.add(i);
        totalBreakablePoints += meldPoints;
      }
    }

    if (breakableMelds.isEmpty) return null;

    // Calculate available points including wild cards (actual values: 2s=20, Jokers=50)
    final handPoints = _calculateHandValue(bot.currentHand);
    final wildCards = bot.currentHand.where((c) => c.isWild).toList();
    final wildCardPoints = wildCards.fold<int>(
      0,
      (sum, card) => sum + card.pointValue,
    );

    final potentialPoints = handPoints + totalBreakablePoints + wildCardPoints;

    // Only break melds if we can definitely meet the requirement
    if (potentialPoints >= playDownRequirement + meldBreakSafetyBuffer) {
      // For now, recommend using wild cards more aggressively
      // Try to create a meld using wilds to boost points
      final meldsWithWilds = possibleMelds
          .where((meld) => meld.any((card) => card.isWild))
          .toList();

      if (meldsWithWilds.isNotEmpty) {
        // Sort by point value, prioritize higher point melds
        meldsWithWilds.sort((a, b) {
          final aPoints = a.fold<int>(0, (sum, card) => sum + card.pointValue);
          final bPoints = b.fold<int>(0, (sum, card) => sum + card.pointValue);
          return bPoints.compareTo(aPoints);
        });

        final bestWildMeld = meldsWithWilds.first;
        final meldPoints = bestWildMeld.fold<int>(
          0,
          (sum, card) => sum + card.pointValue,
        );

        if (meldPoints >= playDownRequirement) {
          return BotDecision(action: 'createMeld', data: bestWildMeld);
        }
      }
    }

    return null;
  }

  /// Handle foot transition decision - IMPROVED STRATEGY: Multiple transition triggers
  BotDecision _handleFootTransitionDecision(
    Player bot,
    GameController controller,
  ) {
    final gameState = controller.gameState;
    final remainingCards = bot.currentHand.length;
    final handValue = _calculateHandValue(bot.currentHand);
    final currentRound = gameState.round;

    // PRE-CHECK: Be more conservative when still on hand pile (not picked up foot yet)
    // This preserves strategic options and wild card management
    final stillOnHandPile = bot.hasPlayedDown && !bot.hasPickedUpFoot;
    final wildCardCount = bot.currentHand.where((c) => c.isWild).length;
    final hasExcessiveWilds =
        wildCardCount >= 6; // Relaxed from 5 to 6 wilds threshold

    // NEW: Competitive pressure - if opponent is on foot, be more aggressive
    final opponentOnFoot = gameState.players.any(
      (p) => p.id != bot.id && p.hasPickedUpFoot,
    );
    final competitivePressure = opponentOnFoot && bot.hasPlayedDown;

    // IMPROVEMENT 1: More aggressive transition with fewer cards OR competitive pressure (only for large hands)
    if ((remainingCards <= aggressiveFootTransitionThreshold ||
            (competitivePressure && remainingCards > 12)) &&
        !(stillOnHandPile && hasExcessiveWilds)) {
      return _tryAggressiveFootTransition(bot, controller);
    }

    // IMPROVEMENT 2: Hand size pressure - transition when hand gets too large
    // OR when competitive pressure exists for very large hands only (>12 cards)
    if ((remainingCards >= handSizePressureThreshold ||
            (competitivePressure && remainingCards > 12)) &&
        bot.hasPlayedDown &&
        !hasExcessiveWilds) {
      return _tryHandSizePressureTransition(bot, controller, handValue);
    }

    // IMPROVEMENT 3: Round-based strategy - be more aggressive in later rounds
    if (currentRound >= lateRoundTransitionRound &&
        remainingCards >= lateRoundHandSizeThreshold) {
      return _tryLateRoundTransition(bot, controller, handValue);
    }

    // NEW: Meld completion trigger - if bot has books/good melds, transition
    final hasBooks = bot.melds.any((meld) => meld.cards.length >= 7);
    final hasMultipleMelds = bot.melds.length >= 3;
    if (hasBooks &&
        hasMultipleMelds &&
        bot.hasPlayedDown &&
        remainingCards >= 5) {
      return _tryAggressiveFootTransition(bot, controller);
    }

    // IMPROVEMENT 4: Post-playdown optimization - more willing after playing down
    // BUT: Be conservative with weak hands to preserve strategic options
    // AND: Be more conservative when still on hand pile
    final hasWeakMeldOpportunity = _hasOnlyWeakMeldOpportunities(
      bot,
      controller,
    );

    if (bot.hasPlayedDown &&
        remainingCards >= postPlaydownTransitionThreshold &&
        !hasWeakMeldOpportunity &&
        !stillOnHandPile) {
      return _tryPostPlaydownTransition(bot, controller);
    }

    // IMPROVEMENT 5: Improved hand quality assessment
    // BUT: Don't override conservative behavior for strategic wild card management
    if (_shouldTransitionBasedOnHandQuality(bot, handValue, remainingCards) &&
        !hasExcessiveWilds) {
      return _tryQualityBasedTransition(bot, controller);
    }

    // Original logic: Check if we can create melds that use up most/all remaining cards
    // BUT: Be more conservative with hands that have strategic value or when on hand pile
    final canPlayMostCards = _canPlayMostCards(bot, controller);
    final shouldBeConservative =
        hasExcessiveWilds || hasWeakMeldOpportunity || stillOnHandPile;

    if (canPlayMostCards && !shouldBeConservative) {
      // Find the best meld opportunity to use maximum cards
      final possibleMelds = _getPossibleMelds(bot, controller);
      if (possibleMelds.isNotEmpty) {
        // Choose meld that uses most cards
        final bestMeld = _chooseLargestMeld(possibleMelds);
        return BotDecision(action: 'createMeld', data: bestMeld);
      }
    }

    // Emergency risk management - improved threshold
    if (handValue <= improvedEmergencyThreshold) {
      final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
      if (cardsToAddToMelds.isNotEmpty) {
        final cardToAdd = cardsToAddToMelds.first;
        return BotDecision(action: 'addToMeld', data: cardToAdd);
      }
    }

    // Otherwise, hold cards and discard strategically
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Try aggressive foot transition - prioritize hand reduction over melding
  BotDecision _tryAggressiveFootTransition(
    Player bot,
    GameController controller,
  ) {
    final handSize = bot.currentHand.length;

    // EMERGENCY: If hand is extremely large (>15 cards), DISCARD immediately, don't meld
    // This targets the 18-card problem specifically
    if (handSize > 15) {
      final cardToDiscard = _chooseCardToDiscard(bot, controller.gameState);
      return BotDecision(action: 'discard', data: cardToDiscard);
    }

    // Only consider melding if hand is small enough
    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
    if (cardsToAddToMelds.isNotEmpty && handSize <= 6) {
      final cardToAdd = cardsToAddToMelds.first;
      return BotDecision(action: 'addToMeld', data: cardToAdd);
    }

    // Try to create any meld possible
    final possibleMelds = _getPossibleMelds(bot, controller);
    if (possibleMelds.isNotEmpty) {
      final bestMeld = _chooseLargestMeld(possibleMelds);
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    // Discard strategically to get closer to foot
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Try transition due to hand size pressure (8+ cards after playdown)
  BotDecision _tryHandSizePressureTransition(
    Player bot,
    GameController controller,
    int handValue,
  ) {
    final handSize = bot.currentHand.length;

    // EMERGENCY DISCARD: With extremely large hands (>15), discard immediately, don't meld
    // This targets the 18-card problem specifically
    if (handSize > 15) {
      final cardToDiscard = _chooseCardToDiscard(bot, controller.gameState);
      return BotDecision(action: 'discard', data: cardToDiscard);
    }

    // With 8+ cards, prioritize reducing hand size but balance with strategy

    // Strategy 1: Add multiple cards to existing melds if possible
    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
    if (cardsToAddToMelds.length >= 2) {
      // Prioritize highest value cards to clear hand space
      cardsToAddToMelds.sort((a, b) => b['priority'].compareTo(a['priority']));
      final cardToAdd = cardsToAddToMelds.first;
      return BotDecision(action: 'addToMeld', data: cardToAdd);
    }

    // Strategy 2: Create melds more aggressively (lower threshold)
    final possibleMelds = _getPossibleMelds(bot, controller);
    if (possibleMelds.isNotEmpty) {
      // Choose meld that clears the most cards
      final bestMeld = _chooseLargestMeld(possibleMelds);
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    // Strategy 3: If hand is getting unwieldy, consider discarding problematic cards
    if (handValue <= handSizePressureNegativeThreshold) {
      final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
      if (cardsToAddToMelds.isNotEmpty) {
        final cardToAdd = cardsToAddToMelds.first;
        return BotDecision(action: 'addToMeld', data: cardToAdd);
      }
    }

    // Default: strategic discard
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Try transition in later rounds (round 3+) where foot access is more valuable
  BotDecision _tryLateRoundTransition(
    Player bot,
    GameController controller,
    int handValue,
  ) {
    // In later rounds, foot contains better cards and requirements are higher

    // Strategy 1: Be more willing to transition with moderate hands
    if (handValue <= lateRoundModerateNegativeThreshold ||
        bot.currentHand.length >= (lateRoundHandSizeThreshold + 1)) {
      final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
      if (cardsToAddToMelds.isNotEmpty) {
        final cardToAdd = cardsToAddToMelds.first;
        return BotDecision(action: 'addToMeld', data: cardToAdd);
      }
    }

    // Strategy 2: Create melds with a lower efficiency threshold
    final canPlaySomeCards = _canPlaySomeCards(
      bot,
      controller,
    ); // New method: 50% threshold
    if (canPlaySomeCards) {
      final possibleMelds = _getPossibleMelds(bot, controller);
      if (possibleMelds.isNotEmpty) {
        final bestMeld = _chooseLargestMeld(possibleMelds);
        return BotDecision(action: 'createMeld', data: bestMeld);
      }
    }

    // Default: strategic discard
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Try transition after playing down (more opportunities available)
  BotDecision _tryPostPlaydownTransition(
    Player bot,
    GameController controller,
  ) {
    // After playing down, we can unlock discard pile, so be more aggressive

    // Strategy 1: Add to existing melds more liberally
    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
    if (cardsToAddToMelds.isNotEmpty) {
      // Even low priority additions are worth it to access foot
      final cardToAdd = cardsToAddToMelds.first;
      return BotDecision(action: 'addToMeld', data: cardToAdd);
    }

    // Strategy 2: Create smaller melds to clear hand
    final possibleMelds = _getPossibleMelds(bot, controller);
    final smallMelds = possibleMelds.where((meld) => meld.length >= 3).toList();
    if (smallMelds.isNotEmpty) {
      // Prefer melds that clear more cards
      final bestMeld = _chooseLargestMeld(smallMelds);
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    // Default: strategic discard
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Try transition based on hand quality assessment
  BotDecision _tryQualityBasedTransition(
    Player bot,
    GameController controller,
  ) {
    // Poor quality hands should be cleared to access foot

    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
    if (cardsToAddToMelds.isNotEmpty) {
      final cardToAdd = cardsToAddToMelds.first;
      return BotDecision(action: 'addToMeld', data: cardToAdd);
    }

    // Even small melds are worthwhile to clear bad hands
    final possibleMelds = _getPossibleMelds(bot, controller);
    if (possibleMelds.isNotEmpty) {
      final bestMeld = possibleMelds.first; // Any meld is good
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    // Strategic discard of worst cards
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Determine if bot should transition based on hand quality
  bool _shouldTransitionBasedOnHandQuality(
    Player bot,
    int handValue,
    int handSize,
  ) {
    // Factors that indicate poor hand quality:
    // 1. Negative point value
    // 2. Many 3s (penalty cards)
    // 3. Large hand with little meld potential
    // 4. Mostly low-value cards

    if (handValue <= handQualityNegativeThreshold) {
      return true; // Negative hands should transition
    }

    // Count penalty cards (3s)
    final threeCount = bot.currentHand
        .where((c) => c.rank == CardRank.three)
        .length;
    if (threeCount >= handQualityThreeCountThreshold) {
      return true; // Too many 3s
    }

    // Large hands with low average value
    if (handSize >= handSizeQualityThreshold) {
      final avgValue = handValue / handSize;
      if (avgValue <= handQualityAvgValueThreshold) {
        return true; // Low-value cards on average
      }
    }

    return false;
  }

  /// Check if bot has only weak meld opportunities (conservative check)
  bool _hasOnlyWeakMeldOpportunities(Player bot, GameController controller) {
    final possibleMelds = _getPossibleMelds(bot, controller);
    if (possibleMelds.isEmpty) return true;

    // Check if all possible melds are weak (low point value)
    for (final meld in possibleMelds) {
      final meldPoints = meld.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      // If any meld has decent points (50+), it's not weak
      if (meldPoints >= 50) {
        return false;
      }
    }

    return true; // All melds are weak
  }

  /// Check if bot can play some of their cards (50% threshold vs 70% in original)
  bool _canPlaySomeCards(Player bot, GameController controller) {
    final remainingCards = bot.currentHand.length;
    if (remainingCards <= 3) return true; // Few cards, try to use them

    // Count how many cards can be added to existing melds
    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
    final addableCards = cardsToAddToMelds.length;

    // Count cards in possible new melds
    final possibleMelds = controller.findPossibleMelds(bot);
    int meldableCards = 0;
    if (possibleMelds.isNotEmpty) {
      final bestMeld = _chooseLargestMeld(possibleMelds);
      meldableCards = bestMeld.length;
    }

    // Can we use 50%+ of remaining cards? (Less conservative than 70%)
    final usableCards = addableCards + meldableCards;
    return usableCards >= (remainingCards * someCardsPlayableThreshold).floor();
  }

  /// Handle go-out decision - Focus on book completion and strategic timing
  BotDecision _handleGoOutDecision(Player bot, GameController controller) {
    // STRATEGIC CHANGE: On foot, focus on completing books before going out

    // Check if we can go out immediately (with required books)
    if (bot.currentHand.isEmpty && bot.canGoOut) {
      return BotDecision(action: 'goOut');
    }

    // NEW STRATEGY: Only meld aggressively if we can complete books or go out soon
    final canCompleteBooks = _canCompleteRequiredBooks(bot, controller);

    if (canCompleteBooks) {
      // Priority 1: Focus on completing books (7+ cards) for maximum points
      final bookCompletionMove = _tryCompleteBooks(bot, controller);
      if (bookCompletionMove != null) return bookCompletionMove;

      // Priority 2: Add to existing melds to build toward books
      final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
      if (cardsToAddToMelds.isNotEmpty) {
        // Prioritize additions that move melds closer to book status (7 cards)
        final bookProgressAdd = _findBestBookProgressAddition(
          bot,
          cardsToAddToMelds,
        );
        if (bookProgressAdd != null) {
          return BotDecision(action: 'addToMeld', data: bookProgressAdd);
        }
        // Fallback to any addition
        return BotDecision(action: 'addToMeld', data: cardsToAddToMelds.first);
      }

      // Priority 3: Create new melds that can become books
      final possibleMelds = _getPossibleMelds(bot, controller);
      if (possibleMelds.isNotEmpty) {
        final bookPotentialMeld = _findBestBookPotentialMeld(possibleMelds);
        return BotDecision(action: 'createMeld', data: bookPotentialMeld);
      }
    } else {
      // Can't complete books easily - hold cards and wait for better opportunities
      // Only add to melds if it directly helps with going out
      if (bot.currentHand.length <= 3) {
        final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
        if (cardsToAddToMelds.isNotEmpty) {
          return BotDecision(
            action: 'addToMeld',
            data: cardsToAddToMelds.first,
          );
        }
      }
    }

    // Emergency case - hand empty but can't go out
    if (bot.currentHand.isEmpty && !bot.canGoOut) {
      return BotDecision(action: 'error');
    }

    // Discard conservatively
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Execute a play-down sequence (single or multi-meld)
  BotDecision _executePlayDown(List<List<PlayingCard>> strategicPlayDown) {
    if (strategicPlayDown.length > 1) {
      // Set up multi-meld sequence
      _plannedMelds = List.from(strategicPlayDown);
      _currentMeldIndex = 1;
      _inMultiMeldSequence = true;
      return BotDecision(
        action: 'createMeld',
        data: strategicPlayDown.first,
        skipPlayDownCheck: true,
      );
    } else {
      // Single meld play-down
      return BotDecision(action: 'createMeld', data: strategicPlayDown.first);
    }
  }

  /// Find natural meld opportunities (no wild cards)
  List<List<PlayingCard>> _findNaturalMeldOpportunities(
    Player bot,
    List<List<PlayingCard>> possibleMelds,
  ) {
    final naturalMelds = <List<PlayingCard>>[];

    for (final meld in possibleMelds) {
      final hasWildCards = meld.any((card) => card.isWild);
      if (!hasWildCards) {
        naturalMelds.add(meld);
      }
    }

    // Sort by length (prefer longer natural melds)
    naturalMelds.sort((a, b) => b.length.compareTo(a.length));
    return naturalMelds;
  }

  /// Check if bot can play most of their remaining cards (reduced from 70% to 60%)
  bool _canPlayMostCards(Player bot, GameController controller) {
    final remainingCards = bot.currentHand.length;
    if (remainingCards <= 3) return true; // Few cards, try to use them

    // Count how many cards can be added to existing melds
    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
    final addableCards = cardsToAddToMelds.length;

    // Count cards in possible new melds
    final possibleMelds = controller.findPossibleMelds(bot);
    int meldableCards = 0;
    if (possibleMelds.isNotEmpty) {
      final bestMeld = _chooseLargestMeld(possibleMelds);
      meldableCards = bestMeld.length;
    }

    // Can we use 60%+ of remaining cards? (Less conservative than 70%)
    final usableCards = addableCards + meldableCards;
    return usableCards >= (remainingCards * mostCardsPlayableThreshold).floor();
  }

  /// Choose the meld that uses the most cards
  List<PlayingCard> _chooseLargestMeld(List<List<PlayingCard>> possibleMelds) {
    possibleMelds.sort((a, b) => b.length.compareTo(a.length));
    return possibleMelds.first;
  }

  /// Check if bot can complete the required clean and dirty books for going out
  bool _canCompleteRequiredBooks(Player bot, GameController controller) {
    int cleanBooks = 0;
    int dirtyBooks = 0;

    // Count existing books
    for (final meld in bot.melds) {
      if (meld.cards.length >= 7) {
        if (meld.isClean) {
          cleanBooks++;
        } else {
          dirtyBooks++;
        }
      }
    }

    // Check if we can potentially complete the missing books
    final needsCleanBook = cleanBooks == 0;
    final needsDirtyBook = dirtyBooks == 0;

    if (!needsCleanBook && !needsDirtyBook) {
      return true; // Already have required books
    }

    // Simple heuristic: if we have 5+ cards in hand and some melds close to books
    if (bot.currentHand.length >= 5) {
      final meldsCloseToBooks = bot.melds
          .where((m) => m.cards.length >= 5)
          .length;
      return meldsCloseToBooks > 0 ||
          _getPossibleMelds(bot, controller).isNotEmpty;
    }

    return false;
  }

  /// Try to complete books (7+ card melds)
  BotDecision? _tryCompleteBooks(Player bot, GameController controller) {
    // Look for melds that are close to becoming books (6 cards)
    for (int i = 0; i < bot.melds.length; i++) {
      final meld = bot.melds[i];
      if (meld.cards.length == 6) {
        // This meld is one card away from being a book - prioritize it
        for (final card in bot.currentHand) {
          if (meld.canAddCard(card)) {
            return BotDecision(
              action: 'addToMeld',
              data: {
                'meldIndex': i,
                'card': card,
                'priority': 1000, // High priority
              },
            );
          }
        }
      }
    }

    return null;
  }

  /// Find the best addition that progresses toward book completion
  Map<String, dynamic>? _findBestBookProgressAddition(
    Player bot,
    List<Map<String, dynamic>> cardsToAdd,
  ) {
    // Prioritize additions to melds that are closest to becoming books
    Map<String, dynamic>? bestAddition;
    int bestScore = -1;

    for (final addition in cardsToAdd) {
      final meldIndex = addition['meldIndex'] as int;
      final meld = bot.melds[meldIndex];

      // Score based on how close the meld is to becoming a book
      int score = meld.cards.length;
      if (meld.cards.length == 6) score += 100; // Almost a book!
      if (meld.cards.length >= 4) score += 50; // Good progress

      if (score > bestScore) {
        bestScore = score;
        bestAddition = addition;
      }
    }

    return bestAddition;
  }

  /// Find meld with best potential to become a book
  List<PlayingCard> _findBestBookPotentialMeld(
    List<List<PlayingCard>> possibleMelds,
  ) {
    // Prefer longer melds that are closer to book size (7 cards)
    possibleMelds.sort((a, b) {
      int scoreA = a.length;
      int scoreB = b.length;

      // Bonus for natural melds (cleaner books worth more points)
      if (!a.any((card) => card.isWild)) scoreA += 10;
      if (!b.any((card) => card.isWild)) scoreB += 10;

      return scoreB.compareTo(scoreA);
    });

    return possibleMelds.first;
  }

  /// Find the best natural meld combination that minimally meets the requirement
  List<List<PlayingCard>> _findBestNaturalMeldCombination(
    List<List<PlayingCard>> naturalMelds,
    int requirement,
  ) {
    if (naturalMelds.isEmpty) return [];

    // Try 2-meld combinations first (most common case)
    final twoCombination = _findTwoNaturalMeldCombination(
      naturalMelds,
      requirement,
    );
    if (twoCombination.isNotEmpty) return twoCombination;

    // Try 3-meld combinations if needed (less common)
    final threeCombination = _findThreeNaturalMeldCombination(
      naturalMelds,
      requirement,
    );
    if (threeCombination.isNotEmpty) return threeCombination;

    return [];
  }

  /// Find combination of exactly 2 natural melds that meets requirement with minimal excess
  List<List<PlayingCard>> _findTwoNaturalMeldCombination(
    List<List<PlayingCard>> naturalMelds,
    int requirement,
  ) {
    List<List<PlayingCard>> bestCombination = [];
    int closestPoints = requirement + 1000; // Start high

    for (int i = 0; i < naturalMelds.length; i++) {
      for (int j = i + 1; j < naturalMelds.length; j++) {
        final meld1 = naturalMelds[i];
        final meld2 = naturalMelds[j];

        // Check if the melds conflict (use same cards)
        if (_meldsConflict(meld1, meld2, 4)) continue; // Assume 4 decks

        final totalPoints =
            meld1.fold<int>(0, (sum, card) => sum + card.pointValue) +
            meld2.fold<int>(0, (sum, card) => sum + card.pointValue);

        if (totalPoints >= requirement && totalPoints < closestPoints) {
          closestPoints = totalPoints;
          // Return the combination with lower-point meld first (strategic)
          final points1 = meld1.fold<int>(
            0,
            (sum, card) => sum + card.pointValue,
          );
          final points2 = meld2.fold<int>(
            0,
            (sum, card) => sum + card.pointValue,
          );

          if (points1 <= points2) {
            bestCombination = [meld1, meld2];
          } else {
            bestCombination = [meld2, meld1];
          }
        }
      }
    }

    return bestCombination;
  }

  /// Find combination of exactly 3 natural melds that meets requirement
  List<List<PlayingCard>> _findThreeNaturalMeldCombination(
    List<List<PlayingCard>> naturalMelds,
    int requirement,
  ) {
    List<List<PlayingCard>> bestCombination = [];
    int closestPoints = requirement + 1000; // Start high

    for (int i = 0; i < naturalMelds.length; i++) {
      for (int j = i + 1; j < naturalMelds.length; j++) {
        for (int k = j + 1; k < naturalMelds.length; k++) {
          final meld1 = naturalMelds[i];
          final meld2 = naturalMelds[j];
          final meld3 = naturalMelds[k];

          // Check if any melds conflict
          if (_meldsConflict(meld1, meld2, 4) ||
              _meldsConflict(meld1, meld3, 4) ||
              _meldsConflict(meld2, meld3, 4)) {
            continue;
          }

          final totalPoints =
              meld1.fold<int>(0, (sum, card) => sum + card.pointValue) +
              meld2.fold<int>(0, (sum, card) => sum + card.pointValue) +
              meld3.fold<int>(0, (sum, card) => sum + card.pointValue);

          if (totalPoints >= requirement && totalPoints < closestPoints) {
            closestPoints = totalPoints;
            bestCombination = [meld1, meld2, meld3];
          }
        }
      }
    }

    return bestCombination;
  }

  /// Finds strategic multi-meld combinations for play-down that minimize points
  /// while retaining cards for discard pile unlocking opportunities
  List<List<PlayingCard>> _findStrategicPlayDown(
    Player bot,
    GameController controller,
    List<List<PlayingCard>> possibleMelds,
  ) {
    final playDownRequirement = controller.gameState.playDownRequirement;

    // Strategy: Find minimal point combinations that meet requirement
    // while maximizing cards kept for discard pile unlocking

    // Prefer natural melds over dirty melds
    final naturalMelds = _findNaturalMeldOpportunities(bot, possibleMelds);

    // Try natural melds first
    final naturalPlayDown = _findBestMeldCombination(
      naturalMelds,
      playDownRequirement,
      controller,
    );
    if (naturalPlayDown.isNotEmpty) {
      return naturalPlayDown;
    }

    // Fall back to mixed strategy if needed
    final bestCombination = _findBestMeldCombination(
      possibleMelds,
      playDownRequirement,
      controller,
    );

    return bestCombination;
  }

  /// Finds the best multi-meld combination that meets play-down requirement
  List<List<PlayingCard>> _findBestMeldCombination(
    List<List<PlayingCard>> possibleMelds,
    int requirement,
    GameController controller,
  ) {
    if (possibleMelds.isEmpty) return [];

    final deckCount = controller.gameState.players.length + 1;

    // Try 2-meld combinations first (most common case)
    final twoCombination = _findTwoMeldCombination(
      possibleMelds,
      requirement,
      deckCount,
    );
    if (twoCombination.isNotEmpty) return twoCombination;

    // Try 3-meld combinations if needed (less common)
    final threeCombination = _findThreeMeldCombination(
      possibleMelds,
      requirement,
      deckCount,
    );
    if (threeCombination.isNotEmpty) return threeCombination;

    // No valid combinations found
    return [];
  }

  /// Finds a combination of exactly 2 melds that meets the requirement
  List<List<PlayingCard>> _findTwoMeldCombination(
    List<List<PlayingCard>> possibleMelds,
    int requirement,
    int deckCount,
  ) {
    for (int i = 0; i < possibleMelds.length; i++) {
      for (int j = i + 1; j < possibleMelds.length; j++) {
        final meld1 = possibleMelds[i];
        final meld2 = possibleMelds[j];

        // Check if the melds conflict (use same cards)
        if (_meldsConflict(meld1, meld2, deckCount)) continue;

        final totalPoints =
            meld1.fold<int>(0, (sum, card) => sum + card.pointValue) +
            meld2.fold<int>(0, (sum, card) => sum + card.pointValue);

        if (totalPoints >= requirement) {
          // Return the combination with lower-point meld first (strategic)
          final points1 = meld1.fold<int>(
            0,
            (sum, card) => sum + card.pointValue,
          );
          final points2 = meld2.fold<int>(
            0,
            (sum, card) => sum + card.pointValue,
          );

          if (points1 <= points2) {
            return [meld1, meld2];
          } else {
            return [meld2, meld1];
          }
        }
      }
    }
    return [];
  }

  /// Finds a combination of exactly 3 melds that meets the requirement
  List<List<PlayingCard>> _findThreeMeldCombination(
    List<List<PlayingCard>> possibleMelds,
    int requirement,
    int deckCount,
  ) {
    for (int i = 0; i < possibleMelds.length; i++) {
      for (int j = i + 1; j < possibleMelds.length; j++) {
        for (int k = j + 1; k < possibleMelds.length; k++) {
          final meld1 = possibleMelds[i];
          final meld2 = possibleMelds[j];
          final meld3 = possibleMelds[k];

          // Check if any melds conflict
          if (_meldsConflict(meld1, meld2, deckCount) ||
              _meldsConflict(meld1, meld3, deckCount) ||
              _meldsConflict(meld2, meld3, deckCount)) {
            continue;
          }

          final totalPoints =
              meld1.fold<int>(0, (sum, card) => sum + card.pointValue) +
              meld2.fold<int>(0, (sum, card) => sum + card.pointValue) +
              meld3.fold<int>(0, (sum, card) => sum + card.pointValue);

          if (totalPoints >= requirement) {
            return [meld1, meld2, meld3];
          }
        }
      }
    }
    return [];
  }

  /// Checks if two melds conflict (use same cards)
  bool _meldsConflict(
    List<PlayingCard> meld1,
    List<PlayingCard> meld2,
    int deckCount,
  ) {
    // Create a map to count cards by rank+suit for each meld
    final meld1Cards = <String, int>{};
    final meld2Cards = <String, int>{};

    for (final card in meld1) {
      final key = '${card.rank.name}-${card.suit?.name ?? 'joker'}';
      meld1Cards[key] = (meld1Cards[key] ?? 0) + 1;
    }

    for (final card in meld2) {
      final key = '${card.rank.name}-${card.suit?.name ?? 'joker'}';
      meld2Cards[key] = (meld2Cards[key] ?? 0) + 1;
    }

    // Check if any card type would be over-used
    for (final entry in meld1Cards.entries) {
      final meld2Count = meld2Cards[entry.key] ?? 0;
      if (meld2Count > 0) {
        final totalNeeded = entry.value + meld2Count;

        // Determine max available cards for this rank+suit
        // Hand & Foot uses (players + 1) decks, each with standard card counts
        int maxAvailable;
        if (entry.key.contains('joker')) {
          maxAvailable = 2 * deckCount; // 2 jokers per standard deck
        } else {
          maxAvailable =
              4 * deckCount; // 4 cards per rank per deck (one per suit)
        }

        if (totalNeeded > maxAvailable) {
          return true; // Would exceed available cards
        }
      }
    }

    return false; // No conflicts detected
  }
}
