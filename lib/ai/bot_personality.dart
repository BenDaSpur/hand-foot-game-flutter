import 'package:flutter/foundation.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../config/game_config.dart';

/// Bot personality types that influence strategic decision-making
enum BotPersonality {
  /// Cautious play, holds cards longer, minimal risks
  conservative,

  /// Quick play-downs, frequent discard pile unlocks, high risks
  aggressive,

  /// Focuses on completing books for maximum points
  bookBuilder,

  /// Switches strategy based on game state and opponents
  adaptive,
}

/// Configuration constants for different bot personalities
class PersonalityConstants {
  final int strategicBufferPoints;
  final int minCardsForAggressiveUnlock;
  final int valuablePileThreshold;
  final int largePileThreshold;
  final int footPileValueThreshold;
  final int footPileSizeThreshold;
  final int handPileValueThreshold;
  final int handPileSizeThreshold;
  final int maxTurnsBeforeForcePlayDown;
  final double highValuePairBreakChance;
  final int bookCompletionPriority;
  final double aggressivenessMultiplier;

  const PersonalityConstants({
    required this.strategicBufferPoints,
    required this.minCardsForAggressiveUnlock,
    required this.valuablePileThreshold,
    required this.largePileThreshold,
    required this.footPileValueThreshold,
    required this.footPileSizeThreshold,
    required this.handPileValueThreshold,
    required this.handPileSizeThreshold,
    required this.maxTurnsBeforeForcePlayDown,
    required this.highValuePairBreakChance,
    required this.bookCompletionPriority,
    required this.aggressivenessMultiplier,
  });

  /// Get personality-based constants
  static PersonalityConstants forPersonality(BotPersonality personality) {
    switch (personality) {
      case BotPersonality.conservative:
        return const PersonalityConstants(
          strategicBufferPoints:
              10, // REDUCED - more aggressive competitiveness
          minCardsForAggressiveUnlock:
              3, // Reduced from 4 - more willing to unlock
          valuablePileThreshold:
              100, // Reduced from 140 - more aggressive pile taking
          largePileThreshold: 6, // Reduced from 8 - lower threshold
          footPileValueThreshold:
              50, // Reduced from 70 - more aggressive in foot
          footPileSizeThreshold:
              5, // Reduced from 7 - more willing to take smaller piles
          handPileValueThreshold:
              50, // REDUCED further - much more aggressive pile taking
          handPileSizeThreshold: 7, // Reduced from 9 - lower threshold
          maxTurnsBeforeForcePlayDown:
              4, // REDUCED - prevent catastrophic hand accumulation
          highValuePairBreakChance:
              0.25, // Increased from 0.15 - more willing to break pairs
          bookCompletionPriority: 200, // Keep high priority for books
          aggressivenessMultiplier:
              0.8, // Increased from 0.7 - less conservative
        );
      case BotPersonality.aggressive:
        return const PersonalityConstants(
          strategicBufferPoints:
              5, // Keep low - but allow patience for bigger plays
          minCardsForAggressiveUnlock: 2, // Keep at 2 - very willing to unlock
          valuablePileThreshold:
              50, // Reduced from 70 - take even smaller piles
          largePileThreshold: 3, // Reduced from 4 - very low threshold
          footPileValueThreshold:
              25, // Reduced from 35 - extremely aggressive in foot
          footPileSizeThreshold: 2, // Reduced from 3 - take almost any pile
          handPileValueThreshold:
              25, // REDUCED further - take almost any valuable pile
          handPileSizeThreshold: 3, // Reduced from 4 - very low threshold
          maxTurnsBeforeForcePlayDown:
              1, // SUPER AGGRESSIVE - counter human accumulation with speed strikes
          highValuePairBreakChance:
              0.8, // Increased from 0.7 - almost always break pairs
          bookCompletionPriority:
              80, // Reduced from 100 - prioritize speed over books
          aggressivenessMultiplier:
              1.6, // Increased from 1.4 - much more aggressive
        );
      case BotPersonality.bookBuilder:
        return const PersonalityConstants(
          strategicBufferPoints:
              15, // Reduced from 25 - less conservative waiting
          minCardsForAggressiveUnlock: 3, // Keep at 3 - balanced approach
          valuablePileThreshold:
              80, // Reduced from 100 - more willing to take piles for books
          largePileThreshold:
              5, // Reduced from 6 - lower threshold for book building
          footPileValueThreshold:
              40, // Reduced from 50 - more aggressive in foot for books
          footPileSizeThreshold:
              4, // Reduced from 5 - take smaller piles for book cards
          handPileValueThreshold:
              60, // Reduced from 75 - more aggressive in hand for books
          handPileSizeThreshold: 5, // Reduced from 6 - lower threshold
          maxTurnsBeforeForcePlayDown:
              5, // REDUCED - prevent excessive accumulation even for books
          highValuePairBreakChance:
              0.4, // Increased from 0.3 - more willing to break for books
          bookCompletionPriority:
              250, // Reduced from 300 - still high but more balanced
          aggressivenessMultiplier:
              1.2, // Increased from 1.0 - more aggressive about books
        );
      case BotPersonality.adaptive:
        return const PersonalityConstants(
          strategicBufferPoints:
              15, // Reduced from 20 - more competitive baseline
          minCardsForAggressiveUnlock: 3, // Keep at 3 - good balance
          valuablePileThreshold:
              75, // Reduced from 100 - more willing to take piles
          largePileThreshold: 5, // Reduced from 6 - lower threshold
          footPileValueThreshold:
              40, // Reduced from 50 - more aggressive in foot
          footPileSizeThreshold: 4, // Reduced from 5 - take smaller piles
          handPileValueThreshold:
              60, // Reduced from 75 - more aggressive in hand
          handPileSizeThreshold: 5, // Reduced from 6 - lower threshold
          maxTurnsBeforeForcePlayDown:
              4, // MODERATE - situational speed (will be overridden by adaptive logic)
          highValuePairBreakChance:
              0.6, // Increased from 0.5 - more willing to break pairs
          bookCompletionPriority: 150, // Keep balanced priority
          aggressivenessMultiplier:
              1.1, // Increased from 1.0 - slightly more aggressive baseline
        );
    }
  }
}

