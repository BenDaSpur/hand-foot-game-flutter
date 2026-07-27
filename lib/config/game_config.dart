/// Different game variants with modified rules
enum GameVariant {
  classic, // Standard Hand & Foot rules
  quick, // Reduced hand/foot sizes for faster games
  marathon, // Higher winning score for longer games
  beginner, // Lower play-down requirements
}

/// Comprehensive game configuration constants and rules for Hand & Foot
///
/// This file serves as the single source of truth for all game mechanics,
/// scoring rules, and configurable settings. All hardcoded values throughout
/// the codebase should reference these constants to ensure consistency and
/// enable future user customization.
class GameConfig {
  // =============================================================================
  // CORE GAME RULES
  // =============================================================================

  /// Minimum natural (non-wild) cards required to form a meld
  static const int minNaturalCardsForMeld = 2;

  /// Minimum total cards required to form a meld
  static const int minTotalCardsForMeld = 3;

  /// Maximum wild cards allowed in a single meld (cannot exceed naturals)
  static const int maxWildCardsInMeld =
      999; // Effectively unlimited, limited by natural count

  /// Number of cards required to form a "book" (eligible for bonus points)
  static const int bookSize = 7;

  /// Number of cards dealt to each player's hand at start of round
  static const int handSize = 11;

  /// Number of cards dealt to each player's foot pile at start of round
  static const int footSize = 11;

  /// Number of cards player must draw when taking discard pile (if less than 7 cards)
  static const int requiredDrawCount = 2;

  /// Minimum cards that must remain in discard pile before forcing deck reshuffle
  static const int minDiscardForReshuffle = 2;

  /// Maximum number of recent actions to store for game history
  static const int maxRecentActions = 10;

  /// Additional cards to pick up when taking discard pile
  static const int additionalDiscardPickup = 5;

  /// Minimum deck size threshold for detecting 3s stalemate situation
  static const int stalemateDeckThreshold = 10;

  /// Number of recent discard cards to check for 3s stalemate (for performance)
  static const int stalemateCheckCardCount = 10;

  // =============================================================================
  // SCORING SYSTEM
  // =============================================================================

  /// Bonus points awarded for completing a clean book (7+ cards, no wilds)
  static const int cleanBookBonus = 500;

  /// Bonus points awarded for completing a dirty book (7+ cards, with wilds)
  static const int dirtyBookBonus = 300;

  /// Bonus points awarded to player who goes out first
  static const int goingOutBonus = 100;

  /// Bonus points for grabbing exactly hand + foot cards at round start
  static const int perfectGrabBonus = 100;

  /// Target card count for the perfect-grab mini-game (hand + foot)
  static const int perfectGrabTarget = handSize + footSize; // 22 cards

  /// Randomized grab targets keep the mini-game from being solved by muscle memory.
  static const int perfectGrabTargetMin = perfectGrabTarget - 2;

  /// Upper bound for randomized perfect-grab targets.
  static const int perfectGrabTargetMax = perfectGrabTarget + 2;

  /// Absolute cap on cards dealt in the perfect-grab mini-game.
  static const int perfectGrabMaxCardsCap = 34;

  /// Extra cards dealt beyond the target before forced grab.
  static const int perfectGrabMaxCardsAboveTarget = 10;

  /// Standard deal-timing defaults (legacy behavior).
  static const int perfectGrabStandardBaseDealIntervalMs = 340;
  static const int perfectGrabStandardMinDealIntervalMs = 72;
  static const int perfectGrabStandardIntervalStepMs = 11;
  static const int perfectGrabStandardJitterMs = 45;

  /// Random deal-timing ranges for per-round variance.
  static const int perfectGrabRandomBaseDealIntervalMinMs = 270;
  static const int perfectGrabRandomBaseDealIntervalRangeMs = 120;
  static const int perfectGrabRandomMinDealIntervalMinMs = 58;
  static const int perfectGrabRandomMinDealIntervalRangeMs = 35;
  static const int perfectGrabRandomIntervalStepMinMs = 8;
  static const int perfectGrabRandomIntervalStepRangeMs = 8;
  static const int perfectGrabRandomJitterMinMs = 55;
  static const int perfectGrabRandomJitterRangeMs = 45;
  static const int perfectGrabDealIntervalFloorMs = 55;

  /// Stutter pause configuration.
  static const int perfectGrabMaxStutters = 2;
  static const int perfectGrabMinStutterCardIndex = 3;
  static const int perfectGrabStutterDelayMinMs = 120;
  static const int perfectGrabStutterDelayRangeMs = 180;

  static const int perfectGrabVisibleCardCap = 8;

  /// Total points needed to win the game
  static const int winningScore = 8500;

  // =============================================================================
  // CARD POINT VALUES
  // =============================================================================

  /// Point value for Jokers (wild cards)
  static const int jokerValue = 50;

  /// Point value for 2s (wild cards)
  static const int twoValue = 20;

  /// Point value for Aces
  static const int aceValue = 20;

  /// Point value for Kings, Queens, Jacks
  static const int faceCardValue = 10;

