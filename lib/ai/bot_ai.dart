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

  // Initialize with optional seed for test reproducibility
  BotAI({int? seed}) : _random = seed != null ? Random(seed) : Random();

  // Public getters for debugging (test use only)
  List<List<PlayingCard>>? get plannedMelds => _plannedMelds;
  int get currentMeldIndex => _currentMeldIndex;
  bool get inMultiMeldSequence => _inMultiMeldSequence;

  // Strategic constants for better maintainability
  static const int strategicBufferPoints = 20;
  static const int aggressiveMatchingThreshold = 3;
  static const int valuablePileThreshold = 60;
  static const int largePileThreshold = 4;
  static const int footPileValueThreshold = 30;
  static const int footPileSizeThreshold = 2;
  static const int handPileValueThreshold = 80;
  static const int handPileSizeThreshold = 5;
  static const int lowHandCardThreshold = 3;
  static const int meldRetentionThreshold = 5;
  static const int postPlaydownMeldValue = 50;
  static const int postPlaydownHandSize = 8;
  static const double highValuePairBreakChance = 0.3;

  // Risk management thresholds
  static const int playDownRiskThreshold = -300;
  static const int footTransitionRiskThreshold = -200;
  static const int wildCardDiscardThreshold = 6;

  BotDecision makeDecision(Player bot, GameController controller) {
    final gameState = controller.gameState;

    switch (gameState.turnPhase) {
      case TurnPhase.draw:
        return _makeDrawDecision(bot, controller);
      case TurnPhase.meld:
        return _makeMeldDecision(bot, controller);
      case TurnPhase.discard:
        return _makeDiscardDecision(bot, controller);
    }
  }

  BotDecision _makeDrawDecision(Player bot, GameController controller) {
    final gameState = controller.gameState;

    // Check if we can unlock the discard pile
    if (gameState.canDrawFromDiscard) {
      final topDiscard = gameState.topDiscard!;

      // Count how many matching natural cards we have
      final matchingNaturals = bot.currentHand
          .where((card) => card.rank == topDiscard.rank && !card.isWild)
          .length;

      if (matchingNaturals >= 2) {
        final discardPileValue = _calculateDiscardPileValue(
          gameState.discardPile,
        );
        final discardPileSize = gameState.discardPile.length;

        // More aggressive if we have many matching cards or valuable pile
        if (matchingNaturals >= aggressiveMatchingThreshold ||
            discardPileValue > valuablePileThreshold ||
            discardPileSize > largePileThreshold) {
          return BotDecision(action: 'drawFromDiscard');
        }

        // On foot pile, be more willing to take smaller piles
        if (bot.hasPickedUpFoot &&
            (discardPileValue > footPileValueThreshold ||
                discardPileSize > footPileSizeThreshold)) {
          return BotDecision(action: 'drawFromDiscard');
        }

        // Conservative threshold for hand pile (save unlocking for better opportunities)
        if (!bot.hasPickedUpFoot &&
            (discardPileValue > handPileValueThreshold ||
                discardPileSize > handPileSizeThreshold)) {
          return BotDecision(action: 'drawFromDiscard');
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

    // Priority 1: If not played down yet, check if we can/should play down
    if (!bot.hasPlayedDown) {
      return _handlePlayDownDecision(bot, controller);
    }

    // Priority 2: If on hand pile, check if we should transition to foot
    if (!bot.hasPickedUpFoot) {
      return _handleFootTransitionDecision(bot, controller);
    }

    // Priority 3: If on foot pile, check if we can go out
    return _handleGoOutDecision(bot, controller);
  }

  BotDecision _makeDiscardDecision(Player bot, GameController controller) {
    final hand = bot.currentHand;
    if (hand.isEmpty) {
      return BotDecision(action: 'error');
    }

    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  List<PlayingCard> _chooseBestMeld(List<List<PlayingCard>> possibleMelds) {
    possibleMelds.sort((a, b) {
      final scoreA = _calculateMeldScore(a);
      final scoreB = _calculateMeldScore(b);
      return scoreB.compareTo(scoreA);
    });

    return possibleMelds.first;
  }

  int _calculateMeldScore(List<PlayingCard> cards) {
    int score = 0;
    for (final card in cards) {
      score += card.pointValue;
    }

    final naturalCards = cards.where((c) => !c.isWild).length;
    final wildCards = cards.where((c) => c.isWild).length;

    if (wildCards == 0 && cards.length >= 7) {
      score += 500;
    } else if (wildCards > 0 && wildCards < naturalCards && cards.length >= 7) {
      score += 300;
    } else if (wildCards >= 3 && naturalCards == 0 && cards.length >= 7) {
      score += 1000;
    }

    return score;
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

    // Separate wild cards and natural cards
    final wildCards = hand.where((c) => c.isWild).toList();
    final naturalCards = hand.where((c) => !c.isWild).toList();

    // Group natural cards by rank
    final cardsByRank = <CardRank, List<PlayingCard>>{};
    for (final card in naturalCards) {
      cardsByRank.putIfAbsent(card.rank, () => []).add(card);
    }

    // Priority 1: Discard 3s strategically
    final threeCards = naturalCards
        .where((c) => c.rank == CardRank.three)
        .toList();
    if (threeCards.isNotEmpty) {
      // If we're preparing to go to foot (hand is small), keep 3s as easy discards
      if (bot.hasPickedUpFoot || bot.currentHand.length <= 4) {
        // Sort by point value - discard red 3s first (more negative)
        threeCards.sort((a, b) => a.pointValue.compareTo(b.pointValue));
        return threeCards.first;
      }
      // Otherwise, discard 3s early to avoid penalties
      else {
        threeCards.sort((a, b) => a.pointValue.compareTo(b.pointValue));
        return threeCards.first;
      }
    }

    // Priority 2: Categorize cards by frequency
    final cardCategories = _categorizeCardsByFrequency(cardsByRank);
    final singletons = cardCategories['singletons']!;
    final pairs = cardCategories['pairs']!;
    final triples = cardCategories['triples']!;

    if (singletons.isNotEmpty) {
      // Sort by point value, prioritize low point cards
      singletons.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return singletons.first;
    }

    // Priority 3: Break up pairs strategically
    if (pairs.isNotEmpty) {
      // Sort pairs by point value
      pairs.sort((a, b) => a.pointValue.compareTo(b.pointValue));

      // If we haven't picked up foot yet, be very careful with pairs (unlock potential)
      if (!bot.hasPickedUpFoot && bot.hasPlayedDown) {
        // Only break up very low-value pairs (4-8 points)
        final veryLowValuePairs = pairs
            .where((c) => c.pointValue <= 5)
            .toList();
        if (veryLowValuePairs.isNotEmpty) {
          return veryLowValuePairs.first;
        }
        // Otherwise, don't break up pairs if we're still on hand pile
      } else {
        // On foot pile or haven't played down - normal pair breaking logic
        final lowValuePairs = pairs.where((c) => c.pointValue < 10).toList();
        if (lowValuePairs.isNotEmpty) {
          return lowValuePairs.first;
        }

        if (pairs.isNotEmpty && _shouldBreakUpHighValuePair()) {
          return pairs.first;
        }
      }
    }

    // Priority 4: Discard from triples+ (keeping the meld potential)
    if (triples.isNotEmpty) {
      triples.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return triples.first;
    }

    // Priority 5: If we must break up high-value pairs
    if (pairs.isNotEmpty) {
      pairs.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return pairs.first;
    }

    // Last resort: discard wild cards (VERY rarely - hold wilds strategically)
    // Only discard wilds if we have MANY or absolutely forced to (1 card left)
    if (wildCards.isNotEmpty &&
        (wildCards.length >= wildCardDiscardThreshold ||
            bot.currentHand.length == 1)) {
      wildCards.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return wildCards.first;
    }

    // Fallback (should never happen)
    return hand.first;
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

  /// Handle play-down decision - be strategic but not completely stubborn
  BotDecision _handlePlayDownDecision(Player bot, GameController controller) {
    final possibleMelds = controller.findPossibleMelds(bot);
    final gameState = controller.gameState;
    final playDownRequirement = gameState.playDownRequirement;

    // Priority 1: FORCED to play down after unlocking discard pile
    final justUnlockedDiscard =
        gameState.hasDrawnFromDeck == false && gameState.discardPile.isNotEmpty;

    if (justUnlockedDiscard) {
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
    }

    // Priority 2: Try strategic multi-meld play-down if available
    final strategicPlayDown = _findStrategicPlayDown(
      bot,
      controller,
      possibleMelds,
    );
    if (strategicPlayDown.isNotEmpty) {
      final totalPoints = strategicPlayDown.fold<int>(
        0,
        (sum, meld) =>
            sum +
            meld.fold<int>(0, (meldSum, card) => meldSum + card.pointValue),
      );

      if (totalPoints >= playDownRequirement) {
        return _executePlayDown(strategicPlayDown);
      }
    }

    // Priority 3: Play down if we have a decent single meld (10+ points over requirement)
    // This handles cases where the bot has a viable meld but hasn't unlocked discard
    final strongThreshold = playDownRequirement + 10;
    for (final meld in possibleMelds) {
      final meldPoints = meld.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      if (meldPoints >= strongThreshold) {
        return BotDecision(action: 'createMeld', data: meld);
      }
    }

    // Priority 4: Risk management - play down if we're about to go very negative
    final handValue = _calculateHandValue(bot.currentHand);
    if (handValue <= playDownRiskThreshold) {
      // Significant negative penalty risk
      final strategicPlayDown = _findStrategicPlayDown(
        bot,
        controller,
        possibleMelds,
      );
      if (strategicPlayDown.isNotEmpty) {
        return _executePlayDown(strategicPlayDown);
      }

      // Emergency fallback for negative risk
      for (final meld in possibleMelds) {
        final meldPoints = meld.fold<int>(
          0,
          (sum, card) => sum + card.pointValue,
        );
        if (meldPoints >= playDownRequirement) {
          return BotDecision(action: 'createMeld', data: meld);
        }
      }
    }

    // Otherwise, HOLD cards and proceed to discard
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Handle foot transition decision - VERY conservative, hold cards until ready
  BotDecision _handleFootTransitionDecision(
    Player bot,
    GameController controller,
  ) {
    // ONLY meld when we're getting close to going to foot and need to use wilds

    // Check if we're about to transition to foot (1-2 cards left)
    if (bot.currentHand.length <= 2) {
      // Now we need to be aggressive to use up remaining cards before foot transition
      final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
      if (cardsToAddToMelds.isNotEmpty) {
        final cardToAdd = cardsToAddToMelds.first;
        return BotDecision(action: 'addToMeld', data: cardToAdd);
      }

      // Try to create new melds to use up remaining cards
      final possibleMelds = controller.findPossibleMelds(bot);
      if (possibleMelds.isNotEmpty) {
        final bestMeld = _chooseBestMeld(possibleMelds);
        return BotDecision(action: 'createMeld', data: bestMeld);
      }
    }

    // Check for negative score risk management
    final handValue = _calculateHandValue(bot.currentHand);
    if (handValue <= footTransitionRiskThreshold) {
      // Moderate risk - start melding to reduce penalties
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

  /// Handle go-out decision - NOW be aggressive to use all cards and go out
  BotDecision _handleGoOutDecision(Player bot, GameController controller) {
    // On foot - be aggressive! Use wilds to dirty books if needed

    // Priority 1: Add cards to existing melds to clear hand
    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
    if (cardsToAddToMelds.isNotEmpty) {
      final cardToAdd = cardsToAddToMelds.first;
      return BotDecision(action: 'addToMeld', data: cardToAdd);
    }

    // Priority 2: Create new melds, including dirty books with wilds if needed
    final possibleMelds = controller.findPossibleMelds(bot);
    if (possibleMelds.isNotEmpty) {
      // Prefer natural melds first, but use dirty melds if we have excess wilds
      final naturalMelds = _findNaturalMeldOpportunities(bot, possibleMelds);
      final wildCards = bot.currentHand.where((c) => c.isWild).toList();

      if (naturalMelds.isNotEmpty) {
        return BotDecision(action: 'createMeld', data: naturalMelds.first);
      } else if (wildCards.length >= 3) {
        // We have many wilds - use them in dirty books to clear hand
        final bestMeld = _chooseBestMeld(possibleMelds);
        return BotDecision(action: 'createMeld', data: bestMeld);
      } else if (possibleMelds.isNotEmpty) {
        // Use any available meld
        final bestMeld = _chooseBestMeld(possibleMelds);
        return BotDecision(action: 'createMeld', data: bestMeld);
      }
    }

    // Check if we can go out
    if (bot.currentHand.isEmpty && bot.canGoOut) {
      return BotDecision(action: 'goOut');
    }

    if (bot.currentHand.isEmpty && !bot.canGoOut) {
      return BotDecision(action: 'error');
    }

    // Discard remaining cards
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

    // Try 2-meld combinations first (most common case)
    final twoCombination = _findTwoMeldCombination(possibleMelds, requirement);
    if (twoCombination.isNotEmpty) return twoCombination;

    // Try 3-meld combinations if needed (less common)
    final threeCombination = _findThreeMeldCombination(
      possibleMelds,
      requirement,
    );
    if (threeCombination.isNotEmpty) return threeCombination;

    // No valid combinations found
    return [];
  }

  /// Finds a combination of exactly 2 melds that meets the requirement
  List<List<PlayingCard>> _findTwoMeldCombination(
    List<List<PlayingCard>> possibleMelds,
    int requirement,
  ) {
    for (int i = 0; i < possibleMelds.length; i++) {
      for (int j = i + 1; j < possibleMelds.length; j++) {
        final meld1 = possibleMelds[i];
        final meld2 = possibleMelds[j];

        // Check if the melds conflict (use same cards)
        if (_meldsConflict(meld1, meld2)) continue;

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
  ) {
    for (int i = 0; i < possibleMelds.length; i++) {
      for (int j = i + 1; j < possibleMelds.length; j++) {
        for (int k = j + 1; k < possibleMelds.length; k++) {
          final meld1 = possibleMelds[i];
          final meld2 = possibleMelds[j];
          final meld3 = possibleMelds[k];

          // Check if any melds conflict
          if (_meldsConflict(meld1, meld2) ||
              _meldsConflict(meld1, meld3) ||
              _meldsConflict(meld2, meld3)) {
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
  bool _meldsConflict(List<PlayingCard> meld1, List<PlayingCard> meld2) {
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
        // Note: We use a conservative estimate since we don't have direct access to deck count here
        // In practice, conflicts are rare due to the large deck size in Hand & Foot
        int maxAvailable;
        if (entry.key.contains('joker')) {
          maxAvailable =
              8; // Conservative: 2 jokers × 4 decks (typical Hand & Foot setup)
        } else {
          maxAvailable =
              4; // Conservative: 1 per suit × 4 decks (typical Hand & Foot setup)
        }

        if (totalNeeded > maxAvailable) {
          return true; // Would exceed available cards
        }
      }
    }

    return false;
  }
}