/// Manages bot personality assignment and behavior modification
class BotPersonalityManager {
  // Per-player personality assignments
  final Map<String, BotPersonality> _playerPersonalities = {};
  final Map<String, PersonalityConstants> _playerConstants = {};

  // Current player context cache
  PersonalityConstants? _currentConstants;
  String? _currentPlayerId;

  BotPersonalityManager();

  /// Assign a personality to a specific bot player
  void assignPersonality(String playerId, BotPersonality personality) {
    _playerPersonalities[playerId] = personality;
    _playerConstants[playerId] = PersonalityConstants.forPersonality(
      personality,
    );
  }

  /// Get personality for a specific player (defaults to adaptive)
  BotPersonality getPersonality(String playerId) {
    return _playerPersonalities[playerId] ?? BotPersonality.adaptive;
  }

  /// Get constants for a specific player (defaults to adaptive)
  PersonalityConstants getConstants(String playerId) {
    return _playerConstants[playerId] ??
        PersonalityConstants.forPersonality(BotPersonality.adaptive);
  }

  /// Set current player context for this decision cycle
  void setCurrentPlayerContext(String playerId) {
    _currentPlayerId = playerId;
    _currentConstants = getConstants(playerId);
  }

  /// Get current player's constants (must call setCurrentPlayerContext first)
  PersonalityConstants get currentConstants {
    if (_currentConstants == null) {
      // Log the issue but don't throw assertions that could break gameplay
      print(
        'WARNING: BotPersonalityManager - accessing currentConstants without context, falling back to Adaptive',
      );

      // In debug mode, also show an assertion (but don't fail)
      assert(() {
        print(
          'DEBUG: BotPersonalityManager context issue - setCurrentPlayerContext() should be called first',
        );
        return true;
      }());

      return PersonalityConstants.forPersonality(BotPersonality.adaptive);
    }
    return _currentConstants!;
  }

  /// Get current player's personality
  BotPersonality get currentPersonality {
    if (_currentPlayerId == null) {
      // Log the issue but don't throw assertions that could break gameplay
      print(
        'WARNING: BotPersonalityManager - accessing currentPersonality without context, falling back to Adaptive',
      );

      // In debug mode, also show an assertion (but don't fail)
      assert(() {
        print(
          'DEBUG: BotPersonalityManager context issue - setCurrentPlayerContext() should be called first',
        );
        return true;
      }());

      return BotPersonality.adaptive;
    }
    return getPersonality(_currentPlayerId!);
  }

