import '../models/card.dart';
import '../models/player.dart';
import '../models/meld.dart';
import '../models/game_state.dart';
import 'bot_game_analyzer.dart';
import 'bot_config.dart';
import 'bot_meld_analyzer.dart';

/// Analyzes discard decisions for bot players.
///
/// This class provides intelligent discard selection by considering:
/// - Card values and penalty costs
/// - What opponents are collecting (defensive discarding)
/// - Cards that don't fit the bot's strategy
/// - Near-book protection for opponents
class BotDiscardAnalyzer {
  // All constants now centralized in BotConfig

  BotDiscardAnalyzer();

  /// Whether wild cards must be kept while the bot is in foot without go-out books.
  static bool mustProtectWildsInFoot(Player bot) {
    return bot.hasPickedUpFoot && !bot.canGoOutWithBooks;
  }

  /// Whether wilds are off-limits as discards right now.
  ///
  /// Wilds are only spendable once the hand is down to
  /// [BotConfig.wildDiscardDesperationHandSize], and never while the bot is in
  /// foot still missing a required go-out book.
  static bool shouldProtectWilds(Player bot) {
    return mustProtectWildsInFoot(bot) ||
        bot.currentHand.length > BotConfig.wildDiscardDesperationHandSize;
  }

  /// Choose the best card to discard considering multiple factors.
  ///
  /// Returns the card that minimizes harm to the bot while avoiding
  /// helping opponents complete their books.
  PlayingCard chooseCardToDiscard(
    Player bot,
    GameState gameState, {
    BotGameAnalyzer? analyzer,
    bool preserveUnlockKeys = true,
  }) {
    if (bot.currentHand.isEmpty) {
      throw StateError('Cannot discard from empty hand');
    }

    // Wild protection has to be an exclusion rather than a score penalty:
    // opponent-feed penalties stack past -400, so a merely-discouraged wild
    // still wins the sort whenever every natural matches an opponent meld.
    var candidates = bot.currentHand;
    if (shouldProtectWilds(bot)) {
      final nonWilds = candidates.where((card) => !card.isWild).toList();
      if (nonWilds.isNotEmpty) {
        candidates = nonWilds;
      }
    }

    // Score each card (higher = more likely to discard)
    final scoredCards = <PlayingCard, int>{};

    for (final card in candidates) {
      scoredCards[card] = _calculateDiscardScore(
        card,
        bot,
        gameState,
        analyzer,
        preserveUnlockKeys: preserveUnlockKeys,
      );
    }

    // Sort by score (highest first = discard priority)
    final sortedCards = scoredCards.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedCards.first.key;
  }

