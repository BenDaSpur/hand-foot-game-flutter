import '../models/player.dart';
import '../models/card.dart';
import '../models/meld.dart';
import '../models/game_state.dart';
import '../game/game_controller.dart';
import '../config/game_config.dart';
import '../utils/debug_logger.dart';
import 'bot_decision.dart';
import 'bot_config.dart';
import 'bot_meld_analyzer.dart';
import 'bot_discard_analyzer.dart';

/// Manages end game decisions for bot players.
///
/// This class handles all logic related to when and how bots should go out,
/// complete books, and position themselves for winning. It focuses on the
/// strategic timing of going out while maximizing points through book completion.
class BotEndGameManager {
  // All constants now centralized in BotConfig

  final BotMeldAnalyzer _meldAnalyzer;

  BotEndGameManager({BotMeldAnalyzer? meldAnalyzer})
    : _meldAnalyzer = meldAnalyzer ?? BotMeldAnalyzer();

  /// True when discarding would empty the foot without go-out eligibility.
  /// Callers should end the turn instead of discarding into an error state.
  static bool wouldEmptyFootWithoutGoOut(Player bot) {
    return bot.hasPickedUpFoot &&
        !bot.canGoOutWithBooks &&
        bot.currentHand.length <= 1;
  }

  /// True when a meld would leave 0–1 cards while the bot still cannot go out.
  static bool leavesUnfinishableSingleCard(
    Player bot, {
    required int cardsRemoved,
    Meld? projectedMeld,
  }) {
    if (!bot.hasPickedUpFoot || bot.canGoOutWithBooks) {
      return false;
    }

    final remaining = bot.currentHand.length - cardsRemoved;
    if (remaining > 1) {
      return false;
    }

    final willHaveClean =
        bot.hasCleanBook ||
        (projectedMeld != null &&
            projectedMeld.cards.length >= BotConfig.bookSize &&
            projectedMeld.isClean);
    final willHaveDirty =
        bot.hasDirtyBook ||
        (projectedMeld != null &&
            projectedMeld.cards.length >= BotConfig.bookSize &&
            !projectedMeld.isClean);

    return !(willHaveClean && willHaveDirty);
  }

  /// True when adding [card] to [meld] would destroy the bot's only clean
  /// book — a wild on a completed all-natural book turns it dirty, revoking
  /// go-out eligibility at the worst possible moment.
  static bool wouldDestroyOnlyCleanBook(
    Player bot,
    Meld meld,
    PlayingCard card,
  ) {
    if (!card.isWild || !(meld.isBook && meld.isClean)) {
      return false;
    }
    return !bot.melds.any((m) => !identical(m, meld) && m.isBook && m.isClean);
  }

  static Meld? projectMeldAfterAdd(
    Player bot,
    int meldIndex,
    PlayingCard card,
  ) {
    if (meldIndex < 0 || meldIndex >= bot.melds.length) {
      return null;
    }
    final meld = bot.melds[meldIndex];
    if (!meld.canAddCard(card)) {
      return null;
    }
    return Meld.createMeld([...meld.cards, card]);
  }

  static bool isSafeAddToMeld(Player bot, Map<String, dynamic> addition) {
    final meldIndex = addition['meldIndex'] as int?;
    final card = addition['card'] as PlayingCard?;
    if (meldIndex == null || card == null) {
      return false;
    }
    if (meldIndex >= 0 &&
        meldIndex < bot.melds.length &&
        wouldDestroyOnlyCleanBook(bot, bot.melds[meldIndex], card)) {
      return false;
    }
    final projected = projectMeldAfterAdd(bot, meldIndex, card);
    return !leavesUnfinishableSingleCard(
      bot,
      cardsRemoved: 1,
      projectedMeld: projected,
    );
  }

  static bool isSafeCreateMeld(Player bot, List<PlayingCard> meldCards) {
    if (meldCards.isEmpty) {
      return false;
    }

    // MeldManager merges same-rank melds: a wild-containing "new" meld would
    // silently poison an existing naturals-only pile. Never allow this while
    // a clean book is still required.
    if (!bot.hasCleanBook &&
        BotMeldAnalyzer.newMeldPoisonsNaturalPile(bot, meldCards)) {
      return false;
    }

    final projected = meldCards.length >= BotConfig.bookSize
        ? Meld.createMeld(meldCards)
        : null;
    return !leavesUnfinishableSingleCard(
      bot,
      cardsRemoved: meldCards.length,
      projectedMeld: projected,
    );
  }

