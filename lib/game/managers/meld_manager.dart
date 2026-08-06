import 'package:flutter/foundation.dart';
import '../../models/card.dart';
import '../../models/player.dart';
import '../../models/meld.dart';
import '../../models/game_state.dart';
import '../go_out_guards.dart';

/// Manages all meld-related operations for the game.
///
/// This class encapsulates the logic for creating melds, adding cards to melds,
/// finding possible melds, and validating meld operations. It reduces the
/// complexity of the GameController by extracting meld-specific functionality.
class MeldManager {
  final GameState _gameState;

  MeldManager(this._gameState);

  /// Creates multiple melds atomically from card indices.
  ///
  /// This method handles multiple meld creation in a single transaction to prevent
  /// index shifting issues during card removal.
  bool createMultipleMeldsFromIndices(
    List<List<int>> allMeldIndices, {
    bool skipPlayDownCheck = false,
  }) {
    final currentPlayer = _gameState.currentPlayer;

    // Validate all indices are within bounds
    for (final meldIndices in allMeldIndices) {
      for (final index in meldIndices) {
        if (index < 0 || index >= currentPlayer.currentHand.length) {
          _debugLog(
            'Invalid index: $index for hand size ${currentPlayer.currentHand.length}',
          );
          return false;
        }
      }
    }

    // Convert indices to cards before any removal
    final allMeldCards = <List<PlayingCard>>[];
    for (final meldIndices in allMeldIndices) {
      final cards = meldIndices
          .map((index) => currentPlayer.currentHand[index])
          .toList();
      allMeldCards.add(cards);
    }

    // Validate all melds can be created
    for (int i = 0; i < allMeldCards.length; i++) {
      final meld = Meld.createMeld(allMeldCards[i]);
      if (meld == null) {
        final cardNames = allMeldCards[i].map((c) => c.compactName).join(', ');
        _debugLog('Failed to create meld ${i + 1}: $cardNames');
        return false;
      }
    }

    if (GoOutGuards.wouldMultiMeldLeaveUnfinishable(
      currentPlayer,
      allMeldCards,
    )) {
      _debugLog(
        'Refused multi-meld: would leave too few foot cards without books',
      );
      return false;
    }

    // Check play-down requirement if applicable
    if (!skipPlayDownCheck && !currentPlayer.hasPlayedDown) {
      final totalPoints = allMeldCards
          .expand((cards) => cards)
          .fold<int>(0, (sum, card) => sum + card.pointValue);

      if (totalPoints < _gameState.playDownRequirement) {
        _debugLog(
          'Play-down requirement not met: $totalPoints < ${_gameState.playDownRequirement}',
        );
        return false;
      }
    }

    // Collect and sort all indices for safe removal
    final allIndicesToRemove = <int>[];
    for (final meldIndices in allMeldIndices) {
      allIndicesToRemove.addAll(meldIndices);
    }
    allIndicesToRemove.sort((a, b) => b.compareTo(a));

    // Remove duplicates
    final uniqueIndices = <int>[];
    for (final index in allIndicesToRemove) {
      if (!uniqueIndices.contains(index)) {
        uniqueIndices.add(index);
      }
    }

    // Remove cards and handle side effects
    _removeCardsAndHandleSideEffects(currentPlayer, uniqueIndices);

    // Create melds and add to existing melds where appropriate
    final cardNamesCreated = <String>[];
    for (final cards in allMeldCards) {
      _createOrAddToMeld(currentPlayer, cards, cardNamesCreated);
    }

    // Update game state and log actions
    if (cardNamesCreated.isNotEmpty) {
      _updateGameStateAfterMeld(currentPlayer, allMeldCards, cardNamesCreated);
      return true;
    }

    return false;
  }

