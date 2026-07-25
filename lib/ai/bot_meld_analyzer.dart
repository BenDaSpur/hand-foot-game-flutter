import '../models/player.dart';
import '../models/card.dart';
import '../models/meld.dart';
import '../game/game_controller.dart';
import '../config/game_config.dart';
import 'bot_config.dart';

/// Analyzes meld opportunities and calculations for bot players.
///
/// This class handles all meld-related analysis including finding possible melds,
/// calculating meld values, determining the best meld opportunities, and evaluating
/// cards that can be added to existing melds.
class BotMeldAnalyzer {
  // All constants now centralized in BotConfig

  /// Naturals-only pile (wilds contaminate toward a dirty book). Not the same as [Meld.isClean],
  /// which is only true for a **completed** clean book (7+ cards).
  static bool isAllNatural(Meld meld) =>
      !meld.cards.any((PlayingCard c) => c.isWild);

  /// Additions scored at or below this by [findCardsToAddToExistingMelds] are
  /// hard-blocked (they would poison a clean-book lane; blocks return -50000
  /// or -25000). Ordinary penalty stacks sum to roughly -13500 at worst, so
  /// this floor cleanly separates blocks from legitimate low-priority plays.
  /// Callers that take candidates unconditionally must filter these out.
  static const int hardBlockedAdditionPriorityFloor = -20000;

  /// Whether an addition candidate from [findCardsToAddToExistingMelds] is
  /// hard-blocked and must never be played.
  static bool isHardBlockedAddition(Map<String, dynamic> addition) {
    return (addition['priority'] as int? ?? 0) <=
        hardBlockedAdditionPriorityFloor;
  }

  /// MeldManager merges a "new" meld into an existing meld of the same rank,
  /// so a wild-containing candidate whose rank matches one of the bot's
  /// naturals-only piles would silently poison that clean-book lane.
  static bool newMeldPoisonsNaturalPile(
    Player bot,
    List<PlayingCard> meldCards,
  ) {
    if (!meldCards.any((c) => c.isWild)) {
      return false;
    }
    final naturalCard = meldCards.firstWhere(
      (c) => !c.isWild,
      orElse: () => meldCards.first,
    );
    if (naturalCard.isWild) {
      return false;
    }
    return bot.melds.any((m) => m.rank == naturalCard.rank && isAllNatural(m));
  }

  /// Keep the clean-book lane open at meld creation. While a played-down bot
  /// has no clean book, drop candidates that would poison an existing
  /// naturals-only pile and prefer wild-free candidates whenever a
  /// natural-only alternative exists (wilds belong in already-dirty piles).
  /// Analytics: session 17849474674147414 — the adaptive bot put wilds in
  /// every meld it created and could never go out.
  static List<List<PlayingCard>> filterCleanLaneMeldCandidates(
    Player bot,
    List<List<PlayingCard>> possibleMelds,
  ) {
    if (!bot.hasPlayedDown || bot.hasCleanBook || possibleMelds.isEmpty) {
      return possibleMelds;
    }

    final nonPoisoning = possibleMelds
        .where((meld) => !newMeldPoisonsNaturalPile(bot, meld))
        .toList();
    final candidates = nonPoisoning.isNotEmpty ? nonPoisoning : possibleMelds;

    final wildFree = candidates
        .where((meld) => !meld.any((card) => card.isWild))
        .toList();
    return wildFree.isNotEmpty ? wildFree : candidates;
  }

  // Cached results for performance
  List<List<PlayingCard>>? _cachedPossibleMelds;
  String? _cachedPlayerId;
  String? _cachedHandFingerprint;

  BotMeldAnalyzer();

