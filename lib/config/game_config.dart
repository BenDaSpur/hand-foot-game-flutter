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

  // =============================================================================
  // SCORING SYSTEM
  // =============================================================================

  /// Bonus points awarded for completing a clean book (7+ cards, no wilds)
  static const int cleanBookBonus = 500;

  /// Bonus points awarded for completing a dirty book (7+ cards, with wilds)
  static const int dirtyBookBonus = 300;

  /// Bonus points awarded to player who goes out first
  static const int goingOutBonus = 100;

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

  /// Spacing between cards in UI layouts
  static const double cardSpacing = 8.0;

  /// Responsive breakpoints for different screen sizes
  static const double desktopBreakpoint = 1200.0;
  static const double tabletLandscapeBreakpoint = 900.0;
  static const double tabletPortraitBreakpoint = 600.0;

  /// Grid layout configurations for different screen sizes
  static const Map<String, int> gridCrossAxisCounts = {
    'desktop': 6,
    'tablet_landscape': 5,
    'tablet_portrait': 4,
    'mobile': 3,
  };

  /// Card sizing constraints
  static const double minCardWidth = 60.0;
  static const double maxCardWidth = 120.0;

  /// Modal dialog size ratios
  static const double modalWidthRatio = 0.9;
  static const double modalHeightRatio = 0.8;

  // =============================================================================
  // PERFORMANCE & TIMING
  // =============================================================================

  /// Debounce delay for user input to prevent accidental double-actions
  static const Duration debounceDelay = Duration(milliseconds: 300);

  /// Animation duration for card movements and UI transitions
  static const Duration animationDuration = Duration(milliseconds: 200);

  /// Bot decision-making delay for realistic gameplay pacing
  static const Duration botDecisionDelay = Duration(milliseconds: 800);

  /// Maximum cached cards for performance optimization
  static const int maxCachedCards = 100;

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