  /// Calculate minimum number of turns needed for bot to go out.
  /// Returns -1 if bot cannot go out (doesn't have required books).
  int calculateTurnsToGoOut(Player bot, GameController controller) {
    if (!_hasRequiredBooks(bot)) {
      return -1; // Cannot go out without required books
    }

    int currentHandSize = bot.currentHand.length;
    if (currentHandSize == 0) {
      return 0; // Can go out immediately
    }

    // Count cards that can be melded to existing melds
    int meldableCards = _countMeldableCardsToExistingMelds(bot);

    // Cards that cannot be melded (3s + cards that don't fit existing melds)
    int nonMeldableCards = currentHandSize - meldableCards;

    // Can only discard 1 card per turn, need exactly 1 card left to go out
    return nonMeldableCards > 0 ? nonMeldableCards : 1;
  }

  /// Count cards that can be added to existing melds
  int _countMeldableCardsToExistingMelds(Player bot) {
    int meldableCount = 0;

    for (final card in bot.currentHand) {
      if (card.isThree) continue; // 3s cannot be melded

      // Check if card can be added to any existing meld
      for (final meld in bot.melds) {
        if (meld.canAddCard(card)) {
          meldableCount++;
          break; // Count each card only once
        }
      }
    }

    return meldableCount;
  }

  /// Optimize bot's action to minimize turns to go out
  BotDecision? optimizeForGoOut(Player bot, GameController controller) {
    final currentTurns = calculateTurnsToGoOut(bot, controller);
    if (currentTurns <= 0) {
      return null; // Can't go out or already can go out immediately
    }

    // If we can go out in 1-2 turns, prioritize actions that get us there
    if (currentTurns <= 2) {
      final meldAction = _findOptimalMeldForGoOut(bot, controller);
      if (meldAction != null) return meldAction;
    }

    return null;
  }

  /// Find the best meld action to minimize go-out timeline
  BotDecision? _findOptimalMeldForGoOut(Player bot, GameController controller) {
    BotDecision? bestAction;
    int bestTurnsAfterAction = 999;

    // Try melding each possible card to existing melds
    for (final card in bot.currentHand) {
      if (card.isThree) continue; // Can't meld 3s

      for (int meldIndex = 0; meldIndex < bot.melds.length; meldIndex++) {
        final meld = bot.melds[meldIndex];
        if (wouldDestroyOnlyCleanBook(bot, meld, card)) {
          continue; // Never break go-out eligibility to shrink the hand
        }
        if (meld.canAddCard(card)) {
          // Simulate adding this card and calculate resulting go-out timeline
          final turnsAfterMeld = _simulateTurnsAfterMelding(bot, card);

          if (turnsAfterMeld >= 0 && turnsAfterMeld < bestTurnsAfterAction) {
            bestAction = BotDecision(
              action: 'addToMeld',
              data: {'card': card, 'meldIndex': meldIndex},
            );
            bestTurnsAfterAction = turnsAfterMeld;
          }
        }
      }
    }

    return bestAction;
  }

  /// Simulate how many turns to go out after melding a specific card
  int _simulateTurnsAfterMelding(Player bot, PlayingCard cardToMeld) {
    // Count remaining cards after melding
    final remainingCards = bot.currentHand.where((c) => c != cardToMeld).length;

    // Count other meldable cards in remaining hand (excluding the card we're melding)
    int remainingMeldable = 0;
    for (final card in bot.currentHand) {
      if (card == cardToMeld || card.isThree) continue;

      for (final meld in bot.melds) {
        if (meld.canAddCard(card)) {
          remainingMeldable++;
          break;
        }
      }
    }

    // Cards that cannot be melded (must be discarded)
    final nonMeldableCards = remainingCards - remainingMeldable;

    return nonMeldableCards > 0 ? nonMeldableCards : 1;
  }