  /// Calculate risk tolerance based on personality and game state
  double calculateRiskTolerance(GameState gameState, Player botPlayer) {
    final personality = getPersonality(botPlayer.id);
    final constants = getConstants(botPlayer.id);

    // Base risk tolerance from personality - increased for all personalities
    double baseRisk =
        constants.aggressivenessMultiplier *
        1.2; // 20% more aggressive baseline
    double riskModifier = 1.0;

    // 1. Score position pressure - enhanced for competitiveness
    final scores = gameState.players.map((p) => p.score).toList()..sort();
    final botScore = botPlayer.score;
    final isLeading = botScore == scores.last;
    final isFarBehind = botScore < (scores.first + scores.last) / 2;

    if (isLeading && personality == BotPersonality.conservative) {
      riskModifier *= 0.8; // Less conservative than before (was 0.7)
    } else if (isFarBehind) {
      riskModifier *= 1.8; // Much more aggressive when behind (was 1.5)
    }

    // 2. Enhanced opponent threat assessment - more sensitive to danger
    final dangerousOpponents = gameState.players
        .where(
          (p) =>
              p.id != botPlayer.id &&
              p.hasPickedUpFoot &&
              p.currentHand.length <= 7, // Expanded danger threshold
        )
        .length;

    if (dangerousOpponents > 0) {
      riskModifier *=
          (1.0 +
          dangerousOpponents *
              0.4); // More aggressive when threatened (was 0.3)
    }

    // 3. Turn pressure (would need turn tracking)
    // This would require turn count tracking from game analyzer

    // 4. Enhanced hand quality assessment - more competitive
    final handQuality = _assessHandQuality(botPlayer);
    if (handQuality > 0.7) {
      riskModifier *= 0.85; // Less patient than before (was 0.8)
    } else if (handQuality < 0.4) {
      riskModifier *= 1.6; // Much more aggressive with poor hands (was 1.4)
    }

    // 5. Book completion opportunity - balanced for competitiveness
    if (personality == BotPersonality.bookBuilder) {
      final nearBooks = botPlayer.melds
          .where((m) => m.cards.length >= 6)
          .length;
      if (nearBooks > 0) {
        riskModifier *= 0.7; // Less conservative than before (was 0.6)
      }
    }

    // 6. Foot transition considerations - more aggressive
    if (botPlayer.hasPickedUpFoot && botPlayer.currentHand.length <= 5) {
      riskModifier *= 1.8; // Much more aggressive in endgame (was 1.5)
    }

    // 7. Round pressure - new enhancement for competitiveness
    if (gameState.round >= 3) {
      riskModifier *= 1.3; // Much more aggressive in later rounds
    }

    // Apply adaptive personality modifications
    if (personality == BotPersonality.adaptive) {
      riskModifier *= _calculateAdaptiveModifier(gameState, botPlayer);
    }

    // Cap risk tolerance at higher bounds for more competitive play
    final finalRisk = (baseRisk * riskModifier).clamp(
      0.4,
      4.0,
    ); // Increased upper bound

    // Log extreme risk tolerance for monitoring
    if (finalRisk > 3.0) {
      _logExtremeRiskTolerance(botPlayer, finalRisk, gameState);
    }

    return finalRisk;
  }

  /// Calculate adaptive personality modifier based on game state
  double _calculateAdaptiveModifier(GameState gameState, Player botPlayer) {
    double modifier = 1.0;

    // Adapt based on round
    if (gameState.round >= GameConfig.lateGameRound) {
      modifier *= 1.2; // More aggressive in later rounds
    }

    // Adapt based on relative position
    final playersAhead = gameState.players
        .where(
          (p) =>
              p.id != botPlayer.id &&
              ((p.hasPlayedDown && !botPlayer.hasPlayedDown) ||
                  (p.hasPickedUpFoot && !botPlayer.hasPickedUpFoot)),
        )
        .length;

    if (playersAhead > 0) {
      modifier *= (1.0 + playersAhead * 0.15); // More aggressive when behind
    }

    return modifier;
  }

