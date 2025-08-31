import 'dart:math' as math;
import 'dart:math';

import '../models/player.dart';
import '../models/card.dart';
import '../models/meld.dart';
import '../models/game_state.dart';
import '../game/game_controller.dart';
import '../config/game_config.dart';
import 'bot_decision.dart';
import 'bot_personality.dart';
import 'bot_game_analyzer.dart';
import 'bot_meld_analyzer.dart';
import 'bot_foot_transition_manager.dart';
import 'bot_end_game_manager.dart';
import '../utils/debug_logger.dart';

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

  // Random number generator for decision variability
  final Random _random;

  // Multi-meld play-down state tracking (legacy - now disabled)
  List<List<PlayingCard>>? _plannedMelds;
  bool _inMultiMeldSequence = false;

  // Performance optimization: Cache pressure analysis results
  Map<String, DateTime>? _lastPressureAnalysis;
  Map<String, BotDecision?>? _cachedPressureResponse;

  // Strategic constants - ENHANCED for human-level strategic play
  static const int maxTurnsBeforeForcePlayDown =
      8; // INCREASED - allow strategic accumulation like humans (35+ cards)
  static const int strongPlayDownBuffer =
      15; // INCREASED - wait for stronger strategic positions
  static const int wildCardDiscardThreshold =
      6; // REDUCED - hoard wilds more strategically
  static const double emergencyRiskTolerance =
      2.5; // INCREASED - take bigger strategic risks
  static const double maxEmergencyRiskTolerance =
      6.0; // INCREASED - allow major strategic gambles

  // Opponent pressure detection thresholds moved to GameConfig

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

    try {
      // DEBUG: Log decision context (removed in release builds)
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'makeDecision in phase ${gameState.turnPhase}',
      );

      // Set context for personality-based decisions
      _personalityManager.setCurrentPlayerContext(bot.id);

      // NEW: Dynamic adaptive personality adjustment
      _applyAdaptivePersonalityAdjustment(bot, gameState);

      // Update game analysis
      _gameAnalyzer.updateOpponentAnalysis(gameState, bot);
      _gameAnalyzer.incrementTurnCount(bot.id);

      // Clear meld cache if needed
      if (gameState.turnPhase == TurnPhase.meld || gameState.hasDrawnFromDeck) {
        _meldAnalyzer.clearCache();
      }

      // NEW: Opponent pressure detection and competitive response (with caching)
      final pressureResponse = _evaluateOpponentPressureWithCaching(
        bot,
        controller,
        gameState,
      );
      if (pressureResponse != null) {
        DebugLogger.botDebug(
          bot.id,
          bot.name,
          'Applying pressure response: ${pressureResponse.action}',
        );
        return pressureResponse;
      }

      // PANIC MODE: Override normal logic for bots in terrible situations
      if (bot.score < -100 && !bot.hasPlayedDown) {
        return _handlePanicMode(bot, controller, gameState);
      }

      // Route to appropriate decision handler based on turn phase
      final decision = switch (gameState.turnPhase) {
        TurnPhase.draw => _makeDrawDecision(bot, controller),
        TurnPhase.meld => _makeMeldDecision(bot, controller),
        TurnPhase.discard => _makeDiscardDecision(bot, controller),
      };

      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'makeDecision returning: ${decision.action}',
      );
      return decision;
    } catch (e, stackTrace) {
      print('ERROR: Bot decision failed for ${bot.id}: $e');
      print('Stack trace: $stackTrace');
      // Emergency fallback
      return gameState.turnPhase == TurnPhase.draw
          ? BotDecision(action: 'drawFromDeck')
          : BotDecision(action: 'noMeld');
    }
  }

  /// Handle draw phase decisions
  BotDecision _makeDrawDecision(Player bot, GameController controller) {
    final gameState = controller.gameState;

    // DEBUG: Log draw decision context (removed in release builds)
    DebugLogger.botDebug(
      bot.id,
      bot.name,
      '_makeDrawDecision - hasPlayedDown=${bot.hasPlayedDown}, melds=${bot.melds.length}, inMultiMeld=$_inMultiMeldSequence',
    );

    // If continuing multi-meld sequence, draw from deck to proceed to meld phase
    // Multi-meld sequence should continue in meld phase, not skip drawing
    if (_inMultiMeldSequence) {
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'Returning drawFromDeck (multi-meld sequence)',
      );
      return BotDecision(action: 'drawFromDeck');
    }

    // Evaluate discard pile opportunity - more aggressive evaluation
    if (gameState.discardPile.isNotEmpty && bot.hasPlayedDown) {
      try {
        final riskTolerance = _personalityManager.calculateRiskTolerance(
          gameState,
          bot,
        );

        // Enhanced: also check for pre-play-down opportunities if pile is very valuable
        final shouldTake = _shouldTakeDiscardPile(
          bot,
          controller,
          riskTolerance,
        );
        final canUnlock = controller.gameState.canUnlockDiscard();

        if (shouldTake && canUnlock) {
          DebugLogger.botDebug(
            bot.id,
            bot.name,
            'Returning drawFromDiscard (discard pile opportunity)',
          );
          return BotDecision(action: 'drawFromDiscard');
        }
      } catch (e) {
        DebugLogger.warning(
          'Risk tolerance calculation failed for bot ${bot.id}: $e',
        );
        // Skip discard pile evaluation and continue to default
      }
    }

    // NEW: Even more aggressive - check discard pile before playing down if pile is huge
    if (gameState.discardPile.length >= 8 && !bot.hasPlayedDown) {
      try {
        final riskTolerance = _personalityManager.calculateRiskTolerance(
          gameState,
          bot,
        );
        if (_shouldTakeDiscardPile(
              bot,
              controller,
              riskTolerance * 2.0,
            ) && // 2x risk tolerance for huge piles
            controller.gameState.canUnlockDiscard()) {
          DebugLogger.botDebug(
            bot.id,
            bot.name,
            'Returning drawFromDiscard (huge pile, pre-play-down)',
          );
          return BotDecision(action: 'drawFromDiscard');
        }
      } catch (e) {
        // Continue to default if error
      }
    }

    // Default to drawing from deck
    DebugLogger.botDebug(bot.id, bot.name, 'Returning drawFromDeck (default)');
    return BotDecision(action: 'drawFromDeck');
  }

  /// Handle meld phase decisions
  BotDecision _makeMeldDecision(Player bot, GameController controller) {
    // Multi-meld sequences should happen within a single turn, not across turns
    // Clear any stale multi-meld state that violates Hand & Foot rules
    if (_inMultiMeldSequence) {
      _plannedMelds = null;
      _inMultiMeldSequence = false;
    }

    // Check for end game decisions first (highest priority)
    final endGameDecision = _endGameManager.handleEndGame(bot, controller);
    if (endGameDecision != null) {
      return endGameDecision;
    }

    // NEW: Check if we can play ALL cards to immediately see foot
    if (bot.hasPlayedDown && !bot.hasPickedUpFoot) {
      final canPlayAllDecision = _checkCanPlayAllCards(bot, controller);
      if (canPlayAllDecision != null) {
        return canPlayAllDecision;
      }
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

    // Post-play-down strategy: Use accumulate-and-dump approach
    // Hold cards strategically for better discard pile unlocking opportunities
    // ENHANCED: Be more aggressive about meld creation vs holding
    if (_shouldHoldCardsStrategically(bot, controller)) {
      // Only hold if we're not in a competitive situation
      final humanPlayers = controller.gameState.players.where(
        (p) => p.type == PlayerType.human,
      );
      final humanThreat = humanPlayers.any(
        (h) => h.hasPickedUpFoot && h.currentHand.length <= 8,
      );

      if (!humanThreat && bot.currentHand.length > 10) {
        return BotDecision(action: 'noMeld');
      }
      // Otherwise, continue to meld building instead of holding
    }

    // If ready to dump everything, execute all possible melds
    if (_shouldExecuteDumpStrategy(bot, controller)) {
      return _executeDumpStrategy(bot, controller);
    }

    // Look for meld opportunities (fallback for conservative play)
    final cardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
      bot,
      controller,
    );
    if (cardsToAdd.isNotEmpty) {
      return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
    }

    // Try to create new melds with book balance consideration
    final possibleMelds = _meldAnalyzer.getPossibleMelds(bot, controller);
    if (possibleMelds.isNotEmpty) {
      // Pass bot context to consider book balance
      final bestMeld = _meldAnalyzer.findBestMeld(possibleMelds, bot: bot);
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    // No meld opportunities
    return BotDecision(action: 'noMeld');
  }

  /// Handle discard phase decisions
  BotDecision _makeDiscardDecision(Player bot, GameController controller) {
    // Check if bot has no cards left - they should go out if they can
    if (bot.currentHand.isEmpty) {
      // Check if bot can go out (has required books)
      if (bot.canGoOutWithBooks) {
        return BotDecision(action: 'goOut');
      } else {
        // Bot is stuck - shouldn't happen, but handle gracefully
        return BotDecision(action: 'error');
      }
    }

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

    // ENHANCED PERSONALITY-BASED URGENCY: Use personality-specific patience, not global
    final personalityConstants = _personalityManager.currentConstants;
    final personalityTurnLimit =
        personalityConstants.maxTurnsBeforeForcePlayDown;

    final roundUrgencyMultiplier = gameState.round >= 3
        ? 0.5
        : 1.0; // Very aggressive in Round 3+
    final urgentTurnLimit = (personalityTurnLimit * roundUrgencyMultiplier)
        .round();

    // PRIORITY 1: Always play down if we can meet requirements (regardless of patience)
    final bestCombination = _meldAnalyzer.findBestPlayDownCombination(
      bot,
      controller,
      playDownRequirement,
    );

    DebugLogger.botDebug(
      bot.id,
      bot.name,
      'PlayDown analysis: combinations=${bestCombination.length}, requirement=$playDownRequirement, turns=$turnCount, urgentLimit=$urgentTurnLimit',
    );

    if (bestCombination.isNotEmpty) {
      // Check if we should play down now based on value vs patience
      final combinationValue = bestCombination.fold<int>(
        0,
        (sum, cards) =>
            sum +
            cards.fold<int>(0, (cardSum, card) => cardSum + card.pointValue),
      );

      // Always play down if: 1) We meet requirement, OR 2) We've waited enough turns, OR 3) Late round
      final meetsRequirement = combinationValue >= playDownRequirement;
      final hasModerateExcess =
          combinationValue >= (playDownRequirement + 10); // Reasonable excess
      final hasWaitedEnough = turnCount >= urgentTurnLimit;
      final lateRoundUrgency = gameState.round >= 3;

      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'PlayDown decision: meets=$meetsRequirement ($combinationValue >= $playDownRequirement), excess=$hasModerateExcess, waited=$hasWaitedEnough, late=$lateRoundUrgency',
      );

      // Play down immediately if we meet basic requirement AND (have reasonable excess OR waited OR late round)
      if (meetsRequirement &&
          (hasModerateExcess || hasWaitedEnough || lateRoundUrgency)) {
        return _executePlayDown(bestCombination);
      }

      // For aggressive bots: play down immediately when meeting requirement (no patience)
      final personality = _personalityManager.getPersonality(bot.id);
      if (personality == BotPersonality.aggressive && meetsRequirement) {
        return _executePlayDown(bestCombination);
      }
    }

    // Check for strategic play-down opportunity
    final riskTolerance = _personalityManager.calculateRiskTolerance(
      gameState,
      bot,
    );
    // AGGRESSIVE FIX: Don't increase requirement beyond base + small buffer
    // (Removed thresholdModifier - was making bots too conservative)
    final adjustedRequirement = (playDownRequirement + strongPlayDownBuffer)
        .clamp(
          playDownRequirement,
          playDownRequirement + 20, // Max 20 extra points, not multiplicative
        );

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

    // AGGRESSIVE FIX: Consider wild melds much more readily
    if (riskTolerance > 0.6) {
      // Reduced from 1.2 - much more willing to use wilds
      final wildCombination = _meldAnalyzer.findBestPlayDownCombination(
        bot,
        controller,
        adjustedRequirement,
      );
      if (wildCombination.isNotEmpty) {
        return _executePlayDown(wildCombination);
      }
    }

    // EMERGENCY PLAY-DOWN: If in high rounds and still haven't played down, be desperate
    if (gameState.round >= 3 && !bot.hasPlayedDown) {
      final desperateCombination = _meldAnalyzer.findBestPlayDownCombination(
        bot,
        controller,
        playDownRequirement, // Use base requirement, no buffer
      );
      if (desperateCombination.isNotEmpty) {
        return _executePlayDown(desperateCombination);
      }

      // SUPER EMERGENCY: Try to play down with ANY valid combination
      final anyValidMeld = possibleMelds.firstWhere(
        (meld) =>
            meld.fold<int>(0, (sum, card) => sum + card.pointValue) >=
            playDownRequirement,
        orElse: () => [],
      );
      if (anyValidMeld.isNotEmpty) {
        return BotDecision(action: 'createMeld', data: anyValidMeld);
      }
    }

    // ULTRA EMERGENCY: Round 4+ and still no play-down = play ANY meld possible
    if (gameState.round >= 4 &&
        !bot.hasPlayedDown &&
        possibleMelds.isNotEmpty) {
      return BotDecision(action: 'createMeld', data: possibleMelds.first);
    }

    // NEGATIVE SCORE/HAND EMERGENCY: If bot has terrible score OR terrible hand value
    final handPenalty = bot.currentHand.fold<int>(
      0,
      (sum, card) => sum + (card.pointValue < 0 ? card.pointValue : 0),
    );
    if ((bot.score < -50 || handPenalty < -250) &&
        !bot.hasPlayedDown &&
        possibleMelds.isNotEmpty) {
      final emergencyMeld = possibleMelds.firstWhere(
        (meld) =>
            meld.fold<int>(0, (sum, card) => sum + card.pointValue) >=
            (playDownRequirement * 0.7).round(),
        orElse: () => possibleMelds.first, // ANY meld if desperate enough
      );
      return BotDecision(action: 'createMeld', data: emergencyMeld);
    }

    return BotDecision(action: 'noMeld');
  }

  /// Handle panic mode for bots with terrible scores
  BotDecision _handlePanicMode(
    Player bot,
    GameController controller,
    GameState gameState,
  ) {
    DebugLogger.botDebug(
      bot.id,
      bot.name,
      'PANIC MODE activated (score: ${bot.score})',
    );

    final possibleMelds = _meldAnalyzer.getPossibleMelds(bot, controller);
    final playDownRequirement = gameState.playDownRequirement;

    switch (gameState.turnPhase) {
      case TurnPhase.draw:
        // In panic mode, always draw from deck (fastest)
        return BotDecision(action: 'drawFromDeck');

      case TurnPhase.meld:
        // Play ANY meld that gets close to requirement, ignore normal strategy
        if (possibleMelds.isNotEmpty) {
          final desperateMeld = possibleMelds.firstWhere(
            (meld) =>
                meld.fold<int>(0, (sum, card) => sum + card.pointValue) >=
                (playDownRequirement * 0.7).round(),
            orElse: () => possibleMelds.first,
          );
          return BotDecision(action: 'createMeld', data: desperateMeld);
        }
        return BotDecision(action: 'noMeld');

      case TurnPhase.discard:
        // Discard highest penalty cards immediately
        final hand = bot.currentHand;
        final penaltyCards = hand.where((card) => card.pointValue < 0).toList();
        if (penaltyCards.isNotEmpty) {
          penaltyCards.sort(
            (a, b) => a.pointValue.compareTo(b.pointValue),
          ); // Most negative first
          return BotDecision(action: 'discard', data: penaltyCards.first);
        }

        // Discard highest value cards to minimize damage
        final sortedHand = List<PlayingCard>.from(hand);
        sortedHand.sort(
          (a, b) => b.pointValue.compareTo(a.pointValue),
        ); // Highest first
        return BotDecision(action: 'discard', data: sortedHand.first);
    }
  }

  /// Execute a play-down sequence (single or multi-meld)
  BotDecision _executePlayDown(List<List<PlayingCard>> melds) {
    if (melds.length > 1) {
      // Multi-meld initial play-down: use multi-meld creation to ensure all melds
      // are validated together and meet the play-down requirement as a group
      return BotDecision(
        action: 'createMultipleMelds',
        data: melds,
        skipPlayDownCheck: false, // Let the system validate the total points
      );
    } else {
      // Single meld play-down
      return BotDecision(action: 'createMeld', data: melds.first);
    }
  }

  /// Enhanced discard pile unlocking logic for competitive play
  bool _shouldTakeDiscardPile(
    Player bot,
    GameController controller,
    double riskTolerance,
  ) {
    final gameState = controller.gameState;
    final discardPile = gameState.discardPile;

    if (discardPile.isEmpty) {
      return false;
    }

    final constants = _personalityManager.currentConstants;
    final pileValue = discardPile.fold<int>(
      0,
      (sum, card) => sum + card.pointValue,
    );
    final pileSize = discardPile.length;

    // Enhanced strategic analysis
    final bookStatus = _analyzeBookRequirements(bot);
    final opponentThreat = _assessOpponentThreat(gameState, bot);

    // Dynamic thresholds based on multiple factors
    var adjustedValueThreshold =
        constants.valuablePileThreshold / riskTolerance;
    var adjustedSizeThreshold = constants.largePileThreshold / riskTolerance;

    // Book completion urgency - take piles if they help complete books
    if (bookStatus['needsBookBalance'] == true) {
      adjustedValueThreshold *= 0.7; // 30% more willing to take pile for books
      adjustedSizeThreshold *= 0.8; // Lower size threshold for book completion
    }

    // Opponent threat adjustment - be more aggressive when opponents are dangerous
    if (opponentThreat > 0.6) {
      adjustedValueThreshold *=
          0.5; // MUCH more aggressive when threatened (was 0.6)
      adjustedSizeThreshold *=
          0.6; // Lower threshold when opponents are close (was 0.7)
    }

    // Round pressure - later rounds require more aggressive pile taking
    if (gameState.round >= 3) {
      adjustedValueThreshold *=
          0.6; // MUCH more aggressive in late rounds (was 0.8)
      adjustedSizeThreshold *= 0.7; // Lower threshold in high rounds (was 0.9)
    }

    // NEW: Human exploitation - humans avoid discard pile, so we should take it more
    final humanPlayers = gameState.players.where(
      (p) => p.type == PlayerType.human,
    );
    if (humanPlayers.any(
      (h) => h.currentHand.length > 15 && !h.hasPlayedDown,
    )) {
      // If human is accumulating and avoiding discard pile, we should take it
      adjustedValueThreshold *=
          0.5; // MUCH more willing to take piles humans ignore (was 0.7)
      adjustedSizeThreshold *=
          0.6; // Take smaller piles to deny human resources (was 0.8)
    }

    // NEW: Exploit large discard piles (23-37 cards observed, but bots ignore them)
    if (pileSize >= GameConfig.largeDiscardPileThreshold) {
      adjustedValueThreshold *= 0.3; // Take huge piles aggressively
      adjustedSizeThreshold *= 0.4; // Almost always take large piles
    } else if (pileSize >= GameConfig.mediumDiscardPileThreshold) {
      adjustedValueThreshold *= 0.6; // Take medium-large piles
      adjustedSizeThreshold *= 0.7; // Lower threshold for medium piles
    }

    // NEW: Competitive pile denial - take piles that would benefit opponents
    if (pileSize >= 5 &&
        _pileWouldBenefitOpponents(discardPile, gameState, bot)) {
      adjustedValueThreshold *= 0.6; // Take piles to deny opponents
    }

    // Enhanced pre-play-down logic
    if (!bot.hasPlayedDown) {
      final playDownRequirement = gameState.playDownRequirement;
      final currentMeldPotential = _calculateCurrentMeldPotential(
        bot,
        controller,
      );

      // If pile helps meet play-down requirement, be much more aggressive
      if (currentMeldPotential + (pileValue * 0.6) >= playDownRequirement) {
        adjustedValueThreshold *=
            0.5; // Very aggressive for play-down opportunities
      }

      final aggressiveMultiplier =
          _personalityManager.shouldBeMoreConservativeWithDiscardPile(bot.id)
          ? 0.9 // Much more aggressive (was 1.1)
          : 0.7; // Very aggressive (was 0.9)
      return pileValue > adjustedValueThreshold * aggressiveMultiplier ||
          pileSize >=
              (adjustedSizeThreshold - 1).clamp(2, adjustedSizeThreshold);
    }

    // Enhanced post-play-down logic - consider hand management and foot transition
    final isInFoot = bot.hasPickedUpFoot;
    final handSize = bot.currentHand.length;

    // If close to foot transition or in foot with few cards, be selective
    if (isInFoot && handSize <= 4) {
      return pileValue >
          adjustedValueThreshold * 1.2; // More selective in endgame
    }

    // If hand is getting large, prioritize pile taking to prevent getting stuck
    if (handSize >= 15) {
      adjustedValueThreshold *= 0.6; // Very aggressive with large hands
      adjustedSizeThreshold *= 0.7; // Lower threshold to prevent hand overflow
    }

    // Standard post-play-down thresholds with competitive adjustments
    return pileValue >
            adjustedValueThreshold * 0.7 || // 30% lower value threshold
        pileSize >=
            (adjustedSizeThreshold - 2).clamp(
              2,
              adjustedSizeThreshold,
            ); // Even lower size threshold
  }

  /// Find best natural meld combination for play-down
  /// Enhanced to prefer having both clean and mixed melds for book diversity
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

    // Try two-meld combinations - prefer one clean and one that could become dirty
    List<List<PlayingCard>>? bestMixedCombination;
    int bestMixedScore = 0;

    for (int i = 0; i < naturalMelds.length; i++) {
      for (int j = i + 1; j < naturalMelds.length; j++) {
        final combination = [naturalMelds[i], naturalMelds[j]];
        final value = _meldAnalyzer.calculateTotalMeldValue(combination);
        if (value >= requirement) {
          // Check if this gives us meld diversity (different ranks)
          final rank1 = naturalMelds[i].first.rank;
          final rank2 = naturalMelds[j].first.rank;

          // Score based on potential for book diversity
          int score = value;
          if (rank1 != rank2) score += 50; // Bonus for different ranks

          // Extra bonus if one meld is larger (closer to book)
          if (naturalMelds[i].length >= 5 || naturalMelds[j].length >= 5) {
            score += 30;
          }

          if (score > bestMixedScore) {
            bestMixedScore = score;
            bestMixedCombination = combination;
          }
        }
      }
    }

    if (bestMixedCombination != null) {
      return bestMixedCombination;
    }

    return [];
  }

  /// Choose the best card to discard
  PlayingCard _chooseCardToDiscard(Player bot, GameState gameState) {
    final hand = bot.currentHand;
    if (hand.isEmpty) {
      // This should not happen due to check in _makeDiscardDecision, but be defensive
      throw BotDecisionException(
        'Cannot discard from empty hand - bot should go out or error',
      );
    }

    // Priority 1: Discard 3s (penalty cards), red 3s first (-300 vs black -5)
    final threes = hand.where((card) => card.rank == CardRank.three).toList();
    if (threes.isNotEmpty) {
      // Sort by point value (most negative first) - red 3s are -300, black 3s are -5
      threes.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      // Add variability: if there are multiple 3s of the same point value, randomly pick one
      final bestValue = threes.first.pointValue;
      final bestThrees = threes
          .where((card) => card.pointValue == bestValue)
          .toList();
      return _selectRandomly(bestThrees);
    }

    // Priority 2: Check if we should hold wild cards strategically
    final wildCards = hand.where((card) => card.isWild).toList();
    final stillOnHandPile = bot.hasPlayedDown && !bot.hasPickedUpFoot;

    // If we're still on hand pile and have wild cards, keep them for foot transition
    // unless we have too many (excessive holding is bad)
    if (stillOnHandPile && wildCards.isNotEmpty && wildCards.length < 8) {
      // Don't discard wilds - they're valuable for foot transition
      // Continue to find other cards to discard
    }

    // Priority 3: ENHANCED discard logic with clean book preservation
    final rankCounts = <CardRank, int>{};
    for (final card in hand) {
      if (!card.isWild) {
        rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
      }
    }

    // Check if bot has clean books for strategic decision-making
    final hasCleanBook = bot.melds.any((m) => m.isClean && m.cards.length >= 7);
    final cleanMeldsNearBook = bot.melds
        .where((m) => m.isClean && m.cards.length >= 5)
        .toList();

    // Find singletons but PROTECT potential clean book cards
    final protectedSingletons = <PlayingCard>[];
    final safeSingletons = <PlayingCard>[];

    for (final card in hand) {
      if (!card.isWild && (rankCounts[card.rank] ?? 0) <= 1) {
        // Check if this card could help complete a clean meld
        final couldHelpCleanMeld = cleanMeldsNearBook.any(
          (meld) => meld.rank == card.rank && !card.isWild,
        );

        if (!hasCleanBook && couldHelpCleanMeld) {
          protectedSingletons.add(card); // Protect for clean book building
        } else {
          safeSingletons.add(card); // Safe to discard
        }
      }
    }

    // Prefer safe singletons first
    if (safeSingletons.isNotEmpty) {
      safeSingletons.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      final bestValue = safeSingletons.first.pointValue;
      final bestSingletons = safeSingletons
          .where((card) => card.pointValue == bestValue)
          .toList();
      return _selectRandomly(bestSingletons);
    }

    // If no safe singletons, use protected ones only if absolutely necessary
    if (protectedSingletons.isNotEmpty) {
      protectedSingletons.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      final bestValue = protectedSingletons.first.pointValue;
      final bestProtected = protectedSingletons
          .where((card) => card.pointValue == bestValue)
          .toList();
      return _selectRandomly(bestProtected);
    }

    // Fallback: Discard lowest value card (avoiding wilds if still on hand pile)
    List<PlayingCard> sortedHand;
    if (stillOnHandPile && wildCards.length < 8) {
      // Exclude wild cards from discard options when still on hand pile
      sortedHand = List<PlayingCard>.from(hand.where((card) => !card.isWild));
      if (sortedHand.isEmpty) {
        // If only wilds left, must discard one
        sortedHand = List<PlayingCard>.from(hand);
      }
    } else {
      sortedHand = List<PlayingCard>.from(hand);
    }

    sortedHand.sort((a, b) => a.pointValue.compareTo(b.pointValue));
    // Add variability: if there are multiple cards of the same low value, randomly pick one
    final bestValue = sortedHand.first.pointValue;
    final bestCards = sortedHand
        .where((card) => card.pointValue == bestValue)
        .toList();
    return _selectRandomly(bestCards);
  }

  /// Strategic holding decision: Should bot hold cards instead of melding immediately?
  /// This implements the superior "accumulate-and-dump" strategy for better discard pile unlocking
  /// Enhanced with personality-based holding tolerance and time-based pressure
  bool _shouldHoldCardsStrategically(Player bot, GameController controller) {
    final gameState = controller.gameState;
    final handSize = bot.currentHand.length;
    final turnCount = _gameAnalyzer.getTurnCount(bot.id);
    final personality = _personalityManager.getPersonality(bot.id);

    // Calculate time-based pressure: worry more the longer we've been in hand without reaching foot
    final timePressure = _calculateTimePressure(bot, turnCount, personality);
    final personalityHoldingLimit = _getPersonalityHoldingLimit(
      personality,
      timePressure,
    );

    // Don't hold if hand exceeds personality-based limit (adjusted for time pressure)
    if (handSize >= personalityHoldingLimit) return false;

    // Don't hold if opponents are close to going out (competitive pressure)
    _gameAnalyzer.updateOpponentAnalysis(gameState, bot);
    final opponentAnalysis = _gameAnalyzer.opponentAnalysis;
    for (final analysis in opponentAnalysis.values) {
      if (analysis.handSize <= 3) return false; // Opponent close to going out
    }

    // Hold cards if we have good discard pile unlocking potential
    final unlockPotential = _calculateDiscardPileUnlockPotential(
      bot,
      gameState,
    );

    // Hold if we have decent hand size for unlocking opportunities
    // More cards = more potential matches for discard pile
    if (handSize >= 10 && unlockPotential >= 3) {
      return true; // Increased thresholds to be more aggressive
    }

    // Be more aggressive about round requirements - don't hold as much
    final playDownRequirement = gameState.playDownRequirement;
    if (handSize >= 12 &&
        _shouldHoldForRoundRequirement(
          bot,
          controller,
          playDownRequirement,
          handSize,
        )) {
      return true; // Only hold if hand is already large
    }

    // Strategic book completion: hold if we can complete books in later rounds
    if (_shouldHoldForBookCompletion(bot, gameState, personality)) {
      return true;
    }

    // Hold if we can potentially dump everything soon
    final dumpPotential = _calculateDumpPotential(bot, controller);
    if (dumpPotential >= 0.8) {
      return true; // Increased threshold - be more selective about holding
    }

    return false;
  }

  /// Should execute dump strategy: meld everything and go to foot
  bool _shouldExecuteDumpStrategy(Player bot, GameController controller) {
    final gameState = controller.gameState;
    final handSize = bot.currentHand.length;
    final playDownRequirement = gameState.playDownRequirement;
    final stillOnHandPile = bot.hasPlayedDown && !bot.hasPickedUpFoot;
    final wildCards = bot.currentHand.where((c) => c.isWild).toList();

    // For initial play-down: check if we have enough meld potential for the round requirement
    if (!bot.hasPlayedDown) {
      final currentMeldPoints = _calculateCurrentMeldPotential(bot, controller);
      // Only dump if we can meet the round requirement
      if (currentMeldPoints >= playDownRequirement) return true;
      return false; // Keep accumulating if we can't meet the requirement
    }

    // Post-play-down: Execute if we can dump a good portion of our hand
    final dumpPotential = _calculateDumpPotential(bot, controller);
    if (dumpPotential >= 0.6 && handSize >= 4) {
      return true; // Reduced from 80% to 60%
    }

    // Execute if hand is getting large
    if (handSize >= 12) {
      return true; // Reduced from 15 to 12
    }

    // NEW: Be more aggressive if on hand pile with wilds and close to foot
    if (stillOnHandPile && wildCards.isNotEmpty && handSize <= 10) {
      // If we have wilds and are close to foot, dump everything we can
      if (dumpPotential >= 0.5) return true; // Even lower threshold with wilds
    }

    // Execute if we can go directly to foot
    final possibleMelds = _meldAnalyzer.getPossibleMelds(bot, controller);
    final cardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
      bot,
      controller,
    );
    final totalMeldableCards =
        possibleMelds.fold<int>(0, (sum, meld) => sum + meld.length) +
        cardsToAdd.length;

    if (totalMeldableCards >= handSize - 1) {
      return true; // Can meld all but 1 card
    }

    return false;
  }

  /// Execute dump strategy: create all possible melds in this turn
  /// Enhanced with competitive book balance analysis
  BotDecision _executeDumpStrategy(Player bot, GameController controller) {
    // Enhanced book analysis
    final bookStatus = _analyzeBookRequirements(bot);
    final needsCleanBook = bookStatus['needsCleanBook'] as bool;
    final needsDirtyBook = bookStatus['needsDirtyBook'] as bool;
    final hasRequiredBooks = bookStatus['hasRequiredBooks'] as bool;

    // Priority 1: Add to existing melds with strategic book balance
    final cardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
      bot,
      controller,
    );
    if (cardsToAdd.isNotEmpty) {
      // Strategic addition based on book requirements
      for (final addition in cardsToAdd) {
        final meld = addition['meld'] as Meld;
        final card = addition['card'] as PlayingCard;

        // If we need a clean book, prioritize keeping clean melds clean
        if (needsCleanBook && meld.isClean && !card.isWild) {
          return BotDecision(action: 'addToMeld', data: addition);
        }

        // If we need a dirty book, prioritize adding to dirty melds
        if (needsDirtyBook && !meld.isClean) {
          return BotDecision(action: 'addToMeld', data: addition);
        }

        // If we have both book types, prioritize largest melds for efficiency
        if (hasRequiredBooks && meld.cards.length >= 6) {
          return BotDecision(action: 'addToMeld', data: addition);
        }
      }

      // If no strategic match, take the first good addition
      return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
    }

    // Priority 2: Create new melds with enhanced book balance strategy
    final possibleMelds = _meldAnalyzer.getPossibleMelds(bot, controller);
    if (possibleMelds.isNotEmpty) {
      // Select meld type based on book requirements for competitive advantage
      List<PlayingCard>? strategicMeld;

      if (needsCleanBook) {
        // Prioritize natural melds that can become clean books
        strategicMeld = possibleMelds.firstWhere(
          (meld) => !meld.any((card) => card.isWild),
          orElse: () => [],
        );
      } else if (needsDirtyBook) {
        // Prioritize melds with wilds that can become dirty books
        strategicMeld = possibleMelds.firstWhere(
          (meld) => meld.any((card) => card.isWild),
          orElse: () => [],
        );
      }

      // Use strategic meld if found, otherwise use enhanced best meld selection
      final selectedMeld = (strategicMeld?.isNotEmpty ?? false)
          ? strategicMeld!
          : _meldAnalyzer.findBestMeld(
              possibleMelds,
              bot: bot,
              preferLarger: true, // Prefer larger melds for efficiency
            );

      return BotDecision(action: 'createMeld', data: selectedMeld);
    }

    return BotDecision(action: 'noMeld');
  }

  /// Calculate potential for unlocking discard pile based on hand composition
  int _calculateDiscardPileUnlockPotential(Player bot, GameState gameState) {
    if (gameState.discardPile.isEmpty) return 0;

    final topCard = gameState.discardPile.last;
    final hand = bot.currentHand;

    // Count potential matching cards for unlocking
    int potential = 0;
    final rankCounts = <CardRank, int>{};

    for (final card in hand) {
      if (!card.isWild && !card.isThree) {
        rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
      }
    }

    // Check if we can unlock with the top card
    if (!topCard.isWild && !topCard.isThree) {
      final matchingCards = rankCounts[topCard.rank] ?? 0;
      if (matchingCards >= 2) {
        potential += 2; // Increased from 1 - Can unlock is very valuable
      }

      // Bonus for each additional matching card (more flexible unlocking)
      potential += (matchingCards - 2).clamp(0, 4); // Increased max bonus
    }

    // General unlock potential (pairs that could match future discards)
    for (final count in rankCounts.values) {
      if (count >= 2) potential++; // Each pair increases unlock potential
      if (count >= 3) potential++; // Extra bonus for triplets
    }

    // Bonus for wild cards (can help with unlocking)
    final wildCount = hand.where((card) => card.isWild).length;
    potential += (wildCount / 3).floor(); // Every 3 wilds adds potential

    return potential;
  }

  /// Calculate what percentage of hand can be melded (0.0 to 1.0)
  double _calculateDumpPotential(Player bot, GameController controller) {
    final handSize = bot.currentHand.length;
    if (handSize == 0) return 1.0;

    final possibleMelds = _meldAnalyzer.getPossibleMelds(bot, controller);
    final cardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
      bot,
      controller,
    );

    final meldableCards =
        possibleMelds.fold<int>(0, (sum, meld) => sum + meld.length) +
        cardsToAdd.length;

    return (meldableCards / handSize).clamp(0.0, 1.0);
  }

  /// Check if bot can play ALL cards to immediately transition to foot
  BotDecision? _checkCanPlayAllCards(Player bot, GameController controller) {
    final handSize = bot.currentHand.length;
    if (handSize == 0) return null;

    // Get all cards we can potentially play
    final possibleMelds = _meldAnalyzer.getPossibleMelds(bot, controller);
    final cardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
      bot,
      controller,
    );

    // Calculate total playable cards
    int totalPlayableCards = 0;
    Set<PlayingCard> usedCards = {};

    // Count cards that can be added to existing melds
    for (final addition in cardsToAdd) {
      final card = addition['card'] as PlayingCard;
      if (!usedCards.contains(card)) {
        usedCards.add(card);
        totalPlayableCards++;
      }
    }

    // Count cards that can form new melds (avoiding double-counting)
    for (final meld in possibleMelds) {
      int newCardsInMeld = 0;
      for (final card in meld) {
        if (!usedCards.contains(card)) {
          usedCards.add(card);
          newCardsInMeld++;
        }
      }
      totalPlayableCards += newCardsInMeld;
    }

    // If we can play ALL cards, execute the strategy
    if (totalPlayableCards >= handSize) {
      // Prioritize adding to existing melds first
      if (cardsToAdd.isNotEmpty) {
        return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
      }
      // Then create new melds
      if (possibleMelds.isNotEmpty) {
        final bestMeld = _meldAnalyzer.findBestMeld(possibleMelds, bot: bot);
        return BotDecision(action: 'createMeld', data: bestMeld);
      }
    }

    return null;
  }

  /// Determine if we should hold cards based on round play-down requirements
  bool _shouldHoldForRoundRequirement(
    Player bot,
    GameController controller,
    int requirement,
    int handSize,
  ) {
    // Calculate current meld potential points
    final currentMeldPoints = _calculateCurrentMeldPotential(bot, controller);

    // More aggressive round-specific strategy
    if (requirement <= 60) {
      // Round 1: 60 points - can often be done with 1 good meld
      // Hold if we're close but not quite there
      return currentMeldPoints >= 45 && currentMeldPoints < 60 && handSize >= 6;
    } else if (requirement <= 90) {
      // Round 2: 90 points - usually needs 2 melds
      // More aggressive - lower thresholds
      return currentMeldPoints >= 60 && currentMeldPoints < 90 && handSize >= 8;
    } else if (requirement <= 120) {
      // Round 3: 120 points - definitely needs multiple melds
      // More aggressive - lower hand size requirement
      return currentMeldPoints >= 80 &&
          currentMeldPoints < 120 &&
          handSize >= 9;
    } else {
      // Round 4+: 150+ points - requires significant accumulation
      // More aggressive - lower requirements
      return currentMeldPoints >= 100 &&
          currentMeldPoints < requirement &&
          handSize >= 11;
    }
  }

  /// Calculate total points from all possible melds we could make right now
  int _calculateCurrentMeldPotential(Player bot, GameController controller) {
    int totalPoints = 0;

    // Points from cards we could add to existing melds
    final cardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
      bot,
      controller,
    );
    for (final addition in cardsToAdd) {
      final card = addition['card'] as PlayingCard;
      totalPoints += card.pointValue;
    }

    // Points from new melds we could create
    final possibleMelds = _meldAnalyzer.getPossibleMelds(bot, controller);
    for (final meld in possibleMelds) {
      int meldValue = 0;
      for (final card in meld) {
        meldValue += card.pointValue;
      }
      // Add book bonus if meld is large enough
      if (meld.length >= GameConfig.bookSize) {
        // Estimate if it would be clean or dirty (simplified)
        final hasWilds = meld.any((card) => card.isWild);
        meldValue += hasWilds
            ? GameConfig.dirtyBookBonus
            : GameConfig.cleanBookBonus;
      }
      totalPoints += meldValue;
    }

    return totalPoints;
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
    _inMultiMeldSequence = false;
  }

  /// Helper method to randomly select from a list of equally good options
  /// Adds decision variability to make bot behavior less predictable
  T _selectRandomly<T>(List<T> options) {
    if (options.isEmpty) {
      throw BotDecisionException('Cannot select from empty options list');
    }
    if (options.length == 1) {
      return options.first;
    }
    return options[_random.nextInt(options.length)];
  }

  /// Calculate time-based pressure: how worried should bot be about still being in hand
  double _calculateTimePressure(
    Player bot,
    int turnCount,
    BotPersonality personality,
  ) {
    // Base pressure increases linearly with turns
    double basePressure = turnCount / 10.0; // Moderate pressure after 10 turns

    // Personality modifiers
    switch (personality) {
      case BotPersonality.conservative:
        return basePressure * 0.7; // Less worried, can hold longer
      case BotPersonality.aggressive:
        return basePressure * 1.3; // More worried, wants to transition sooner
      case BotPersonality.bookBuilder:
        return basePressure * 0.8; // Slightly less worried, focused on books
      case BotPersonality.adaptive:
        return basePressure * 1.0; // Standard pressure
    }
  }

  /// Get personality-based hand size limit, adjusted for time pressure
  int _getPersonalityHoldingLimit(
    BotPersonality personality,
    double timePressure,
  ) {
    int baseLimit;

    switch (personality) {
      case BotPersonality.conservative:
        baseLimit = 14; // Reduced from 18 - more aggressive
        break;
      case BotPersonality.aggressive:
        baseLimit = 10; // Reduced from 14 - much more aggressive
        break;
      case BotPersonality.bookBuilder:
        baseLimit = 12; // Reduced from 16 - more aggressive
        break;
      case BotPersonality.adaptive:
        baseLimit = 12; // Reduced from 16 - more aggressive
        break;
    }

    // Reduce limit based on time pressure
    final pressureReduction = (timePressure * 5)
        .round(); // Up to 5 card reduction - more pressure
    return (baseLimit - pressureReduction).clamp(8, baseLimit);
  }

  /// Enhanced book completion strategy for competitive play
  bool _shouldHoldForBookCompletion(
    Player bot,
    GameState gameState,
    BotPersonality personality,
  ) {
    // Start considering book completion earlier (round 2+) for competitiveness
    if (gameState.round < 2) return false;

    // All personalities should consider book completion, not just BookBuilder
    bool shouldConsider = false;
    switch (personality) {
      case BotPersonality.bookBuilder:
        shouldConsider = true; // Always consider
        break;
      case BotPersonality.adaptive:
        shouldConsider = _random.nextDouble() > 0.2; // 80% chance
        break;
      case BotPersonality.conservative:
        shouldConsider = _random.nextDouble() > 0.4; // 60% chance
        break;
      case BotPersonality.aggressive:
        shouldConsider =
            _random.nextDouble() > 0.6; // 40% chance (focus on speed)
        break;
    }

    if (!shouldConsider) return false;

    // Enhanced book analysis - check both clean and dirty book requirements
    final bookStatus = _analyzeBookRequirements(bot);
    if (!bookStatus['hasNearCompleteBooks'] &&
        !bookStatus['needsBookBalance']) {
      return false;
    }

    // More aggressive about book completion when opponents are threatening
    _gameAnalyzer.updateOpponentAnalysis(gameState, bot);
    final opponentAnalysis = _gameAnalyzer.opponentAnalysis;

    // If any opponent is in foot with small hand, prioritize books more aggressively
    for (final analysis in opponentAnalysis.values) {
      if (analysis.hasPickedUpFoot && analysis.handSize <= 6) {
        return true; // Must complete books to have going out potential
      }
    }

    // Hold if we're close to completing books and in good position
    return bookStatus['hasNearCompleteBooks'] as bool;
  }

  /// Enhanced book requirements analysis for competitive play
  Map<String, dynamic> _analyzeBookRequirements(Player bot) {
    final analysis = <String, dynamic>{};

    // Count current book status
    int cleanBooks = 0;
    int dirtyBooks = 0;
    int nearCompleteBooks = 0;
    int nearCompleteCleanBooks = 0;
    int nearCompleteDirtyBooks = 0;

    for (final meld in bot.melds) {
      final isBook = meld.cards.length >= GameConfig.bookSize;
      final isNearComplete = meld.cards.length >= 6;

      if (isBook) {
        if (meld.isClean) {
          cleanBooks++;
        } else {
          dirtyBooks++;
        }
      } else if (isNearComplete) {
        nearCompleteBooks++;
        if (meld.isClean) {
          nearCompleteCleanBooks++;
        } else {
          nearCompleteDirtyBooks++;
        }
      }
    }

    // Strategic analysis for competitive play
    analysis['cleanBooks'] = cleanBooks;
    analysis['dirtyBooks'] = dirtyBooks;
    analysis['hasRequiredBooks'] = cleanBooks > 0 && dirtyBooks > 0;
    analysis['hasNearCompleteBooks'] = nearCompleteBooks > 0;
    analysis['needsCleanBook'] = cleanBooks == 0 && nearCompleteCleanBooks > 0;
    analysis['needsDirtyBook'] = dirtyBooks == 0 && nearCompleteDirtyBooks > 0;
    analysis['needsBookBalance'] =
        (cleanBooks == 0 && dirtyBooks > 0) ||
        (dirtyBooks == 0 && cleanBooks > 0);
    analysis['canGoOut'] = cleanBooks > 0 && dirtyBooks > 0;
    analysis['bookCompletionPotential'] = nearCompleteBooks;

    return analysis;
  }

  /// Assess threat level from opponents for competitive decision-making
  double _assessOpponentThreat(GameState gameState, Player botPlayer) {
    _gameAnalyzer.updateOpponentAnalysis(gameState, botPlayer);
    final opponentAnalysis = _gameAnalyzer.opponentAnalysis;

    if (opponentAnalysis.isEmpty) return 0.0;

    double maxThreat = 0.0;

    for (final analysis in opponentAnalysis.values) {
      double threat = 0.0;

      // Immediate threat - opponents in foot with few cards
      if (analysis.hasPickedUpFoot && analysis.handSize <= 3) {
        threat += 0.8; // Very high threat
      } else if (analysis.hasPickedUpFoot && analysis.handSize <= 6) {
        threat += 0.5; // High threat
      }

      // Development threat - opponents ahead in game phases
      if (analysis.hasPickedUpFoot && !botPlayer.hasPickedUpFoot) {
        threat += 0.3; // Ahead in development
      } else if (analysis.hasPlayedDown && !botPlayer.hasPlayedDown) {
        threat += 0.2; // Ahead in play-down
      }

      // Book completion threat
      if (analysis.hasNearCompleteBook) {
        threat += 0.2; // Close to completing books
      }

      // Score pressure
      if (analysis.score > botPlayer.score + 500) {
        threat += 0.1; // Score advantage
      }

      maxThreat = math.max(maxThreat, threat);
    }

    return maxThreat.clamp(0.0, 1.0);
  }

  /// NEW: Cached opponent pressure evaluation for performance
  BotDecision? _evaluateOpponentPressureWithCaching(
    Player bot,
    GameController controller,
    GameState gameState,
  ) {
    // Cache pressure analysis for performance (check max every 2 seconds)
    final now = DateTime.now();
    final lastCheck = _lastPressureAnalysis?[bot.id];

    if (lastCheck != null &&
        now.difference(lastCheck).inSeconds < 2 &&
        _cachedPressureResponse != null) {
      return _cachedPressureResponse![bot.id];
    }

    // Perform fresh analysis
    final result = _evaluateOpponentPressure(bot, controller, gameState);

    // Cache the result
    _lastPressureAnalysis ??= {};
    _cachedPressureResponse ??= {};
    _lastPressureAnalysis![bot.id] = now;
    _cachedPressureResponse![bot.id] = result;

    return result;
  }

  /// NEW: Evaluate opponent pressure and return competitive counter-strategy
  BotDecision? _evaluateOpponentPressure(
    Player bot,
    GameController controller,
    GameState gameState,
  ) {
    final humanPlayers = gameState.players.where(
      (p) => p.type == PlayerType.human,
    );

    for (final human in humanPlayers) {
      // THREAT 1: Human accumulation strategy (like the 35-card pattern we observed)
      if (human.currentHand.length >= GameConfig.humanAccumulationThreat &&
          !human.hasPlayedDown) {
        return _counterHumanAccumulation(bot, controller, gameState, human);
      }

      // THREAT 2: Human close to going out
      if (human.hasPickedUpFoot &&
          human.currentHand.length <= GameConfig.dangerousOpponentHandSize) {
        return _blockOpponentGoOut(bot, controller, gameState, human);
      }

      // THREAT 3: Human building books faster than us
      if (_isOpponentOutpacingBooks(bot, human)) {
        return _accelerateBookBuilding(bot, controller, gameState);
      }
    }

    return null; // No immediate pressure tactics needed
  }

  /// Counter human accumulation strategy - apply early pressure
  BotDecision? _counterHumanAccumulation(
    Player bot,
    GameController controller,
    GameState gameState,
    Player human,
  ) {
    final personality = _personalityManager.getPersonality(bot.id);

    // AGGRESSIVE BOTS: Speed demon counter-strategy
    if (personality == BotPersonality.aggressive) {
      return _executeSpeedDemonStrategy(bot, controller, gameState, human);
    }

    // OTHER BOTS: General counter-tactics
    if (gameState.turnPhase == TurnPhase.draw &&
        gameState.discardPile.length >= 6) {
      // Take large discard piles to deny accumulation opportunities
      if (bot.hasPlayedDown && controller.canUnlockDiscard()) {
        return BotDecision(action: 'drawFromDiscard');
      }
    }

    if (gameState.turnPhase == TurnPhase.meld &&
        bot.hasPickedUpFoot &&
        bot.currentHand.length <= 10) {
      // If we're in foot and human is still accumulating, rush to go out
      if (controller.canPlayerGoOut()) {
        // Try to go out immediately to cut off their strategy
        final possibleDiscards = bot.currentHand
            .where((card) => !card.isThree)
            .toList();
        if (possibleDiscards.isNotEmpty) {
          return BotDecision(action: 'goOut', data: possibleDiscards.first);
        }
      }
    }

    return null;
  }

  /// NEW: Speed demon strategy - end game before humans can accumulate
  BotDecision? _executeSpeedDemonStrategy(
    Player bot,
    GameController controller,
    GameState gameState,
    Player human,
  ) {
    // Strategy: Play down immediately, rush to foot, go out ASAP to prevent human accumulation

    if (!bot.hasPlayedDown) {
      // EMERGENCY: Play down with minimum points if human accumulating - but ensure rule compliance
      final possibleMelds = controller.findPossibleMelds(bot);
      if (possibleMelds.isNotEmpty) {
        // Find a meld that meets the minimum play-down requirement
        final gameState = controller.gameState;
        final playDownRequirement = gameState.playDownRequirement;

        for (final meld in possibleMelds) {
          final meldValue = meld.fold<int>(
            0,
            (sum, card) => sum + card.pointValue,
          );
          if (meldValue >= playDownRequirement) {
            return BotDecision(action: 'createMeld', data: meld);
          }
        }

        // If no single meld meets requirement, try multi-meld combination
        final bestCombination = _meldAnalyzer.findBestPlayDownCombination(
          bot,
          controller,
          playDownRequirement,
        );
        if (bestCombination.isNotEmpty) {
          return _executePlayDown(bestCombination);
        }
      }
    }

    if (bot.hasPlayedDown && !bot.hasPickedUpFoot && bot.isHandEmpty) {
      // Rush to foot immediately
      return BotDecision(action: 'pickUpFoot');
    }

    if (bot.hasPickedUpFoot && bot.currentHand.length <= 12) {
      // Aggressive go-out attempt - don't wait for perfect books
      if (controller.canPlayerGoOut()) {
        final possibleDiscards = bot.currentHand
            .where((card) => !card.isThree)
            .toList();
        if (possibleDiscards.isNotEmpty) {
          return BotDecision(action: 'goOut', data: possibleDiscards.first);
        }
      }

      // If can't go out, rush to complete minimum required books
      final cleanBooks = bot.melds
          .where((m) => m.cards.length >= 7 && m.isClean)
          .length;
      final dirtyBooks = bot.melds
          .where((m) => m.cards.length >= 7 && !m.isClean)
          .length;

      if (cleanBooks == 0 || dirtyBooks == 0) {
        // Rush to complete missing book type
        return _rushToCompleteRequiredBooks(bot, controller);
      }
    }

    // Take discard pile aggressively to speed up game
    if (gameState.turnPhase == TurnPhase.draw &&
        gameState.discardPile.length >= 4) {
      if (controller.canUnlockDiscard()) {
        return BotDecision(action: 'drawFromDiscard');
      }
    }

    return null;
  }

  /// Rush to complete required books for going out
  BotDecision? _rushToCompleteRequiredBooks(
    Player bot,
    GameController controller,
  ) {
    final cleanBooks = bot.melds
        .where((m) => m.cards.length >= 7 && m.isClean)
        .length;
    final dirtyBooks = bot.melds
        .where((m) => m.cards.length >= 7 && !m.isClean)
        .length;

    final needsClean = cleanBooks == 0;
    final needsDirty = dirtyBooks == 0;

    // Find near-complete melds of the needed type
    for (int i = 0; i < bot.melds.length; i++) {
      final meld = bot.melds[i];
      if (meld.cards.length >= 5) {
        // Near book
        final isClean = meld.isClean;

        if ((needsClean && isClean) || (needsDirty && !isClean)) {
          // Try to add cards to complete this book
          final addableCards = bot.currentHand.where(
            (card) => meld.canAddCard(card),
          );
          if (addableCards.isNotEmpty) {
            return BotDecision(
              action: 'addToMeld',
              data: {'meldIndex': i, 'card': addableCards.first},
            );
          }
        }
      }
    }

    // If no near-complete books, create new meld of needed type
    final possibleMelds = controller.findPossibleMelds(bot);
    for (final meld in possibleMelds) {
      final isClean = !meld.any((card) => card.isWild);
      if ((needsClean && isClean) || (needsDirty && !isClean)) {
        return BotDecision(action: 'createMeld', data: meld);
      }
    }

    return null;
  }

  // Getters for testing and debugging

  /// Block opponent from going out
  BotDecision? _blockOpponentGoOut(
    Player bot,
    GameController controller,
    GameState gameState,
    Player opponent,
  ) {
    // Strategy: If opponent is close to going out, take defensive actions

    if (gameState.turnPhase == TurnPhase.draw) {
      // Take discard pile to prevent opponent from using it
      if (gameState.discardPile.isNotEmpty && controller.canUnlockDiscard()) {
        return BotDecision(action: 'drawFromDiscard');
      }
    }

    if (gameState.turnPhase == TurnPhase.discard) {
      // Discard cards that are less useful to opponents
      final safestDiscard = _findSafestDiscardAgainstOpponent(bot, opponent);
      if (safestDiscard != null) {
        return BotDecision(action: 'discard', data: safestDiscard);
      }
    }

    return null;
  }

  /// Accelerate book building when opponent is outpacing us
  BotDecision? _accelerateBookBuilding(
    Player bot,
    GameController controller,
    GameState gameState,
  ) {
    if (gameState.turnPhase == TurnPhase.meld) {
      // Prioritize completing near-books over creating new melds
      for (int i = 0; i < bot.melds.length; i++) {
        final meld = bot.melds[i];
        if (meld.cards.length >= 5) {
          // Near-book
          final matchingCards = bot.currentHand
              .where((card) => meld.canAddCard(card))
              .toList();

          if (matchingCards.isNotEmpty) {
            return BotDecision(
              action: 'addToMeld',
              data: {'meldIndex': i, 'card': matchingCards.first},
            );
          }
        }
      }
    }

    return null;
  }

  /// Check if opponent is outpacing us in book building
  bool _isOpponentOutpacingBooks(Player bot, Player opponent) {
    final botBooks = bot.melds.where((Meld m) => m.cards.length >= 7).length;
    final opponentBooks = opponent.melds
        .where((Meld m) => m.cards.length >= 7)
        .length;

    // Opponent has more books, or same books but ahead in game phase
    return opponentBooks > botBooks ||
        (opponentBooks >= botBooks &&
            opponent.hasPickedUpFoot &&
            !bot.hasPickedUpFoot);
  }

  /// Find safest card to discard that minimizes opponent benefit
  PlayingCard? _findSafestDiscardAgainstOpponent(Player bot, Player opponent) {
    final possibleDiscards = bot.currentHand
        .where((card) => !card.isThree)
        .toList();

    if (possibleDiscards.isEmpty) return null;

    // Avoid discarding cards that opponent might need for their visible melds
    final opponentRanks = opponent.melds.map((m) => m.cards.first.rank).toSet();

    final saferDiscards = possibleDiscards
        .where((card) => !opponentRanks.contains(card.rank))
        .toList();

    if (saferDiscards.isNotEmpty) {
      return saferDiscards.first;
    }

    return possibleDiscards.first; // Fallback
  }

  /// Check if discard pile would significantly benefit opponents
  bool _pileWouldBenefitOpponents(
    List<PlayingCard> pile,
    GameState gameState,
    Player bot,
  ) {
    final opponents = gameState.players.where((p) => p.id != bot.id);

    for (final opponent in opponents) {
      // Check if pile contains cards that match opponent's visible melds
      final opponentRanks = opponent.melds
          .map((m) => m.cards.first.rank)
          .toSet();

      final beneficialCards = pile
          .where((card) => opponentRanks.contains(card.rank) || card.isWild)
          .length;

      // If more than 30% of pile would benefit opponent, consider taking it
      if (beneficialCards / pile.length > 0.3) {
        return true;
      }

      // If opponent is close to going out and pile has high-value cards
      if (opponent.hasPickedUpFoot && opponent.currentHand.length <= 8) {
        final highValueCards = pile
            .where((card) => card.pointValue > 10)
            .length;
        if (highValueCards >= 3) {
          return true; // Deny high-value cards to opponent close to going out
        }
      }
    }

    return false;
  }

  /// NEW: Dynamic adaptive personality adjustment based on opponent behavior
  void _applyAdaptivePersonalityAdjustment(Player bot, GameState gameState) {
    try {
      // Only apply to adaptive personality bots
      if (_personalityManager.getPersonality(bot.id) !=
          BotPersonality.adaptive) {
        return;
      }

      final humanPlayers = gameState.players.where(
        (p) => p.type == PlayerType.human,
      );

      // Only apply adaptive adjustments when there are human players (not in tests)
      if (humanPlayers.isEmpty) {
        return;
      }

      // Validate game state before making adaptations
      if (gameState.round < 1 || gameState.round > 10) {
        DebugLogger.botDebug(
          bot.id,
          bot.name,
          'Invalid round ${gameState.round}, skipping adaptive adjustment',
        );
        return;
      }

      for (final human in humanPlayers) {
        // ADAPTATION 1: Counter human accumulation with speed
        if (human.currentHand.length >= 20 &&
            !human.hasPlayedDown &&
            gameState.round <= 4) {
          // Human is accumulating - switch to aggressive mode to end game quickly
          _overrideAdaptiveConstants(bot, 'speed_counter', {
            'maxTurnsBeforeForcePlayDown': 1, // Strike fast
            'aggressivenessMultiplier': 1.8, // Be very aggressive
            'handPileValueThreshold': 20, // Take any pile to speed up
          });
          return;
        }

        // ADAPTATION 2: Match human book building with patience
        if (human.melds.length >= 8 && human.hasPlayedDown) {
          // Human is building many books - switch to book builder mode
          _overrideAdaptiveConstants(bot, 'book_matcher', {
            'maxTurnsBeforeForcePlayDown': 9, // Allow book building
            'bookCompletionPriority': 300, // Prioritize books heavily
            'aggressivenessMultiplier': 1.3, // Competitive book building
          });
          return;
        }

        // ADAPTATION 3: Outlast aggressive opponents
        if (human.hasPickedUpFoot &&
            human.currentHand.length <= 10 &&
            gameState.round <= 3) {
          // Human is playing aggressively - switch to defensive mode
          _overrideAdaptiveConstants(bot, 'defensive_counter', {
            'maxTurnsBeforeForcePlayDown': 6, // Be more patient
            'strategicBufferPoints': 25, // Wait for stronger position
            'aggressivenessMultiplier': 0.9, // Be more defensive
          });
          return;
        }
      }

      // Default adaptive behavior if no specific pattern detected
      _overrideAdaptiveConstants(bot, 'default_adaptive', {
        'maxTurnsBeforeForcePlayDown': 4,
        'aggressivenessMultiplier': 1.1,
      });
    } catch (e) {
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'Error in adaptive personality adjustment: $e',
      );
    }
  }

  /// Override adaptive bot constants for situational strategy
  void _overrideAdaptiveConstants(
    Player bot,
    String strategy,
    Map<String, dynamic> overrides,
  ) {
    // This would ideally modify the personality manager's constants for this bot
    // For now, we'll track the strategy and apply it in decision-making
    DebugLogger.botDebug(bot.id, bot.name, 'Adaptive strategy: $strategy');
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

/// Specific exception type for bot decision-making errors
class BotDecisionException implements Exception {
  final String message;

  const BotDecisionException(this.message);

  @override
  String toString() => 'BotDecisionException: $message';
}
