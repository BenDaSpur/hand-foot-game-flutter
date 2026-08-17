// Configuration system for different Hand & Foot game variants.
//
// This system allows for multiple game types with different rules, scoring,
// and gameplay mechanics while maintaining a consistent core game engine.

enum GameType { classic, strict, marathon, speed, highStakes }

/// Configuration for a specific game type variant.
///
/// Contains all the variable parameters that can differ between game types,
/// allowing the same core game logic to support multiple rule variants.
class GameTypeConfig {
  // === DECK & SETUP ===
  final int
  deckMultiplier; // Multiplier for number of decks (players * multiplier)
  final int handSize;
  final int footSize;
  final int maxRounds; // 0 = unlimited

  // === SCORING SYSTEM ===
  final int basePlayDownRequirement; // Round 1 requirement
  final int playDownIncrement; // Added each round
  final int winningScoreThreshold;
  final int cleanBookBonus;
  final int dirtyBookBonus;
  final int goingOutBonus;
  final double penaltyMultiplier; // Multiplier for unplayed card penalties

  // === RULE VARIATIONS ===
  final bool
  allowMeldPhaseGoingOut; // Can go out during meld phase vs discard-only
  final bool allowPlayDownGoingOut; // Can go out immediately after play-down
  final bool requireDiscardForFootTransition; // Must discard to pick up foot
  final bool requireBothBookTypes; // Need clean AND dirty books to go out
  final bool firstOutWins; // First to go out wins vs highest score wins

  // === TIMING & PERFORMANCE ===
  final Duration turnTimeLimit; // 0 = unlimited
  final bool enableBotAnalytics; // Track bot decisions for this game type

  // === VISUAL & UX ===
  final String displayName;
  final String description;
  final String difficultyLabel; // "Easy", "Hard", "Expert"

  const GameTypeConfig({
    required this.deckMultiplier,
    required this.handSize,
    required this.footSize,
    required this.maxRounds,
    required this.basePlayDownRequirement,
    required this.playDownIncrement,
    required this.winningScoreThreshold,
    required this.cleanBookBonus,
    required this.dirtyBookBonus,
    required this.goingOutBonus,
    required this.penaltyMultiplier,
    required this.allowMeldPhaseGoingOut,
    required this.allowPlayDownGoingOut,
    required this.requireDiscardForFootTransition,
    required this.requireBothBookTypes,
    required this.firstOutWins,
    required this.turnTimeLimit,
    required this.enableBotAnalytics,
    required this.displayName,
    required this.description,
    required this.difficultyLabel,
  }) : assert(basePlayDownRequirement > 0, 'Base requirement must be positive'),
       assert(
         cleanBookBonus >= dirtyBookBonus,
         'Clean bonus should >= dirty bonus',
       ),
       assert(penaltyMultiplier >= 0, 'Penalty multiplier cannot be negative');

  /// Factory method to create configuration for Classic mode (current rules).
  static const GameTypeConfig classic = GameTypeConfig(
    deckMultiplier: 1, // players + 1 deck
    handSize: 11,
    footSize: 11,
    maxRounds: 0, // Unlimited
    basePlayDownRequirement: 60,
    playDownIncrement: 30,
    winningScoreThreshold: 8500,
    cleanBookBonus: 500,
    dirtyBookBonus: 300,
    goingOutBonus: 100,
    penaltyMultiplier: 1.0,
    allowMeldPhaseGoingOut: true, // Current behavior
    allowPlayDownGoingOut: true,
    requireDiscardForFootTransition: false, // Automatic transition
    requireBothBookTypes: true,
    firstOutWins: false, // Highest score wins
    turnTimeLimit: Duration.zero, // Unlimited
    enableBotAnalytics: true,
    displayName: 'Classic Hand & Foot',
    description: 'Balanced gameplay with standard rules and strategic depth',
    difficultyLabel: 'Medium',
  );

  /// Factory method for Strict mode (traditional rules).
  static const GameTypeConfig strict = GameTypeConfig(
    deckMultiplier: 1,
    handSize: 11,
    footSize: 11,
    maxRounds: 0,
    basePlayDownRequirement: 60,
    playDownIncrement: 30,
    winningScoreThreshold: 8500,
    cleanBookBonus: 500,
    dirtyBookBonus: 300,
    goingOutBonus: 100,
    penaltyMultiplier: 1.0,
    allowMeldPhaseGoingOut: false, // Must discard to end turn
    allowPlayDownGoingOut: false, // Must discard after playing down
    requireDiscardForFootTransition: true, // Must discard to pick up foot
    requireBothBookTypes: true,
    firstOutWins: false,
    turnTimeLimit: Duration.zero,
    enableBotAnalytics: true,
    displayName: 'Strict Hand & Foot',
    description:
        'Traditional rules requiring discards to end turns and transitions',
    difficultyLabel: 'Hard',
  );

  /// Factory method for Marathon mode (double decks, higher scores).
  static const GameTypeConfig marathon = GameTypeConfig(
    deckMultiplier: 2, // Double decks for longer games
    handSize: 15, // Slightly larger hands
    footSize: 15,
    maxRounds: 6, // Longer games
    basePlayDownRequirement: 90, // Higher requirements
    playDownIncrement: 45, // Steeper progression (90, 135, 180, 225...)
    winningScoreThreshold: 15000, // Much higher winning score
    cleanBookBonus: 750, // Higher book bonuses
    dirtyBookBonus: 450,
    goingOutBonus: 200, // Double going out bonus
    penaltyMultiplier: 1.0,
    allowMeldPhaseGoingOut: true,
    allowPlayDownGoingOut: true,
    requireDiscardForFootTransition: false,
    requireBothBookTypes: true,
    firstOutWins: false,
    turnTimeLimit: Duration.zero,
    enableBotAnalytics: true,
    displayName: 'Marathon Hand & Foot',
    description: 'Extended gameplay with double decks and higher scoring',
    difficultyLabel: 'Expert',
  );

