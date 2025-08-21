import 'dart:math';
import '../models/card.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../game/game_controller.dart';

class BotDecision {
  final String action;
  final dynamic data;
  final bool skipPlayDownCheck;

  BotDecision({
    required this.action,
    this.data,
    this.skipPlayDownCheck = false,
  });
}

class BotAI {
  final Random _random;

  // Multi-meld play-down state tracking
  List<List<PlayingCard>>? _plannedMelds;
  int _currentMeldIndex = 0;
  bool _inMultiMeldSequence = false;

  // Turn tracking for strategic play-down timing
  final Map<String, int> _playerTurnCounts = {};

  // Performance optimization - cache possible melds during decision cycle
  List<List<PlayingCard>>? _cachedPossibleMelds;
  String? _cachedPlayerId;

  // Initialize with optional seed for test reproducibility
  BotAI({int? seed}) : _random = seed != null ? Random(seed) : Random();

  // Public getters for debugging (test use only)
  List<List<PlayingCard>>? get plannedMelds => _plannedMelds;
  int get currentMeldIndex => _currentMeldIndex;
  bool get inMultiMeldSequence => _inMultiMeldSequence;

  // Strategic constants for better maintainability
  static const int strategicBufferPoints = 20;
  static const int minCardsForAggressiveUnlock = 3;
  static const int valuablePileThreshold =
      100; // More conservative - wait for better piles
  static const int largePileThreshold = 6; // Increased threshold
  static const int footPileValueThreshold = 50; // Increased from 30
  static const int footPileSizeThreshold = 3; // Increased from 2
  static const int handPileValueThreshold = 120; // Increased from 80
  static const int handPileSizeThreshold = 7; // Increased from 5
  static const int lowHandCardThreshold = 3;
  static const int meldRetentionThreshold = 5;
  static const int postPlaydownMeldValue = 50;
  static const int postPlaydownHandSize = 8;
  static const double highValuePairBreakChance = 0.2; // More conservative

  // New strategic constants
  static const int maxTurnsBeforeForcePlayDown = 5;
  static const int minimalPlayDownBuffer =
      5; // Just meet requirement + small buffer

  // Risk management thresholds
  static const int playDownRiskThreshold = -300;
  static const int footTransitionRiskThreshold = -200;
  static const int wildCardDiscardThreshold =
      10; // Much higher - wilds are valuable
  static const int strongPlayDownBuffer = 10;

  // Discard decision thresholds
  static const int veryLowValuePairThreshold = 5;
  static const int lowValuePairThreshold = 10;
  static const int emergencyMeldBreakThreshold =
      10; // Break small melds if needed

  // High round detection and thresholds
  static const int highRoundHandSizeThreshold = 15;
  static const int highRoundPlayDownThreshold = 120; // Round 3+
  static const int emergencyHandSizeThreshold = 20;
  static const int emergencyFootSizeThreshold = 15;
  static const int lowValueCardThreshold = 5;
  static const int mediumValueCardThreshold = 10;
  static const int highValueCardThreshold = 15;
  static const int smallMeldPointThreshold = 50;
  static const int meldBreakSafetyBuffer = 20;

  // Game rule constants
  static const int minCardsToUnlockDiscard = 2;
  static const int minCardsForFootTransition = 2;
  static const int bookMinSize = 7;
  static const int naturalBookBonus = 500;
  static const int mixedBookBonus = 300;
  static const int wildBookBonus = 1000;
  static const int minWildCardsForWildBook = 3;

  BotDecision makeDecision(Player bot, GameController controller) {
    final gameState = controller.gameState;

    // Track turn counts for strategic play-down timing
    _trackPlayerTurn(bot.id, gameState);

    // Clear cached melds if this is a different player or meld phase
    if (_cachedPlayerId != bot.id || gameState.turnPhase == TurnPhase.meld) {
      _cachedPossibleMelds = null;
      _cachedPlayerId = bot.id;
    }

    switch (gameState.turnPhase) {
      case TurnPhase.draw:
        return _makeDrawDecision(bot, controller);
      case TurnPhase.meld:
        return _makeMeldDecision(bot, controller);
      case TurnPhase.discard:
        return _makeDiscardDecision(bot, controller);
    }
  }

  void _trackPlayerTurn(String playerId, GameState gameState) {
    // Reset turn count when new round starts (when player hasn't played down)
    final currentPlayer = gameState.players.firstWhere((p) => p.id == playerId);
    if (!currentPlayer.hasPlayedDown) {
      _playerTurnCounts[playerId] = (_playerTurnCounts[playerId] ?? 0) + 1;
    } else {
      _playerTurnCounts[playerId] = 0; // Reset after playing down
    }
  }

  int _getTurnCount(String playerId) {
    return _playerTurnCounts[playerId] ?? 0;
  }

  /// Get possible melds with caching for performance optimization
  List<List<PlayingCard>> _getPossibleMelds(
    Player bot,
    GameController controller,
  ) {
    if (_cachedPossibleMelds == null || _cachedPlayerId != bot.id) {
      _cachedPossibleMelds = controller.findPossibleMelds(bot);
      _cachedPlayerId = bot.id;
    }
    return _cachedPossibleMelds!;
  }

