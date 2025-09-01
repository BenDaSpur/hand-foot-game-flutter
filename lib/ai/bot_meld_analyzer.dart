import '../models/player.dart';
import '../models/card.dart';
import '../models/meld.dart';
import '../game/game_controller.dart';
import '../config/game_config.dart';

/// Analyzes meld opportunities and calculations for bot players.
///
/// This class handles all meld-related analysis including finding possible melds,
/// calculating meld values, determining the best meld opportunities, and evaluating
/// cards that can be added to existing melds.
class BotMeldAnalyzer {
  // Meld evaluation constants
  static const int minMeldSize = 3;
  static const int weakMeldThreshold = 50;
  static const int strongMeldThreshold = 100;
  static const int bookSize = 7;
  static const int cleanMeldBonus = 50;
  static const int bookProgressBonus = 30;

  // Cached results for performance
  List<List<PlayingCard>>? _cachedPossibleMelds;
  String? _cachedPlayerId;

  BotMeldAnalyzer();

  /// Get all possible melds for a bot player (with caching)
  List<List<PlayingCard>> getPossibleMelds(
    Player bot,
    GameController controller,
  ) {
    // Use cached result if available for the same player
    if (_cachedPossibleMelds != null && _cachedPlayerId == bot.id) {
      return _cachedPossibleMelds!;
    }

    // Calculate and cache new result
    _cachedPossibleMelds = controller.findPossibleMelds(bot);
    _cachedPlayerId = bot.id;

    return _cachedPossibleMelds!;
  }

  /// Clear cached meld calculations (call when hand changes)
  void clearCache() {
    _cachedPossibleMelds = null;
    _cachedPlayerId = null;
  }

  /// Choose the largest meld from a list of possible melds
  List<PlayingCard>? chooseLargestMeld(List<List<PlayingCard>> possibleMelds) {
    if (possibleMelds.isEmpty) {
      return null; // Return null instead of throwing
    }

    possibleMelds.sort((a, b) => b.length.compareTo(a.length));
    return possibleMelds.first;
  }

  /// Find the best meld based on multiple criteria (size, points, cleanliness)
  /// ENHANCED with competitive human-like aggressive meld building
  List<PlayingCard> findBestMeld(
    List<List<PlayingCard>> possibleMelds, {
    bool preferClean = true,
    bool preferLarger = true,
    Player? bot,
    dynamic gameState,
  }) {
    if (possibleMelds.isEmpty) {
      return []; // Return empty list instead of throwing
    }

    // If bot is provided, check their book balance
    bool needsCleanBookMore = false;
    bool needsDirtyBookMore = false;

    if (bot != null) {
      int cleanBooks = 0;
      int dirtyBooks = 0;
      int cleanMeldsNearBook = 0; // 5-6 cards
      int dirtyMeldsNearBook = 0;

      for (final meld in bot.melds) {
        if (meld.cards.length >= 7) {
          if (meld.isClean) {
            cleanBooks++;
          } else {
            dirtyBooks++;
          }
        } else if (meld.cards.length >= 5) {
          if (meld.isClean) {
            cleanMeldsNearBook++;
          } else {
            dirtyMeldsNearBook++;
          }
        }
      }

      // Determine what type of book we need more urgently
      if (cleanBooks == 0 && dirtyBooks > 0) {
        needsCleanBookMore = true;
        preferClean = true; // Override preference
      } else if (dirtyBooks == 0 && cleanBooks > 0) {
        needsDirtyBookMore = true;
        preferClean = false; // Override preference
      } else if (cleanBooks == 0 && dirtyBooks == 0) {
        // Need both - check which we're closer to completing
        if (cleanMeldsNearBook > dirtyMeldsNearBook) {
          needsCleanBookMore = true; // Focus on clean since we're closer
        } else if (dirtyMeldsNearBook > cleanMeldsNearBook) {
          needsDirtyBookMore = true; // Focus on dirty since we're closer
        }
        // Otherwise maintain original preference
      }
    }

    possibleMelds.sort((a, b) {
      int scoreA = _calculateMeldScore(
        a,
        preferClean,
        preferLarger,
        needsCleanBookMore: needsCleanBookMore,
        needsDirtyBookMore: needsDirtyBookMore,
      );
      int scoreB = _calculateMeldScore(
        b,
        preferClean,
        preferLarger,
        needsCleanBookMore: needsCleanBookMore,
        needsDirtyBookMore: needsDirtyBookMore,
      );
      return scoreB.compareTo(scoreA);
    });

    return possibleMelds.first;
  }

