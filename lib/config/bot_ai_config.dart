import '../ai/bot_personality.dart';
import 'game_config.dart';

/// Configuration constants for Bot AI behavior and gameplay tuning.
///
/// This file centralizes all bot AI constants to enable easy gameplay balancing
/// and potential runtime configuration. Constants are organized by functional area
/// and include detailed documentation about their gameplay impact.
///
/// For core game rule constants (scoring, meld requirements, etc.), see GameConfig.
class BotAIConfig {
  // =============================================================================
  // STRATEGIC DECISION CONSTANTS
  // =============================================================================

  /// Maximum turns bot will wait before forcing play-down (prevents infinite holding)
  /// Lower = more aggressive play-down, Higher = more strategic waiting
  /// Recommended range: 3-7 turns
  static const int maxTurnsBeforeForcePlayDown = 5;

  /// Points above requirement needed for comfortable play-down
  /// Lower = more aggressive, Higher = more conservative
  /// Recommended range: 5-20 points
  static const int strongPlayDownBuffer = 10;

  /// Number of wild cards before bot considers discarding them
  /// Lower = more conservative with wilds, Higher = more willing to hoard
  /// Recommended range: 8-15 cards
  static const int wildCardDiscardThreshold = 10;

  // =============================================================================
  // RISK MANAGEMENT CONSTANTS
  // =============================================================================

  /// Base risk tolerance for normal situations
  /// Lower = more conservative decisions, Higher = more aggressive
  /// Recommended range: 1.5-3.0
  static const double emergencyRiskTolerance = 2.0;

  /// Maximum risk tolerance in desperate situations
  /// Higher allows more desperate plays when behind
  /// Recommended range: 4.0-8.0
  static const double maxEmergencyRiskTolerance = 6.0;

  // =============================================================================
  // PERSONALITY MULTIPLIERS
  // =============================================================================

  /// Gets personality constants for a specific bot personality type
  static PersonalityConstants getPersonalityConstants(
    BotPersonality personality,
  ) {
    switch (personality) {
      case BotPersonality.conservative:
        return const PersonalityConstants(
          bufferMultiplier: 1.3, // +30% safety buffer
          riskTolerance: 0.7, // -30% risk taking
          discardPileThreshold: 1.5, // +50% more cautious with discard pile
          playDownModifier: 1.2, // +20% higher play-down requirement
        );
      case BotPersonality.aggressive:
        return const PersonalityConstants(
          bufferMultiplier: 0.5, // -50% safety buffer
          riskTolerance: 1.4, // +40% risk taking
          discardPileThreshold: 0.6, // -40% more willing to take pile
          playDownModifier: 0.8, // -20% lower play-down requirement
        );
      case BotPersonality.bookBuilder:
        return const PersonalityConstants(
          bufferMultiplier: 1.0, // Standard buffer
          riskTolerance: 1.1, // +10% risk for book building
          discardPileThreshold: 0.8, // -20% more selective with pile
          playDownModifier: 0.9, // -10% lower requirement for book focus
          bookCompletionBonus: 2.0, // +100% priority for completing books
        );
      case BotPersonality.adaptive:
        return const PersonalityConstants(
          bufferMultiplier: 1.0, // Baseline - adapts based on game state
          riskTolerance: 1.0, // Baseline - adapts based on situation
          discardPileThreshold: 1.0, // Baseline - adapts based on opponents
          playDownModifier: 1.0, // Baseline - adapts based on round
          adaptiveScaling: true, // Enables dynamic adjustment
        );
    }
  }

  // =============================================================================
  // FOOT TRANSITION CONSTANTS
  // =============================================================================

  /// Hand size that triggers aggressive foot transition
  /// Lower = transitions earlier, Higher = holds hand longer
  /// Recommended range: 3-6 cards
  static const int aggressiveFootTransitionThreshold = 4;

  /// Hand size that creates pressure to transition
  /// Prevents getting stuck with too many cards
  /// Recommended range: 6-10 cards
  static const int handSizePressureThreshold = 7;

  /// Round number when late-game transition strategy kicks in
  /// Later rounds should be more aggressive about transitioning
  /// Recommended range: 2-4 rounds
  static const int lateRoundTransitionRound = 3;

  // =============================================================================
  // END GAME CONSTANTS
  // =============================================================================

  /// Hand size considered "winning position" for end game
  /// Small enough to go out quickly but flexible for final plays
  /// Recommended range: 3-6 cards
  static const int winningPositionHandSize = 4;

  // Note: Book size and bonuses are defined in GameConfig to ensure consistency