  BotDecision _makeDrawDecision(Player bot, GameController controller) {
    final gameState = controller.gameState;

    // STRATEGIC CHANGE: Only unlock discard pile if we haven't played down yet
    // AND we can unlock, OR if already played down and it's very valuable
    if (gameState.canDrawFromDiscard) {
      final topDiscard = gameState.topDiscard!;

      // Count how many matching natural cards we have
      final matchingNaturals = bot.currentHand
          .where((card) => card.rank == topDiscard.rank && !card.isWild)
          .length;

      if (matchingNaturals >= minCardsToUnlockDiscard) {
        final discardPileValue = _calculateDiscardPileValue(
          gameState.discardPile,
        );
        final discardPileSize = gameState.discardPile.length;

        // If we haven't played down, be VERY conservative - only take exceptional piles
        if (!bot.hasPlayedDown) {
          // Only unlock if pile is exceptionally valuable
          if (discardPileValue > valuablePileThreshold * 1.5 ||
              discardPileSize >= largePileThreshold + 3) {
            return BotDecision(action: 'drawFromDiscard');
          }
        } else {
          // After playing down, more willing to take good piles for book building
          if (bot.hasPickedUpFoot) {
            // On foot - focus on book completion
            if (discardPileValue > footPileValueThreshold ||
                discardPileSize >= footPileSizeThreshold) {
              return BotDecision(action: 'drawFromDiscard');
            }
          } else {
            // Still on hand after playing down - moderate threshold
            if (discardPileValue > handPileValueThreshold ||
                discardPileSize >= handPileSizeThreshold) {
              return BotDecision(action: 'drawFromDiscard');
            }
          }
        }
      }
    }

    return BotDecision(action: 'drawFromDeck');
  }

