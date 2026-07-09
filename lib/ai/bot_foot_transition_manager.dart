import '../models/player.dart';
import '../models/card.dart';
import '../game/game_controller.dart';
import '../config/game_config.dart';
import 'bot_decision.dart';
import 'bot_config.dart';
import 'bot_meld_analyzer.dart';

/// Manages intelligent foot transition decisions for bot players.
///
/// This class encapsulates all logic related to when and how bots should
/// transition from their hand to their foot pile. The decision is based on
/// multiple factors including hand size, card quality, game round, and
/// strategic position.
class BotFootTransitionManager {
  // All thresholds now centralized in BotConfig

  final BotMeldAnalyzer _meldAnalyzer;

  BotFootTransitionManager({BotMeldAnalyzer? meldAnalyzer})
    : _meldAnalyzer = meldAnalyzer ?? BotMeldAnalyzer();

  /// Main entry point for foot transition decisions.
  ///
  /// Analyzes the current game state and bot's hand to determine if and how
  /// the bot should work towards transitioning to their foot pile.
  BotDecision? handleFootTransition(Player bot, GameController controller) {
    if (!bot.hasPlayedDown || bot.hasPickedUpFoot) {
      return null; // Not ready for foot transition
    }

    final gameState = controller.gameState;
    final remainingCards = bot.currentHand.length;
    final handValue = _calculateHandValue(bot.currentHand);
    final currentRound = gameState.round;

    // Emergency transition - always transition with very few cards
    if (_shouldEmergencyTransition(bot, remainingCards)) {
      return _handleEmergencyTransition(bot, controller);
    }

    // Aggressive transition for small hands or competitive pressure
    if (_shouldAggressiveTransition(bot, controller, remainingCards)) {
      return _tryAggressiveFootTransition(bot, controller);
    }

    // Hand size pressure - transition when hand gets too large
    if (_shouldHandSizePressureTransition(bot, controller, remainingCards)) {
      return _tryHandSizePressureTransition(bot, controller, handValue);
    }

    // Late round strategy - more aggressive in later rounds
    if (_shouldLateRoundTransition(currentRound, remainingCards)) {
      return _tryLateRoundTransition(bot, controller, handValue);
    }

    // Post-playdown optimization
    if (_shouldPostPlaydownTransition(bot, remainingCards)) {
      return _tryPostPlaydownTransition(bot, controller);
    }

    // Hand quality assessment
    if (_shouldQualityBasedTransition(bot, handValue, remainingCards)) {
      return _tryQualityBasedTransition(bot, controller);
    }

    // Meld completion trigger
    if (_shouldMeldCompletionTransition(bot, remainingCards)) {
      return _tryAggressiveFootTransition(bot, controller);
    }

    // Check if most cards can be played
    if (_shouldPlayMostCardsTransition(bot, controller)) {
      return _tryPlayMostCardsTransition(bot, controller);
    }

    return null; // Continue holding cards
  }

  /// Check if bot should make an emergency transition (very few cards)
  bool _shouldEmergencyTransition(Player bot, int remainingCards) {
    return remainingCards <= BotConfig.emergencyTransitionThreshold &&
        bot.hasPlayedDown &&
        !bot.hasPickedUpFoot;
  }

