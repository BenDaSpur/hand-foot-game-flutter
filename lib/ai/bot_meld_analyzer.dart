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
  List<PlayingCard> chooseLargestMeld(List<List<PlayingCard>> possibleMelds) {
    if (possibleMelds.isEmpty) {
      throw ArgumentError('Cannot choose from empty meld list');
    }

    possibleMelds.sort((a, b) => b.length.compareTo(a.length));
    return possibleMelds.first;
  }

  /// Find the best meld based on multiple criteria (size, points, cleanliness)
  /// Now considers the bot's existing book balance to ensure both types are built
  List<PlayingCard> findBestMeld(
    List<List<PlayingCard>> possibleMelds, {
    bool preferClean = true,
    bool preferLarger = true,
    Player? bot,
  }) {
    if (possibleMelds.isEmpty) {
      throw ArgumentError('Cannot choose from empty meld list');
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

    // Base score from meld size
    if (preferLarger) {
      score += meld.length * 10;
    } else {
      score += minMeldSize * 10; // Prefer minimum viable melds
    }

    // Bonus for point value
    final pointValue = meld.fold<int>(0, (sum, card) => sum + card.pointValue);
    score += (pointValue / 10).floor();

    // Clean meld bonus
    final isClean = !meld.any((card) => card.isWild);

    // CRITICAL: Strongly prefer the book type we're missing
    if (needsCleanBookMore && isClean) {
      score +=
          cleanMeldBonus * 3; // Triple bonus for desperately needed clean meld
    } else if (needsDirtyBookMore && !isClean) {
      score +=
          cleanMeldBonus * 2; // Double bonus for desperately needed dirty meld
    } else if (isClean && preferClean) {
      score += cleanMeldBonus; // Normal clean bonus
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
          final priority = _calculateAdditionPriority(card, meld, i);
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
  int _calculateAdditionPriority(PlayingCard card, Meld meld, int meldIndex) {
    int priority = card.pointValue;

    // Bonus for book progression
    if (meld.cards.length == 6) {
      priority += 100; // Almost a book!
    } else if (meld.cards.length >= 4) {
      priority += 50; // Good progress
    }

    // Clean meld protection - prioritize natural cards for clean melds
    if (meld.isClean) {
      if (!card.isWild) {
        priority += 200; // Keep it clean
      } else {
        priority -= 100; // Penalty for making it dirty
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
  List<List<PlayingCard>> findBestPlayDownCombination(
    Player bot,
    GameController controller,
    int requirement,
  ) {
    final possibleMelds = getPossibleMelds(bot, controller);
    if (possibleMelds.isEmpty) return [];

    // Try single meld first
    for (final meld in possibleMelds) {
      final meldValue = calculateTotalMeldValue([meld]);
      if (meldValue >= requirement) {
        return [meld];
      }
    }

    // Try two-meld combinations
    for (int i = 0; i < possibleMelds.length; i++) {
      for (int j = i + 1; j < possibleMelds.length; j++) {
        final combination = [possibleMelds[i], possibleMelds[j]];
        final combinedValue = calculateTotalMeldValue(combination);
        if (combinedValue >= requirement) {
          return combination;
        }
      }
    }

    return []; // No combination meets requirement
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