  BotDecision _makeMeldDecision(Player bot, GameController controller) {
    // Check if we're in the middle of a multi-meld play-down sequence
    if (_plannedMelds != null && _currentMeldIndex < _plannedMelds!.length) {
      final nextMeld = _plannedMelds![_currentMeldIndex];
      _currentMeldIndex++;

      // If this was the last meld in the sequence, clear the state
      if (_currentMeldIndex >= _plannedMelds!.length) {
        _plannedMelds = null;
        _currentMeldIndex = 0;
        _inMultiMeldSequence = false;
      }

      return BotDecision(
        action: 'createMeld',
        data: nextMeld,
        skipPlayDownCheck: true,
      );
    }

    // New strategic decision tree: 1. Play down, 2. Go to foot, 3. Go out

    BotDecision result;

    // Priority 1: If not played down yet, check if we can/should play down
    if (!bot.hasPlayedDown) {
      result = _handlePlayDownDecision(bot, controller);
      if (result.action != 'error') {
        return result;
      }
    }

    // Priority 2: If on hand pile, check if we should transition to foot
    if (!bot.hasPickedUpFoot) {
      result = _handleFootTransitionDecision(bot, controller);
      if (result.action != 'error') {
        return result;
      }
    }

    // Priority 3: If on foot pile, check if we can go out
    result = _handleGoOutDecision(bot, controller);
    if (result.action != 'error') {
      return result;
    }

    // FAILSAFE: If all strategies fail/return error, discard if possible, otherwise error
    if (bot.currentHand.isEmpty) {
      return BotDecision(action: 'error'); // Cannot discard from empty hand
    }
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  BotDecision _makeDiscardDecision(Player bot, GameController controller) {
    final hand = bot.currentHand;
    if (hand.isEmpty) {
      return BotDecision(action: 'error');
    }

    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  int _calculateDiscardPileValue(List<PlayingCard> discardPile) {
    int value = 0;
    for (final card in discardPile) {
      value += card.pointValue;
    }
    return value;
  }

  List<Map<String, dynamic>> _findCardsToAddToExistingMelds(Player bot) {
    final cardsToAdd = <Map<String, dynamic>>[];

    for (int i = 0; i < bot.melds.length; i++) {
      final meld = bot.melds[i];
      for (final card in bot.currentHand) {
        if (meld.canAddCard(card)) {
          cardsToAdd.add({
            'meldIndex': i,
            'card': card,
            'priority': card.pointValue,
          });
        }
      }
    }

    cardsToAdd.sort((a, b) => b['priority'].compareTo(a['priority']));
    return cardsToAdd;
  }

  PlayingCard _chooseCardToDiscard(Player bot) {
    final hand = List<PlayingCard>.from(bot.currentHand);
    final wildCards = hand.where((c) => c.isWild).toList();
    final naturalCards = hand.where((c) => !c.isWild).toList();

    // Group natural cards by rank for analysis
    final cardsByRank = <CardRank, List<PlayingCard>>{};
    for (final card in naturalCards) {
      cardsByRank.putIfAbsent(card.rank, () => []).add(card);
    }

    // Try discard priorities in order
    PlayingCard? result;

    // Priority 1: Discard 3s strategically
    result = _tryDiscardThrees(bot, naturalCards);
    if (result != null) return result;

    // Priority 2-5: Handle natural cards by frequency
    result = _tryDiscardNaturalCards(bot, cardsByRank);
    if (result != null) return result;

    // Last resort: discard wild cards (very rarely)
    result = _tryDiscardWildCards(bot, wildCards);
    if (result != null) return result;

    // Fallback (should never happen) - but check for empty hand
    if (hand.isEmpty) {
      throw StateError('Bot has no cards to discard');
    }
    return hand.first;
  }

  /// Try to discard 3s strategically (ALWAYS priority - they're negative/penalty)
  PlayingCard? _tryDiscardThrees(Player bot, List<PlayingCard> naturalCards) {
    final threeCards = naturalCards
        .where((c) => c.rank == CardRank.three)
        .toList();

    if (threeCards.isEmpty) return null;

    // Sort by point value - discard black 3s first (most negative)
    threeCards.sort((a, b) => a.pointValue.compareTo(b.pointValue));
    return threeCards.first;
  }

  /// Try to discard natural cards - Adaptive based on game situation
  PlayingCard? _tryDiscardNaturalCards(
    Player bot,
    Map<CardRank, List<PlayingCard>> cardsByRank,
  ) {
    final cardCategories = _categorizeCardsByFrequency(cardsByRank);
    final singletons = cardCategories['singletons']!;
    final pairs = cardCategories['pairs']!;
    final handSize = bot.currentHand.length;
    final isHighRound = _isHighRoundSituation(bot, handSize);

    // Priority 2: Try to discard low-value singletons first
    final singletonResult = _tryDiscardSingletons(singletons, isHighRound);
    if (singletonResult != null) return singletonResult;

    // Priority 3: Try to break up pairs based on situation
    final pairResult = _tryDiscardPairs(bot, pairs, isHighRound);
    if (pairResult != null) return pairResult;

    // Priority 4: Emergency discard if too many cards
    final emergencyResult = _tryEmergencyDiscard(singletons, handSize);
    if (emergencyResult != null) return emergencyResult;

    return null; // Usually hold onto valuable cards
  }

  /// Check if we're in a high round situation requiring more flexible strategy
  bool _isHighRoundSituation(Player bot, int handSize) {
    return !bot.hasPlayedDown && handSize > highRoundHandSizeThreshold;
  }

  /// Try to discard singleton cards with appropriate value thresholds
  PlayingCard? _tryDiscardSingletons(
    List<PlayingCard> singletons,
    bool isHighRound,
  ) {
    final lowValueThreshold = isHighRound
        ? mediumValueCardThreshold
        : lowValueCardThreshold;
    final lowValueSingletons = singletons
        .where((card) => card.pointValue <= lowValueThreshold)
        .toList();
    if (lowValueSingletons.isNotEmpty) {
      lowValueSingletons.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return lowValueSingletons.first;
    }
    return null;
  }

  /// Try to discard from pairs based on game state and round
  PlayingCard? _tryDiscardPairs(
    Player bot,
    List<PlayingCard> pairs,
    bool isHighRound,
  ) {
    if (!bot.hasPlayedDown) {
      return _tryDiscardPairsBeforePlayDown(pairs, isHighRound);
    } else {
      return _tryDiscardPairsAfterPlayDown(pairs);
    }
  }

  /// Try to discard from pairs before playing down (more conservative)
  PlayingCard? _tryDiscardPairsBeforePlayDown(
    List<PlayingCard> pairs,
    bool isHighRound,
  ) {
    if (isHighRound) {
      // Higher rounds: be more willing to break up medium-value pairs
      final mediumPairs = pairs
          .where((card) => card.pointValue <= highValueCardThreshold)
          .toList();
      if (mediumPairs.isNotEmpty) {
        mediumPairs.sort((a, b) => a.pointValue.compareTo(b.pointValue));
        return mediumPairs.first;
      }
    } else {
      // Early rounds: only very low value pairs
      final veryLowPairs = pairs
          .where((card) => card.pointValue <= lowValueCardThreshold)
          .toList();
      if (veryLowPairs.isNotEmpty && _shouldBreakUpHighValuePair()) {
        veryLowPairs.sort((a, b) => a.pointValue.compareTo(b.pointValue));
        return veryLowPairs.first;
      }
    }
    return null;
  }

  /// Try to discard from pairs after playing down (more liberal)
  PlayingCard? _tryDiscardPairsAfterPlayDown(List<PlayingCard> pairs) {
    final lowPairs = pairs
        .where((card) => card.pointValue <= mediumValueCardThreshold)
        .toList();
    if (lowPairs.isNotEmpty) {
      lowPairs.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return lowPairs.first;
    }
    return null;
  }

  /// Emergency discard when hand is too large
  PlayingCard? _tryEmergencyDiscard(
    List<PlayingCard> singletons,
    int handSize,
  ) {
    if (handSize >= emergencyHandSizeThreshold && singletons.isNotEmpty) {
      singletons.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return singletons.first;
    }
    return null;
  }

  /// Try to discard wild cards (EXTREMELY conservative - absolute last resort)
  PlayingCard? _tryDiscardWildCards(Player bot, List<PlayingCard> wildCards) {
    if (wildCards.isEmpty) return null;

    // ONLY discard wilds in these emergency situations:
    // 1. We have 10+ wild cards (excessive hoarding)
    // 2. We have exactly 1 card left and must discard (going out impossible)
    // 3. We're on foot with 15+ cards and can't make any melds

    final handSize = bot.currentHand.length;
    final isOnFoot = bot.hasPickedUpFoot;

    // Emergency case 1: Excessive wild hoarding
    if (wildCards.length >= wildCardDiscardThreshold) {
      wildCards.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return wildCards.first;
    }

    // Emergency case 2: Must discard last card but can't go out
    if (handSize == 1 && !bot.canGoOut) {
      return wildCards.first;
    }

    // Emergency case 3: On foot with huge hand and no meld opportunities
    if (isOnFoot && handSize >= emergencyFootSizeThreshold) {
      // Only if we really can't use the wilds anywhere
      wildCards.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return wildCards.first;
    }

    return null; // Almost never discard wilds
  }

  bool _shouldBreakUpHighValuePair() {
    // Strategic chance to break up high-value pairs when no other options
    return _random.nextDouble() < highValuePairBreakChance;
  }

  /// Calculate total point value of cards in hand (negative for penalty cards)
  int _calculateHandValue(List<PlayingCard> hand) {
    int totalValue = 0;
    for (final card in hand) {
      totalValue += card.pointValue;
    }
    return totalValue;
  }

  /// Categorize cards by frequency for discard decision
  Map<String, List<PlayingCard>> _categorizeCardsByFrequency(
    Map<CardRank, List<PlayingCard>> cardsByRank,
  ) {
    final singletons = <PlayingCard>[];
    final pairs = <PlayingCard>[];
    final triples = <PlayingCard>[];

    for (final entry in cardsByRank.entries) {
      if (entry.key == CardRank.three) continue; // Skip 3s (handled elsewhere)

      if (entry.value.length == 1) {
        singletons.addAll(entry.value);
      } else if (entry.value.length == 2) {
        pairs.addAll(entry.value);
      } else if (entry.value.length >= 3) {
        triples.addAll(entry.value);
      }
    }

    return {'singletons': singletons, 'pairs': pairs, 'triples': triples};
  }

  /// Handle play-down decision with new strategic approach
  BotDecision _handlePlayDownDecision(Player bot, GameController controller) {
    final possibleMelds = _getPossibleMelds(bot, controller);
    final gameState = controller.gameState;
    final playDownRequirement = gameState.playDownRequirement;
    final turnCount = _getTurnCount(bot.id);

    // STRATEGIC CHANGE: Hold cards until turn 5, then play minimal points
    if (turnCount < maxTurnsBeforeForcePlayDown) {
      return _handleEarlyGamePlayDown(
        bot,
        controller,
        possibleMelds,
        playDownRequirement,
      );
    } else {
      return _handleLateGamePlayDown(possibleMelds, playDownRequirement);
    }
  }

  /// Handle early game play-down (before turn 5) - conservative strategy
  BotDecision _handleEarlyGamePlayDown(
    Player bot,
    GameController controller,
    List<List<PlayingCard>> possibleMelds,
    int playDownRequirement,
  ) {
    // Priority 1: Forced play-down after unlocking discard pile
    final forcedResult = _tryForcedPlayDown(
      bot,
      controller,
      possibleMelds,
      playDownRequirement,
    );
    if (forcedResult != null) return forcedResult;

    // Priority 2: Natural meld opportunity - play minimal points needed
    final naturalResult = _tryNaturalMeldPlayDown(
      possibleMelds,
      playDownRequirement,
    );
    if (naturalResult != null) return naturalResult;

    // Priority 3: HIGH ROUND STRATEGY - break up existing small melds if needed
    if (playDownRequirement > highRoundPlayDownThreshold) {
      // Later rounds (Round 3+)
      final meldBreakResult = _tryHighPointWildMeldForHighRounds(
        bot,
        controller,
        possibleMelds,
        playDownRequirement,
      );
      if (meldBreakResult != null) return meldBreakResult;
    }

    // Priority 4: Exceptional opportunity (way over requirement)
    final exceptionalResult = _tryExceptionalPlayDown(
      possibleMelds,
      playDownRequirement,
    );
    if (exceptionalResult != null) return exceptionalResult;

    // Otherwise, HOLD cards and discard strategically
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Handle late game play-down (turn 5+) - forced minimal play-down
  BotDecision _handleLateGamePlayDown(
    List<List<PlayingCard>> possibleMelds,
    int playDownRequirement,
  ) {
    // Turn 5+: Play down with minimal points to unlock discard pile ability
    final minimalResult = _tryMinimalPlayDown(
      possibleMelds,
      playDownRequirement,
    );
    if (minimalResult != null) return minimalResult;

    // Emergency fallback - must discard to complete turn
    // This should rarely happen since turn 5+ usually forces play-down
    return BotDecision(action: 'error'); // Will be caught by failsafe
  }

  /// Try forced play-down after unlocking discard pile
  BotDecision? _tryForcedPlayDown(
    Player bot,
    GameController controller,
    List<List<PlayingCard>> possibleMelds,
    int playDownRequirement,
  ) {
    final gameState = controller.gameState;
    final justUnlockedDiscard =
        gameState.hasDrawnFromDeck == false && gameState.discardPile.isNotEmpty;

    if (!justUnlockedDiscard) return null;

    // Forced to play down after unlocking discard pile
    final strategicPlayDown = _findStrategicPlayDown(
      bot,
      controller,
      possibleMelds,
    );
    if (strategicPlayDown.isNotEmpty) {
      return _executePlayDown(strategicPlayDown);
    }

    // Fallback: Find any meld that meets play-down requirement
    for (final meld in possibleMelds) {
      final meldPoints = meld.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      if (meldPoints >= playDownRequirement) {
        return BotDecision(action: 'createMeld', data: meld);
      }
    }

    return null;
  }

  /// Try natural meld play-down (no wilds) - play minimal points needed to unlock discard pickup
  BotDecision? _tryNaturalMeldPlayDown(
    List<List<PlayingCard>> possibleMelds,
    int playDownRequirement,
  ) {
    // Find all natural melds (no wild cards)
    final naturalMelds = possibleMelds
        .where((meld) => !meld.any((card) => card.isWild))
        .toList();

    if (naturalMelds.isEmpty) return null;

    // First try single natural melds that meet the requirement
    List<PlayingCard>? bestSingleMeld;
    int closestSinglePoints = playDownRequirement + 1000; // Start high

    for (final meld in naturalMelds) {
      final meldPoints = meld.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );

      // Must meet requirement and be closer to requirement than current best
      if (meldPoints >= playDownRequirement &&
          meldPoints < closestSinglePoints) {
        bestSingleMeld = meld;
        closestSinglePoints = meldPoints;
      }
    }

    // If we found a single natural meld that works, use it
    if (bestSingleMeld != null) {
      return BotDecision(action: 'createMeld', data: bestSingleMeld);
    }

    // If no single natural meld meets requirement, try natural multi-meld combinations
    final naturalMultiMeld = _findBestNaturalMeldCombination(
      naturalMelds,
      playDownRequirement,
    );

    if (naturalMultiMeld.isNotEmpty) {
      return _executePlayDown(naturalMultiMeld);
    }

    return null;
  }

  /// Try exceptional play-down (way over requirement)
  BotDecision? _tryExceptionalPlayDown(
    List<List<PlayingCard>> possibleMelds,
    int playDownRequirement,
  ) {
    final exceptionalThreshold = playDownRequirement + 100; // Very high bar

    for (final meld in possibleMelds) {
      final meldPoints = meld.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      if (meldPoints >= exceptionalThreshold) {
        return BotDecision(action: 'createMeld', data: meld);
      }
    }

    return null;
  }

  /// Try minimal play-down (just enough to meet requirement)
  BotDecision? _tryMinimalPlayDown(
    List<List<PlayingCard>> possibleMelds,
    int playDownRequirement,
  ) {
    // Find the meld closest to (but meeting) the requirement
    List<PlayingCard>? bestMeld;
    int closestPoints = playDownRequirement + 1000; // Start high

    for (final meld in possibleMelds) {
      final meldPoints = meld.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );

      // Must meet requirement and be closer to requirement than current best
      if (meldPoints >= playDownRequirement && meldPoints < closestPoints) {
        bestMeld = meld;
        closestPoints = meldPoints;
      }
    }

    if (bestMeld != null) {
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    return null;
  }

  /// NEW: Try high-value wild card melds for high round requirements
  ///
  /// NOTE: This method analyzes small existing melds that could theoretically be broken up
  /// but actually tries to create new wild-heavy melds to meet high point requirements.
  /// It does NOT actually break existing melds - that would require game controller support.
  BotDecision? _tryHighPointWildMeldForHighRounds(
    Player bot,
    GameController controller,
    List<List<PlayingCard>> possibleMelds,
    int playDownRequirement,
  ) {
    // Only consider this in higher rounds where requirements are tough
    if (bot.melds.isEmpty) return null;

    // Find small, low-value melds that we could break up
    final breakableMelds = <int>[];
    int totalBreakablePoints = 0;

    for (int i = 0; i < bot.melds.length; i++) {
      final meld = bot.melds[i];
      final meldPoints = meld.pointValue;

      // Only break up small melds (not books) and relatively low point value
      if (meld.cards.length < bookMinSize &&
          meldPoints <= smallMeldPointThreshold) {
        breakableMelds.add(i);
        totalBreakablePoints += meldPoints;
      }
    }

    if (breakableMelds.isEmpty) return null;

    // Calculate available points including wild cards (actual values: 2s=20, Jokers=50)
    final handPoints = _calculateHandValue(bot.currentHand);
    final wildCards = bot.currentHand.where((c) => c.isWild).toList();
    final wildCardPoints = wildCards.fold<int>(
      0,
      (sum, card) => sum + card.pointValue,
    );

    final potentialPoints = handPoints + totalBreakablePoints + wildCardPoints;

    // Only break melds if we can definitely meet the requirement
    if (potentialPoints >= playDownRequirement + meldBreakSafetyBuffer) {
      // For now, recommend using wild cards more aggressively
      // Try to create a meld using wilds to boost points
      final meldsWithWilds = possibleMelds
          .where((meld) => meld.any((card) => card.isWild))
          .toList();

      if (meldsWithWilds.isNotEmpty) {
        // Sort by point value, prioritize higher point melds
        meldsWithWilds.sort((a, b) {
          final aPoints = a.fold<int>(0, (sum, card) => sum + card.pointValue);
          final bPoints = b.fold<int>(0, (sum, card) => sum + card.pointValue);
          return bPoints.compareTo(aPoints);
        });

        final bestWildMeld = meldsWithWilds.first;
        final meldPoints = bestWildMeld.fold<int>(
          0,
          (sum, card) => sum + card.pointValue,
        );

        if (meldPoints >= playDownRequirement) {
          return BotDecision(action: 'createMeld', data: bestWildMeld);
        }
      }
    }

    return null;
  }

  /// Handle foot transition decision - NEW STRATEGY: Wait until can play all cards at once
  BotDecision _handleFootTransitionDecision(
    Player bot,
    GameController controller,
  ) {
    // STRATEGIC CHANGE: Try to play ALL remaining hand cards in one turn to go to foot

    // Check if we can meld/add all or most of our remaining cards
    final remainingCards = bot.currentHand.length;

    // If we have very few cards left (1-2), try to use them up
    if (remainingCards <= 2) {
      // Add to existing melds first
      final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
      if (cardsToAddToMelds.isNotEmpty) {
        final cardToAdd = cardsToAddToMelds.first;
        return BotDecision(action: 'addToMeld', data: cardToAdd);
      }
    }

    // Check if we can create melds that use up most/all remaining cards
    final canPlayAllCards = _canPlayMostCards(bot, controller);
    if (canPlayAllCards) {
      // Find the best meld opportunity to use maximum cards
      final possibleMelds = _getPossibleMelds(bot, controller);
      if (possibleMelds.isNotEmpty) {
        // Choose meld that uses most cards
        final bestMeld = _chooseLargestMeld(possibleMelds);
        return BotDecision(action: 'createMeld', data: bestMeld);
      }
    }

    // Emergency risk management - only if very negative hand
    final handValue = _calculateHandValue(bot.currentHand);
    if (handValue <= -100) {
      // Much more conservative threshold
      final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
      if (cardsToAddToMelds.isNotEmpty) {
        final cardToAdd = cardsToAddToMelds.first;
        return BotDecision(action: 'addToMeld', data: cardToAdd);
      }
    }

    // Otherwise, HOLD cards and discard strategically
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Handle go-out decision - Focus on book completion and strategic timing
  BotDecision _handleGoOutDecision(Player bot, GameController controller) {
    // STRATEGIC CHANGE: On foot, focus on completing books before going out

    // Check if we can go out immediately (with required books)
    if (bot.currentHand.isEmpty && bot.canGoOut) {
      return BotDecision(action: 'goOut');
    }

    // NEW STRATEGY: Only meld aggressively if we can complete books or go out soon
    final canCompleteBooks = _canCompleteRequiredBooks(bot, controller);

    if (canCompleteBooks) {
      // Priority 1: Focus on completing books (7+ cards) for maximum points
      final bookCompletionMove = _tryCompleteBooks(bot, controller);
      if (bookCompletionMove != null) return bookCompletionMove;

      // Priority 2: Add to existing melds to build toward books
      final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
      if (cardsToAddToMelds.isNotEmpty) {
        // Prioritize additions that move melds closer to book status (7 cards)
        final bookProgressAdd = _findBestBookProgressAddition(
          bot,
          cardsToAddToMelds,
        );
        if (bookProgressAdd != null) {
          return BotDecision(action: 'addToMeld', data: bookProgressAdd);
        }
        // Fallback to any addition
        return BotDecision(action: 'addToMeld', data: cardsToAddToMelds.first);
      }

      // Priority 3: Create new melds that can become books
      final possibleMelds = _getPossibleMelds(bot, controller);
      if (possibleMelds.isNotEmpty) {
        final bookPotentialMeld = _findBestBookPotentialMeld(possibleMelds);
        return BotDecision(action: 'createMeld', data: bookPotentialMeld);
      }
    } else {
      // Can't complete books easily - hold cards and wait for better opportunities
      // Only add to melds if it directly helps with going out
      if (bot.currentHand.length <= 3) {
        final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
        if (cardsToAddToMelds.isNotEmpty) {
          return BotDecision(
            action: 'addToMeld',
            data: cardsToAddToMelds.first,
          );
        }
      }
    }

    // Emergency case - hand empty but can't go out
    if (bot.currentHand.isEmpty && !bot.canGoOut) {
      return BotDecision(action: 'error');
    }

    // Discard conservatively
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Execute a play-down sequence (single or multi-meld)
  BotDecision _executePlayDown(List<List<PlayingCard>> strategicPlayDown) {
    if (strategicPlayDown.length > 1) {
      // Set up multi-meld sequence
      _plannedMelds = List.from(strategicPlayDown);
      _currentMeldIndex = 1;
      _inMultiMeldSequence = true;
      return BotDecision(
        action: 'createMeld',
        data: strategicPlayDown.first,
        skipPlayDownCheck: true,
      );
    } else {
      // Single meld play-down
      return BotDecision(action: 'createMeld', data: strategicPlayDown.first);
    }
  }

  /// Find natural meld opportunities (no wild cards)
  List<List<PlayingCard>> _findNaturalMeldOpportunities(
    Player bot,
    List<List<PlayingCard>> possibleMelds,
  ) {
    final naturalMelds = <List<PlayingCard>>[];

    for (final meld in possibleMelds) {
      final hasWildCards = meld.any((card) => card.isWild);
      if (!hasWildCards) {
        naturalMelds.add(meld);
      }
    }

    // Sort by length (prefer longer natural melds)
    naturalMelds.sort((a, b) => b.length.compareTo(a.length));
    return naturalMelds;
  }

  /// Check if bot can play most of their remaining cards
  bool _canPlayMostCards(Player bot, GameController controller) {
    final remainingCards = bot.currentHand.length;
    if (remainingCards <= 3) return true; // Few cards, try to use them

    // Count how many cards can be added to existing melds
    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
    final addableCards = cardsToAddToMelds.length;

    // Count cards in possible new melds
    final possibleMelds = controller.findPossibleMelds(bot);
    int meldableCards = 0;
    if (possibleMelds.isNotEmpty) {
      final bestMeld = _chooseLargestMeld(possibleMelds);
      meldableCards = bestMeld.length;
    }

    // Can we use 70%+ of remaining cards?
    final usableCards = addableCards + meldableCards;
    return usableCards >= (remainingCards * 0.7).floor();
  }

  /// Choose the meld that uses the most cards
  List<PlayingCard> _chooseLargestMeld(List<List<PlayingCard>> possibleMelds) {
    possibleMelds.sort((a, b) => b.length.compareTo(a.length));
    return possibleMelds.first;
  }

  /// Check if bot can complete the required clean and dirty books for going out
  bool _canCompleteRequiredBooks(Player bot, GameController controller) {
    int cleanBooks = 0;
    int dirtyBooks = 0;

    // Count existing books
    for (final meld in bot.melds) {
      if (meld.cards.length >= 7) {
        if (meld.isClean) {
          cleanBooks++;
        } else {
          dirtyBooks++;
        }
      }
    }

    // Check if we can potentially complete the missing books
    final needsCleanBook = cleanBooks == 0;
    final needsDirtyBook = dirtyBooks == 0;

    if (!needsCleanBook && !needsDirtyBook) {
      return true; // Already have required books
    }

    // Simple heuristic: if we have 5+ cards in hand and some melds close to books
    if (bot.currentHand.length >= 5) {
      final meldsCloseToBooks = bot.melds
          .where((m) => m.cards.length >= 5)
          .length;
      return meldsCloseToBooks > 0 ||
          _getPossibleMelds(bot, controller).isNotEmpty;
    }

    return false;
  }

  /// Try to complete books (7+ card melds)
  BotDecision? _tryCompleteBooks(Player bot, GameController controller) {
    // Look for melds that are close to becoming books (6 cards)
    for (int i = 0; i < bot.melds.length; i++) {
      final meld = bot.melds[i];
      if (meld.cards.length == 6) {
        // This meld is one card away from being a book - prioritize it
        for (final card in bot.currentHand) {
          if (meld.canAddCard(card)) {
            return BotDecision(
              action: 'addToMeld',
              data: {
                'meldIndex': i,
                'card': card,
                'priority': 1000, // High priority
              },
            );
          }
        }
      }
    }

    return null;
  }

  /// Find the best addition that progresses toward book completion
  Map<String, dynamic>? _findBestBookProgressAddition(
    Player bot,
    List<Map<String, dynamic>> cardsToAdd,
  ) {
    // Prioritize additions to melds that are closest to becoming books
    Map<String, dynamic>? bestAddition;
    int bestScore = -1;

    for (final addition in cardsToAdd) {
      final meldIndex = addition['meldIndex'] as int;
      final meld = bot.melds[meldIndex];

      // Score based on how close the meld is to becoming a book
      int score = meld.cards.length;
      if (meld.cards.length == 6) score += 100; // Almost a book!
      if (meld.cards.length >= 4) score += 50; // Good progress

      if (score > bestScore) {
        bestScore = score;
        bestAddition = addition;
      }
    }

    return bestAddition;
  }

  /// Find meld with best potential to become a book
  List<PlayingCard> _findBestBookPotentialMeld(
    List<List<PlayingCard>> possibleMelds,
  ) {
    // Prefer longer melds that are closer to book size (7 cards)
    possibleMelds.sort((a, b) {
      int scoreA = a.length;
      int scoreB = b.length;

      // Bonus for natural melds (cleaner books worth more points)
      if (!a.any((card) => card.isWild)) scoreA += 10;
      if (!b.any((card) => card.isWild)) scoreB += 10;

      return scoreB.compareTo(scoreA);
    });

    return possibleMelds.first;
  }

  /// Find the best natural meld combination that minimally meets the requirement
  List<List<PlayingCard>> _findBestNaturalMeldCombination(
    List<List<PlayingCard>> naturalMelds,
    int requirement,
  ) {
    if (naturalMelds.isEmpty) return [];

    // Try 2-meld combinations first (most common case)
    final twoCombination = _findTwoNaturalMeldCombination(
      naturalMelds,
      requirement,
    );
    if (twoCombination.isNotEmpty) return twoCombination;

    // Try 3-meld combinations if needed (less common)
    final threeCombination = _findThreeNaturalMeldCombination(
      naturalMelds,
      requirement,
    );
    if (threeCombination.isNotEmpty) return threeCombination;

    return [];
  }

  /// Find combination of exactly 2 natural melds that meets requirement with minimal excess
  List<List<PlayingCard>> _findTwoNaturalMeldCombination(
    List<List<PlayingCard>> naturalMelds,
    int requirement,
  ) {
    List<List<PlayingCard>> bestCombination = [];
    int closestPoints = requirement + 1000; // Start high

    for (int i = 0; i < naturalMelds.length; i++) {
      for (int j = i + 1; j < naturalMelds.length; j++) {
        final meld1 = naturalMelds[i];
        final meld2 = naturalMelds[j];

        // Check if the melds conflict (use same cards)
        if (_meldsConflict(meld1, meld2, 4)) continue; // Assume 4 decks

        final totalPoints =
            meld1.fold<int>(0, (sum, card) => sum + card.pointValue) +
            meld2.fold<int>(0, (sum, card) => sum + card.pointValue);

        if (totalPoints >= requirement && totalPoints < closestPoints) {
          closestPoints = totalPoints;
          // Return the combination with lower-point meld first (strategic)
          final points1 = meld1.fold<int>(
            0,
            (sum, card) => sum + card.pointValue,
          );
          final points2 = meld2.fold<int>(
            0,
            (sum, card) => sum + card.pointValue,
          );

          if (points1 <= points2) {
            bestCombination = [meld1, meld2];
          } else {
            bestCombination = [meld2, meld1];
          }
        }
      }
    }

    return bestCombination;
  }

  /// Find combination of exactly 3 natural melds that meets requirement
  List<List<PlayingCard>> _findThreeNaturalMeldCombination(
    List<List<PlayingCard>> naturalMelds,
    int requirement,
  ) {
    List<List<PlayingCard>> bestCombination = [];
    int closestPoints = requirement + 1000; // Start high

    for (int i = 0; i < naturalMelds.length; i++) {
      for (int j = i + 1; j < naturalMelds.length; j++) {
        for (int k = j + 1; k < naturalMelds.length; k++) {
          final meld1 = naturalMelds[i];
          final meld2 = naturalMelds[j];
          final meld3 = naturalMelds[k];

          // Check if any melds conflict
          if (_meldsConflict(meld1, meld2, 4) ||
              _meldsConflict(meld1, meld3, 4) ||
              _meldsConflict(meld2, meld3, 4)) {
            continue;
          }

          final totalPoints =
              meld1.fold<int>(0, (sum, card) => sum + card.pointValue) +
              meld2.fold<int>(0, (sum, card) => sum + card.pointValue) +
              meld3.fold<int>(0, (sum, card) => sum + card.pointValue);

          if (totalPoints >= requirement && totalPoints < closestPoints) {
            closestPoints = totalPoints;
            bestCombination = [meld1, meld2, meld3];
          }
        }
      }
    }

    return bestCombination;
  }

  /// Finds strategic multi-meld combinations for play-down that minimize points
  /// while retaining cards for discard pile unlocking opportunities
  List<List<PlayingCard>> _findStrategicPlayDown(
    Player bot,
    GameController controller,
    List<List<PlayingCard>> possibleMelds,
  ) {
    final playDownRequirement = controller.gameState.playDownRequirement;

    // Strategy: Find minimal point combinations that meet requirement
    // while maximizing cards kept for discard pile unlocking

    // Prefer natural melds over dirty melds
    final naturalMelds = _findNaturalMeldOpportunities(bot, possibleMelds);

    // Try natural melds first
    final naturalPlayDown = _findBestMeldCombination(
      naturalMelds,
      playDownRequirement,
      controller,
    );
    if (naturalPlayDown.isNotEmpty) {
      return naturalPlayDown;
    }

    // Fall back to mixed strategy if needed
    final bestCombination = _findBestMeldCombination(
      possibleMelds,
      playDownRequirement,
      controller,
    );

    return bestCombination;
  }

  /// Finds the best multi-meld combination that meets play-down requirement
  List<List<PlayingCard>> _findBestMeldCombination(
    List<List<PlayingCard>> possibleMelds,
    int requirement,
    GameController controller,
  ) {
    if (possibleMelds.isEmpty) return [];

    final deckCount = controller.gameState.players.length + 1;

    // Try 2-meld combinations first (most common case)
    final twoCombination = _findTwoMeldCombination(
      possibleMelds,
      requirement,
      deckCount,
    );
    if (twoCombination.isNotEmpty) return twoCombination;

    // Try 3-meld combinations if needed (less common)
    final threeCombination = _findThreeMeldCombination(
      possibleMelds,
      requirement,
      deckCount,
    );
    if (threeCombination.isNotEmpty) return threeCombination;

    // No valid combinations found
    return [];
  }

  /// Finds a combination of exactly 2 melds that meets the requirement
  List<List<PlayingCard>> _findTwoMeldCombination(
    List<List<PlayingCard>> possibleMelds,
    int requirement,
    int deckCount,
  ) {
    for (int i = 0; i < possibleMelds.length; i++) {
      for (int j = i + 1; j < possibleMelds.length; j++) {
        final meld1 = possibleMelds[i];
        final meld2 = possibleMelds[j];

        // Check if the melds conflict (use same cards)
        if (_meldsConflict(meld1, meld2, deckCount)) continue;

        final totalPoints =
            meld1.fold<int>(0, (sum, card) => sum + card.pointValue) +
            meld2.fold<int>(0, (sum, card) => sum + card.pointValue);

        if (totalPoints >= requirement) {
          // Return the combination with lower-point meld first (strategic)
          final points1 = meld1.fold<int>(
            0,
            (sum, card) => sum + card.pointValue,
          );
          final points2 = meld2.fold<int>(
            0,
            (sum, card) => sum + card.pointValue,
          );

          if (points1 <= points2) {
            return [meld1, meld2];
          } else {
            return [meld2, meld1];
          }
        }
      }
    }
    return [];
  }

  /// Finds a combination of exactly 3 melds that meets the requirement
  List<List<PlayingCard>> _findThreeMeldCombination(
    List<List<PlayingCard>> possibleMelds,
    int requirement,
    int deckCount,
  ) {
    for (int i = 0; i < possibleMelds.length; i++) {
      for (int j = i + 1; j < possibleMelds.length; j++) {
        for (int k = j + 1; k < possibleMelds.length; k++) {
          final meld1 = possibleMelds[i];
          final meld2 = possibleMelds[j];
          final meld3 = possibleMelds[k];

          // Check if any melds conflict
          if (_meldsConflict(meld1, meld2, deckCount) ||
              _meldsConflict(meld1, meld3, deckCount) ||
              _meldsConflict(meld2, meld3, deckCount)) {
            continue;
          }

          final totalPoints =
              meld1.fold<int>(0, (sum, card) => sum + card.pointValue) +
              meld2.fold<int>(0, (sum, card) => sum + card.pointValue) +
              meld3.fold<int>(0, (sum, card) => sum + card.pointValue);

          if (totalPoints >= requirement) {
            return [meld1, meld2, meld3];
          }
        }
      }
    }
    return [];
  }

  /// Checks if two melds conflict (use same cards)
  bool _meldsConflict(
    List<PlayingCard> meld1,
    List<PlayingCard> meld2,
    int deckCount,
  ) {
    // Create a map to count cards by rank+suit for each meld
    final meld1Cards = <String, int>{};
    final meld2Cards = <String, int>{};

    for (final card in meld1) {
      final key = '${card.rank.name}-${card.suit?.name ?? 'joker'}';
      meld1Cards[key] = (meld1Cards[key] ?? 0) + 1;
    }

    for (final card in meld2) {
      final key = '${card.rank.name}-${card.suit?.name ?? 'joker'}';
      meld2Cards[key] = (meld2Cards[key] ?? 0) + 1;
    }

    // Check if any card type would be over-used
    for (final entry in meld1Cards.entries) {
      final meld2Count = meld2Cards[entry.key] ?? 0;
      if (meld2Count > 0) {
        final totalNeeded = entry.value + meld2Count;

        // Determine max available cards for this rank+suit
        // Hand & Foot uses (players + 1) decks, each with standard card counts
        int maxAvailable;
        if (entry.key.contains('joker')) {
          maxAvailable = 2 * deckCount; // 2 jokers per standard deck
        } else {
          maxAvailable =
              4 * deckCount; // 4 cards per rank per deck (one per suit)
        }

        if (totalNeeded > maxAvailable) {
          return true; // Would exceed available cards
        }
      }
    }

    return false; // No conflicts detected
  }
}