  /// Point value for 8, 9, 10
  static const int highNumberValue = 10;

  /// Point value for 4, 5, 6, 7
  static const int lowNumberValue = 5;

  /// Point penalty for red 3s (hearts, diamonds) when held in hand
  static const int red3Penalty = -300;

  /// Point penalty for black 3s (clubs, spades) when held in hand
  static const int black3Penalty = -5;

  // =============================================================================
  // PLAY-DOWN REQUIREMENTS
  // =============================================================================

  /// Base play-down requirement for round 1
  static const int basePlayDownRequirement = 60;

  /// Points added to requirement each subsequent round
  static const int playDownIncrement = 30;

  /// Play-down requirements by round (calculated dynamically)
  /// Round 1: 60, Round 2: 90, Round 3: 120, Round 4: 150, etc.
  static int getPlayDownRequirement(int round) {
    return basePlayDownRequirement + ((round - 1) * playDownIncrement);
  }

  /// Predefined requirements for common rounds (for UI display)
  static const Map<int, int> playDownRequirements = {
    1: 60,
    2: 90,
    3: 120,
    4: 150,
    5: 180,
    6: 210,
    7: 240,
    8: 270,
  };

  // =============================================================================
  // DECK CONFIGURATION
  // =============================================================================

  /// Number of standard 52-card decks used in the game
  /// Formula: (number of players + 1) decks
  static int getNumDecks(int numPlayers) => numPlayers + 1;

  /// Total cards in game deck (excluding jokers)
  static int getTotalCards(int numPlayers) => getNumDecks(numPlayers) * 52;

  /// Number of jokers added to the deck (4 per deck)
  static int getNumJokers(int numPlayers) => getNumDecks(numPlayers) * 4;

  // =============================================================================
  // GAME FLOW SETTINGS
  // =============================================================================

  /// Minimum number of players required to start a game
  static const int minPlayers = 2;

  /// Maximum number of players supported
  static const int maxPlayers = 6;

  /// Default number of players for single-player mode (1 human + 3 bots)
  static const int defaultPlayers = 4;

  /// Maximum number of rounds before forcing game end (prevents infinite games)
  static const int maxRounds = 20;

  /// Round number when late-game strategy starts (more aggressive play)
  static const int lateGameRound = 3;

  /// Maximum wild cards recommended in a single meld before penalty
  static const int excessiveWildThreshold = 3;

  // =============================================================================
  // BOT AI CONSTANTS
  // =============================================================================

  /// Bot AI penalty and priority constants for strategic decision making
  static const int wildCardMeldPenalty =
      2000; // Penalty per wild card in new melds
  static const int wildCardUsageBasePenalty =
      3000; // Base penalty for using wilds
  static const int cleanBookProtectionPenalty =
      2000; // Penalty for contaminating clean books
  static const int criticalCleanBookProtectionPenalty =
      5000; // Never contaminate when no clean books
  static const int bookCompletionPriority =
      2000; // Priority for completing books
  static const int cleanBookCompletionPriority =
      1500; // Priority for clean book completion
  static const int wildCardStrategicBonus =
      2500; // Bonus in critical situations

  // =============================================================================
  // DIFFICULTY & VARIANTS
  // =============================================================================

  /// Variant-specific configurations
  static Map<String, dynamic> getVariantConfig(GameVariant variant) {
    switch (variant) {
      case GameVariant.quick:
        return {
          'handSize': 7,
          'footSize': 7,
          'winningScore': 5000,
          'playDownMultiplier': 0.8,
        };
      case GameVariant.marathon:
        return {
          'handSize': 13,
          'footSize': 13,
          'winningScore': 15000,
          'playDownMultiplier': 1.2,
        };
      case GameVariant.beginner:
        return {
          'handSize': 11,
          'footSize': 11,
          'winningScore': 6000,
          'playDownMultiplier': 0.7,
        };
      case GameVariant.classic:
        return {
          'handSize': handSize,
          'footSize': footSize,
          'winningScore': winningScore,
          'playDownMultiplier': 1.0,
        };
    }
  }

  // =============================================================================
  // UI CONFIGURATION (GAME-SPECIFIC)
  // =============================================================================

  /// Card aspect ratio for consistent rendering
  static const double cardAspectRatio = 0.7;

  /// Spacing between cards in UI layouts - reduced for better space usage
  static const double cardSpacing = 4.0;

  /// Responsive breakpoints for different screen sizes
  static const double ultraWideBreakpoint = 1600.0; // New ultra-wide breakpoint
  static const double desktopBreakpoint = 1200.0;
  static const double tabletLandscapeBreakpoint = 900.0;
  static const double tabletPortraitBreakpoint = 600.0;

  /// Grid layout configurations for different screen sizes - optimized for more cards per row
  static const Map<String, int> gridCrossAxisCounts = {
    'ultra_wide': 10, // New category for ultra-wide screens
    'desktop': 8, // Increased from 6 to 8
    'tablet_landscape': 7, // Increased from 5 to 7
    'tablet_portrait': 5, // Increased from 4 to 5
    'mobile': 5, // Increased from 4 to 5 for better mobile utilization
  };