  /// Assess hand quality (0.0 to 1.0)
  double _assessHandQuality(Player player) {
    if (player.currentHand.isEmpty) return 0.0;

    final hand = player.currentHand;
    double qualityScore = 0.0;
    final rankCounts = <String, int>{};

    for (final card in hand) {
      rankCounts[card.rank.name] = (rankCounts[card.rank.name] ?? 0) + 1;

      if (card.isWild) {
        qualityScore += 0.15; // Wilds are very valuable
      } else if (card.rank.index >= 10) {
        // Jack, Queen, King, Ace
        qualityScore += 0.08; // High ranks are good
      } else {
        qualityScore += 0.02; // Basic value
      }
    }

    // Bonus for potential melds
    for (final count in rankCounts.values) {
      if (count >= GameConfig.minTotalCardsForMeld) {
        qualityScore += 0.1; // Strong meld potential
      } else if (count >= 2) {
        qualityScore += 0.05; // Some meld potential
      }
    }

    return (qualityScore / hand.length).clamp(0.0, 1.0);
  }

  /// Check if personality should modify discard pile evaluation
  bool shouldBeMoreConservativeWithDiscardPile(String playerId) {
    final personality = getPersonality(playerId);
    return personality == BotPersonality.conservative ||
        personality == BotPersonality.bookBuilder;
  }

  /// Check if personality should prioritize book completion
  bool shouldPrioritizeBookCompletion(String playerId) {
    final personality = getPersonality(playerId);
    return personality == BotPersonality.bookBuilder;
  }

  /// Get personality-specific play-down threshold modifier
  double getPlayDownThresholdModifier(String playerId) {
    final personality = getPersonality(playerId);
    switch (personality) {
      case BotPersonality.aggressive:
        return 0.8; // Play down with 20% less points
      case BotPersonality.conservative:
        return 1.3; // Need 30% more points
      case BotPersonality.bookBuilder:
        return 1.1; // Slightly more conservative
      case BotPersonality.adaptive:
        return 1.0; // Standard threshold
    }
  }

  /// Clear all personality data (call when game ends)
  void clearPersonalityData() {
    _playerPersonalities.clear();
    _playerConstants.clear();
    _currentConstants = null;
    _currentPlayerId = null;
  }

  /// Auto-assign random personalities to bot players
  void assignRandomPersonalities(List<Player> botPlayers) {
    final personalities = BotPersonality.values;

    for (final player in botPlayers) {
      if (player.type == PlayerType.bot) {
        // Use hash-based deterministic assignment for consistency across game sessions
        // Player IDs are typically sequential ('1', '2', '3') so hash collisions are unlikely
        // and this provides good distribution across personality types
        final randomPersonality =
            personalities[(player.id.hashCode % personalities.length)];
        assignPersonality(player.id, randomPersonality);

        // Log assignment for debugging
        print(
          'BotPersonalityManager: Assigned ${randomPersonality.name} to bot ${player.name} (${player.id})',
        );
      }
    }
  }

  /// Get personality description for UI/debugging
  String getPersonalityDescription(BotPersonality personality) {
    switch (personality) {
      case BotPersonality.conservative:
        return 'Cautious player who holds cards longer and takes minimal risks';
      case BotPersonality.aggressive:
        return 'Bold player who plays down quickly and takes high risks';
      case BotPersonality.bookBuilder:
        return 'Strategic player focused on completing books for maximum points';
      case BotPersonality.adaptive:
        return 'Flexible player who adapts strategy based on game situation';
    }
  }

  /// Get all assigned personalities for debugging
  Map<String, BotPersonality> getAllAssignedPersonalities() {
    return Map.from(_playerPersonalities);
  }

  /// Log extreme risk tolerance events for monitoring
  void _logExtremeRiskTolerance(
    Player botPlayer,
    double riskTolerance,
    GameState gameState,
  ) {
    if (kDebugMode) {
      print(
        'EXTREME RISK: Bot ${botPlayer.name} (${getPersonality(botPlayer.id).name}) '
        'has risk tolerance of ${riskTolerance.toStringAsFixed(2)} '
        '(Round ${gameState.round}, Score: ${botPlayer.score})',
      );
    }

    // Could also log to analytics for tracking extreme decisions
    // GameAnalyticsLogger.logGameEvent(...) if needed
  }
}
