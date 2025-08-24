import 'dart:math';

import '../models/player.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../game/game_controller.dart';
import 'bot_decision.dart';
import 'bot_personality.dart';
import 'bot_game_analyzer.dart';
import 'bot_meld_analyzer.dart';
import 'bot_foot_transition_manager.dart';
import 'bot_end_game_manager.dart';

/// Enhanced Bot AI coordinator that orchestrates all bot decision-making.
///
/// This class serves as the main interface for bot AI decisions, coordinating
/// between specialized managers for different aspects of gameplay including
/// personality, game analysis, meld analysis, foot transitions, and end game.
class EnhancedBotAI {
  // Core components
  final BotPersonalityManager _personalityManager;
  final BotGameAnalyzer _gameAnalyzer;
  final BotMeldAnalyzer _meldAnalyzer;
  final BotFootTransitionManager _footTransitionManager;
  final BotEndGameManager _endGameManager;

  // Random number generator for decision variability (future use)
  // ignore: unused_field
  final Random _random;

  // Multi-meld play-down state tracking
  List<List<PlayingCard>>? _plannedMelds;
  int _currentMeldIndex = 0;
  bool _inMultiMeldSequence = false;

  // Strategic constants
  static const int maxTurnsBeforeForcePlayDown = 5;
  static const int strongPlayDownBuffer = 10;
  static const int wildCardDiscardThreshold = 10;
  static const double emergencyRiskTolerance = 2.0;
  static const double maxEmergencyRiskTolerance = 6.0;

  EnhancedBotAI({int? seed})
    : _personalityManager = BotPersonalityManager(),
      _gameAnalyzer = BotGameAnalyzer(),
      _meldAnalyzer = BotMeldAnalyzer(),
      _footTransitionManager = BotFootTransitionManager(),
      _endGameManager = BotEndGameManager(),
      _random = seed != null ? Random(seed) : Random();

  /// Main entry point for bot decisions
  BotDecision makeDecision(Player bot, GameController controller) {
    final gameState = controller.gameState;

    // Set context for personality-based decisions
    _personalityManager.setCurrentPlayerContext(bot.id);

    // Update game analysis
    _gameAnalyzer.updateOpponentAnalysis(gameState, bot);
    _gameAnalyzer.incrementTurnCount(bot.id);

    // Clear meld cache if needed
    if (gameState.turnPhase == TurnPhase.meld || gameState.hasDrawnFromDeck) {
      _meldAnalyzer.clearCache();
    }

    // Route to appropriate decision handler based on turn phase
    switch (gameState.turnPhase) {
      case TurnPhase.draw:
        return _makeDrawDecision(bot, controller);
      case TurnPhase.meld:
        return _makeMeldDecision(bot, controller);
      case TurnPhase.discard:
        return _makeDiscardDecision(bot, controller);
    }
  }

  /// Handle draw phase decisions
  BotDecision _makeDrawDecision(Player bot, GameController controller) {
    final gameState = controller.gameState;

    // If continuing multi-meld sequence, no draw needed
    if (_inMultiMeldSequence) {
      return BotDecision(action: 'skipDraw');
    }

    // Evaluate discard pile opportunity
    if (gameState.discardPile.isNotEmpty && bot.hasPlayedDown) {
      final riskTolerance = _personalityManager.calculateRiskTolerance(
        gameState,
        bot,
      );

      if (_shouldTakeDiscardPile(bot, controller, riskTolerance)) {
        return BotDecision(action: 'drawFromDiscard');
      }
    }

    // Default to drawing from deck
    return BotDecision(action: 'drawFromDeck');
  }

  /// Handle meld phase decisions
  BotDecision _makeMeldDecision(Player bot, GameController controller) {
    // Handle multi-meld sequence continuation
    if (_inMultiMeldSequence && _plannedMelds != null) {
      return _continueMultiMeldSequence();
    }

    // Check for end game decisions first (highest priority)
    final endGameDecision = _endGameManager.handleEndGame(bot, controller);
    if (endGameDecision != null) {
      return endGameDecision;
    }

    // Check for foot transition decisions
    final footTransitionDecision = _footTransitionManager.handleFootTransition(
      bot,
      controller,
    );
    if (footTransitionDecision != null) {
      return footTransitionDecision;
    }

    // Handle play-down if not yet played down
    if (!bot.hasPlayedDown) {
      return _handlePlayDownDecision(bot, controller);
    }

    // Look for meld opportunities
    final cardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
      bot,
      controller,
    );
    if (cardsToAdd.isNotEmpty) {
      return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
    }