  /// Check if bot has required books (both clean and dirty)
  bool _hasRequiredBooks(Player bot) {
    bool hasCleanBook = false;
    bool hasDirtyBook = false;

    for (final meld in bot.melds) {
      if (meld.cards.length >= BotConfig.bookSize) {
        if (meld.isClean) {
          hasCleanBook = true;
        } else {
          hasDirtyBook = true;
        }
      }
    }

    return hasCleanBook && hasDirtyBook;
  }

  /// Whether the bot has both required books and is on the foot pile.
  bool isReadyToFinishRound(Player bot) {
    return bot.hasPickedUpFoot && bot.canGoOutWithBooks;
  }

  /// Build the correct action to end the round when books are satisfied.
  ///
  /// Going out requires an empty hand — bots must discard or meld their last
  /// card(s) first. Returns null when the bot is not in a finishing position.
  BotDecision? buildFinishRoundDecision(
    Player bot,
    GameController controller,
    TurnPhase turnPhase,
  ) {
    if (!isReadyToFinishRound(bot)) {
      return null;
    }

    if (bot.currentHand.isEmpty) {
      return BotDecision(action: 'goOut');
    }

    if (bot.currentHand.length <= 4) {
      final optimized = optimizeForGoOut(bot, controller);
      if (optimized != null) {
        return optimized;
      }
    }

    if (bot.currentHand.length == 1) {
      if (turnPhase == TurnPhase.discard) {
        return BotDecision(action: 'discard', data: bot.currentHand.first);
      }
      final cardsToAdd = _findGoOutSafeAdditions(bot, controller);
      if (cardsToAdd.isNotEmpty) {
        return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
      }
      return BotDecision(action: 'noMeld');
    }

    if (bot.currentHand.length == 2) {
      if (turnPhase == TurnPhase.meld) {
        final meldAction = _findOptimalMeldForGoOut(bot, controller);
        if (meldAction != null) {
          return meldAction;
        }
        return BotDecision(action: 'noMeld');
      }
      if (turnPhase == TurnPhase.discard) {
        return BotDecision(
          action: 'discard',
          data: _chooseCardToDiscard(bot, controller),
        );
      }
    }

    return null;
  }

