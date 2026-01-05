/// Centralized configuration for bot AI behavior.
///
/// This class consolidates all magic numbers and thresholds used by the bot AI
/// into a single location for easy tuning and consistency.
class BotConfig {
  // ===== HAND SIZE THRESHOLDS =====

  /// Hand size at which emergency protocols activate (force melding)
  static const int emergencyHandSizeThreshold = 15;

  /// Critical hand size - panic mode, any meld is better than none
  static const int criticalHandSizeThreshold = 18;

  /// Hand size threshold to force play-down
  static const int playDownEmergencyThreshold = 14;

  /// Minimum turns before emergency protocols can activate
  static const int minTurnsForEmergency = 4;

  /// When opponent hand size exceeds ours by this much, apply pressure
  static const int competitiveThreatHandSizeGap = 15;

  // ===== FOOT TRANSITION THRESHOLDS =====

  /// Trigger aggressive foot transition at this card count
  static const int aggressiveFootTransitionThreshold = 10;

  /// Start pressure to transition when hand reaches this size
  static const int handSizePressureThreshold = 12;

  /// Emergency transition at this card count
  static const int emergencyTransitionThreshold = 8;

  /// Emergency at this large hand size
  static const int largeHandEmergencyThreshold = 10;

  /// Transition threshold after play-down
  static const int postPlaydownTransitionThreshold = 8;

  // ===== PLAY-DOWN STRATEGY =====

  /// Maximum turns to wait before forcing play-down
  static const int maxTurnsBeforeForcePlayDown = 4;

  /// Buffer points to add when evaluating play-down timing
  static const int strongPlayDownBuffer = 5;

  // ===== DISCARD PILE EVALUATION =====

  /// Multiplier for aggressive discard pile evaluation
  static const double aggressiveDiscardMultiplier = 0.8;

  /// Multiplier for competitive discard pile evaluation
  static const double competitiveDiscardMultiplier = 0.6;

  /// Multiplier for defensive discard pile evaluation
  static const double defensiveDiscardMultiplier = 0.7;

  /// Minimum cards in discard pile to consider taking
  static const int minimumDiscardPileSize = 2;

  /// In foot phase, become urgent about discards at this threshold
  static const int footPhaseUrgencyThreshold = 5;

  // ===== WILD CARD MANAGEMENT =====

  /// Threshold to consider discarding wild cards
  static const int wildCardDiscardThreshold = 8;

  /// Number of wilds considered excessive (affects strategy)
  static const int excessiveWildsThreshold = 6;

  // ===== RISK TOLERANCE =====

  /// Emergency risk tolerance ceiling
  static const double emergencyRiskTolerance = 1.8;

  /// Maximum emergency risk tolerance
  static const double maxEmergencyRiskTolerance = 6.0;

  // ===== MELD EVALUATION =====

  /// Minimum meld size
  static const int minMeldSize = 3;

  /// Weak meld point threshold
  static const int weakMeldThreshold = 50;

  /// Strong meld point threshold
  static const int strongMeldThreshold = 100;

  /// Cards needed for a book
  static const int bookSize = 7;

  /// Bonus points for clean melds
  static const int cleanMeldBonus = 50;

  /// Bonus for book progress
  static const int bookProgressBonus = 30;

  // ===== END GAME =====

  /// Winning position hand size threshold
  static const int winningPositionHandSize = 6;

  /// Aggressive go-out hand size under pressure
  static const int aggressiveGoOutHandSize = 8;

  /// Clean book bonus points
  static const int cleanBookBonus = 500;

  /// Dirty book bonus points
  static const int dirtyBookBonus = 300;

  /// Clean book completion priority
  static const int cleanBookCompletionPriority = 2000;

  /// Dirty book completion priority
  static const int dirtyBookCompletionPriority = 1500;

  /// Clean meld protection bonus
  static const int cleanMeldProtectionBonus = 1000;

  /// Wild penalty for clean melds
  static const int wildPenaltyForCleanMeld = 500;

  /// Oversized book penalty
  static const int oversizedBookPenalty = 100;

  /// Excessive wild penalty
  static const int excessiveWildPenalty = 200;

  // ===== OPPONENT ANALYSIS =====

  /// Dangerous opponent threshold (turns to win)
  static const int dangerousTurnThreshold = 2;

  /// Near-book threshold (cards in meld)
  static const int nearBookThreshold = 6;

  /// High hand quality threshold (0.0-1.0)
  static const double highHandQualityThreshold = 0.7;

  /// Low hand quality threshold (0.0-1.0)
  static const double lowHandQualityThreshold = 0.4;

  /// Emergency hand size for analyzer
  static const int analyzerEmergencyHandSize = 20;

  /// End game hand size threshold
  static const int endGameHandSize = 5;

  // ===== HAND QUALITY EVALUATION =====

  /// Negative hand value threshold to trigger transition
  static const int handQualityNegativeThreshold = -40;

  /// Number of 3s that trigger quality-based transition
  static const int handQualityThreeCountThreshold = 3;

  /// Average value threshold for large hands
  static const int handQualityAvgValueThreshold = 5;

  /// Hand size for quality evaluation
  static const int handSizeQualityThreshold = 6;

  // ===== ADAPTIVE PERSONALITY =====

  /// Threshold for playing most cards (foot transition)
  static const double mostCardsPlayableThreshold = 0.6;

  /// Threshold for playing some cards
  static const double someCardsPlayableThreshold = 0.5;

  /// Round to start late-game strategy
  static const int lateGameRound = 3;

  /// Round to trigger late-round transition logic
  static const int lateRoundTransitionRound = 2;

  /// Hand size for late-round transition
  static const int lateRoundHandSizeThreshold = 10;

  /// Hand size pressure negative threshold
  static const int handSizePressureNegativeThreshold = -30;

  /// Late round moderate negative threshold
  static const int lateRoundModerateNegativeThreshold = -20;

  /// Improved emergency threshold
  static const int improvedEmergencyThreshold = -60;

  // ===== CACHING =====

  /// Cache expiry for pressure analysis (milliseconds)
  static const int pressureCacheExpiryMs = 1000;

  /// Cache expiry for meld analysis (milliseconds)
  static const int meldCacheExpiryMs = 500;

  // ===== DISCARD ANALYZER =====

  /// Priority for discarding 3s (always discard first)
  static const int threesPriority = 1000;

  /// Weight penalty for feeding opponents
  static const int opponentNeedsWeight = 50;

  /// Extra penalty for near-book cards
  static const int nearBookPenalty = 100;

  /// Bonus for keeping duplicates
  static const int duplicateBonus = 20;

  /// Protection score to avoid discarding wilds
  static const int wildProtection = 200;

  // Prevent instantiation
  BotConfig._();
}