  /// Calculate a score for a meld based on various criteria
  int _calculateMeldScore(
    List<PlayingCard> meld,
    bool preferClean,
    bool preferLarger, {
    bool needsCleanBookMore = false,
    bool needsDirtyBookMore = false,
  }) {
    int score = 0;

    // Base score from meld size - ENHANCED for human-like aggressive building
    if (preferLarger) {
      score +=
          meld.length * 15; // INCREASED from 10 - prioritize larger melds more
    } else {
      score += minMeldSize * 10; // Prefer minimum viable melds
    }

    // Bonus for point value - ENHANCED
    final pointValue = meld.fold<int>(0, (sum, card) => sum + card.pointValue);
    score += (pointValue / 8).floor(); // INCREASED bonus (was /10)

    // NEW: Aggressive meld building bonus (human pattern showed 18+ melds)
    score += 25; // Base bonus for creating any meld (be more meld-aggressive)

    // Clean meld bonus
    final isClean = !meld.any((card) => card.isWild);

    // CRITICAL: Strongly prefer the book type we're missing
    if (needsCleanBookMore && isClean) {
      score +=
          cleanMeldBonus * 5; // MASSIVE bonus for desperately needed clean meld
    } else if (needsDirtyBookMore && !isClean) {
      score +=
          cleanMeldBonus * 2; // Double bonus for desperately needed dirty meld
    } else if (isClean && preferClean) {
      score += cleanMeldBonus; // Normal clean bonus
    }

    // ADDITIONAL: Heavily penalize creating dirty melds when no clean books exist
    if (needsCleanBookMore && !isClean) {
      score -=
          cleanMeldBonus * 3; // Major penalty for wrong type when desperate
    }

    // Book potential bonus - extra important for the type we need
    if (meld.length >= 5) {
      score += bookProgressBonus;
      if ((needsCleanBookMore && isClean) || (needsDirtyBookMore && !isClean)) {
        score += bookProgressBonus * 2; // Extra bonus for needed book type
      }
    }

    return score;
  }

  /// Find all cards that can be added to existing melds
  List<Map<String, dynamic>> findCardsToAddToExistingMelds(
    Player bot,
    GameController controller,
  ) {
    final cardsToAdd = <Map<String, dynamic>>[];

    for (int i = 0; i < bot.melds.length; i++) {
      final meld = bot.melds[i];
      for (final card in bot.currentHand) {
        if (_canAddCardToMeld(card, meld)) {
          final priority = _calculateAdditionPriority(card, meld, i, bot: bot);
          cardsToAdd.add({
            'card': card,
            'meld': meld,
            'meldIndex': i,
            'priority': priority,
          });
        }
      }
    }

    // Sort by priority (highest first)
    cardsToAdd.sort((a, b) => b['priority'].compareTo(a['priority']));
    return cardsToAdd;
  }

  /// Calculate the priority score for adding a card to a meld
  int _calculateAdditionPriority(
    PlayingCard card,
    Meld meld,
    int meldIndex, {
    Player? bot,
  }) {
    int priority = card.pointValue;

    // Check if bot has clean books (for enhanced protection)
    bool hasCleanBook = false;
    if (bot != null) {
      hasCleanBook = bot.melds.any((m) => m.isClean && m.cards.length >= 7);
    }

    // Bonus for book progression
    if (meld.cards.length == 6) {
      priority += 100; // Almost a book!
    } else if (meld.cards.length >= 4) {
      priority += 50; // Good progress
    }

    // ENHANCED Clean meld protection - prioritize natural cards for clean melds
    if (meld.isClean) {
      if (!card.isWild) {
        priority += 200; // Keep it clean

        // CRITICAL: Extra bonus if we don't have a clean book yet
        if (meld.cards.length >= 4) {
          priority += 300; // Building toward essential clean book
        }

        // ULTRA-CRITICAL: If no clean books exist, heavily prioritize building one
        if (!hasCleanBook && meld.cards.length >= 3) {
          priority += 500; // Essential for going out
        }
      } else {
        // MUCH stronger penalty for making clean meld dirty
        priority -= 500; // Strong penalty for making it dirty

        // CRITICAL: Extremely harsh penalty if we have no clean books
        if (!hasCleanBook) {
          priority -= 2000; // Never contaminate when no clean books exist
        }

        if (meld.cards.length >= 5) {
          priority -= 1000; // Never contaminate a near-complete clean meld
        }
      }
    }

    // Discourage oversized books (8+ cards)
    if (meld.cards.length >= 8) {
      priority -= 50;
    }

    return priority;
  }