  /// Get all possible melds for a bot player (with caching)
  List<List<PlayingCard>> getPossibleMelds(
    Player bot,
    GameController controller,
  ) {
    final handFingerprint = bot.currentHand
        .map((c) => '${c.rank.index}:${c.suit?.index ?? -1}')
        .join(',');

    // Use cached result only when player AND hand contents match
    if (_cachedPossibleMelds != null &&
        _cachedPlayerId == bot.id &&
        _cachedHandFingerprint == handFingerprint) {
      return _cachedPossibleMelds!;
    }

    // Calculate and cache new result
    _cachedPossibleMelds = controller.findPossibleMelds(bot);
    _cachedPlayerId = bot.id;
    _cachedHandFingerprint = handFingerprint;

    return _cachedPossibleMelds!;
  }

  /// Clear cached meld calculations (call when hand changes)
  void clearCache() {
    _cachedPossibleMelds = null;
    _cachedPlayerId = null;
    _cachedHandFingerprint = null;
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
          if (isAllNatural(meld)) {
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

    var candidateMelds = possibleMelds;
    if (needsCleanBookMore) {
      final cleanOnlyMelds = possibleMelds
          .where((meld) => !meld.any((card) => card.isWild))
          .toList();
      if (cleanOnlyMelds.isNotEmpty) {
        candidateMelds = cleanOnlyMelds;
      }
    }

    candidateMelds.sort((a, b) {
      int scoreA = _calculateMeldScore(
        a,
        preferClean,
        preferLarger,
        needsCleanBookMore: needsCleanBookMore,
        needsDirtyBookMore: needsDirtyBookMore,
        bot: bot,
      );
      int scoreB = _calculateMeldScore(
        b,
        preferClean,
        preferLarger,
        needsCleanBookMore: needsCleanBookMore,
        needsDirtyBookMore: needsDirtyBookMore,
        bot: bot,
      );
      return scoreB.compareTo(scoreA);
    });

    return candidateMelds.first;
  }

  /// Calculate a score for a meld based on various criteria
  int _calculateMeldScore(
    List<PlayingCard> meld,
    bool preferClean,
    bool preferLarger, {
    bool needsCleanBookMore = false,
    bool needsDirtyBookMore = false,
    Player? bot,
  }) {
    int score = 0;

    // Base score from meld size - ENHANCED for human-like aggressive building
    if (preferLarger) {
      score +=
          meld.length * 15; // INCREASED from 10 - prioritize larger melds more
    } else {
      score += BotConfig.minMeldSize * 10; // Prefer minimum viable melds
    }

    // Bonus for point value - ENHANCED
    final pointValue = meld.fold<int>(0, (sum, card) => sum + card.pointValue);
    score += (pointValue / 8).floor(); // INCREASED bonus (was /10)

    // NEW: Aggressive meld building bonus (human pattern showed 18+ melds)
    score += 25; // Base bonus for creating any meld (be more meld-aggressive)

    // Clean meld bonus
    final isClean = !meld.any((card) => card.isWild);
    final wildCount = meld.where((card) => card.isWild).length;

    // CRITICAL: Strongly prefer the book type we're missing
    if (needsCleanBookMore && isClean) {
      score +=
          BotConfig.cleanMeldBonus *
          5; // MASSIVE bonus for desperately needed clean meld
    } else if (needsDirtyBookMore && !isClean) {
      score +=
          BotConfig.cleanMeldBonus *
          2; // Double bonus for desperately needed dirty meld
    } else if (isClean && preferClean) {
      score += BotConfig.cleanMeldBonus; // Normal clean bonus
    }

    // ADDITIONAL: Heavily penalize creating dirty melds when no clean books exist
    if (needsCleanBookMore && !isClean) {
      score -= BotConfig.cleanMeldBonus * 3;
      score -= BotConfig.dirtyNewMeldWhenCleanBookNeededPenalty;
      score -= wildCount * BotConfig.cleanMeldBonus * 2;
    }

    // Book potential bonus - extra important for the type we need
    if (meld.length >= 5) {
      score += BotConfig.bookProgressBonus;
      if ((needsCleanBookMore && isClean) || (needsDirtyBookMore && !isClean)) {
        score +=
            BotConfig.bookProgressBonus * 2; // Extra bonus for needed book type
      }
    }

    // NEW: MASSIVE PENALTY for creating new melds with wild cards
    if (wildCount > 0) {
      // Hard-block candidates that would merge a wild into an existing
      // naturals-only pile (clean-book lane) — see newMeldPoisonsNaturalPile.
      if (bot != null && newMeldPoisonsNaturalPile(bot, meld)) {
        score -= 50000;
      }

      score -=
          wildCount *
          GameConfig
              .wildCardMeldPenalty; // Huge penalty per wild card in new meld

      // EVEN BIGGER penalty if we're creating a mostly-wild meld
      final naturalCount = meld.length - wildCount;
      if (wildCount >= naturalCount) {
        score -= 1000; // Don't create meld with more wilds than naturals
      }

      // STRATEGIC WILD DUMPING: If we're in critical situation and must use wilds, be smart
      if (bot != null && _isInCriticalWildDumpingSituation(bot)) {
        score += _calculateNewMeldWildDumpingBonus(meld, bot);
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

    // CRITICAL: Check clean book protection FIRST before any bonuses
    // Check if meld has no wild cards (potential clean meld/book)
    final meldHasNoWilds = isAllNatural(meld);
    if (card.isWild && bot != null && meldHasNoWilds) {
      final hasCleanBook = bot.hasCleanBook;

      // HARD BLOCK: Never contaminate a naturals-only pile while an
      // already-dirty meld can still legally accept this wild (analytics:
      // session 17849271160166016 — a bot poisoned its only clean-book lane
      // at foot transition despite four dirty melds with wild capacity).
      final dirtyMeldCanTakeWild = bot.melds.any(
        (m) => m != meld && m.cards.any((c) => c.isWild) && m.canAddCard(card),
      );
      if (dirtyMeldCanTakeWild) {
        return -50000;
      }

      // HARD BLOCK: Never contaminate any natural-only pile until a clean book exists
      // (humans complete clean books first ~77% of the time; bots were dirty-first ~80%).
      if (!hasCleanBook) {
        return -50000;
      }

      final cleanBookCount = bot.melds.where((m) => m.isClean).length;

      // With a clean book already secured, still protect additional large natural piles
      // when a smaller/already-dirty alternative exists for the wild.
      if (meld.cards.length >= 5 && cleanBookCount < 2) {
        final alternativeTargets = bot.melds
            .where(
              (m) =>
                  m != meld &&
                  m.canAddCard(card) &&
                  m.cards.length < meld.cards.length,
            )
            .toList();

        if (alternativeTargets.isNotEmpty) {
          return -50000; // Absolutely never do this when smaller alternatives exist
        }
      }

      // Strong protection for medium-sized clean melds too
      if (meld.cards.length >= 4 && cleanBookCount < 2) {
        final alternativeTargets = bot.melds
            .where(
              (m) => m != meld && m.canAddCard(card) && m.cards.length <= 3,
            )
            .toList();

        if (alternativeTargets.isNotEmpty) {
          return -25000; // Very strong protection when small alternatives exist
        }
      }
    }

    // NEW: ULTRA-AGGRESSIVE WILD CARD HOARDING STRATEGY
    if (card.isWild && bot != null) {
      // Count how many 2-card rank combinations we have (potential melds)
      final rankCounts = <CardRank, int>{};
      for (final handCard in bot.currentHand) {
        if (!handCard.isWild && !handCard.isThree) {
          rankCounts[handCard.rank] = (rankCounts[handCard.rank] ?? 0) + 1;
        }
      }

      final twoCardRanks = rankCounts.entries.where((e) => e.value >= 2).length;

      // MASSIVE penalty for using wilds unless absolutely necessary
      priority -=
          GameConfig.wildCardUsageBasePenalty; // Start with huge penalty

      // Determine if wild card usage is justified in current situation
      final criticalSituation = _isWildCardUsageCritical(bot, twoCardRanks);

      if (criticalSituation) {
        priority +=
            GameConfig.wildCardStrategicBonus; // Reduce penalty significantly
        // STRATEGIC WILD DUMPING: When we must use wilds, be smart about it
        priority += _calculateStrategicWildDumpingBonus(card, meld, bot);
      }

      // Apply situational modifiers (natural meld availability penalty, etc.)
      priority += _calculateWildCardSituationalModifier(bot, criticalSituation);
    }

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

    // ENHANCED Clean meld protection — use naturals-only (in-progress piles are not [Meld.isClean])
    final meldIsAllNatural = isAllNatural(meld);
    if (meldIsAllNatural) {
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
          priority -= GameConfig
              .cleanBookProtectionPenalty; // Never contaminate when no clean books exist
        }

        if (meld.cards.length >= 5) {
          priority -= 1000; // Never contaminate a near-complete clean meld
        }
      }
    }

    // Additional clean book protection penalties (backup to hard blocks above)
    if (card.isWild &&
        bot != null &&
        meldIsAllNatural &&
        meld.cards.length >= 3) {
      final cleanBookCount = bot.melds
          .where((m) => m.isClean && m.cards.length >= 7)
          .length;

      // Escalating penalties based on meld size and clean book deficit
      if (cleanBookCount == 0) {
        priority -= GameConfig.criticalCleanBookProtectionPenalty;
        if (meld.cards.length >= 5) {
          priority -= 2000; // Extra penalty for large clean melds
        }
      } else if (cleanBookCount < 2) {
        priority -= GameConfig.cleanBookProtectionPenalty;
        if (meld.cards.length >= 5) {
          priority -= 1000; // Extra penalty for large clean melds
        }
      }
    }

    // Discourage oversized books (8+ cards)
    if (meld.cards.length >= 8) {
      priority -= 50;
    }

    return priority;
  }

  /// Calculate strategic wild card dumping bonus when in critical situations
  int _calculateStrategicWildDumpingBonus(
    PlayingCard card,
    Meld meld,
    Player bot,
  ) {
    int bonus = 0;
    // Strategy 1: HAND PHASE - Prioritize smallest melds to concentrate wilds
    if (!bot.hasPickedUpFoot && bot.currentHand.length <= 4) {
      // Bonus for adding to smallest melds (concentrate wilds on fewer melds).
      // Naturals-only piles never get the tiny-meld bonus — small clean melds
      // are clean-book lanes, not wild dumping grounds.
      if (meld.cards.length <= 3) {
        if (!isAllNatural(meld)) {
          bonus += 800; // Big bonus for tiny already-dirty melds
        }
      } else if (meld.cards.length <= 5) {
        bonus += 400; // Medium bonus for small melds
      }
      // Penalty for adding to large melds (spread wilds out less)
      else if (meld.cards.length >= 7) {
        bonus -= 300; // Don't waste wilds on completed books
      }
    }
    // Strategy 2: FOOT PHASE - Prioritize completing books, but PROTECT clean books
    else if (bot.hasPickedUpFoot && bot.currentHand.length <= 6) {
      // Incomplete naturals-only piles are "clean builders"; mixed piles are dirty lanes
      final isNaturalOnlyMeld = isAllNatural(meld);
      final cleanBookCount = bot.melds
          .where((m) => m.isClean && m.cards.length >= 7)
          .length;

      // MASSIVE bonus for completing books (6 -> 7 cards)
      if (meld.cards.length == 6) {
        if (!isNaturalOnlyMeld) {
          bonus += 1500; // Huge bonus for dirty book completion
        } else {
          // For naturals-only melds, only give bonus if no smaller alternatives exist
          final smallerAlternatives = bot.melds
              .where(
                (m) => m != meld && m.canAddCard(card) && m.cards.length <= 4,
              )
              .toList();

          if (smallerAlternatives.isEmpty) {
            bonus +=
                1000; // Reduced bonus for clean book completion when necessary
          } else {
            bonus -= 500; // Penalty for contaminating when alternatives exist
          }
        }
      }
      // Good bonus for near-book melds (5 -> 6 cards)
      else if (meld.cards.length == 5) {
        if (!isNaturalOnlyMeld) {
          bonus += 800; // Getting close to dirty book
        } else {
          bonus += 400; // Reduced bonus for clean melds
        }
      }
      // Medium bonus for growing medium melds (4 -> 5 cards)
      else if (meld.cards.length == 4) {
        bonus += 400; // Building toward book
      }
      // REVISED: Bonus for tiny melds (prefer contaminating small melds)
      else if (meld.cards.length <= 3) {
        if (!isNaturalOnlyMeld) {
          bonus += 200; // Prefer already dirty small melds
        } else if (cleanBookCount == 0) {
          bonus -= 400; // Protect small clean melds when no clean books exist
        } else {
          bonus +=
              100; // Small bonus for small clean melds when we have clean books
        }
      }
    }

    // Strategy 3: Count existing wilds in meld - prefer melds that already have wilds
    final existingWilds = meld.cards.where((c) => c.isWild).length;
    if (existingWilds > 0) {
      bonus +=
          existingWilds *
          300; // Concentrate wilds on melds that already have them
    }

    return bonus;
  }

  /// Check if bot is in a critical situation where wild dumping strategy applies
  bool _isInCriticalWildDumpingSituation(Player bot) {
    // Same logic as in _calculateAdditionPriority but extracted for reuse

    // 1. Need to play down and have no natural options
    if (!bot.hasPlayedDown) {
      final rankCounts = <CardRank, int>{};
      for (final card in bot.currentHand) {
        if (!card.isWild && !card.isThree) {
          rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
        }
      }
      final naturalMeldCount = rankCounts.entries
          .where((e) => e.value >= 2)
          .length;
      if (naturalMeldCount == 0) return true;
    }
    // 2. Trying to get into foot (hand dumping)
    else if (!bot.hasPickedUpFoot && bot.currentHand.length <= 4) {
      return true;
    }
    // 3. End game — only "critical dump" when wilds help the *missing* book type.
    else if (bot.hasPickedUpFoot && bot.currentHand.length <= 6) {
      final hasCleanBook = bot.hasCleanBook;
      final hasDirtyBook = bot.hasDirtyBook;

      // Already have dirty books but no clean book — prioritize naturals; don't
      // treat normal foot play as permission to spam new dirty melds.
      if (!hasCleanBook && hasDirtyBook) {
        return bot.currentHand.length <= 2;
      }

      // Need both books and already building a strong naturals pile — stay off wild dumps.
      if (!hasCleanBook &&
          !hasDirtyBook &&
          bot.melds.any((m) => m.cards.length >= 4 && isAllNatural(m))) {
        return false;
      }

      if (!hasCleanBook || !hasDirtyBook) {
        return true;
      }
    }

    return false;
  }

  /// Calculate bonus for creating new melds with wilds in critical situations
  int _calculateNewMeldWildDumpingBonus(List<PlayingCard> meld, Player bot) {
    int bonus = 0;
    final wildCount = meld.where((c) => c.isWild).length;

    // Hand phase dumping: Prefer to create smaller concentrated wild melds
    if (!bot.hasPickedUpFoot && bot.currentHand.length <= 4) {
      // Bonus for concentrated wild usage (more wilds in fewer melds)
      if (wildCount >= 2) {
        bonus += wildCount * 400; // Bonus for concentrating wilds
      }

      // Prefer minimum viable melds (3 cards) to use fewer total cards
      if (meld.length == 3) {
        bonus += 300; // Efficient meld size
      }
    }
    // Foot phase dumping: Focus on book creation potential
    else if (bot.hasPickedUpFoot && bot.currentHand.length <= 6) {
      // Bonus for melds that could become books
      if (meld.length >= 4) {
        bonus += (meld.length - 3) * 200; // Larger melds closer to book status
      }

      // Extra bonus if this creates meld type we need
      final hasCleanBook = bot.melds.any(
        (m) => m.isClean && m.cards.length >= 7,
      );
      final hasDirtyBook = bot.melds.any(
        (m) => !m.isClean && m.cards.length >= 7,
      );
      final isClean = wildCount == 0;

      if (!hasCleanBook && isClean) {
        bonus += 600; // Need clean book
      } else if (!hasDirtyBook && !isClean) {
        bonus += 400; // Need dirty book
      }
    }

    return bonus;
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
      if (meldPoints >= BotConfig.weakMeldThreshold) {
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
    return bot.melds
        .where((meld) => meld.cards.length >= BotConfig.bookSize)
        .toList();
  }

  /// Count clean and dirty books
  Map<String, int> countBooks(Player bot) {
    int cleanBooks = 0;
    int dirtyBooks = 0;

    for (final meld in bot.melds) {
      if (meld.cards.length >= BotConfig.bookSize) {
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

    // EMERGENCY MODE: If bot has large hand but hasn't played down, be CONSERVATIVE
    final handSize = bot.currentHand.length;
    if (handSize >= 12 && !bot.hasPlayedDown) {
      // Even in emergency, prefer efficient play-down over dumping all cards
      // This prevents Sue from playing 3 melds when only 1 efficient meld is needed
      // Fall through to normal conservative logic below
    }
    // POST-PLAYDOWN: If already played down and hand is huge, be more aggressive
    else if (handSize >= 15 && bot.hasPlayedDown) {
      // Only use ALL melds if absolutely necessary for foot transition
      final allMeldsValue = calculateTotalMeldValue(possibleMelds);
      if (allMeldsValue >= requirement && possibleMelds.length <= 4) {
        // Reduced from 6 to 4 melds max to be less wasteful
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

  /// Calculate efficiency for play-down meld selection
  /// Higher efficiency = better choice for conservative play-down
  double _calculateMeldPlayDownEfficiency(
    List<PlayingCard> meld,
    int requirement,
    int meldValue,
  ) {
    double efficiency = 100.0; // Base efficiency

    // 1. Prefer melds closer to requirement (avoid over-melding)
    final excess = meldValue - requirement;
    if (excess == 0) {
      efficiency += 50.0; // Perfect match bonus
    } else {
      // Penalty for excess points (more excess = lower efficiency)
      efficiency -= (excess * 0.5); // 0.5 penalty per excess point
    }

    // 2. Strong preference for clean melds (no wilds)
    final hasWilds = meld.any((card) => card.isWild);
    if (!hasWilds) {
      efficiency += 30.0; // Clean meld bonus
    } else {
      efficiency -= 20.0; // Dirty meld penalty
    }

    // 3. Prefer minimum card count (efficiency bonus)
    if (meld.length == 3) {
      efficiency += 15.0; // Minimum size bonus
    } else if (meld.length >= 7) {
      efficiency += 10.0; // Book bonus (but less than minimum size)
    }

    // 4. Special bonus for using high-value cards efficiently
    // If using aces/kings for exact requirement, that's very efficient
    final avgCardValue = meldValue / meld.length;
    if (avgCardValue >= 20 && excess <= 10) {
      efficiency += 10.0; // High-value efficiency bonus
    }

    return efficiency;
  }

  /// Find the best combination of exactly N melds that meets the requirement
  List<List<PlayingCard>> _findBestCombinationOfSize(
    List<List<PlayingCard>> possibleMelds,
    int requirement,
    int combinationSize,
  ) {
    if (combinationSize == 1) {
      // Single meld - find the most EFFICIENT option for play-down
      List<PlayingCard>? bestMeld;
      double bestEfficiency = 0.0; // Higher efficiency is better

      for (final meld in possibleMelds) {
        final meldValue = calculateTotalMeldValue([meld]);
        if (meldValue >= requirement) {
          // Calculate efficiency: prefer melds closer to requirement + clean melds
          final efficiency = _calculateMeldPlayDownEfficiency(
            meld,
            requirement,
            meldValue,
          );
          if (efficiency > bestEfficiency) {
            bestMeld = meld;
            bestEfficiency = efficiency;
          }
        }
      }

      return bestMeld != null ? [bestMeld] : [];
    }

    if (combinationSize == 2) {
      // Two-meld combinations - find the most efficient option
      List<List<PlayingCard>>? bestCombination;
      double bestEfficiency = 0.0;

      for (int i = 0; i < possibleMelds.length; i++) {
        for (int j = i + 1; j < possibleMelds.length; j++) {
          final combination = [possibleMelds[i], possibleMelds[j]];
          final combinedValue = calculateTotalMeldValue(combination);
          if (combinedValue >= requirement) {
            // Calculate combined efficiency of both melds
            final efficiency1 = _calculateMeldPlayDownEfficiency(
              possibleMelds[i],
              requirement ~/ 2,
              calculateTotalMeldValue([possibleMelds[i]]),
            );
            final efficiency2 = _calculateMeldPlayDownEfficiency(
              possibleMelds[j],
              requirement ~/ 2,
              calculateTotalMeldValue([possibleMelds[j]]),
            );
            final combinedEfficiency = (efficiency1 + efficiency2) / 2;

            // Bonus for combination that's closer to requirement
            final excess = combinedValue - requirement;
            final adjustedEfficiency = combinedEfficiency - (excess * 0.3);

            if (adjustedEfficiency > bestEfficiency) {
              bestCombination = combination;
              bestEfficiency = adjustedEfficiency;
            }
          }
        }
      }

      return bestCombination ?? [];
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

  /// Check if wild card usage is justified in current game situation
  bool _isWildCardUsageCritical(Player bot, int twoCardRanks) {
    // 1. Need to play down and this is the ONLY way
    if (!bot.hasPlayedDown) {
      final naturalMeldCount = twoCardRanks;
      if (naturalMeldCount == 0) {
        return true; // Must use wilds to play down
      }
    }

    // 2. Trying to get into foot (hand almost empty)
    if (!bot.hasPickedUpFoot && bot.currentHand.length <= 4) {
      return true; // Dump strategy to reach foot
    }

    // 3. End game — align with [_isInCriticalWildDumpingSituation]
    if (bot.hasPickedUpFoot && bot.currentHand.length <= 6) {
      final hasCleanBook = bot.hasCleanBook;
      final hasDirtyBook = bot.hasDirtyBook;

      if (!hasCleanBook && hasDirtyBook) {
        return bot.currentHand.length <= 2;
      }

      if (!hasCleanBook &&
          !hasDirtyBook &&
          bot.melds.any((m) => m.cards.length >= 4 && isAllNatural(m))) {
        return false;
      }

      if (!hasCleanBook || !hasDirtyBook) {
        return true;
      }
    }

    // 4. Emergency situation (huge hand, late game)
    if (bot.currentHand.length >= 20) {
      return true; // Must reduce hand size
    }

    return false;
  }

  /// Calculate wild card situational modifier based on game context
  int _calculateWildCardSituationalModifier(
    Player bot,
    bool criticalSituation,
  ) {
    if (criticalSituation) {
      return GameConfig.wildCardStrategicBonus; // Reduce penalty significantly
    }

    // Extra penalty if we have many unused 2-card combinations
    final hand = bot.currentHand;
    final rankCounts = <CardRank, int>{};
    for (final card in hand) {
      if (!card.isWild && card.rank != CardRank.three) {
        rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
      }
    }

    final twoCardRanks = rankCounts.entries.where((e) => e.value >= 2).length;
    if (twoCardRanks >= 2) {
      return -GameConfig
          .cleanBookCompletionPriority; // You have natural melds available!
    }

    return 0; // No additional modifier
  }
}