  /// Calculate discard priority score for a card.
  /// Higher score = better candidate for discard.
  int _calculateDiscardScore(
    PlayingCard card,
    Player bot,
    GameState gameState,
    BotGameAnalyzer? analyzer, {
    bool preserveUnlockKeys = true,
  }) {
    int score = 0;

    // 1. PRIORITY: 3s should always be discarded (penalty cards)
    if (card.isThree) {
      // Red 3s are worse than black 3s
      if (card.isRed) {
        return BotConfig.threesPriority + 300; // Red 3 = -300 points
      }
      return BotConfig.threesPriority + 5; // Black 3 = -5 points
    }

    // 2. Base score from inverse point value (low value = good to discard)
    // Invert: high point cards (aces=20, wilds=50) get negative score.
    // Protected wilds never reach here — [chooseCardToDiscard] drops them.
    score += 50 - card.pointValue;

    // 3. DEFENSIVE: Check if opponents need this card (visible melds are
    // always scanned; the analyzer only adds tracked-rank intelligence)
    final opponentNeedScore = _calculateOpponentNeedScore(
      card,
      gameState,
      analyzer,
      bot.id,
    );
    score -= opponentNeedScore; // Reduce score if opponents need it

    // 4. STRATEGIC: Duplicate ranks — keep at least one 4–8 pair as a generic
    // unlock key. Humans dump *singletons* of those ranks, not their last pair
    // (analytics: 278+171 no-key draws after bots shed 4/5/7/8 pairs).
    final sameRankCount = bot.currentHand
        .where((c) => c.rank == card.rank && !c.isWild)
        .length;
    final handSize = bot.currentHand.length;
    if (sameRankCount >= 2) {
      if (handSize >= BotConfig.humanLargeHandDiscardThreshold &&
          _isHumanPreferredDiscardRank(card.rank) &&
          sameRankCount >= 3) {
        var protectedNearBook = false;
        for (final meld in bot.melds) {
          if (meld.cards.length >= 5 && _cardFitsMeld(card, meld)) {
            protectedNearBook = true;
            break;
          }
        }
        if (!protectedNearBook) {
          // 3+ copies: dump extras, keep a pair.
          score += BotConfig.humanLowRankDiscardBonus;
        } else {
          score -= BotConfig.duplicateBonus;
        }
      } else {
        score -= BotConfig.duplicateBonus * sameRankCount;
      }
    }

    // Human pattern: singleton low ranks on oversized hands
    if (!card.isWild &&
        handSize >= BotConfig.humanLargeHandDiscardThreshold &&
        _isHumanPreferredDiscardRank(card.rank) &&
        sameRankCount <= 1) {
      score += BotConfig.humanLowRankDiscardBonus;
    }

    // 5. MELD FIT: Don't discard cards that fit existing melds
    for (final meld in bot.melds) {
      if (_cardFitsMeld(card, meld)) {
        score -= 30; // Keep cards that can extend melds
      }
    }

    // 6. BOOK COMPLETION: Heavily penalize discarding cards near completing books
    for (final meld in bot.melds) {
      if (meld.cards.length >= 5 && _cardFitsMeld(card, meld)) {
        score -= 50; // Strong incentive to keep near-book cards
      }
    }

    // 7. UNLOCK KEYS: Keep 2+ matching naturals for an attractive discard pile
    // (also before play-down — keys are needed immediately after playing down).
    // Skip when caller force-spends keys (pile frozen / declined / useless top).
    if (preserveUnlockKeys &&
        !gameState.discardPileFrozen &&
        !card.isWild &&
        !card.isThree &&
        gameState.discardPile.isNotEmpty) {
      final top = gameState.topDiscard;
      if (top != null && !top.isWild && !top.isThree && card.rank == top.rank) {
        final matchingNaturals = bot.currentHand
            .where((c) => c.rank == top.rank && !c.isWild)
            .length;
        final pileSize = gameState.discardPile.length;
        final minPile = bot.hasPlayedDown
            ? BotConfig.preserveUnlockKeysMeldPileSize
            : BotConfig.preserveUnlockKeysPileSize;
        if (matchingNaturals >= 2 && pileSize >= minPile) {
          // Preserve unlock ability — humans unlock ~12% of draws
          score -= 80;
          if (pileSize >= 10) {
            score -= 40;
          }
        }
      }
    }

    // Generic 4–8 pair hold: even when the current top is a different rank,
    // keep the last unlock-rank pair so the next 4/5/6 discard is contestable.
    if (preserveUnlockKeys &&
        !gameState.discardPileFrozen &&
        !card.isWild &&
        !card.isThree &&
        _isHumanPreferredDiscardRank(card.rank) &&
        sameRankCount == 2 &&
        !_hasOtherGenericUnlockPair(bot, card.rank)) {
      score -= BotConfig.genericUnlockKeyHoldPenalty;
    }

    return score;
  }

  /// Calculate how much opponents might want this card.
  ///
  /// Penalties must dominate the low-rank dump bonuses: discarding a rank an
  /// opponent has visibly melded feeds their books and lets them unlock the
  /// discard pile with a matching natural pair.
  int _calculateOpponentNeedScore(
    PlayingCard card,
    GameState gameState,
    BotGameAnalyzer? analyzer,
    String botId,
  ) {
    if (card.isWild) {
      // Wild discards freeze the pile and fit no specific opponent rank
      return 0;
    }

    int needScore = 0;

    for (final player in gameState.players) {
      if (player.id == botId) continue;

      // Check opponent's melds for matching ranks
      for (final meld in player.melds) {
        if (_cardFitsMeld(card, meld)) {
          final meldSize = meld.cards.length;

          // Near-book melds are critical - don't feed them!
          if (meldSize >= 6) {
            needScore +=
                BotConfig.opponentBookFeedPenalty; // Would complete their book!
          } else if (meldSize >= 5) {
            needScore += BotConfig.opponentNearBookFeedPenalty; // Getting close
          } else {
            needScore +=
                BotConfig.opponentMeldedRankPenalty; // They're building this
          }

          // Large hand + visible meld of this rank = unlock risk: they can
          // hold matching naturals and take the whole pile.
          if (player.currentHand.length >=
              BotConfig.opponentUnlockRiskHandSize) {
            needScore += BotConfig.opponentUnlockRiskPenalty;
          }
        }
      }

      // Check analyzer's tracked "likely needed ranks"
      final analysis = analyzer?.opponentAnalysis[player.id];
      if (analysis != null) {
        if (analysis.likelyNeededRanks.contains(card.rank)) {
          needScore += BotConfig.opponentNeedsWeight;
        }
      }
    }

    return needScore;
  }

  /// Ranks any opponent has face-up melds for. Discarding these ranks feeds
  /// opponent books and enables discard-pile unlocks.
  static Set<CardRank> opponentMeldedRanks(GameState gameState, String botId) {
    final ranks = <CardRank>{};
    for (final player in gameState.players) {
      if (player.id == botId) continue;
      for (final meld in player.melds) {
        ranks.add(meld.rank);
      }
    }
    return ranks;
  }