  /// Check if a card can be added to a specific meld
  bool _canAddCardToMeld(PlayingCard card, Meld meld) {
    if (meld.cards.isEmpty) return false;

    // Wild cards can usually be added (with limits)
    if (card.isWild) {
      final wildCount = meld.cards.where((c) => c.isWild).length;
      final naturalCount = meld.cards.length - wildCount;
      return wildCount < naturalCount; // Don't exceed natural count
    }

    // Natural cards must match the meld's rank
    final naturalCard = meld.cards.firstWhere(
      (c) => !c.isWild,
      orElse: () => meld.cards.first,
    );

    return card.rank == naturalCard.rank;
  }

  /// Check if bot has only weak meld opportunities
  bool hasOnlyWeakMeldOpportunities(Player bot, GameController controller) {
    final possibleMelds = getPossibleMelds(bot, controller);
    if (possibleMelds.isEmpty) return true;

    // Check if all possible melds are weak (low point value)
    for (final meld in possibleMelds) {
      final meldPoints = meld.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      if (meldPoints >= weakMeldThreshold) {
        return false; // Has at least one good meld
      }
    }

    return true; // All melds are weak
  }

  /// Find natural meld opportunities (no wild cards)
  List<List<PlayingCard>> findNaturalMeldOpportunities(
    Player bot,
    GameController controller,
  ) {
    final possibleMelds = getPossibleMelds(bot, controller);
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

  /// Find meld opportunities with wild cards
  List<List<PlayingCard>> findWildMeldOpportunities(
    Player bot,
    GameController controller,
  ) {
    final possibleMelds = getPossibleMelds(bot, controller);
    final wildMelds = <List<PlayingCard>>[];

    for (final meld in possibleMelds) {
      final hasWildCards = meld.any((card) => card.isWild);
      if (hasWildCards) {
        wildMelds.add(meld);
      }
    }

    // Sort by effectiveness (point value per wild card used)
    wildMelds.sort((a, b) {
      final aScore = _calculateWildMeldEffectiveness(a);
      final bScore = _calculateWildMeldEffectiveness(b);
      return bScore.compareTo(aScore);
    });

    return wildMelds;
  }

  /// Calculate the effectiveness of a meld that uses wild cards
  double _calculateWildMeldEffectiveness(List<PlayingCard> meld) {
    final wildCount = meld.where((card) => card.isWild).length;
    if (wildCount == 0) return 0.0;

    final totalPoints = meld.fold<int>(0, (sum, card) => sum + card.pointValue);
    return totalPoints / wildCount; // Points per wild card
  }

  /// Find melds with book potential (5-6 cards)
  List<Meld> findMeldsWithBookPotential(Player bot) {
    return bot.melds
        .where((meld) => meld.cards.length >= 5 && meld.cards.length <= 6)
        .toList();
  }

  /// Find existing books (7+ cards)
  List<Meld> findExistingBooks(Player bot) {
    return bot.melds.where((meld) => meld.cards.length >= bookSize).toList();
  }

  /// Count clean and dirty books
  Map<String, int> countBooks(Player bot) {
    int cleanBooks = 0;
    int dirtyBooks = 0;

    for (final meld in bot.melds) {
      if (meld.cards.length >= bookSize) {
        if (meld.isClean) {
          cleanBooks++;
        } else {
          dirtyBooks++;
        }
      }
    }

    return {'clean': cleanBooks, 'dirty': dirtyBooks};
  }

  /// Calculate the total point value of possible melds
  int calculateTotalMeldValue(List<List<PlayingCard>> melds) {
    int totalValue = 0;
    for (final meld in melds) {
      totalValue += meld.fold<int>(0, (sum, card) => sum + card.pointValue);
    }
    return totalValue;
  }

  /// Find the best combination of melds for play-down
  /// ENHANCED: Now supports 3, 4, 5+ meld combinations for aggressive hand emptying
  List<List<PlayingCard>> findBestPlayDownCombination(
    Player bot,
    GameController controller,
    int requirement,
  ) {
    final possibleMelds = getPossibleMelds(bot, controller);
    if (possibleMelds.isEmpty) return [];

    // AGGRESSIVE MODE: If bot has large hand, try to use ALL melds for foot transition
    final handSize = bot.currentHand.length;
    if (handSize >= 12 && bot.hasPlayedDown) {
      // Try to create ALL possible melds to aggressively empty hand
      final allMeldsValue = calculateTotalMeldValue(possibleMelds);
      if (allMeldsValue >= requirement && possibleMelds.length <= 6) {
        // Limit to 6 melds max to avoid UI/performance issues
        return possibleMelds;
      }
    }

    // Try progressively larger combinations (1, 2, 3, 4, 5 melds)
    for (
      int combinationSize = 1;
      combinationSize <= 5 && combinationSize <= possibleMelds.length;
      combinationSize++
    ) {
      final bestCombination = _findBestCombinationOfSize(
        possibleMelds,
        requirement,
        combinationSize,
      );
      if (bestCombination.isNotEmpty) {
        return bestCombination;
      }
    }

    return []; // No combination meets requirement
  }

  /// Find the best combination of exactly N melds that meets the requirement
  List<List<PlayingCard>> _findBestCombinationOfSize(
    List<List<PlayingCard>> possibleMelds,
    int requirement,
    int combinationSize,
  ) {
    if (combinationSize == 1) {
      // Single meld - simple iteration
      for (final meld in possibleMelds) {
        final meldValue = calculateTotalMeldValue([meld]);
        if (meldValue >= requirement) {
          return [meld];
        }
      }
      return [];
    }

    if (combinationSize == 2) {
      // Two-meld combinations - nested loops
      for (int i = 0; i < possibleMelds.length; i++) {
        for (int j = i + 1; j < possibleMelds.length; j++) {
          final combination = [possibleMelds[i], possibleMelds[j]];
          final combinedValue = calculateTotalMeldValue(combination);
          if (combinedValue >= requirement) {
            return combination;
          }
        }
      }
      return [];
    }

    // For 3+ melds, use recursive combination generation (with performance limits)
    if (possibleMelds.length >= combinationSize) {
      final combinations = _generateCombinations(
        possibleMelds,
        combinationSize,
      );

      // Limit combinations checked to prevent performance issues
      final maxCombinationsToCheck = (combinationSize <= 3) ? 50 : 20;
      final limitedCombinations = combinations
          .take(maxCombinationsToCheck)
          .toList();

      for (final combination in limitedCombinations) {
        final combinedValue = calculateTotalMeldValue(combination);
        if (combinedValue >= requirement) {
          return combination;
        }
      }
    }

    return [];
  }

  /// Generate all combinations of specified size from the list of melds
  List<List<List<PlayingCard>>> _generateCombinations(
    List<List<PlayingCard>> melds,
    int size,
  ) {
    final combinations = <List<List<PlayingCard>>>[];

    void generateCombinationsRecursive(
      List<List<PlayingCard>> current,
      int startIndex,
      int remainingSize,
    ) {
      if (remainingSize == 0) {
        combinations.add(List.from(current));
        return;
      }

      // Performance limit: stop if we have enough combinations
      if (combinations.length >= 100) return;

      for (int i = startIndex; i <= melds.length - remainingSize; i++) {
        current.add(melds[i]);
        generateCombinationsRecursive(current, i + 1, remainingSize - 1);
        current.removeLast();
      }
    }

    generateCombinationsRecursive([], 0, size);
    return combinations;
  }

  /// NEW: Find the maximum number of melds that can be created for hand emptying
  /// Used for aggressive foot transition - ignores point requirements
  List<List<PlayingCard>> findMaximalMeldCombination(
    Player bot,
    GameController controller,
  ) {
    final possibleMelds = getPossibleMelds(bot, controller);
    if (possibleMelds.isEmpty) return [];

    final handSize = bot.currentHand.length;

    // AGGRESSIVE FOOT TRANSITION: Try to use ALL melds if hand is large
    if (handSize >= 10 && possibleMelds.length >= 3) {
      // Check if we can avoid card overlap (simplified check)
      final totalCardsinMelds = possibleMelds.fold<int>(
        0,
        (sum, meld) => sum + meld.length,
      );

      // If melds use most of our hand, return all of them
      if (totalCardsinMelds >= (handSize * 0.7).round()) {
        return possibleMelds
            .take(5)
            .toList(); // Limit to 5 melds for UI performance
      }
    }

    // Otherwise, find the largest feasible combination
    for (int size = possibleMelds.length; size >= 1; size--) {
      if (size <= 5) {
        // Performance limit
        final combination = _findLargestValidCombination(possibleMelds, size);
        if (combination.isNotEmpty) {
          return combination;
        }
      }
    }

    return possibleMelds.take(1).toList(); // Fallback: at least one meld
  }

  /// Find the largest valid combination of melds without overlap
  List<List<PlayingCard>> _findLargestValidCombination(
    List<List<PlayingCard>> possibleMelds,
    int targetSize,
  ) {
    if (targetSize == 1) {
      return possibleMelds.isNotEmpty ? [possibleMelds.first] : [];
    }

    if (targetSize == 2 && possibleMelds.length >= 2) {
      // Simple two-meld combination
      return [possibleMelds[0], possibleMelds[1]];
    }

    // For 3+ melds, use combination generation with overlap checking
    final combinations = _generateCombinations(possibleMelds, targetSize);

    for (final combination in combinations.take(20)) {
      // Performance limit
      if (_hasMinimalCardOverlap(combination)) {
        return combination;
      }
    }

    return [];
  }

  /// Check if meld combination has minimal card overlap (simplified heuristic)
  bool _hasMinimalCardOverlap(List<List<PlayingCard>> meldCombination) {
    // Simplified check: assume minimal overlap if total cards < reasonable limit
    final totalCards = meldCombination.fold<int>(
      0,
      (sum, meld) => sum + meld.length,
    );

    // If we're trying to meld more cards than we have, there's likely significant overlap
    // This is a heuristic - exact overlap checking would be more complex
    return totalCards <= 20; // Reasonable hand size limit
  }

  /// Analyze hand composition for meld potential
  Map<String, dynamic> analyzeHandComposition(Player bot) {
    final hand = bot.currentHand;
    final rankCounts = <CardRank, int>{};
    int wildCount = 0;
    int threeCount = 0;

    for (final card in hand) {
      if (card.isWild) {
        wildCount++;
      } else if (card.rank == CardRank.three) {
        threeCount++;
      } else {
        rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
      }
    }

    // Find potential melds (ranks with 2+ naturals)
    final potentialMelds = rankCounts.entries
        .where((entry) => entry.value >= 2)
        .toList();

    return {
      'potentialMelds': potentialMelds.length,
      'wildCards': wildCount,
      'penaltyCards': threeCount,
      'strongRanks': rankCounts.entries
          .where((e) => e.value >= GameConfig.minTotalCardsForMeld)
          .length,
      'rankDistribution': rankCounts,
    };
  }

  /// Estimate meld potential score for strategic decisions
  int estimateMeldPotential(Player bot, GameController controller) {
    final composition = analyzeHandComposition(bot);
    final possibleMelds = getPossibleMelds(bot, controller);

    int score = 0;

    // Base score from possible melds
    score += possibleMelds.length * 20;

    // Bonus for total potential points
    score += calculateTotalMeldValue(possibleMelds);

    // Bonus for wild cards (flexibility)
    score += (composition['wildCards'] as int) * 15;

    // Penalty for penalty cards
    score -= (composition['penaltyCards'] as int) * 10;

    return score;
  }
}