  /// Helper methods to access GameConfig constants with bot AI context
  static int get bookMinSize => GameConfig.bookSize;
  static int get cleanBookBonus => GameConfig.cleanBookBonus;
  static int get dirtyBookBonus => GameConfig.dirtyBookBonus;

  // =============================================================================
  // PERFORMANCE TUNING
  // =============================================================================

  /// Maximum melds to analyze for play-down combinations
  /// Higher = better decisions but slower performance
  /// Recommended range: 8-15 combinations
  static const int maxMeldCombinationsToAnalyze = 12;

  /// Cache timeout for meld analysis (in turns)
  /// Higher = better performance but potentially stale decisions
  /// Recommended range: 1-3 turns
  static const int meldAnalysisCacheTurns = 2;

  // =============================================================================
  // DEBUGGING & DEVELOPMENT
  // =============================================================================

  /// Enable detailed logging for bot decision making
  /// Should be false in production for performance
  static const bool enableDetailedLogging = false;

  /// Enable decision timing metrics
  /// Useful for performance analysis during development
  static const bool enablePerformanceMetrics = false;

  // =============================================================================
  // VALIDATION
  // =============================================================================

  /// Validates that all configuration values are within reasonable ranges
  static void validateConfiguration() {
    assert(
      maxTurnsBeforeForcePlayDown >= 3 && maxTurnsBeforeForcePlayDown <= 10,
      'maxTurnsBeforeForcePlayDown should be between 3-10 turns',
    );

    assert(
      wildCardDiscardThreshold >= 5 && wildCardDiscardThreshold <= 20,
      'wildCardDiscardThreshold should be between 5-20 cards',
    );

    assert(
      emergencyRiskTolerance >= 1.0 && emergencyRiskTolerance <= 5.0,
      'emergencyRiskTolerance should be between 1.0-5.0',
    );

    assert(
      winningPositionHandSize >= 2 && winningPositionHandSize <= 8,
      'winningPositionHandSize should be between 2-8 cards',
    );

    // Validate consistency with GameConfig
    assert(
      bookMinSize == GameConfig.bookSize,
      'BotAIConfig bookMinSize must match GameConfig.bookSize',
    );
    assert(
      cleanBookBonus == GameConfig.cleanBookBonus,
      'BotAIConfig cleanBookBonus must match GameConfig.cleanBookBonus',
    );
  }
}

/// Constants for individual bot personality types
class PersonalityConstants {
  final double bufferMultiplier;
  final double riskTolerance;
  final double discardPileThreshold;
  final double playDownModifier;
  final double bookCompletionBonus;
  final bool adaptiveScaling;

  const PersonalityConstants({
    required this.bufferMultiplier,
    required this.riskTolerance,
    required this.discardPileThreshold,
    required this.playDownModifier,
    this.bookCompletionBonus = 1.0,
    this.adaptiveScaling = false,
  });
}

/// Difficulty presets for different player skill levels
///
/// These presets modify the base constants to create different challenge levels
/// for players of varying skill levels. Each preset represents a complete
/// configuration optimized for a specific difficulty.
class DifficultyPresets {
  /// Beginner-friendly bot configuration
  /// - Quicker decisions (less strategic waiting)
  /// - Less wild card hoarding
  /// - More conservative risk-taking
  static const Map<String, dynamic> beginner = {
    'maxTurnsBeforeForcePlayDown': 3,
    'wildCardDiscardThreshold': 8,
    'emergencyRiskTolerance': 1.5,
    'personalityModifier': 0.8, // Reduce personality extremes
  };

  /// Intermediate bot configuration (default balanced gameplay)
  static const Map<String, dynamic> intermediate = {
    'maxTurnsBeforeForcePlayDown': 5,
    'wildCardDiscardThreshold': 10,
    'emergencyRiskTolerance': 2.0,
    'personalityModifier': 1.0, // Standard personality effects
  };

  /// Expert bot configuration
  /// - More patient and strategic decisions
  /// - Better wild card management
  /// - Higher calculated risk tolerance
  static const Map<String, dynamic> expert = {
    'maxTurnsBeforeForcePlayDown': 7,
    'wildCardDiscardThreshold': 12,
    'emergencyRiskTolerance': 2.5,
    'personalityModifier': 1.2, // Enhance personality differences
  };

  /// Gets the configuration value for a specific difficulty and setting
  static T getConfigValue<T>(
    String difficulty,
    String setting,
    T defaultValue,
  ) {
    final config = _getConfig(difficulty);
    return config[setting] as T? ?? defaultValue;
  }

  static Map<String, dynamic> _getConfig(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return beginner;
      case 'expert':
        return expert;
      case 'intermediate':
      default:
        return intermediate;
    }
  }
}