  /// Creates a single meld from card indices.
  bool createMeldByIndices(
    List<int> cardIndices, {
    bool skipPlayDownCheck = false,
  }) {
    final currentPlayer = _gameState.currentPlayer;

    // Validate indices
    for (final index in cardIndices) {
      if (index < 0 || index >= currentPlayer.currentHand.length) {
        return false;
      }
    }

    // Get cards at indices
    final cards = cardIndices
        .map((index) => currentPlayer.currentHand[index])
        .toList();

    if (GoOutGuards.wouldCreateMeldLeaveUnfinishable(currentPlayer, cards)) {
      _debugLog(
        'Refused meld by indices: would leave too few foot cards without books',
      );
      return false;
    }

    // Check play-down requirement if needed
    if (!skipPlayDownCheck && !currentPlayer.hasPlayedDown) {
      final cardPointValue = cards.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      if (cardPointValue < _gameState.playDownRequirement) {
        return false;
      }
    }

    // Try to add to existing meld first
    final naturalCards = cards.where((card) => !card.isWild).toList();
    if (naturalCards.isNotEmpty) {
      final rank = naturalCards.first.rank;
      final existingMeldIndex = currentPlayer.findMeldByRank(rank);

      if (existingMeldIndex != -1) {
        final existingMeld = currentPlayer.melds[existingMeldIndex];

        // Validate all cards can be added
        for (final card in cards) {
          if (!existingMeld.canAddCard(card)) {
            return false;
          }
        }

        // Remove cards and add to meld
        _removeCardsAndHandleSideEffects(currentPlayer, cardIndices);
        for (final card in cards) {
          existingMeld.addCard(card);
        }

        // Update state
        _gameState.hasMelded = true;
        final cardNames = cards.map((c) => c.compactName).join(', ');
        _gameState.logAction('added to existing meld: $cardNames');
        currentPlayer.hasPlayedDown = true;
        return true;
      }
    }

    // Create new meld
    final meld = Meld.createMeld(cards);
    if (meld != null) {
      _removeCardsAndHandleSideEffects(currentPlayer, cardIndices);
      currentPlayer.melds.add(meld);
      _gameState.hasMelded = true;

      final cardNames = cards.map((c) => c.compactName).join(', ');
      final wasFirstMeld = !currentPlayer.hasPlayedDown;
      if (wasFirstMeld) {
        final points = cards.fold<int>(0, (sum, card) => sum + card.pointValue);
        _gameState.logAction('played down with $points points: $cardNames');
      } else {
        _gameState.logAction('created new meld: $cardNames');
      }

      currentPlayer.hasPlayedDown = true;
      return true;
    }

    return false;
  }

  /// Finds all possible melds in a player's hand.
  List<List<PlayingCard>> findPossibleMelds(Player player) {
    final possibleMelds = <List<PlayingCard>>[];
    final hand = List<PlayingCard>.from(player.currentHand);

    final cardsByRank = <CardRank, List<PlayingCard>>{};
    final wildCards = <PlayingCard>[];

    // Group cards by rank
    for (final card in hand) {
      if (card.isWild) {
        wildCards.add(card);
      } else {
        cardsByRank.putIfAbsent(card.rank, () => []).add(card);
      }
    }

    // Find possible melds
    for (final entry in cardsByRank.entries) {
      // Skip 3s - they cannot be melded
      if (entry.key == CardRank.three) {
        _debugLog('Filtering out 3s from meld analysis');
        continue;
      }

      final naturalCards = entry.value;

      // Natural melds (3+ cards of same rank) - prefer minimum clean melds
      if (naturalCards.length >= 3) {
        // Only add the full meld (for backwards compatibility with tests)
        possibleMelds.add(naturalCards);
      }
      // Mixed melds (2+ naturals + wilds) - only if no clean meld available
      else if (naturalCards.length >= 2 && wildCards.isNotEmpty) {
        final meldCards = List<PlayingCard>.from(naturalCards);
        final wildsNeeded = 3 - naturalCards.length;
        final availableWilds = wildCards.take(wildsNeeded).toList();
        if (availableWilds.length == wildsNeeded) {
          meldCards.addAll(availableWilds);
          possibleMelds.add(meldCards);
        }
      }
    }

    // Validate no 3s in melds (defensive check)
    possibleMelds.removeWhere(
      (meld) => meld.any((card) => card.rank == CardRank.three),
    );

    return possibleMelds;
  }

  /// Gets all cards that are currently playable for melding.
  List<PlayingCard> getPlayableCards(Player player) {
    final playableCards = <PlayingCard>[];

    if (_gameState.turnPhase == TurnPhase.meld) {
      // Add cards from possible new melds
      final possibleMelds = findPossibleMelds(player);
      for (final meld in possibleMelds) {
        playableCards.addAll(meld);
      }

      // Add cards that can be added to existing melds
      for (int i = 0; i < player.melds.length; i++) {
        for (final card in player.currentHand) {
          if (player.melds[i].canAddCard(card)) {
            playableCards.add(card);
          }
        }
      }
    }

    return playableCards.toSet().toList();
  }

