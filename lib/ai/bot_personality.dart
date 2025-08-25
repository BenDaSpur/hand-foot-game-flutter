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
          strategicBufferPoints: 30, // +50% buffer
          minCardsForAggressiveUnlock: 4, // Need more cards
          valuablePileThreshold: 140, // +40% threshold
          largePileThreshold: 8, // +33% threshold
          footPileValueThreshold: 70, // +40% threshold
          footPileSizeThreshold: 7, // +40% threshold
          handPileValueThreshold: 105, // +40% threshold
          handPileSizeThreshold: 9, // +50% threshold
          maxTurnsBeforeForcePlayDown: 6, // +20% more turns
          highValuePairBreakChance: 0.15, // 70% less likely
          bookCompletionPriority: 200, // Higher priority for books
          aggressivenessMultiplier: 0.7, // 30% less aggressive
        );
      case BotPersonality.aggressive:
        return const PersonalityConstants(
          strategicBufferPoints: 10, // 50% less buffer
          minCardsForAggressiveUnlock: 2, // Need fewer cards
          valuablePileThreshold: 70, // 30% lower threshold
          largePileThreshold: 4, // 33% lower threshold
          footPileValueThreshold: 35, // 30% lower threshold
          footPileSizeThreshold: 3, // 40% lower threshold
          handPileValueThreshold: 45, // 40% lower threshold
          handPileSizeThreshold: 4, // 33% lower threshold
          maxTurnsBeforeForcePlayDown: 3, // 40% fewer turns
          highValuePairBreakChance: 0.7, // 40% more likely
          bookCompletionPriority: 100, // Standard priority
          aggressivenessMultiplier: 1.4, // 40% more aggressive
        );
      case BotPersonality.bookBuilder:
        return const PersonalityConstants(
          strategicBufferPoints: 25, // Moderate buffer
          minCardsForAggressiveUnlock: 3, // Standard
          valuablePileThreshold: 100, // Standard
          largePileThreshold: 6, // Standard
          footPileValueThreshold: 50, // Standard
          footPileSizeThreshold: 5, // Standard
          handPileValueThreshold: 75, // Standard
          handPileSizeThreshold: 6, // Standard
          maxTurnsBeforeForcePlayDown: 6, // More patient for books
          highValuePairBreakChance: 0.3, // Moderate
          bookCompletionPriority: 300, // Very high priority
          aggressivenessMultiplier: 1.0, // Standard aggression
        );
      case BotPersonality.adaptive:
        return const PersonalityConstants(
          strategicBufferPoints: 20, // Standard (will be modified dynamically)
          minCardsForAggressiveUnlock: 3, // Standard
          valuablePileThreshold: 100, // Standard
          largePileThreshold: 6, // Standard
          footPileValueThreshold: 50, // Standard
          footPileSizeThreshold: 5, // Standard
          handPileValueThreshold: 75, // Standard
          handPileSizeThreshold: 6, // Standard
          maxTurnsBeforeForcePlayDown: 5, // Standard
          highValuePairBreakChance: 0.5, // Standard
          bookCompletionPriority: 150, // Standard
          aggressivenessMultiplier: 1.0, // Will be modified dynamically
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

    // Base risk tolerance from personality
    double baseRisk = constants.aggressivenessMultiplier;
    double riskModifier = 1.0;

    // 1. Score position pressure
    final scores = gameState.players.map((p) => p.score).toList()..sort();
    final botScore = botPlayer.score;
    final isLeading = botScore == scores.last;
    final isFarBehind = botScore < (scores.first + scores.last) / 2;

    if (isLeading && personality == BotPersonality.conservative) {
      riskModifier *= 0.7; // Play even more conservatively when leading
    } else if (isFarBehind) {
      riskModifier *= 1.5; // Take more risks when behind
    }

    // 2. Opponent threat assessment
    final dangerousOpponents = gameState.players
        .where(
          (p) =>
              p.id != botPlayer.id &&
              p.hasPickedUpFoot &&
              p.currentHand.length <= 5,
        )
        .length;

    if (dangerousOpponents > 0) {
      riskModifier *=
          (1.0 + dangerousOpponents * 0.3); // More aggressive when threatened
    }

    // 3. Turn pressure (would need turn tracking)
    // This would require turn count tracking from game analyzer

    // 4. Hand quality assessment
    final handQuality = _assessHandQuality(botPlayer);
    if (handQuality > 0.7) {
      riskModifier *= 0.8; // Good hand, can be patient
    } else if (handQuality < 0.4) {
      riskModifier *= 1.4; // Poor hand, need to take chances
    }

    // 5. Book completion opportunity (for book builders)
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

    // Apply adaptive personality modifications
    if (personality == BotPersonality.adaptive) {
      riskModifier *= _calculateAdaptiveModifier(gameState, botPlayer);
    }

    // Cap risk tolerance at reasonable bounds
    final finalRisk = (baseRisk * riskModifier).clamp(0.3, 3.0);
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
}