  /// Handle emergency transition when hand is extremely low
  BotDecision _handleEmergencyTransition(
    Player bot,
    GameController controller,
  ) {
    // Check if bot has no cards left - they should go out if they can
    if (bot.currentHand.isEmpty) {
      if (bot.canGoOutWithBooks) {
        return BotDecision(action: 'goOut');
      } else {
        return BotDecision(action: 'error');
      }
    }

    // PRIORITY 1: Try to add cards to existing melds (more efficient than discarding)
    final cardsToAdd = _findCardsToAddToExistingMelds(bot, controller);
    if (cardsToAdd.isNotEmpty) {
      return BotDecision(action: 'addToMeld', data: cardsToAdd.first);
    }

    // PRIORITY 2: Try to create new melds if possible
    final possibleMelds = controller.findPossibleMelds(bot);
    if (possibleMelds.isNotEmpty) {
      final bestMeld = _selectBestNewMeld(bot, possibleMelds);
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    // PRIORITY 3: Discard as last resort
    if (bot.currentHand.isEmpty) {
      return BotDecision(action: 'error');
    }
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Check if bot should make an aggressive transition
  bool _shouldAggressiveTransition(
    Player bot,
    GameController controller,
    int remainingCards,
  ) {
    final gameState = controller.gameState;
    final stillOnHandPile = bot.hasPlayedDown && !bot.hasPickedUpFoot;
    final wildCardCount = bot.currentHand.where((c) => c.isWild).length;
    final hasExcessiveWilds =
        wildCardCount >= BotConfig.excessiveWildsThreshold;

    // Check for competitive pressure
    final opponentOnFoot = gameState.players.any(
      (p) => p.id != bot.id && p.hasPickedUpFoot,
    );
    final competitivePressure = opponentOnFoot && bot.hasPlayedDown;

    // Aggressive transition when: few cards OR competitive pressure with medium hand size
    final shouldTransitionForSize =
        remainingCards <= BotConfig.aggressiveFootTransitionThreshold;
    final shouldTransitionForPressure =
        competitivePressure &&
        remainingCards <= 15 &&
        remainingCards > BotConfig.aggressiveFootTransitionThreshold;

    return (shouldTransitionForSize || shouldTransitionForPressure) &&
        !(stillOnHandPile &&
            hasExcessiveWilds &&
            remainingCards > BotConfig.aggressiveFootTransitionThreshold);
  }

  /// Check if bot should transition due to hand size pressure
  bool _shouldHandSizePressureTransition(
    Player bot,
    GameController controller,
    int remainingCards,
  ) {
    final gameState = controller.gameState;

    // Check for competitive pressure
    final opponentOnFoot = gameState.players.any(
      (p) => p.id != bot.id && p.hasPickedUpFoot,
    );
    final competitivePressure = opponentOnFoot && bot.hasPlayedDown;

    final hasHandSizePressure =
        remainingCards >= BotConfig.handSizePressureThreshold;
    final hasCompetitivePressure = competitivePressure && remainingCards > 12;
    final shouldTransition = hasHandSizePressure || hasCompetitivePressure;

    return shouldTransition && bot.hasPlayedDown;
  }

  /// Check if bot should use late round transition strategy
  bool _shouldLateRoundTransition(int currentRound, int remainingCards) {
    return currentRound >= BotConfig.lateRoundTransitionRound &&
        remainingCards >= BotConfig.lateRoundHandSizeThreshold;
  }

  /// Check if bot should transition after playing down
  bool _shouldPostPlaydownTransition(Player bot, int remainingCards) {
    final hasWeakMeldOpportunity = _hasOnlyWeakMeldOpportunities(bot);

    return bot.hasPlayedDown &&
        !bot.hasPickedUpFoot &&
        remainingCards >= BotConfig.postPlaydownTransitionThreshold &&
        !hasWeakMeldOpportunity;
  }

  /// Check if bot should transition based on hand quality
  bool _shouldQualityBasedTransition(
    Player bot,
    int handValue,
    int remainingCards,
  ) {
    final wildCardCount = bot.currentHand.where((c) => c.isWild).length;
    final hasExcessiveWilds =
        wildCardCount >= BotConfig.excessiveWildsThreshold;

    return _shouldTransitionBasedOnHandQuality(
          bot,
          handValue,
          remainingCards,
        ) &&
        !hasExcessiveWilds;
  }

  /// Check if bot should transition due to meld completion
  bool _shouldMeldCompletionTransition(Player bot, int remainingCards) {
    final hasBooks = bot.melds.any(
      (meld) => meld.cards.length >= GameConfig.bookSize,
    );
    final hasMultipleMelds =
        bot.melds.length >= GameConfig.minTotalCardsForMeld;

    return hasBooks &&
        hasMultipleMelds &&
        bot.hasPlayedDown &&
        remainingCards >= 5;
  }

  /// Check if bot should transition when most cards can be played
  bool _shouldPlayMostCardsTransition(Player bot, GameController controller) {
    final wildCardCount = bot.currentHand.where((c) => c.isWild).length;
    final hasExcessiveWilds =
        wildCardCount >= BotConfig.excessiveWildsThreshold;
    final hasWeakMeldOpportunity = _hasOnlyWeakMeldOpportunities(bot);
    final canPlayMostCards = _canPlayMostCards(bot, controller);

    final shouldBeConservative = hasExcessiveWilds || hasWeakMeldOpportunity;

    return canPlayMostCards && !shouldBeConservative;
  }

  /// Try aggressive foot transition - prioritize hand reduction
  BotDecision _tryAggressiveFootTransition(
    Player bot,
    GameController controller,
  ) {
    final handSize = bot.currentHand.length;
    final wildCards = bot.currentHand.where((c) => c.isWild).toList();

    // Emergency discard for extremely large hands
    if (handSize > BotConfig.largeHandEmergencyThreshold) {
      if (bot.currentHand.isEmpty) {
        return BotDecision(action: 'error');
      }
      final cardToDiscard = _chooseCardToDiscard(bot);
      return BotDecision(action: 'discard', data: cardToDiscard);
    }

    // Priority 1: Use wild cards aggressively when transitioning to foot
    if (wildCards.isNotEmpty && handSize <= 8) {
      // Try to add wilds to existing melds to clear hand faster
      final cardsToAddWithWilds =
          _findCardsToAddToExistingMeldsWithWildPriority(
            bot,
            controller,
            prioritizeWilds: true,
          );
      if (cardsToAddWithWilds.isNotEmpty) {
        final cardToAdd = cardsToAddWithWilds.first;
        return BotDecision(action: 'addToMeld', data: cardToAdd);
      }
    }

    // Add to existing melds if hand is small enough
    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot, controller);
    if (cardsToAddToMelds.isNotEmpty && handSize <= 6) {
      final cardToAdd = cardsToAddToMelds.first;
      return BotDecision(action: 'addToMeld', data: cardToAdd);
    }

    // Try to create any meld possible (prioritize using wilds)
    final possibleMelds = controller.findPossibleMelds(bot);
    if (possibleMelds.isNotEmpty) {
      final bestMeld = _selectBestNewMeld(bot, possibleMelds);
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    // Discard strategically to get closer to foot
    if (bot.currentHand.isEmpty) {
      return BotDecision(action: 'error');
    }
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Try transition due to hand size pressure
  BotDecision _tryHandSizePressureTransition(
    Player bot,
    GameController controller,
    int handValue,
  ) {
    final handSize = bot.currentHand.length;

    // Emergency discard for extremely large hands
    if (handSize > BotConfig.largeHandEmergencyThreshold) {
      if (bot.currentHand.isEmpty) {
        return BotDecision(action: 'error');
      }
      final cardToDiscard = _chooseCardToDiscard(bot);
      return BotDecision(action: 'discard', data: cardToDiscard);
    }

    // Add multiple cards to existing melds if possible (analyzer already sorted)
    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot, controller);
    if (cardsToAddToMelds.length >= 2) {
      final cardToAdd = cardsToAddToMelds.first;
      return BotDecision(action: 'addToMeld', data: cardToAdd);
    }

    // Create melds more aggressively
    final possibleMelds = controller.findPossibleMelds(bot);
    if (possibleMelds.isNotEmpty) {
      final bestMeld = _selectBestNewMeld(bot, possibleMelds);
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    // Consider discarding if hand value is poor
    if (handValue <= BotConfig.handSizePressureNegativeThreshold) {
      final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot, controller);
      if (cardsToAddToMelds.isNotEmpty) {
        final cardToAdd = cardsToAddToMelds.first;
        return BotDecision(action: 'addToMeld', data: cardToAdd);
      }
    }

    // Default: strategic discard
    if (bot.currentHand.isEmpty) {
      return BotDecision(action: 'error');
    }
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Try transition in later rounds where foot access is more valuable
  BotDecision _tryLateRoundTransition(
    Player bot,
    GameController controller,
    int handValue,
  ) {
    // Be more willing to transition with moderate hands
    if (handValue <= BotConfig.lateRoundModerateNegativeThreshold ||
        bot.currentHand.length >= (BotConfig.lateRoundHandSizeThreshold + 1)) {
      final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot, controller);
      if (cardsToAddToMelds.isNotEmpty) {
        final cardToAdd = cardsToAddToMelds.first;
        return BotDecision(action: 'addToMeld', data: cardToAdd);
      }
    }

    // Create melds with lower efficiency threshold
    if (_canPlaySomeCards(bot, controller)) {
      final possibleMelds = controller.findPossibleMelds(bot);
      if (possibleMelds.isNotEmpty) {
        final bestMeld = _selectBestNewMeld(bot, possibleMelds);
        return BotDecision(action: 'createMeld', data: bestMeld);
      }
    }

    // Default: strategic discard
    if (bot.currentHand.isEmpty) {
      return BotDecision(action: 'error');
    }
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Try transition after playing down
  BotDecision _tryPostPlaydownTransition(
    Player bot,
    GameController controller,
  ) {
    // Add to existing melds more liberally
    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot, controller);
    if (cardsToAddToMelds.isNotEmpty) {
      final cardToAdd = cardsToAddToMelds.first;
      return BotDecision(action: 'addToMeld', data: cardToAdd);
    }

    // Create smaller melds to clear hand
    final possibleMelds = controller.findPossibleMelds(bot);
    final smallMelds = possibleMelds
        .where((meld) => meld.length >= GameConfig.minTotalCardsForMeld)
        .toList();
    if (smallMelds.isNotEmpty) {
      final bestMeld = _selectBestNewMeld(bot, smallMelds);
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    // Default: strategic discard
    if (bot.currentHand.isEmpty) {
      return BotDecision(action: 'error');
    }
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Try transition based on hand quality assessment
  BotDecision _tryQualityBasedTransition(
    Player bot,
    GameController controller,
  ) {
    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot, controller);
    if (cardsToAddToMelds.isNotEmpty) {
      final cardToAdd = cardsToAddToMelds.first;
      return BotDecision(action: 'addToMeld', data: cardToAdd);
    }

    // Even small melds are worthwhile to clear bad hands
    final possibleMelds = controller.findPossibleMelds(bot);
    if (possibleMelds.isNotEmpty) {
      final bestMeld = _selectBestNewMeld(bot, possibleMelds);
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    // Strategic discard of worst cards
    if (bot.currentHand.isEmpty) {
      return BotDecision(action: 'error');
    }
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Try transition when most cards can be played
  BotDecision _tryPlayMostCardsTransition(
    Player bot,
    GameController controller,
  ) {
    final possibleMelds = controller.findPossibleMelds(bot);
    if (possibleMelds.isNotEmpty) {
      final bestMeld = _selectBestNewMeld(bot, possibleMelds);
      return BotDecision(action: 'createMeld', data: bestMeld);
    }

    // Emergency risk management
    final handValue = _calculateHandValue(bot.currentHand);
    if (handValue <= BotConfig.improvedEmergencyThreshold) {
      final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot, controller);
      if (cardsToAddToMelds.isNotEmpty) {
        final cardToAdd = cardsToAddToMelds.first;
        return BotDecision(action: 'addToMeld', data: cardToAdd);
      }
    }

    // Hold cards and discard strategically
    if (bot.currentHand.isEmpty) {
      return BotDecision(action: 'error');
    }
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  /// Determine if bot should transition based on hand quality
  bool _shouldTransitionBasedOnHandQuality(
    Player bot,
    int handValue,
    int handSize,
  ) {
    // Negative point value
    if (handValue <= BotConfig.handQualityNegativeThreshold) {
      return true;
    }

    // Too many 3s (penalty cards)
    final threeCount = bot.currentHand
        .where((c) => c.rank == CardRank.three)
        .length;
    if (threeCount >= BotConfig.handQualityThreeCountThreshold) {
      return true;
    }

    // Large hands with low average value
    if (handSize >= BotConfig.handSizeQualityThreshold) {
      final avgValue = handValue / handSize;
      if (avgValue <= BotConfig.handQualityAvgValueThreshold) {
        return true;
      }
    }

    return false;
  }

  /// Check if bot can play most of their remaining cards
  bool _canPlayMostCards(Player bot, GameController controller) {
    final remainingCards = bot.currentHand.length;
    if (remainingCards <= 3) return true;

    // Count addable cards and meldable cards more accurately
    final totalPlayable = _calculateTotalPlayableCards(bot, controller);

    // Can we play ALL cards? (immediate foot transition)
    if (totalPlayable >= remainingCards) return true;

    // Can we use 60%+ of remaining cards?
    return totalPlayable >=
        (remainingCards * BotConfig.mostCardsPlayableThreshold).floor();
  }

  /// Calculate total cards that can be played (avoiding double-counting)
  int _calculateTotalPlayableCards(Player bot, GameController controller) {
    Set<PlayingCard> usedCards = {};
    int totalPlayable = 0;

    // Count cards that can be added to existing melds
    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot, controller);
    for (final addition in cardsToAddToMelds) {
      final card = addition['card'] as PlayingCard;
      if (!usedCards.contains(card)) {
        usedCards.add(card);
        totalPlayable++;
      }
    }

    // Count cards in possible melds (avoiding cards already counted)
    final possibleMelds = controller.findPossibleMelds(bot);
    for (final meld in possibleMelds) {
      int newCardsInMeld = 0;
      for (final card in meld) {
        if (!usedCards.contains(card)) {
          usedCards.add(card);
          newCardsInMeld++;
        }
      }
      // Only count this meld if it adds new cards
      if (newCardsInMeld >= GameConfig.minTotalCardsForMeld) {
        totalPlayable += newCardsInMeld;
      }
    }

    return totalPlayable;
  }

  /// Check if bot can play some of their cards (50% threshold)
  bool _canPlaySomeCards(Player bot, GameController controller) {
    final remainingCards = bot.currentHand.length;
    if (remainingCards <= 3) return true;

    // Count addable cards
    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot, controller);
    final addableCards = cardsToAddToMelds.length;

    // Count meldable cards
    final possibleMelds = controller.findPossibleMelds(bot);
    int meldableCards = 0;
    if (possibleMelds.isNotEmpty) {
      final bestMeld = _selectBestNewMeld(bot, possibleMelds);
      meldableCards = bestMeld.length;
    }

    // Can we use 50%+ of remaining cards?
    final usableCards = addableCards + meldableCards;
    return usableCards >=
        (remainingCards * BotConfig.someCardsPlayableThreshold).floor();
  }

  /// Best new meld using analyzer scoring (clean/dirty balance), not list order.
  List<PlayingCard> _selectBestNewMeld(
    Player bot,
    List<List<PlayingCard>> possibleMelds,
  ) {
    return _meldAnalyzer.findBestMeld(
      possibleMelds,
      bot: bot,
      preferLarger: true,
    );
  }

  /// Calculate the total point value of a hand
  int _calculateHandValue(List<PlayingCard> hand) {
    return hand.fold(0, (sum, card) => sum + card.pointValue);
  }

  /// Choose the best card to discard from bot's hand
  PlayingCard _chooseCardToDiscard(Player bot) {
    final hand = bot.currentHand;
    // This method should only be called when hand is non-empty
    assert(hand.isNotEmpty, 'Cannot discard from empty hand');

    // Priority 1: Discard 3s (penalty cards), red 3s first (-300 vs black -5)
    final threes = hand.where((card) => card.rank == CardRank.three).toList();
    if (threes.isNotEmpty) {
      // Sort by point value (most negative first) - red 3s are -300, black 3s are -5
      threes.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return threes.first;
    }

    // Then discard lowest value cards
    final sortedHand = List<PlayingCard>.from(hand);
    sortedHand.sort((a, b) => a.pointValue.compareTo(b.pointValue));
    return sortedHand.first;
  }

  /// Add-to-meld candidates with clean/wild scoring from [BotMeldAnalyzer].
  List<Map<String, dynamic>> _findCardsToAddToExistingMelds(
    Player bot,
    GameController controller,
  ) {
    return _meldAnalyzer.findCardsToAddToExistingMelds(bot, controller);
  }

  /// Same as [_findCardsToAddToExistingMelds], optionally boosting wild targets after analyzer ordering.
  List<Map<String, dynamic>> _findCardsToAddToExistingMeldsWithWildPriority(
    Player bot,
    GameController controller, {
    bool prioritizeWilds = false,
  }) {
    final additions = _meldAnalyzer
        .findCardsToAddToExistingMelds(bot, controller)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (prioritizeWilds) {
      for (final a in additions) {
        final card = a['card'] as PlayingCard;
        final base = a['priority'] as int;
        a['priority'] = base + (card.isWild ? 100 : 0);
      }
      additions.sort(
        (a, b) => (b['priority'] as int).compareTo(a['priority'] as int),
      );
    }
    return additions;
  }

  /// Check if bot has only weak meld opportunities
  bool _hasOnlyWeakMeldOpportunities(Player bot) {
    // Count cards of same rank to identify potential melds
    final rankCounts = <CardRank, int>{};
    for (final card in bot.currentHand) {
      if (!card.isWild && card.rank != CardRank.three) {
        rankCounts[card.rank] = (rankCounts[card.rank] ?? 0) + 1;
      }
    }

    // Count wilds
    final wildCount = bot.currentHand.where((c) => c.isWild).length;

    // Check if any rank + wilds can make a decent meld (3+ cards, 50+ points)
    for (final entry in rankCounts.entries) {
      final naturalCount = entry.value;
      final totalAvailable = naturalCount + wildCount;

      if (totalAvailable >= GameConfig.minTotalCardsForMeld &&
          naturalCount >= GameConfig.minNaturalCardsForMeld) {
        // Calculate potential points (simplified)
        final estimatedPoints =
            naturalCount * 10 + (totalAvailable - naturalCount) * 20;
        if (estimatedPoints >= 50) {
          return false; // Has at least one good meld opportunity
        }
      }
    }

    return true; // Only weak opportunities
  }
}
