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

    try {
      // DEBUG: Log decision context (removed in release builds)
      DebugLogger.botDebug(
        bot.id,
        bot.name,
        'makeDecision in phase ${gameState.turnPhase}',
      );

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

    // Evaluate discard pile opportunity
    if (gameState.discardPile.isNotEmpty && bot.hasPlayedDown) {
      try {
        final riskTolerance = _personalityManager.calculateRiskTolerance(
          gameState,
          bot,
        );

        if (_shouldTakeDiscardPile(bot, controller, riskTolerance) &&
            controller.gameState.canUnlockDiscard()) {
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
    if (_shouldHoldCardsStrategically(bot, controller)) {
      return BotDecision(action: 'noMeld');
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

    // Priority 3: Discard lowest value non-useful cards (avoid wilds if still on hand pile)
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
      // Add variability: if there are multiple singletons of the same low value, randomly pick one
      final bestValue = singletons.first.pointValue;
      final bestSingletons = singletons
          .where((card) => card.pointValue == bestValue)
          .toList();
      return _selectRandomly(bestSingletons);
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
    if (handSize >= 8 && unlockPotential >= 2) return true;

    // Hold based on round requirements - higher rounds need more accumulation
    final playDownRequirement = gameState.playDownRequirement;
    if (_shouldHoldForRoundRequirement(
      bot,
      controller,
      playDownRequirement,
      handSize,
    )) {
      return true;
    }

    // Strategic book completion: hold if we can complete books in later rounds
    if (_shouldHoldForBookCompletion(bot, gameState, personality)) {
      return true;
    }

    // Hold if we can potentially dump everything soon
    final dumpPotential = _calculateDumpPotential(bot, controller);
    if (dumpPotential >= 0.7) return true; // Can dump 70%+ of hand

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

    // Post-play-down: Execute if we can dump most of our hand
    final dumpPotential = _calculateDumpPotential(bot, controller);
    if (dumpPotential >= 0.8 && handSize >= 5) return true; // Can dump 80%+

    // Execute if hand is getting dangerously large
    if (handSize >= 15) return true;

    // NEW: Be more aggressive if on hand pile with wilds and close to foot
    if (stillOnHandPile && wildCards.isNotEmpty && handSize <= 8) {
      // If we have wilds and are close to foot, dump everything we can
      if (dumpPotential >= 0.6) return true; // Lower threshold with wilds
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
  /// Enhanced to maintain book balance (both clean and dirty books)
  BotDecision _executeDumpStrategy(Player bot, GameController controller) {
    // Check current book status
    int cleanBooks = 0;
    for (final meld in bot.melds) {
      if (meld.cards.length >= 7) {
        if (meld.isClean) {
          cleanBooks++;
        }
      }
    }

    // Priority 1: Add to existing melds first (highest efficiency)
    // But be strategic about which melds to add to
    final cardsToAdd = _meldAnalyzer.findCardsToAddToExistingMelds(
      bot,
      controller,
    );
    if (cardsToAdd.isNotEmpty) {
      // If we lack a clean book, avoid adding wilds to clean melds
      if (cleanBooks == 0) {
        for (final addition in cardsToAdd) {
          final meld = addition['meld'] as Meld;
          final card = addition['card'] as PlayingCard;
          // Prioritize keeping clean melds clean if we don't have a clean book yet
          if (meld.isClean && !card.isWild) {
            return BotDecision(action: 'addToMeld', data: addition);
          }
        }
      }
      // Otherwise take the first good addition
      return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
    }

    // Priority 2: Create new melds with book balance in mind
    final possibleMelds = _meldAnalyzer.getPossibleMelds(bot, controller);
    if (possibleMelds.isNotEmpty) {
      // Use the enhanced findBestMeld that considers book balance
      final bestMeld = _meldAnalyzer.findBestMeld(
        possibleMelds,
        bot: bot,
        preferLarger: true, // Still want large melds for dumping
      );
      return BotDecision(action: 'createMeld', data: bestMeld);
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
      if (matchingCards >= 2) potential++; // Can unlock

      // Bonus for each additional matching card (more flexible unlocking)
      potential += (matchingCards - 2).clamp(0, 3);
    }

    // General unlock potential (pairs that could match future discards)
    for (final count in rankCounts.values) {
      if (count >= 2) potential++; // Each pair increases unlock potential
    }

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

    // Round-specific holding strategy
    if (requirement <= 60) {
      // Round 1: 60 points - can often be done with 1 good meld
      // Hold if we're close but not quite there
      return currentMeldPoints >= 40 && currentMeldPoints < 60 && handSize >= 7;
    } else if (requirement <= 90) {
      // Round 2: 90 points - usually needs 2 melds
      // Hold more aggressively to get multiple meld opportunities
      return currentMeldPoints >= 50 && currentMeldPoints < 90 && handSize >= 9;
    } else if (requirement <= 120) {
      // Round 3: 120 points - definitely needs multiple melds
      // Hold even more cards for better combinations
      return currentMeldPoints >= 70 &&
          currentMeldPoints < 120 &&
          handSize >= 11;
    } else {
      // Round 4+: 150+ points - requires significant accumulation
      // Must hold many cards to have enough meld opportunities
      return currentMeldPoints >= 90 &&
          currentMeldPoints < requirement &&
          handSize >= 13;
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
        baseLimit = 18; // Can hold more cards
        break;
      case BotPersonality.aggressive:
        baseLimit = 14; // Holds fewer cards
        break;
      case BotPersonality.bookBuilder:
        baseLimit = 16; // Moderate holding for book building
        break;
      case BotPersonality.adaptive:
        baseLimit = 16; // Standard holding
        break;
    }

    // Reduce limit based on time pressure
    final pressureReduction = (timePressure * 4)
        .round(); // Up to 4 card reduction
    return (baseLimit - pressureReduction).clamp(12, baseLimit);
  }

  /// Should hold cards to complete books in later rounds as defensive strategy
  bool _shouldHoldForBookCompletion(
    Player bot,
    GameState gameState,
    BotPersonality personality,
  ) {
    // Only relevant in later rounds (3+) when someone might go out soon
    if (gameState.round < 3) return false;

    // BookBuilder personality is most likely to use this strategy
    if (personality != BotPersonality.bookBuilder &&
        _random.nextDouble() > 0.3) {
      return false; // 30% chance for other personalities
    }

    // Check if we have potential for completing books
    final nearCompleteBooks = _findNearCompleteBooks(bot);
    if (nearCompleteBooks.isEmpty) return false;

    // Hold if we can complete books and opponents might be close to going out
    _gameAnalyzer.updateOpponentAnalysis(gameState, bot);
    final opponentAnalysis = _gameAnalyzer.opponentAnalysis;

    // If any opponent has small hand, prioritize completing books defensively
    for (final analysis in opponentAnalysis.values) {
      if (analysis.handSize <= 5) {
        return nearCompleteBooks.isNotEmpty; // Complete at least one book
      }
    }

    return false;
  }

  /// Find melds that are close to becoming books (6 cards, need 1 more)
  List<Meld> _findNearCompleteBooks(Player bot) {
    final nearCompleteBooks = <Meld>[];

    for (final meld in bot.melds) {
      if (meld.cards.length == 6) {
        // One card away from book
        nearCompleteBooks.add(meld);
      }
    }

    return nearCompleteBooks;
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