  /// Hand indices that should show playable (green) highlight in the UI.
  ///
  /// Prefer this over [getPlayableCards] for rendering: identity/`==` on
  /// [PlayingCard] is suit+rank, so duplicate multi-deck cards cannot be
  /// keyed reliably by object equality alone.
  Set<int> getPlayableCardIndices(Player player) {
    final playableIndices = <int>{};
    if (_gameState.turnPhase != TurnPhase.meld) {
      return playableIndices;
    }

    final hand = player.currentHand;
    final possibleMelds = findPossibleMelds(player);
    var shouldHighlightWilds = false;

    for (final meld in possibleMelds) {
      final remaining = List<PlayingCard>.from(meld);
      for (int i = 0; i < hand.length; i++) {
        final matchIndex = remaining.indexWhere(
          (card) => identical(card, hand[i]),
        );
        if (matchIndex >= 0) {
          playableIndices.add(i);
          remaining.removeAt(matchIndex);
        }
      }
      if (meld.any((card) => card.isWild)) {
        shouldHighlightWilds = true;
      }
    }

    // findPossibleMelds prefers clean melds when a rank has 3+ naturals, so it
    // omits dirty alternatives. Wilds remain legal with those ranks (and with
    // pair+wild candidates already flagged above).
    if (!shouldHighlightWilds && hand.any((card) => card.isWild)) {
      final naturalCounts = <CardRank, int>{};
      for (final card in hand) {
        if (!card.isWild && card.rank != CardRank.three) {
          naturalCounts.update(
            card.rank,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
      shouldHighlightWilds = naturalCounts.values.any((count) => count >= 3);
    }

    // findPossibleMelds reuses wildCards.take(...) without consuming, so only
    // the first wild is typically present in meld lists. Light up every wild
    // that could complete a dirty new meld.
    if (shouldHighlightWilds) {
      for (int i = 0; i < hand.length; i++) {
        if (hand[i].isWild) {
          playableIndices.add(i);
        }
      }
    }

    for (int i = 0; i < hand.length; i++) {
      for (final meld in player.melds) {
        if (meld.canAddCard(hand[i])) {
          playableIndices.add(i);
          break;
        }
      }
    }

    return playableIndices;
  }

  /// Helper to create a new meld or add to existing meld.
  void _createOrAddToMeld(
    Player player,
    List<PlayingCard> cards,
    List<String> cardNamesCreated,
  ) {
    final naturalCards = cards.where((card) => !card.isWild).toList();

    if (naturalCards.isEmpty) return;

    final rank = naturalCards.first.rank;
    final existingMeldIndex = player.findMeldByRank(rank);

    if (existingMeldIndex != -1) {
      // Add to existing meld
      final existingMeld = player.melds[existingMeldIndex];
      for (final card in cards) {
        existingMeld.addCard(card);
      }
      cardNamesCreated.add(
        'added to ${rank.name}: ${cards.map((c) => c.compactName).join(', ')}',
      );
    } else {
      // Create new meld
      final meld = Meld.createMeld(cards)!;
      player.melds.add(meld);
      cardNamesCreated.add(
        'new ${rank.name}: ${cards.map((c) => c.compactName).join(', ')}',
      );
    }
  }

  /// Updates game state after successful meld creation.
  void _updateGameStateAfterMeld(
    Player player,
    List<List<PlayingCard>> allMeldCards,
    List<String> cardNamesCreated,
  ) {
    final wasFirstPlayDown = !player.hasPlayedDown;

    _gameState.hasMelded = true;
    player.hasPlayedDown = true;

    if (wasFirstPlayDown) {
      final totalPoints = allMeldCards
          .expand((cards) => cards)
          .fold<int>(0, (sum, card) => sum + card.pointValue);
      _gameState.logAction(
        'played down with $totalPoints points: ${cardNamesCreated.join('; ')}',
      );
    } else {
      _gameState.logAction('created melds: ${cardNamesCreated.join('; ')}');
    }

    // CRITICAL FIX: Check if player has gone out after melding (same logic as GameState.playMeld)
    if (player.canGoOut) {
      _gameState.logAction('went out and ended the round!');

      // Debug logging to match GameState.playMeld behavior
      if (kDebugMode) {
        _gameState.logAction(
          'GOING OUT DEBUG (MeldManager): footSize=${player.foot.length}, '
          'hasCleanBook=${player.hasCleanBook}, '
          'hasDirtyBook=${player.hasDirtyBook}',
        );
      }

      _gameState.endRound();
    }
  }

  /// Removes cards from hand and handles side effects like foot pickup.
  void _removeCardsAndHandleSideEffects(Player player, List<int> cardIndices) {
    player.removeCardsByIndices(cardIndices);

    // Check for foot pickup
    if (player.isHandEmpty && !player.hasPickedUpFoot) {
      player.pickUpFoot();
      _gameState.logAction('picked up foot pile');
    }
  }

  /// Debug logging helper.
  void _debugLog(String message) {
    assert(() {
      print('[MeldManager] $message');
      return true;
    }());
  }
}
