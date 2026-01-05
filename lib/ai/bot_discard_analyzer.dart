import '../models/card.dart';
import '../models/player.dart';
import '../models/meld.dart';
import '../models/game_state.dart';
import 'bot_game_analyzer.dart';
import 'bot_config.dart';

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

  /// Choose the best card to discard considering multiple factors.
  ///
  /// Returns the card that minimizes harm to the bot while avoiding
  /// helping opponents complete their books.
  PlayingCard chooseCardToDiscard(
    Player bot,
    GameState gameState, {
    BotGameAnalyzer? analyzer,
  }) {
    if (bot.currentHand.isEmpty) {
      throw StateError('Cannot discard from empty hand');
    }

    // Score each card (higher = more likely to discard)
    final scoredCards = <PlayingCard, int>{};

    for (final card in bot.currentHand) {
      scoredCards[card] = _calculateDiscardScore(
        card,
        bot,
        gameState,
        analyzer,
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
    BotGameAnalyzer? analyzer,
  ) {
    int score = 0;

    // 1. PRIORITY: 3s should always be discarded (penalty cards)
    if (card.isThree) {
      // Red 3s are worse than black 3s
      if (card.isRed) {
        return BotConfig.threesPriority + 300; // Red 3 = -300 points
      }
      return BotConfig.threesPriority + 5; // Black 3 = -5 points
    }

    // 2. NEVER discard wilds unless desperate (< 3 cards)
    if (card.isWild && bot.currentHand.length > 3) {
      return -BotConfig.wildProtection;
    }

    // 3. Base score from inverse point value (low value = good to discard)
    // Invert: high point cards (aces=20, wilds=50) get negative score
    score += 50 - card.pointValue;

    // 4. DEFENSIVE: Check if opponents need this card
    if (analyzer != null) {
      final opponentNeedScore = _calculateOpponentNeedScore(
        card,
        gameState,
        analyzer,
        bot.id,
      );
      score -= opponentNeedScore; // Reduce score if opponents need it
    }

    // 5. STRATEGIC: Don't discard cards we have multiples of (meld potential)
    final sameRankCount = bot.currentHand
        .where((c) => c.rank == card.rank && !c.isWild)
        .length;
    if (sameRankCount >= 2) {
      score -= BotConfig.duplicateBonus * sameRankCount;
    }

    // 6. MELD FIT: Don't discard cards that fit existing melds
    for (final meld in bot.melds) {
      if (_cardFitsMeld(card, meld)) {
        score -= 30; // Keep cards that can extend melds
      }
    }

    // 7. BOOK COMPLETION: Heavily penalize discarding cards near completing books
    for (final meld in bot.melds) {
      if (meld.cards.length >= 5 && _cardFitsMeld(card, meld)) {
        score -= 50; // Strong incentive to keep near-book cards
      }
    }

    return score;
  }

  /// Calculate how much opponents might want this card.
  int _calculateOpponentNeedScore(
    PlayingCard card,
    GameState gameState,
    BotGameAnalyzer analyzer,
    String botId,
  ) {
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
                BotConfig.nearBookPenalty; // Would complete their book!
          } else if (meldSize >= 5) {
            needScore += BotConfig.opponentNeedsWeight * 2; // Getting close
          } else if (meldSize >= 3) {
            needScore += BotConfig.opponentNeedsWeight; // They're building this
          }
        }
      }

      // Check analyzer's tracked "likely needed ranks"
      final analysis = analyzer.opponentAnalysis[player.id];
      if (analysis != null) {
        if (analysis.likelyNeededRanks.contains(card.rank)) {
          needScore += BotConfig.opponentNeedsWeight;
        }
      }
    }

    return needScore;
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