  /// Card sizing constraints
  static const double minCardWidth = 50.0; // Reduced from 60 for small phones
  static const double maxCardWidth = 120.0;
  static const double mobileCardWidth = 55.0; // Optimized for mobile

  /// Modal dialog size ratios
  static const double modalWidthRatio =
      0.95; // Increased for better mobile utilization
  static const double modalHeightRatio =
      0.9; // Increased for better mobile utilization
  static const double mobileModalWidthRatio =
      0.98; // Maximum utilization on mobile
  static const double mobileModalHeightRatio =
      0.95; // Maximum utilization on mobile

  // =============================================================================
  // BOT AI STRATEGIC CONSTANTS
  // =============================================================================

  /// Hand size that triggers human accumulation threat detection
  static const int humanAccumulationThreat = 25;

  /// Hand size that signals opponent is close to going out
  static const int dangerousOpponentHandSize = 8;

  /// Aggression multiplier when competitive pressure is detected
  static const double competitivePressureMultiplier = 1.5;

  /// Large discard pile threshold for aggressive exploitation
  static const int largeDiscardPileThreshold =
      12; // Lowered from 20 after bot analysis

  /// Medium discard pile threshold for strategic consideration
  static const int mediumDiscardPileThreshold =
      6; // Lowered from 10 after bot analysis

  // =============================================================================
  // PERFORMANCE & TIMING
  // =============================================================================

  /// How long finished/cancelled multiplayer games are kept before cleanup.
  static const Duration gameCleanupDelay = Duration(hours: 1);

  /// Debounce delay for user input to prevent accidental double-actions
  static const Duration debounceDelay = Duration(milliseconds: 300);

  /// Animation duration for card movements and UI transitions
  static const Duration animationDuration = Duration(milliseconds: 200);

  /// Duration for cards flying between deck/discard and hand
  static const Duration cardFlyDuration = Duration(milliseconds: 350);

  /// Duration for center-screen card reveal fan
  static const Duration cardRevealDuration = Duration(milliseconds: 500);

  /// Pause after reveal so the player can read drawn cards
  static const Duration cardRevealPause = Duration(milliseconds: 500);

  /// Stagger delay between sequential card flights
  static const Duration cardStaggerDelay = Duration(milliseconds: 120);

  /// Duration for meld cards flying during discard unlock
  static const Duration cardMeldFlyDuration = Duration(milliseconds: 400);

  /// Bot decision-making delay for realistic gameplay pacing
  static const Duration botDecisionDelay = Duration(milliseconds: 800);

  /// Maximum cached cards for performance optimization
  static const int maxCachedCards = 100;

  /// Bot turn processing threshold for detecting stuck loops
  static const int botStuckThreshold = 5;

  /// Maximum bot processing recursion depth to prevent infinite loops
  static const int maxBotProcessingDepth = 10;

  /// Bot processing delay for realistic gameplay pacing
  static const Duration botProcessingDelay = Duration(seconds: 1);

  /// Number of turns considered "early game" where bots don't panic about large hands
  /// Starting hand is 11 cards, so bot needs ~5+ turns to accumulate before panic is warranted
  static const int earlyGameTurnThreshold = 5;

  // =============================================================================
  // VALIDATION & HELPERS
  // =============================================================================

  /// Validates that a meld meets all requirements
  static bool isValidMeld(List<dynamic> cards) {
    if (cards.length < minTotalCardsForMeld) return false;

    // Count natural vs wild cards
    int naturalCount = 0;
    int wildCount = 0;

    for (final card in cards) {
      if (card.isWild) {
        wildCount++;
      } else {
        naturalCount++;
      }
    }

    // Must have minimum natural cards
    if (naturalCount < minNaturalCardsForMeld) return false;

    // Wild cards cannot exceed natural cards
    if (wildCount > naturalCount) return false;

    return true;
  }

  /// Calculates total point value for a list of cards
  static int calculateCardPoints(List<dynamic> cards) {
    return cards.fold<int>(0, (sum, card) => sum + (card.pointValue as int));
  }

  /// Checks if a player has met the going out requirements
  static bool canGoOut(dynamic player) {
    // Must have at least one clean book AND one dirty book
    int cleanBooks = 0;
    int dirtyBooks = 0;

    for (final meld in player.melds) {
      if (meld.cards.length >= bookSize) {
        if (meld.isClean) {
          cleanBooks++;
        } else {
          dirtyBooks++;
        }
      }
    }

    return cleanBooks >= 1 && dirtyBooks >= 1;
  }

  /// Returns appropriate UI message for current game state
  static String getGameStateMessage(String phase, int round) {
    switch (phase) {
      case 'draw':
        return 'Draw 2 cards or take the discard pile';
      case 'meld':
        return 'Create melds or add to existing ones';
      case 'discard':
        return 'Discard a card to end your turn';
      default:
        return 'Round $round - Play-down requirement: ${getPlayDownRequirement(round)} points';
    }
  }
}
