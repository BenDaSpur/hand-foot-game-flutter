import 'dart:math';
import '../models/card.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../game/game_controller.dart';

class BotDecision {
  final String action;
  final dynamic data;

  BotDecision({required this.action, this.data});
}

class BotAI {
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
        if (matchingNaturals >= 3 ||
            discardPileValue > 60 ||
            discardPileSize > 4) {
          return BotDecision(action: 'drawFromDiscard');
        }

        // On foot pile, be more willing to take smaller piles
        if (bot.hasPickedUpFoot &&
            (discardPileValue > 30 || discardPileSize > 2)) {
          return BotDecision(action: 'drawFromDiscard');
        }

        // Conservative threshold for hand pile (save unlocking for better opportunities)
        if (!bot.hasPickedUpFoot &&
            (discardPileValue > 80 || discardPileSize > 5)) {
          return BotDecision(action: 'drawFromDiscard');
        }
      }
    }

    return BotDecision(action: 'drawFromDeck');
  }

  BotDecision _makeMeldDecision(Player bot, GameController controller) {
    final possibleMelds = controller.findPossibleMelds(bot);

    // If player hasn't played down yet, use strategic multi-meld approach
    if (!bot.hasPlayedDown) {
      final strategicPlayDown = _findStrategicPlayDown(
        bot,
        controller,
        possibleMelds,
      );
      if (strategicPlayDown.isNotEmpty) {
        // Create the first meld from our strategic combination
        final firstMeld = _chooseBestMeld(strategicPlayDown);
        return BotDecision(action: 'createMeld', data: firstMeld);
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
    // 30% chance to break up high-value pairs when no other options
    return Random().nextDouble() < 0.3;
  }

  bool _shouldMeldAfterPlayDown(
    Player bot,
    GameController controller,
    List<List<PlayingCard>> possibleMelds,
  ) {
    if (possibleMelds.isEmpty) return false;

    // If we're close to running out of hand (3 or fewer cards), be aggressive
    if (bot.currentHand.length <= 3) {
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

        // Only meld if we have 5+ of this rank (keep 2 for potential unlock)
        if (totalOfThisRank >= 5) {
          return true;
        }
      }
      return false;
    }

    // On foot pile - more aggressive, but still strategic
    // Meld if we have high-value melds or many cards in hand
    final bestMeld = _chooseBestMeld(possibleMelds);
    final meldValue = _calculateMeldScore(bestMeld);

    return meldValue >= 50 || bot.currentHand.length > 8;
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

    // Try to find minimal combinations that meet play-down requirement
    final viableCombinations = <List<List<PlayingCard>>>[];

    // Strategy 1: Single meld if it barely exceeds requirement (avoid over-commitment)
    for (final points in sortedPoints) {
      if (points >= playDownRequirement && points <= playDownRequirement + 20) {
        // Only use single meld if it's close to requirement (not massive overkill)
        viableCombinations.add(meldsByPoints[points]!);
        break; // Take first minimal single meld option
      }
    }

    // Strategy 2: Multi-meld combinations (like 3 nines + 3 tens = 60)
    if (viableCombinations.isEmpty) {
      final combinations = _findMeldCombinations(
        meldsByPoints,
        playDownRequirement,
      );
      viableCombinations.addAll(combinations);
    }

    // Strategy 3: Evaluate unlock potential for each combination
    if (viableCombinations.isNotEmpty) {
      final bestCombination = _chooseBestStrategicCombination(
        bot,
        controller,
        viableCombinations,
      );
      return bestCombination;
    }

    return [];
  }

  /// Finds multi-meld combinations that meet play-down requirement
  List<List<List<PlayingCard>>> _findMeldCombinations(
    Map<int, List<List<PlayingCard>>> meldsByPoints,
    int requirement,
  ) {
    final combinations = <List<List<PlayingCard>>>[];
    final sortedPoints = meldsByPoints.keys.toList()..sort();

    // Try combinations of 2-3 melds
    for (int i = 0; i < sortedPoints.length; i++) {
      for (int j = i; j < sortedPoints.length; j++) {
        final points1 = sortedPoints[i];
        final points2 = sortedPoints[j];

        if (points1 + points2 >= requirement) {
          // Found 2-meld combination
          for (final meld1 in meldsByPoints[points1]!) {
            for (final meld2 in meldsByPoints[points2]!) {
              if (!_meldsConflict(meld1, meld2)) {
                combinations.add([meld1, meld2]);
              }
            }
          }
        }

        // Try 3-meld combinations
        for (int k = j; k < sortedPoints.length; k++) {
          final points3 = sortedPoints[k];
          if (points1 + points2 + points3 >= requirement) {
            for (final meld1 in meldsByPoints[points1]!) {
              for (final meld2 in meldsByPoints[points2]!) {
                for (final meld3 in meldsByPoints[points3]!) {
                  if (!_meldsConflict(meld1, meld2) &&
                      !_meldsConflict(meld1, meld3) &&
                      !_meldsConflict(meld2, meld3)) {
                    combinations.add([meld1, meld2, meld3]);
                  }
                }
              }
            }
          }
        }
      }
    }

    return combinations;
  }

  /// Checks if two melds conflict (use same cards)
  bool _meldsConflict(List<PlayingCard> meld1, List<PlayingCard> meld2) {
    for (final card1 in meld1) {
      for (final card2 in meld2) {
        if (card1.rank == card2.rank && card1.suit == card2.suit) {
          return true;
        }
      }
    }
    return false;
  }

  /// Chooses the best strategic combination based on unlock potential
  List<List<PlayingCard>> _chooseBestStrategicCombination(
    Player bot,
    GameController controller,
    List<List<List<PlayingCard>>> combinations,
  ) {
    if (combinations.isEmpty) return [];

    // Score each combination based on:
    // 1. Minimizes points used (keeps more cards)
    // 2. Maximizes discard pile unlock potential
    // 3. Preserves natural card diversity

    var bestCombination = combinations.first;
    var bestScore = double.negativeInfinity;

    for (final combination in combinations) {
      final score = _scoreCombination(bot, controller, combination);
      if (score > bestScore) {
        bestScore = score;
        bestCombination = combination;
      }
    }

    return bestCombination;
  }

  /// Scores a meld combination based on strategic value
  double _scoreCombination(
    Player bot,
    GameController controller,
    List<List<PlayingCard>> combination,
  ) {
    final usedCards = <PlayingCard>[];
    var totalPoints = 0;

    for (final meld in combination) {
      usedCards.addAll(meld);
      totalPoints += meld.fold<int>(0, (sum, card) => sum + card.pointValue);
    }

    final remainingCards = bot.currentHand
        .where(
          (card) => !usedCards.any(
            (used) => used.rank == card.rank && used.suit == card.suit,
          ),
        )
        .toList();

    var score = 0.0;

    // Prefer minimal point usage (keep more cards)
    score -= totalPoints * 0.1;

    // Bonus for retaining pairs (unlock potential)
    final remainingRanks = <CardRank, int>{};
    for (final card in remainingCards) {
      if (!card.isWild) {
        remainingRanks[card.rank] = (remainingRanks[card.rank] ?? 0) + 1;
      }
    }

    // Big bonus for keeping pairs (2+ of same rank for unlocking)
    for (final count in remainingRanks.values) {
      if (count >= 2) {
        score += count * 10.0; // Encourage keeping pairs
      }
    }

    // Bonus for keeping fewer but higher-count ranks vs many singletons
    score += remainingRanks.length * -5.0; // Prefer consolidation

    return score;
  }
}