  /// Opponent-aware version of the managers' legacy "threes first, then
  /// lowest point value" discard. Keeps that ordering, but holds wilds per
  /// [shouldProtectWilds] and avoids ranks any opponent has visibly melded
  /// whenever a safe alternative exists.
  static PlayingCard chooseSafeLowValueDiscard(
    Player bot,
    GameState gameState,
  ) {
    final hand = bot.currentHand;
    if (hand.isEmpty) {
      // Graceful recovery — never crash the game session.
      print(
        'Warning: chooseSafeLowValueDiscard called with empty hand for '
        '${bot.name}, using fallback card',
      );
      return const PlayingCard(rank: CardRank.ace, suit: Suit.spades);
    }

    // Priority 1: 3s (penalty cards), red 3s first (-300 vs black -5).
    // Threes can never be melded, so they are always safe to discard.
    final threes = hand.where((card) => card.isThree).toList();
    if (threes.isNotEmpty) {
      threes.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return threes.first;
    }

    var candidates = List<PlayingCard>.from(hand);

    // Drop wilds before the safety filter runs. Analytics session
    // 17851241195649564: the aggressive bot pitched three 2s on consecutive
    // turns from a 4-card hand pile because every natural it held matched an
    // opponent meld, leaving the wild as the only "safe" candidate — and each
    // one froze the pile it had been unlocking every turn.
    if (shouldProtectWilds(bot)) {
      final nonWilds = candidates.where((card) => !card.isWild).toList();
      if (nonWilds.isNotEmpty) {
        candidates = nonWilds;
      }
    }

    // Avoid feeding ranks opponents have visibly melded when possible. A wild
    // that survived the guard above counts as safe: it freezes the pile
    // instead of feeding it.
    final meldedRanks = opponentMeldedRanks(gameState, bot.id);
    final safeCandidates = candidates
        .where((card) => card.isWild || !meldedRanks.contains(card.rank))
        .toList();
    if (safeCandidates.isNotEmpty) {
      candidates = safeCandidates;
    }

    candidates.sort((a, b) => a.pointValue.compareTo(b.pointValue));
    return candidates.first;
  }

  /// True when the hand still has a 4–8 natural pair other than [exceptRank].
  bool _hasOtherGenericUnlockPair(Player bot, CardRank exceptRank) {
    final counts = <CardRank, int>{};
    for (final held in bot.currentHand) {
      if (held.isWild ||
          !_isHumanPreferredDiscardRank(held.rank) ||
          held.rank == exceptRank) {
        continue;
      }
      counts[held.rank] = (counts[held.rank] ?? 0) + 1;
      if ((counts[held.rank] ?? 0) >= 2) {
        return true;
      }
    }
    return false;
  }

  /// Ranks humans discard most while trimming large hands (analytics).
  bool _isHumanPreferredDiscardRank(CardRank rank) {
    return BotMeldAnalyzer.isHumanUnlockKeyRank(rank);
  }

  /// Check if a card can be added to a meld.
  bool _cardFitsMeld(PlayingCard card, Meld meld) {
    if (card.isWild) return true; // Wilds fit anywhere (with restrictions)

    if (meld.cards.isEmpty) return false;

    // Find the natural rank of the meld
    final naturalCard = meld.cards.firstWhere(
      (c) => !c.isWild,
      orElse: () => meld.cards.first,
    );

    return card.rank == naturalCard.rank;
  }

  /// Analyze the discard pile for strategic opportunities.
  ///
  /// Returns a map of ranks to counts, helping identify what's available.
  Map<CardRank, int> analyzeDiscardPile(List<PlayingCard> discardPile) {
    final rankCounts = <CardRank, int>{};

    for (final card in discardPile) {
      if (!card.isThree && !card.isWild) {
        rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
      }
    }

    return rankCounts;
  }

  /// Identify cards in discard pile that would help opponent complete books.
  List<PlayingCard> findDangerousDiscards(
    List<PlayingCard> discardPile,
    GameState gameState,
    String botId,
  ) {
    final dangerous = <PlayingCard>[];

    for (final card in discardPile) {
      for (final player in gameState.players) {
        if (player.id == botId) continue;

        for (final meld in player.melds) {
          if (meld.cards.length >= 5 && _cardFitsMeld(card, meld)) {
            dangerous.add(card);
            break;
          }
        }
      }
    }

    return dangerous;
  }

  /// Calculate the "safety" of taking the discard pile.
  ///
  /// Returns a score where higher = safer to take.
  /// Considers whether opponents could benefit from the pile contents.
  int calculateDiscardPileSafety(
    List<PlayingCard> discardPile,
    GameState gameState,
    String botId,
  ) {
    if (discardPile.isEmpty) return 0;

    int safetyScore = 100; // Base safety

    // Count dangerous cards (ones opponents need)
    final dangerous = findDangerousDiscards(discardPile, gameState, botId);
    safetyScore -= dangerous.length * 20;

    // Bonus for pile having cards we can use
    // (Would need bot reference to check this)

    return safetyScore.clamp(0, 100);
  }
}