    // Try to create new melds
    final possibleMelds = _meldAnalyzer.getPossibleMelds(bot, controller);
    if (possibleMelds.isNotEmpty) {
      final bestMeld = _meldAnalyzer.findBestMeld(possibleMelds);
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    // No meld opportunities
    return BotDecision(action: 'noMeld');
  }

  /// Handle discard phase decisions
  BotDecision _makeDiscardDecision(Player bot, GameController controller) {
    final cardToDiscard = _chooseCardToDiscard(bot, controller.gameState);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Handle play-down decision logic
  BotDecision _handlePlayDownDecision(Player bot, GameController controller) {
    final gameState = controller.gameState;
    final possibleMelds = _meldAnalyzer.getPossibleMelds(bot, controller);
    final playDownRequirement = gameState.playDownRequirement;
    final turnCount = _gameAnalyzer.getTurnCount(bot.id);

    if (possibleMelds.isEmpty) {
      return BotDecision(action: 'noMeld');
    }

    // Force play-down after max turns
    if (turnCount >= maxTurnsBeforeForcePlayDown) {
      final bestCombination = _meldAnalyzer.findBestPlayDownCombination(
        bot,
        controller,
        playDownRequirement,
      );
      if (bestCombination.isNotEmpty) {
        return _executePlayDown(bestCombination);
      }
    }

    // Check for strategic play-down opportunity
    final riskTolerance = _personalityManager.calculateRiskTolerance(
      gameState,
      bot,
    );
    final thresholdModifier = _personalityManager.getPlayDownThresholdModifier(
      bot.id,
    );
    final adjustedRequirement = (playDownRequirement * thresholdModifier)
        .round();

    // Try natural melds first (preferred)
    final naturalMelds = _meldAnalyzer.findNaturalMeldOpportunities(
      bot,
      controller,
    );
    final naturalCombination = _findBestNaturalCombination(
      naturalMelds,
      adjustedRequirement,
    );
    if (naturalCombination.isNotEmpty) {
      return _executePlayDown(naturalCombination);
    }

    // Consider wild melds if risk tolerance allows
    if (riskTolerance > 1.2) {
      final wildCombination = _meldAnalyzer.findBestPlayDownCombination(
        bot,
        controller,
        adjustedRequirement,
      );
      if (wildCombination.isNotEmpty) {
        return _executePlayDown(wildCombination);
      }
    }

    return BotDecision(action: 'noMeld');
  }

  /// Execute a play-down sequence (single or multi-meld)
  BotDecision _executePlayDown(List<List<PlayingCard>> melds) {
    if (melds.length > 1) {
      // Set up multi-meld sequence
      _plannedMelds = List.from(melds);
      _currentMeldIndex = 1;
      _inMultiMeldSequence = true;
      return BotDecision(
        action: 'createMeld',
        data: melds.first,
        skipPlayDownCheck: true,
      );
    } else {
      // Single meld play-down
      return BotDecision(action: 'createMeld', data: melds.first);
    }
  }

  /// Continue multi-meld sequence
  BotDecision _continueMultiMeldSequence() {
    if (_plannedMelds == null || _currentMeldIndex >= _plannedMelds!.length) {
      _inMultiMeldSequence = false;
      _plannedMelds = null;
      _currentMeldIndex = 0;
      return BotDecision(action: 'noMeld');
    }

    final nextMeld = _plannedMelds![_currentMeldIndex];
    _currentMeldIndex++;

    if (_currentMeldIndex >= _plannedMelds!.length) {
      _inMultiMeldSequence = false;
      _plannedMelds = null;
      _currentMeldIndex = 0;
    }

    return BotDecision(
      action: 'createMeld',
      data: nextMeld,
      skipPlayDownCheck: true,
    );
  }

  /// Check if bot should take the discard pile
  bool _shouldTakeDiscardPile(
    Player bot,
    GameController controller,
    double riskTolerance,
  ) {
    final gameState = controller.gameState;
    final discardPile = gameState.discardPile;

    if (discardPile.length < 2) return false;

    final constants = _personalityManager.currentConstants;
    final pileValue = discardPile.fold<int>(
      0,
      (sum, card) => sum + card.pointValue,
    );
    final pileSize = discardPile.length;

    // Adjust thresholds based on risk tolerance and personality
    final adjustedValueThreshold =
        (constants.valuablePileThreshold / riskTolerance).round();
    final adjustedSizeThreshold = (constants.largePileThreshold / riskTolerance)
        .round();

    // Conservative check for pre-play-down
    if (!bot.hasPlayedDown) {
      final conservativeMultiplier =
          _personalityManager.shouldBeMoreConservativeWithDiscardPile(bot.id)
          ? 1.5
          : 1.2;
      return pileValue > adjustedValueThreshold * conservativeMultiplier ||
          pileSize >= adjustedSizeThreshold + 3;
    }

    return pileValue > adjustedValueThreshold ||
        pileSize >= adjustedSizeThreshold;
  }

  /// Find best natural meld combination for play-down
  List<List<PlayingCard>> _findBestNaturalCombination(
    List<List<PlayingCard>> naturalMelds,
    int requirement,
  ) {
    if (naturalMelds.isEmpty) return [];

    // Try single melds first
    for (final meld in naturalMelds) {
      final value = _meldAnalyzer.calculateTotalMeldValue([meld]);
      if (value >= requirement) {
        return [meld];
      }
    }

    // Try two-meld combinations
    for (int i = 0; i < naturalMelds.length; i++) {
      for (int j = i + 1; j < naturalMelds.length; j++) {
        final combination = [naturalMelds[i], naturalMelds[j]];
        final value = _meldAnalyzer.calculateTotalMeldValue(combination);
        if (value >= requirement) {
          return combination;
        }
      }
    }

    return [];
  }

  /// Choose the best card to discard
  PlayingCard _chooseCardToDiscard(Player bot, GameState gameState) {
    final hand = bot.currentHand;
    if (hand.isEmpty) {
      throw Exception('Cannot discard from empty hand');
    }

    // Priority 1: Discard 3s (penalty cards)
    final threes = hand.where((card) => card.rank == CardRank.three).toList();
    if (threes.isNotEmpty) {
      return threes.first;
    }

    // Priority 2: Discard lowest value non-useful cards
    final rankCounts = <CardRank, int>{};
    for (final card in hand) {
      if (!card.isWild) {
        rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
      }
    }

    // Find singletons (cards without pairs)
    final singletons = hand
        .where((card) => !card.isWild && (rankCounts[card.rank] ?? 0) <= 1)
        .toList();

    if (singletons.isNotEmpty) {
      singletons.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return singletons.first;
    }

    // Fallback: Discard lowest value card
    final sortedHand = List<PlayingCard>.from(hand);
    sortedHand.sort((a, b) => a.pointValue.compareTo(b.pointValue));
    return sortedHand.first;
  }

  /// Assign personalities to bot players
  void assignPersonality(String playerId, BotPersonality personality) {
    _personalityManager.assignPersonality(playerId, personality);
  }

  /// Auto-assign random personalities to bot players
  void assignRandomPersonalities(List<Player> botPlayers) {
    _personalityManager.assignRandomPersonalities(botPlayers);
  }

  /// Clear all game data when game ends
  void clearGameData() {
    _personalityManager.clearPersonalityData();
    _gameAnalyzer.clearAnalysisData();
    _meldAnalyzer.clearCache();
    _plannedMelds = null;
    _currentMeldIndex = 0;
    _inMultiMeldSequence = false;
  }

  // Getters for testing and debugging
  Map<String, OpponentAnalysis> get opponentAnalysis =>
      _gameAnalyzer.opponentAnalysis;
  BotPersonalityManager get personalityManager => _personalityManager;
  BotGameAnalyzer get gameAnalyzer => _gameAnalyzer;
  BotMeldAnalyzer get meldAnalyzer => _meldAnalyzer;
  bool get inMultiMeldSequence => _inMultiMeldSequence;
  List<List<PlayingCard>>? get plannedMelds => _plannedMelds;
}
