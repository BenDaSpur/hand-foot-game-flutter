// Example integration showing how to use the GameType system with existing code.
// This file demonstrates the changes needed to support multiple game variants.

import 'package:flutter/material.dart';
import '../game/game_controller.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../screens/game_type_selection_screen.dart';
import 'game_type_config.dart';

/// Example of how GameController would be enhanced to support game types.
///
/// This shows the key integration points without breaking existing code.
class GameTypeIntegrationExample {
  /// Example: Enhanced GameController factory with game type support
  static GameController createGameWithType({
    required List<Player> players,
    required GameType gameType,
    int? seed,
  }) {
    // final config = GameTypeConfig.forType(gameType);

    // Note: This would require enhancing the existing GameController
    // to accept a gameTypeConfig parameter and create deck with configurable count:
    // final deckCount = config.calculateDeckCount(players.length);
    // final deck = Deck.createMultiDeck(deckCount, seed: seed);

    return GameController(
      players: players,
      seed: seed,
      // gameTypeConfig: config, // Would be added in implementation
    );
  }

  /// Example: Enhanced GameState with configurable rules
  static void demonstrateGameStateEnhancements() {
    // Current static access (would be deprecated):
    // final oldRequirement = GameConfig.basePlayDownRequirement;

    // New configurable access:
    final classicConfig = GameTypeConfig.classic;
    final marathonConfig = GameTypeConfig.marathon;

    // Round 3 play-down requirements:
    final classicR3 = classicConfig.calculatePlayDownRequirement(3); // 120 pts
    final marathonR3 = marathonConfig.calculatePlayDownRequirement(
      3,
    ); // 180 pts

    print('Classic Round 3: $classicR3 pts');
    print('Marathon Round 3: $marathonR3 pts');
  }

  /// Example: Game ending logic with different rule variants
  static bool shouldGameEnd(GameState gameState, GameTypeConfig config) {
    final scores = gameState.players.map((p) => p.score).toList();
    final someoneWentOut = gameState.players.any((p) => p.canGoOut);

    return config.shouldGameEnd(scores, someoneWentOut);
  }

  /// Example: Turn ending validation with rule variants
  static bool canGoOutDuringMeldPhase(
    GameState gameState,
    GameTypeConfig config,
  ) {
    if (!config.allowMeldPhaseGoingOut) {
      return false; // Strict mode - must discard to end turn
    }

    return gameState.currentPlayer.canGoOut; // Classic behavior
  }

  /// Example: Foot transition with different rules
  static bool shouldPickUpFoot(
    Player player,
    GameTypeConfig config,
    GameState gameState,
  ) {
    if (config.requireDiscardForFootTransition) {
      // Strict mode - only pick up foot after discarding
      return player.isHandEmpty && gameState.turnPhase == TurnPhase.discard;
    }

    // Classic mode - automatic foot pickup
    return player.isHandEmpty;
  }

  /// Example: Enhanced scoring with configurable multipliers
  static int calculateRoundScore(
    Player player,
    GameTypeConfig config,
    bool wentOut,
  ) {
    // Base score calculation
    var roundScore = player.calculateTotalScore(includeAllUnplayedCards: true);

    // Apply penalty multiplier for high stakes mode
    final unplayedPenalty = player.calculateAllUnplayedCardsValue();
    final adjustedPenalty = (unplayedPenalty * config.penaltyMultiplier)
        .round();
    roundScore =
        roundScore + (adjustedPenalty - unplayedPenalty); // Adjust penalty

    // Add configurable going out bonus
    if (wentOut) {
      roundScore += config.goingOutBonus;
    }

    // Add configurable book bonuses
    final cleanBooks = player.melds
        .where((m) => m.isClean && m.cards.length >= 7)
        .length;
    final dirtyBooks = player.melds
        .where((m) => !m.isClean && m.cards.length >= 7)
        .length;

    roundScore += (cleanBooks * config.cleanBookBonus);
    roundScore += (dirtyBooks * config.dirtyBookBonus);

    return roundScore;
  }

  /// Example: Integration with main menu navigation
  static void navigateToGameTypeSelection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameTypeSelectionScreen(
          onGameTypeSelected: (gameType) {
            Navigator.pop(context); // Close selection screen
            _startGameWithType(context, gameType);
          },
        ),
      ),
    );
  }

  static void _startGameWithType(BuildContext context, GameType gameType) {
    // Create players
    final players = [
      Player(id: '1', name: 'You', type: PlayerType.human),
      Player(id: '2', name: 'Bot 1', type: PlayerType.bot),
      Player(id: '3', name: 'Bot 2', type: PlayerType.bot),
    ];

    // Note: Create game with selected type
    // final controller = createGameWithType(
    //   players: players,
    //   gameType: gameType,
    // );

    // Note: Navigate to enhanced game screen with game type context
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (context) => EnhancedGameScreen(
    //     gameController: controller,
    //     gameType: gameType,
    //   ),
    // ));

    print(
      'Would start ${gameType.displayName} game with ${players.length} players',
    );
  }
}

/// Enhanced GameController interface (pseudo-code showing needed changes)
abstract class EnhancedGameControllerInterface {
  GameTypeConfig get gameTypeConfig;
  GameState get gameState; // Would exist in actual implementation

  /// Check if current game type allows going out during meld phase
  bool get allowsMeldPhaseGoingOut => gameTypeConfig.allowMeldPhaseGoingOut;

  /// Check if current game type requires discard for foot transition
  bool get requiresDiscardForFoot =>
      gameTypeConfig.requireDiscardForFootTransition;

  /// Calculate play-down requirement for current round
  int get currentPlayDownRequirement =>
      gameTypeConfig.calculatePlayDownRequirement(gameState.round);

  /// Check if game should end based on current scores and rules
  bool shouldGameEndNow() {
    final scores = gameState.players.map((p) => p.score).toList();
    final someoneWentOut = gameState.players.any((p) => p.canGoOut);
    return gameTypeConfig.shouldGameEnd(scores, someoneWentOut);
  }
}

/// Usage examples for different game types:
void demonstrateGameTypes() {
  // Classic game (current behavior)
  final classic = GameTypeConfig.classic;
  print('Classic R3: ${classic.calculatePlayDownRequirement(3)} pts'); // 120

  // Strict game (traditional rules)
  final strict = GameTypeConfig.strict;
  print(
    'Strict allows meld-phase going out: ${strict.allowMeldPhaseGoingOut}',
  ); // false

  // Marathon game (extended play)
  final marathon = GameTypeConfig.marathon;
  print('Marathon R3: ${marathon.calculatePlayDownRequirement(3)} pts'); // 180
  print(
    'Marathon deck count for 3 players: ${marathon.calculateDeckCount(3)}',
  ); // 7 decks

  // Speed game (fast wins)
  final speed = GameTypeConfig.speed;
  print('Speed first out wins: ${speed.firstOutWins}'); // true
  print('Speed R3: ${speed.calculatePlayDownRequirement(3)} pts'); // 60

  // High stakes (dramatic scoring)
  final highStakes = GameTypeConfig.highStakes;
  print(
    'High stakes penalty multiplier: ${highStakes.penaltyMultiplier}',
  ); // 2.0
  print('High stakes clean book: ${highStakes.cleanBookBonus} pts'); // 1000
}