  /// Main entry point for end game decisions.
  ///
  /// Determines if the bot should go out, complete books, or continue building
  /// towards a winning position based on current game state and hand.
  BotDecision? handleEndGame(Player bot, GameController controller) {
    if (!bot.hasPickedUpFoot) {
      return null; // Not ready for end game decisions
    }

    final gameState = controller.gameState;
    final finishDecision = buildFinishRoundDecision(
      bot,
      controller,
      gameState.turnPhase,
    );
    if (finishDecision != null) {
      return finishDecision;
    }

    // On foot with empty hand but missing books — cannot finish
    if (bot.currentHand.isEmpty) {
      DebugLogger.warning(
        'Bot ${bot.name} has empty foot but cannot go out (missing required books)',
      );
      return null;
    }

    // NEW: Go-out optimization for edge cases (like Ben with Q♦ + 5s)
    // When bot has required books and 2-4 cards, optimize for minimum go-out turns
    if (_hasRequiredBooks(bot) &&
        bot.currentHand.length <= 4 &&
        bot.currentHand.length > 2) {
      final goOutOptimization = optimizeForGoOut(bot, controller);
      if (goOutOptimization != null) {
        return goOutOptimization;
      }
    }

    // Missing a required book type — build the clean/dirty pair before shrinking hand
    if (!bot.canGoOutWithBooks) {
      final incompleteBookDecision = _handleIncompleteBookRequirements(
        bot,
        controller,
        gameState.turnPhase,
      );
      if (incompleteBookDecision != null) {
        return incompleteBookDecision;
      }
      // Dirty books but no clean book: never discard into an empty-hand trap.
      // Return endTurn (not null) so callers do not fall through to a normal discard.
      if (gameState.turnPhase == TurnPhase.discard &&
          wouldEmptyFootWithoutGoOut(bot)) {
        DebugLogger.warning(
          'Bot ${bot.name}: refusing last-card discard without go-out books '
          '(clean=${bot.hasCleanBook}, dirty=${bot.hasDirtyBook})',
        );
        return BotDecision(action: 'endTurn');
      }
    }

    // Aggressive go-out under competitive pressure (only when books are valid)
    if (_shouldGoOutAggressively(bot, gameState)) {
      final goOutDecision = _attemptAggressiveGoOut(bot, controller);
      if (goOutDecision != null) {
        return goOutDecision;
      }
    }

    // Check if bot is in winning position (has required books and few cards)
    if (_isInWinningPosition(bot)) {
      return _handleWinningPosition(bot, controller);
    }

    // Focus on completing books to reach winning position
    final canCompleteBooks = _canCompleteRequiredBooks(bot, controller);
    if (canCompleteBooks) {
      return _handleBookCompletion(bot, controller);
    }

    // Can't complete books easily - try melding in meld phase, discard later
    if (gameState.turnPhase == TurnPhase.meld) {
      final cardsToAdd = _findCardsToAddToExistingMelds(bot, controller);
      for (final addition in cardsToAdd) {
        if (isSafeAddToMeld(bot, addition)) {
          return BotDecision(action: 'addToMeld', data: addition);
        }
      }

      final possibleMelds = controller.findPossibleMelds(bot);
      if (possibleMelds.isNotEmpty) {
        final bestMeld = _findBestBookPotentialMeld(possibleMelds);
        if (isSafeCreateMeld(bot, bestMeld)) {
          return BotDecision(action: 'createMeld', data: bestMeld);
        }
      }

      return BotDecision(action: 'noMeld');
    }

    // Default: discard conservatively in discard phase
    final cardToDiscard = _chooseCardToDiscard(bot, controller);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Check if bot is in immediate winning position
  bool _isInWinningPosition(Player bot) {
    // Must be on foot with few cards AND have required books
    if (!bot.hasPickedUpFoot ||
        bot.currentHand.length > BotConfig.winningPositionHandSize ||
        !bot.canGoOutWithBooks) {
      return false;
    }

    // Count existing books
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

    // Has required books: at least 1 clean AND 1 dirty book
    return cleanBooks >= 1 && dirtyBooks >= 1;
  }

  /// Handle decisions when bot is in winning position
  BotDecision _handleWinningPosition(Player bot, GameController controller) {
    // With 1 card: try to go out
    if (bot.currentHand.length == 1) {
      final lastCard = bot.currentHand.first;
      final cardsToAdd = _findGoOutSafeAdditions(bot, controller);

      for (final addition in cardsToAdd) {
        if ((addition['card'] as PlayingCard) == lastCard) {
          return BotDecision(action: 'addToMeld', data: addition);
        }
      }

      // If can't add last card to meld, must discard
      return BotDecision(action: 'discard', data: lastCard);
    }

    // With 2-4 cards: reduce hand strategically
    final cardsToAdd = _findGoOutSafeAdditions(bot, controller);
    if (cardsToAdd.isNotEmpty) {
      return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
    }

    // No useful additions - discard to reduce hand size
    final cardToDiscard = _chooseCardToDiscard(bot, controller);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Handle book completion strategy
  BotDecision _handleBookCompletion(Player bot, GameController controller) {
    // Priority 1: Complete books (7+ cards) for maximum points
    final bookCompletionMove = _tryCompleteBooks(bot, controller);
    if (bookCompletionMove != null) {
      return bookCompletionMove;
    }

    // Priority 2: Add to existing melds to build toward books
    // (respects clean-book filters in _findBestBookProgressAddition)
    final cardsToAdd = _findCardsToAddToExistingMelds(bot, controller);
    if (cardsToAdd.isNotEmpty) {
      final bestAddition = _findBestBookProgressAddition(bot, cardsToAdd);
      if (bestAddition != null) {
        return BotDecision(action: 'addToMeld', data: bestAddition);
      }
      // No clean-book-safe addition — fall through to create a new meld
    }

    // Priority 3: Create new melds that can become books. While a clean book
    // is still required, skip candidates that would merge a wild into an
    // existing naturals-only pile (MeldManager merges same-rank melds).
    var possibleMelds = controller.findPossibleMelds(bot);
    if (!bot.hasCleanBook) {
      possibleMelds = possibleMelds
          .where(
            (meld) => !BotMeldAnalyzer.newMeldPoisonsNaturalPile(bot, meld),
          )
          .toList();
    }
    if (possibleMelds.isNotEmpty) {
      final bestMeld = _findBestBookPotentialMeld(possibleMelds);
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    // No good options - discard conservatively
    final cardToDiscard = _chooseCardToDiscard(bot, controller);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Check if bot can complete the required clean and dirty books for going out
  bool _canCompleteRequiredBooks(Player bot, GameController controller) {
    int cleanBooks = 0;
    int dirtyBooks = 0;
    int cleanMeldsNearBook = 0; // Clean melds with 5-6 cards
    int dirtyMeldsNearBook = 0; // Dirty melds with 5-6 cards

    // Count existing books and near-books
    for (final meld in bot.melds) {
      if (meld.cards.length >= BotConfig.bookSize) {
        if (meld.isClean) {
          cleanBooks++;
        } else {
          dirtyBooks++;
        }
      } else if (meld.cards.length >= 5) {
        // Near-books: use all-natural (Meld.isClean is only for completed books)
        if (BotMeldAnalyzer.isAllNatural(meld)) {
          cleanMeldsNearBook++;
        } else {
          dirtyMeldsNearBook++;
        }
      }
    }

    final needsCleanBook = cleanBooks == 0;
    final needsDirtyBook = dirtyBooks == 0;

    if (!needsCleanBook && !needsDirtyBook) {
      return true; // Already have required books
    }

    // IMPORTANT: Check if we have potential for BOTH types of books
    // Don't just focus on completing any book - we need one of each type!

    // If we need a clean book, check our potential - MORE AGGRESSIVE
    if (needsCleanBook) {
      // Check if we have natural melds close to book status
      if (cleanMeldsNearBook > 0) {
        // We have natural melds that could become clean books
        for (final meld in bot.melds) {
          if (meld.cards.length >= 4 && // Reduced from 5 - more optimistic
              meld.cards.length < BotConfig.bookSize &&
              BotMeldAnalyzer.isAllNatural(meld)) {
            // Check if we can add natural cards (not wilds) to complete it
            for (final card in bot.currentHand) {
              if (_canAddCardToMeld(card, meld) && !card.isWild) {
                // Can complete clean book - be more optimistic about dirty book potential
                if (!needsDirtyBook ||
                    dirtyMeldsNearBook > 0 ||
                    dirtyBooks > 0 ||
                    bot.currentHand.where((c) => c.isWild).length >= 2) {
                  // NEW: wilds help with dirty books
                  return true;
                }
              }
            }
          }
        }
      }

      // Check if we can create new clean melds - MORE AGGRESSIVE
      final possibleCleanMelds = controller
          .findPossibleMelds(bot)
          .where(
            (meld) => !meld.any((card) => card.isWild) && meld.length >= 3,
          ) // Reduced from 4 to 3
          .toList();

      // Be more optimistic - if we have ANY clean meld potential, try to go for it
      if (cleanMeldsNearBook == 0 &&
          possibleCleanMelds.isEmpty &&
          bot.currentHand.where((c) => !c.isWild && !c.isThree).length < 6) {
        // NEW: more optimistic threshold
        return false; // Can't get required clean book
      }
    }

    // If we need a dirty book, check our potential
    if (needsDirtyBook) {
      // Check if we have melds that could become dirty books
      if (dirtyMeldsNearBook > 0 || cleanMeldsNearBook > 0) {
        // We have melds that could become dirty books (can add wilds to clean melds)
        for (final meld in bot.melds) {
          if (meld.cards.length >= 4 &&
              meld.cards.length < BotConfig.bookSize) {
            // Reduced from 5 - more aggressive
            // Check if we can add any card (including wilds) to complete it
            for (final card in bot.currentHand) {
              if (_canAddCardToMeld(card, meld)) {
                // Can complete dirty book - be more optimistic about clean book potential
                if (!needsCleanBook ||
                    cleanMeldsNearBook > 0 ||
                    cleanBooks > 0 ||
                    bot.currentHand
                            .where((c) => !c.isWild && !c.isThree)
                            .length >=
                        4) {
                  // NEW: optimistic about clean potential
                  return true;
                }
              }
            }
          }
        }
      }

      // Check if we can create new mixed melds with wilds - MORE AGGRESSIVE
      final possibleMixedMelds = controller
          .findPossibleMelds(bot)
          .where(
            (meld) => meld.any((card) => card.isWild) && meld.length >= 3,
          ) // Reduced from 4 to 3
          .toList();

      // Be more optimistic about dirty book potential
      final wildCount = bot.currentHand.where((c) => c.isWild).length;
      if (dirtyMeldsNearBook == 0 &&
          possibleMixedMelds.isEmpty &&
          cleanMeldsNearBook == 0 &&
          wildCount < 3) {
        // NEW: if we have wilds, we can make dirty books
        return false; // Can't get required dirty book (and no clean melds to make dirty)
      }
    }

    return true; // Can potentially complete required books
  }

  /// Try to complete books (7+ card melds) with clean book priority
  BotDecision? _tryCompleteBooks(Player bot, GameController controller) {
    // Priority 1: Complete clean books first (500 pts vs 300 for dirty).
    // Use all-natural (not Meld.isClean) — isClean is only true for completed 7+ books.
    for (int i = 0; i < bot.melds.length; i++) {
      final meld = bot.melds[i];
      if (meld.cards.length == 6 && BotMeldAnalyzer.isAllNatural(meld)) {
        // Natural meld one card from book - only add natural cards
        for (final card in bot.currentHand) {
          if (_canAddCardToMeld(card, meld) && !card.isWild) {
            return BotDecision(
              action: 'addToMeld',
              data: {
                'meldIndex': i,
                'card': card,
                'priority': BotConfig.cleanBookCompletionPriority,
              },
            );
          }
        }
      }
    }

    // Priority 2: Complete dirty books only when a clean book already exists
    if (!bot.hasCleanBook) {
      return null;
    }

    for (int i = 0; i < bot.melds.length; i++) {
      final meld = bot.melds[i];
      if (meld.cards.length == 6 && !BotMeldAnalyzer.isAllNatural(meld)) {
        // Dirty meld one card from book - can add wilds if needed
        for (final card in bot.currentHand) {
          if (_canAddCardToMeld(card, meld)) {
            return BotDecision(
              action: 'addToMeld',
              data: {
                'meldIndex': i,
                'card': card,
                'priority': BotConfig.dirtyBookCompletionPriority,
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
    Map<String, dynamic>? bestAddition;
    int bestScore = -1;

    final needsCleanBook = !bot.hasCleanBook && bot.hasDirtyBook;

    for (final addition in cardsToAdd) {
      final meldIndex = addition['meldIndex'] as int;
      final meld = bot.melds[meldIndex];
      final card = addition['card'] as PlayingCard;
      final allNatural = BotMeldAnalyzer.isAllNatural(meld);

      // Missing clean book: only extend natural-only piles with naturals
      if (needsCleanBook) {
        if (!allNatural || card.isWild) {
          continue;
        }
      }

      // Base score on meld progress toward book status
      int score = meld.cards.length;
      if (meld.cards.length == 6) {
        score += 100; // Almost a book!
      }
      if (meld.cards.length >= 4) {
        score += 50; // Good progress
      }

      // Clean book protection: heavily prioritize keeping natural piles clean
      if (allNatural) {
        if (!card.isWild) {
          score +=
              BotConfig.cleanMeldProtectionBonus; // Massive bonus for naturals
        } else {
          // Penalty for making natural meld dirty, unless already a clean book
          if (meld.isClean) {
            score += 25; // Small bonus - already a clean book
          } else {
            score -= BotConfig
                .wildPenaltyForCleanMeld; // Big penalty - would make dirty
          }
        }
      } else {
        // Dirty meld - limit wild accumulation
        final wildCount = meld.cards.where((c) => c.isWild).length;
        if (card.isWild && wildCount >= GameConfig.excessiveWildThreshold) {
          score -= BotConfig.excessiveWildPenalty; // Discourage excessive wilds
        }
      }

      // Book size limits: discourage oversized books (8+ cards are wasteful)
      if (meld.cards.length >= 8) {
        score -= BotConfig.oversizedBookPenalty; // Better to spread cards
      }

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

      // Major bonus for clean melds - they can become 500pt clean books
      final aIsClean = !a.any((card) => card.isWild);
      final bIsClean = !b.any((card) => card.isWild);

      if (aIsClean && !bIsClean) scoreA += 50; // Clean beats dirty
      if (bIsClean && !aIsClean) scoreB += 50;
      if (aIsClean && bIsClean) {
        // Both clean - prioritize longer clean melds
        scoreA += 30;
        scoreB += 30;
      }

      // Moderate bonus for natural melds over mixed ones
      if (aIsClean) scoreA += 10;
      if (bIsClean) scoreB += 10;

      return scoreB.compareTo(scoreA);
    });

    return possibleMelds.first;
  }

  /// Check if a card can be added to a meld
  bool _canAddCardToMeld(PlayingCard card, Meld meld) {
    // Wild cards can usually be added
    if (card.isWild) {
      // Check wild card limits (wilds <= naturals)
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

  /// Find cards that can be added to existing melds, excluding hard-blocked
  /// (clean-book-poisoning) additions — end-game paths pick from this list
  /// without re-checking analyzer priorities.
  List<Map<String, dynamic>> _findCardsToAddToExistingMelds(
    Player bot,
    GameController controller,
  ) {
    return _meldAnalyzer
        .findCardsToAddToExistingMelds(bot, controller)
        .where((addition) => !BotMeldAnalyzer.isHardBlockedAddition(addition))
        .toList();
  }

  /// Additions safe to play while going out — never one that would flip the
  /// bot's only clean book to dirty and revoke go-out eligibility.
  List<Map<String, dynamic>> _findGoOutSafeAdditions(
    Player bot,
    GameController controller,
  ) {
    return _findCardsToAddToExistingMelds(bot, controller)
        .where(
          (addition) => !wouldDestroyOnlyCleanBook(
            bot,
            addition['meld'] as Meld,
            addition['card'] as PlayingCard,
          ),
        )
        .toList();
  }

  /// Choose the best card to discard from bot's hand: threes first, wilds
  /// protected in foot, then the lowest-value card that does not feed a rank
  /// opponents have visibly melded.
  PlayingCard _chooseCardToDiscard(Player bot, GameController controller) {
    final hand = bot.currentHand;
    if (hand.isEmpty) {
      // This indicates a logic error - empty hand should trigger foot pickup or go out
      print('Warning: Bot ${bot.name} has empty hand but is trying to discard');
      print('  - Has picked up foot: ${bot.hasPickedUpFoot}');
      print('  - Can go out: ${bot.canGoOut}');
      print('  - Using fallback card to prevent crash');

      // Return a safe fallback card
      return const PlayingCard(rank: CardRank.ace, suit: Suit.spades);
    }

    return BotDiscardAnalyzer.chooseSafeLowValueDiscard(
      bot,
      controller.gameState,
    );
  }

  /// Build toward the missing clean or dirty book before attempting to go out.
  BotDecision? _handleIncompleteBookRequirements(
    Player bot,
    GameController controller,
    TurnPhase turnPhase,
  ) {
    if (turnPhase != TurnPhase.meld) {
      return null;
    }

    final needsClean = !bot.hasCleanBook;
    final needsDirty = !bot.hasDirtyBook;
    if (!needsClean && !needsDirty) {
      return null;
    }

    // Clean-book-first (human pattern): always chase natural piles before dirty.
    if (needsClean) {
      for (int i = 0; i < bot.melds.length; i++) {
        final meld = bot.melds[i];
        // Use all-natural — Meld.isClean is only true for completed 7+ books.
        if (BotMeldAnalyzer.isAllNatural(meld) &&
            meld.cards.length < BotConfig.bookSize) {
          for (final card in bot.currentHand) {
            if (!card.isWild && _canAddCardToMeld(card, meld)) {
              final addition = {'meldIndex': i, 'card': card};
              if (!isSafeAddToMeld(bot, addition)) {
                continue;
              }
              return BotDecision(action: 'addToMeld', data: addition);
            }
          }
        }
      }

      final cleanMelds = controller
          .findPossibleMelds(bot)
          .where((meld) => !meld.any((card) => card.isWild))
          .toList();
      if (cleanMelds.isNotEmpty) {
        final bestMeld = _findBestBookPotentialMeld(cleanMelds);
        if (isSafeCreateMeld(bot, bestMeld)) {
          return BotDecision(action: 'createMeld', data: bestMeld);
        }
      }

      // Still missing clean book — do not fall through into dirty inflation.
      return null;
    }

    // Dirty book only (clean already secured)
    if (needsDirty) {
      final cardsToAdd = _findCardsToAddToExistingMelds(bot, controller);
      for (final addition in cardsToAdd) {
        final meldIndex = addition['meldIndex'] as int;
        final meld = bot.melds[meldIndex];
        // Only extend already-mixed piles toward a dirty book
        if (!BotMeldAnalyzer.isAllNatural(meld) &&
            meld.cards.length < BotConfig.bookSize &&
            isSafeAddToMeld(bot, addition)) {
          return BotDecision(action: 'addToMeld', data: addition);
        }
      }

      final dirtyMelds = controller
          .findPossibleMelds(bot)
          .where((meld) => meld.any((card) => card.isWild))
          .toList();
      if (dirtyMelds.isNotEmpty) {
        final bestMeld = _findBestBookPotentialMeld(dirtyMelds);
        if (isSafeCreateMeld(bot, bestMeld)) {
          return BotDecision(action: 'createMeld', data: bestMeld);
        }
      }
    }

    return null;
  }

  /// NEW: Check if bot should go out aggressively under pressure
  bool _shouldGoOutAggressively(Player bot, dynamic gameState) {
    if (!bot.canGoOutWithBooks) {
      return false;
    }

    // Get human players
    final humanPlayers = gameState.players.where(
      (p) => p.type == PlayerType.human,
    );

    for (final human in humanPlayers) {
      // If human is accumulating massive hands (25+ cards), cut off their strategy
      if (human.currentHand.length >= 25 && !human.hasPlayedDown) {
        return bot.currentHand.length <= BotConfig.aggressiveGoOutHandSize;
      }

      // Opponent holding a large penalty pile — good time to end the round
      if (human.calculateAllUnplayedCardsValue() >=
              BotConfig.aggressiveGoOutOpponentPenaltyThreshold &&
          bot.currentHand.length <= BotConfig.aggressiveGoOutHandSize) {
        return true;
      }

      // If human has more books than us, go out to prevent them from gaining more advantage
      final humanBooks = human.melds
          .where((Meld m) => m.cards.length >= 7)
          .length;
      final botBooks = bot.melds.where((Meld m) => m.cards.length >= 7).length;
      if (humanBooks > botBooks &&
          bot.currentHand.length <= BotConfig.aggressiveGoOutHandSize) {
        return true;
      }

      // Late game aggression - if we're past round 4, be more willing to go out
      if (gameState.round >= 4 &&
          bot.currentHand.length <= BotConfig.aggressiveGoOutHandSize) {
        return true;
      }
    }

    return false;
  }

  /// NEW: Attempt aggressive go-out when under competitive pressure
  BotDecision? _attemptAggressiveGoOut(Player bot, GameController controller) {
    // Check book requirements - need at least one clean and one dirty book
    final cleanBooks = bot.melds
        .where((m) => m.cards.length >= 7 && m.isClean)
        .length;
    final dirtyBooks = bot.melds
        .where((m) => m.cards.length >= 7 && !m.isClean)
        .length;

    if (cleanBooks > 0 && dirtyBooks > 0) {
      // Have required books — discard last card(s) to go out (hand must be empty)
      final possibleDiscards = bot.currentHand
          .where((card) => !card.isThree)
          .toList();
      if (possibleDiscards.isNotEmpty) {
        return BotDecision(action: 'discard', data: possibleDiscards.first);
      }
      if (bot.currentHand.isNotEmpty) {
        return BotDecision(action: 'discard', data: bot.currentHand.first);
      }
    }

    return null;
  }
}
