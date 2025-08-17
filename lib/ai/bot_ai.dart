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

    final possibleMelds = controller.findPossibleMelds(bot);

    // If player hasn't played down yet, use strategic multi-meld approach
    if (!bot.hasPlayedDown) {
      final strategicPlayDown = _findStrategicPlayDown(
        bot,
        controller,
        possibleMelds,
      );
      if (strategicPlayDown.isNotEmpty) {
        // Check if this is a multi-meld play-down
        if (strategicPlayDown.length > 1) {
          // Set up multi-meld sequence
          _plannedMelds = List.from(strategicPlayDown);
          _currentMeldIndex = 1; // We'll return the first one immediately
          _inMultiMeldSequence = true;
          return BotDecision(
            action: 'createMeld',
            data: strategicPlayDown.first,
            skipPlayDownCheck: true,
          );
        } else {
          // Single meld play-down
          return BotDecision(
            action: 'createMeld',
            data: strategicPlayDown.first,
          );
        }
      }
    } else {
      // Already played down - be more strategic about melding
      if (_shouldMeldAfterPlayDown(bot, controller, possibleMelds)) {
        final bestMeld = _chooseBestMeld(possibleMelds);
        return BotDecision(action: 'createMeld', data: bestMeld);
      }
    }

    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
    if (cardsToAddToMelds.isNotEmpty) {
      final cardToAdd = cardsToAddToMelds.first;
      return BotDecision(action: 'addToMeld', data: cardToAdd);
    }

    // No melds to make, proceed to discard
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

    // Priority 2: Discard singletons, but consider unlock potential
    final singletons = <PlayingCard>[];
    final pairs = <PlayingCard>[];
    final triples = <PlayingCard>[];

    for (final entry in cardsByRank.entries) {
      if (entry.key == CardRank.three) continue; // Already handled 3s

      if (entry.value.length == 1) {
        singletons.addAll(entry.value);
      } else if (entry.value.length == 2) {
        pairs.addAll(entry.value);
      } else if (entry.value.length >= 3) {
        triples.addAll(entry.value);
      }
    }

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

    // Last resort: discard wild cards (should rarely happen)
    if (wildCards.isNotEmpty) {
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

  bool _shouldMeldAfterPlayDown(
    Player bot,
    GameController controller,
    List<List<PlayingCard>> possibleMelds,
  ) {
    if (possibleMelds.isEmpty) return false;

    // If we're close to running out of hand, be aggressive
    if (bot.currentHand.length <= lowHandCardThreshold) {
      return true;
    }

    // If we haven't picked up our foot yet, be more conservative to keep unlock options
    if (!bot.hasPickedUpFoot) {
      // Only meld if we have 4+ of the same rank (keep some for unlocking)
      for (final meld in possibleMelds) {
        final naturalCards = meld.where((c) => !c.isWild).toList();
        if (naturalCards.isEmpty) continue;

        final rank = naturalCards.first.rank;
        final totalOfThisRank = bot.currentHand
            .where((c) => c.rank == rank && !c.isWild)
            .length;

        // Only meld if we have enough of this rank (keep 2 for potential unlock)
        if (totalOfThisRank >= meldRetentionThreshold) {
          return true;
        }
      }
      return false;
    }

    // On foot pile - more aggressive, but still strategic
    // Meld if we have high-value melds or many cards in hand
    final bestMeld = _chooseBestMeld(possibleMelds);
    final meldValue = _calculateMeldScore(bestMeld);

    return meldValue >= postPlaydownMeldValue ||
        bot.currentHand.length > postPlaydownHandSize;
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

    // Group possible melds by point value for analysis
    final meldsByPoints = <int, List<List<PlayingCard>>>{};
    for (final meld in possibleMelds) {
      final points = meld.fold<int>(0, (sum, card) => sum + card.pointValue);
      meldsByPoints.putIfAbsent(points, () => []).add(meld);
    }

    // Sort point values ascending (prefer lower point melds)
    final sortedPoints = meldsByPoints.keys.toList()..sort();

    // Strategy 1: Single meld if it meets requirement
    for (final points in sortedPoints) {
      if (points >= playDownRequirement) {
        // Return single meld as a list (for consistency with multi-meld)
        return [meldsByPoints[points]!.first];
      }
    }

    // Strategy 2: Multi-meld combinations
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
    // Hand & Foot uses 4 decks for 3 players (playerCount + 1)
    for (final entry in meld1Cards.entries) {
      final meld2Count = meld2Cards[entry.key] ?? 0;
      if (meld2Count > 0) {
        final totalNeeded = entry.value + meld2Count;

        // Determine max available cards for this rank+suit
        const deckCount = 4; // Assuming 3 players + 1 deck = 4 decks
        int maxAvailable;
        if (entry.key.contains('joker')) {
          maxAvailable = 2 * deckCount; // 2 jokers per deck
        } else {
          maxAvailable = deckCount; // 1 per suit per deck
        }

        if (totalNeeded > maxAvailable) {
          return true; // Would exceed available cards
        }
      }
    }

    return false;
  }
}