  /// Factory method for Speed mode (fast games, first out wins).
  static const GameTypeConfig speed = GameTypeConfig(
    deckMultiplier: 1,
    handSize: 11, // Smaller hands for faster play
    footSize: 11,
    maxRounds: 3, // Shorter games
    basePlayDownRequirement: 30, // Lower requirements for speed
    playDownIncrement: 15, // Gentler progression (30, 45, 60)
    winningScoreThreshold: 5000, // Lower winning threshold
    cleanBookBonus: 300, // Reduced bonuses for speed
    dirtyBookBonus: 200,
    goingOutBonus: 500, // Higher going out bonus to encourage speed
    penaltyMultiplier: 0.75, // Reduced penalties for speed
    allowMeldPhaseGoingOut: true,
    allowPlayDownGoingOut: true,
    requireDiscardForFootTransition: false,
    requireBothBookTypes: false, // Either clean OR dirty book to go out
    firstOutWins: true, // First out wins regardless of score
    turnTimeLimit: Duration(seconds: 30), // 30 second turn limit
    enableBotAnalytics: false, // Faster performance
    displayName: 'Speed Hand & Foot',
    description: 'Fast-paced games where first player out wins',
    difficultyLabel: 'Easy',
  );

  /// Factory method for High Stakes mode (dramatic scoring).
  static const GameTypeConfig highStakes = GameTypeConfig(
    deckMultiplier: 1,
    handSize: 11,
    footSize: 11,
    maxRounds: 4, // Shorter but intense
    basePlayDownRequirement: 80, // Slightly higher than classic
    playDownIncrement: 40, // Steeper progression (80, 120, 160, 200)
    winningScoreThreshold: 10000,
    cleanBookBonus: 1000, // Double clean book bonus
    dirtyBookBonus: 600, // Double dirty book bonus
    goingOutBonus: 300, // Triple going out bonus
    penaltyMultiplier: 2.0, // Double penalties - high risk/reward
    allowMeldPhaseGoingOut: true,
    allowPlayDownGoingOut: true,
    requireDiscardForFootTransition: false,
    requireBothBookTypes: true,
    firstOutWins: false,
    turnTimeLimit: Duration.zero,
    enableBotAnalytics: true,
    displayName: 'High Stakes Hand & Foot',
    description: 'Dramatic scoring with doubled bonuses and penalties',
    difficultyLabel: 'Expert',
  );

  /// Get all available game types.
  static const Map<GameType, GameTypeConfig> allGameTypes = {
    GameType.classic: classic,
    GameType.strict: strict,
    GameType.marathon: marathon,
    GameType.speed: speed,
    GameType.highStakes: highStakes,
  };

  /// Get configuration for a specific game type.
  static GameTypeConfig forType(GameType type) {
    return allGameTypes[type] ?? classic;
  }

  /// Calculate the actual number of decks for a given number of players.
  int calculateDeckCount(int playerCount) {
    return (playerCount * deckMultiplier) + 1;
  }

  /// Calculate play-down requirement for a specific round.
  int calculatePlayDownRequirement(int round) {
    return basePlayDownRequirement + ((round - 1) * playDownIncrement);
  }

  /// Check if the game should end based on scores and game type rules.
  bool shouldGameEnd(List<int> scores, bool someoneWentOut) {
    if (firstOutWins && someoneWentOut) {
      return true; // Speed mode - first out wins
    }

    final highestScore = scores.isEmpty
        ? 0
        : scores.reduce((a, b) => a > b ? a : b);
    return highestScore >= winningScoreThreshold;
  }

  /// Get display information for game type selection UI.
  Map<String, dynamic> getDisplayInfo() {
    return {
      'name': displayName,
      'description': description,
      'difficulty': difficultyLabel,
      'deckCount': '$deckMultiplier× decks',
      'handSize': '$handSize cards',
      'winCondition': firstOutWins
          ? 'First out wins'
          : '$winningScoreThreshold points',
      'playDownStart':
          '$basePlayDownRequirement pts (+$playDownIncrement/round)',
      'specialRules': _getSpecialRules(),
    };
  }

  List<String> _getSpecialRules() {
    final rules = <String>[];

    if (!allowMeldPhaseGoingOut) {
      rules.add('Must discard to end turn');
    }
    if (requireDiscardForFootTransition) {
      rules.add('Must discard to reach foot');
    }
    if (!requireBothBookTypes) {
      rules.add('Only one book type required');
    }
    if (firstOutWins) {
      rules.add('First out wins');
    }
    if (penaltyMultiplier != 1.0) {
      rules.add('$penaltyMultiplier× penalty cards');
    }
    if (turnTimeLimit != Duration.zero) {
      rules.add('${turnTimeLimit.inSeconds}s turn limit');
    }

    return rules;
  }
}

/// Extension to convert GameType enum to user-friendly strings.
extension GameTypeExtension on GameType {
  String get displayName {
    switch (this) {
      case GameType.classic:
        return 'Classic';
      case GameType.strict:
        return 'Strict';
      case GameType.marathon:
        return 'Marathon';
      case GameType.speed:
        return 'Speed';
      case GameType.highStakes:
        return 'High Stakes';
    }
  }

  String get description {
    return GameTypeConfig.forType(this).description;
  }
}
