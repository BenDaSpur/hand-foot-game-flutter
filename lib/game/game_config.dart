/// Game configuration constants and rules
class GameConfig {
  // Meld requirements
  static const int minNaturalCardsForMeld = 2;
  static const int minTotalCardsForMeld = 3;
  static const int maxWildCardsInMeld = 3;
  static const int bookSize = 7;

  // Play-down requirements by round
  static const Map<int, int> playDownRequirements = {
    1: 60,
    2: 90,
    3: 120,
    4: 150,
  };

  // Scoring
  static const int cleanBookBonus = 500;
  static const int dirtyBookBonus = 300;
  static const int goingOutBonus = 100;

  // UI Constants
  static const double cardAspectRatio = 0.7;
  static const double cardSpacing = 8.0;
  static const double modalWidthRatio = 0.9;
  static const double modalHeightRatio = 0.8;

  // Responsive breakpoints
  static const double desktopBreakpoint = 1200;
  static const double tabletLandscapeBreakpoint = 800;
  static const double tabletPortraitBreakpoint = 600;

  // Grid configuration
  static const Map<String, int> gridCrossAxisCounts = {
    'desktop': 8,
    'tablet_landscape': 7,
    'tablet_portrait': 6,
    'mobile': 5,
  };

  // Card size constraints
  static const double minCardWidth = 40.0;
  static const double maxCardWidth = 65.0;

  // Animation and timing
  static const Duration debounceDelay = Duration(milliseconds: 300);
  static const Duration animationDuration = Duration(milliseconds: 200);

  // Performance settings
  static const bool enableKeepAlive = true;
  static const int maxCachedCards = 100;
}
