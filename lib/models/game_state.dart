import 'package:flutter/foundation.dart';
import 'card.dart';
import 'deck.dart';
import 'player.dart';
import 'meld.dart';
import '../config/game_config.dart';

enum GamePhase { setup, playing, roundEnd, gameEnd }

enum TurnPhase { draw, meld, discard }

/// Exception thrown when game state becomes inconsistent
class GameStateException implements Exception {
  final String message;
  const GameStateException(this.message);

  @override
  String toString() => 'GameStateException: $message';
}

class GameAction {
  final String message;
  final DateTime timestamp;
  final String playerName;

  GameAction({required this.message, required this.playerName})
    : timestamp = DateTime.now();

  GameAction.withTimestamp({
    required this.message,
    required this.playerName,
    required this.timestamp,
  });

  @override
  String toString() => '$playerName: $message';
}

class GameState {
  final List<Player> players;
  final Deck deck;
  final List<PlayingCard> discardPile;
  final List<GameAction> recentActions;
  int currentPlayerIndex;
  GamePhase phase;
  TurnPhase turnPhase;
  int round;
  Player? winner;

  bool discardPileFrozen;
  bool hasDrawnFromDeck;
  bool hasMelded;

  // Track 3s stalemate situation
  /// Player index where stalemate detection started (null if no stalemate detected)
  int? _stalemateStartPlayer;

  /// Count of consecutive 3 discards in stalemate situation
  int _stalemateDiscardCount = 0;

  // Multiplayer privacy controls
  bool _isMultiplayer = false;
  String? _viewerId;

  GameState({
    required this.players,
    required this.deck,
    List<PlayingCard>? discardPile,
    List<GameAction>? recentActions,
    this.currentPlayerIndex = 0,
    this.phase = GamePhase.setup,
    this.turnPhase = TurnPhase.draw,
    this.round = 1,
    this.winner,
    this.discardPileFrozen = false,
    this.hasDrawnFromDeck = false,
    this.hasMelded = false,
    bool isMultiplayer = false,
    String? viewerId,
  }) : discardPile = discardPile ?? [],
       recentActions = recentActions ?? [],
       _isMultiplayer = isMultiplayer,
       _viewerId = viewerId;

  Player get currentPlayer => players[currentPlayerIndex];

  PlayingCard? get topDiscard => discardPile.isEmpty ? null : discardPile.last;

  /// Sets the game to multiplayer mode with optional viewer ID for privacy controls
  ///
  /// When [isMultiplayer] is true, action logging will respect multiplayer privacy rules,
  /// only showing card details for the viewer's own actions or public actions.
  /// The [viewerId] should match a player's ID to enable proper privacy filtering.
  void setMultiplayerMode(bool isMultiplayer, [String? viewerId]) {
    _isMultiplayer = isMultiplayer;
    _viewerId = viewerId;
  }

  /// Updates the viewer ID for multiplayer privacy controls
  ///
  /// This allows changing which player's perspective is being shown
  /// without recreating the entire GameState object.
  void setViewerId(String? viewerId) {
    _viewerId = viewerId;
  }

  void _logAction(String message, {bool showCardDetails = true}) {
    // Determine if card details should be shown based on player type and action visibility
    final isHuman = currentPlayer.type == PlayerType.human;
    final isPublicAction =
        message.contains('discard') ||
        message.contains('meld') ||
        message.contains('unlocked') ||
        message.contains('picked up foot') ||
        message.contains('went out');

    // In multiplayer, only show card details for the viewer's own actions or public actions
    // In single player, show details for human actions or public actions
    bool shouldShowDetails;
    if (_isMultiplayer && _viewerId != null) {
      // Multiplayer mode: only show details if this is the viewer's turn or public action
      final isViewersTurn = currentPlayer.id == _viewerId;
      shouldShowDetails = showCardDetails && (isViewersTurn || isPublicAction);
    } else {
      // Single player mode: show details for human players or public actions
      shouldShowDetails = showCardDetails && (isHuman || isPublicAction);
    }

    final finalMessage = shouldShowDetails
        ? message
        : _sanitizeMessage(message);

    recentActions.add(
      GameAction(message: finalMessage, playerName: currentPlayer.name),
    );

    // Keep only the last N actions to avoid memory issues
    if (recentActions.length > GameConfig.maxRecentActions) {
      recentActions.removeAt(0);
    }
  }

  /// Public method for logging game actions with proper privacy controls
  void logAction(String message, {bool showCardDetails = true}) {
    _logAction(message, showCardDetails: showCardDetails);
  }

  String _sanitizeMessage(String message) {
    // Remove specific card details from bot actions that shouldn't be visible
    if (message.startsWith('drew:')) {
      return 'drew';
    }
    return message;
  }

  bool get canDrawFromDiscard {
    // Players can only draw from discard if they can unlock it
    return canUnlockDiscard();
  }

  bool canUnlockDiscard() {
    if (discardPile.isEmpty || hasDrawnFromDeck) return false;
    final topCard = topDiscard!;
    if (topCard.isWild) return false;

    // 3s cannot be melded, so discard pile cannot be unlocked when top card is a 3
    if (topCard.isThree) return false;

    // Must have already met play-down requirement
    if (!currentPlayer.hasPlayedDown) return false;

    // Check if player has at least 2 matching natural cards
    final matchingCards = currentPlayer.currentHand
        .where((card) => card.rank == topCard.rank && !card.isWild)
        .toList();

    return matchingCards.length >= 2;
  }

  bool get canEndTurn => turnPhase == TurnPhase.discard && hasMelded;

  int get playDownRequirement {
    return 30 + (round * 30); // Round 1: 60, Round 2: 90, Round 3: 120, etc.
  }

  void nextPlayer() {
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    turnPhase = TurnPhase.draw;
    hasDrawnFromDeck = false;
    hasMelded = false;

    // Clear newly drawn cards from the NEW current player at the start of their turn
    // This clears highlights from their PREVIOUS turn when it's their turn again
    currentPlayer.clearNewlyDrawnCards();
  }

  void startRound() {
    phase = GamePhase.playing;
    currentPlayerIndex = 0;
    turnPhase = TurnPhase.draw;
    discardPileFrozen = false;
    hasDrawnFromDeck = false;
    hasMelded = false;

    // Reset stalemate tracking for new round
    _resetStalemateTracking();

    discardPile.clear();
    for (final player in players) {
      player.melds.clear();
      player.hasPickedUpFoot = false;
      player.hasPlayedDown = false;
    }
  }

  void dealCards() {
    for (final player in players) {
      player.dealHand(deck.drawCards(11));
      player.dealFoot(deck.drawCards(11));
    }

    final firstDiscard = deck.drawCard();
    if (firstDiscard != null) {
      discardPile.add(firstDiscard);
      if (firstDiscard.isWild) {
        discardPileFrozen = true;
      }
    }
  }

  /// Draws exactly [GameConfig.requiredDrawCount] cards from the deck.
  /// If deck becomes insufficient during draw, attempts to reshuffle discard pile.
  /// Returns true if successful, false if unable to draw required number of cards.
  bool drawFromDeck() {
    if (hasDrawnFromDeck) return false;

    // Check if deck has insufficient cards BEFORE starting the draw
    // Reshuffle proactively when deck has fewer cards than required
    if (deck.size < GameConfig.requiredDrawCount) {
      _attemptReshuffleForEmptyDeck();
    }

    final cardsDrawn = <PlayingCard>[];

    // Attempt to draw required number of cards
    for (int i = 0; i < GameConfig.requiredDrawCount; i++) {
      PlayingCard? card;

      if (!deck.isEmpty) {
        card = deck.drawCard();
      } else {
        // Deck is still empty after reshuffle attempt - try once more
        _attemptReshuffleForEmptyDeck();
        if (!deck.isEmpty) {
          card = deck.drawCard();
        }
      }

      if (card != null) {
        cardsDrawn.add(card);
      } else {
        // Still unable to draw - this should be extremely rare
        // Return any cards we managed to draw
        for (final drawnCard in cardsDrawn) {
          deck.returnCard(drawnCard);
        }
        _logAction(
          'insufficient cards in deck after reshuffle - ending round immediately',
        );

        // Emergency round end due to insufficient cards
        _emergencyEndRoundInsufficientCards();
        return false;
      }
    }

    currentPlayer.addNewlyDrawnCards(cardsDrawn);
    hasDrawnFromDeck = true;
    turnPhase = TurnPhase.meld;

    final cardNames = cardsDrawn.map((c) => c.compactName).join(', ');
    _logAction('drew: $cardNames');

    return true;
  }

  bool drawFromDiscard() {
    if (!canDrawFromDiscard) return false;

    // Drawing from discard is the same as unlocking it
    return unlockDiscard();
  }

  bool unlockDiscard() {
    if (!canUnlockDiscard()) return false;

    final topCard = topDiscard!;
    // Find 2 matching natural cards
    final matchingCards = currentPlayer.currentHand
        .where((card) => card.rank == topCard.rank && !card.isWild)
        .take(2)
        .toList();

    if (matchingCards.length < 2) return false;

    // Remove the 2 matching cards from hand and create meld with top discard
    for (final card in matchingCards) {
      currentPlayer.removeCardFromHand(card);
    }

    // Take the top discard card
    final discardCard = discardPile.removeLast();

    // Check if we should add to existing meld or create new one
    final meldCards = [...matchingCards, discardCard];
    final existingMeldIndex = currentPlayer.findMeldByRank(discardCard.rank);

    if (existingMeldIndex != -1) {
      // Add to existing meld - validate each card can be added
      final existingMeld = currentPlayer.melds[existingMeldIndex];

      // First validate all cards can be added
      for (final card in meldCards) {
        if (!existingMeld.canAddCard(card)) {
          // This shouldn't happen with proper unlock validation, but safety check
          // Log the issue for debugging if needed
          final cardName = card.compactName;
          final meldRank = existingMeld.rank.name;
          _logAction(
            'ERROR: Could not add $cardName to $meldRank meld during unlock',
          );
          return false;
        }
      }

      // Add all cards - double-check each addition for robustness
      for (final card in meldCards) {
        if (!existingMeld.addCard(card)) {
          // Extra safety: if addCard fails, log and return false
          // Note: This error logging is rare and shouldn't spam logs under normal gameplay
          final cardName = card.compactName;
          final meldRank = existingMeld.rank.name;
          _logAction(
            'ERROR: Failed to add $cardName to $meldRank meld during unlock',
          );
          return false;
        }
      }
      final meldCardNames = meldCards.map((c) => c.compactName).join(', ');
      _logAction(
        'unlocked discard pile and added to existing meld: $meldCardNames',
      );
    } else {
      // Create new meld
      final meld = Meld.createMeld(meldCards);
      if (meld != null) {
        currentPlayer.melds.add(meld);
        final meldCardNames = meldCards.map((c) => c.compactName).join(', ');
        _logAction('unlocked discard pile and melded: $meldCardNames');
      }
    }

    currentPlayer.hasPlayedDown = true; // Ensure play-down status is set

    // Take the next cards from discard pile (or what's available)
    final additionalDiscards = <PlayingCard>[];
    for (
      int i = 0;
      i < GameConfig.additionalDiscardPickup && discardPile.isNotEmpty;
      i++
    ) {
      additionalDiscards.add(discardPile.removeLast());
    }

    // Edge Case 1: If no additional cards in discard, take remaining from deck
    final remainingNeeded =
        GameConfig.additionalDiscardPickup - additionalDiscards.length;
    if (remainingNeeded > 0) {
      // Edge Case 2: Reshuffle discard if deck doesn't have enough cards
      if (deck.size < remainingNeeded && discardPile.length > 1) {
        _reshuffleDiscardIntoDeck();
      }

      if (!deck.isEmpty) {
        final cardsFromDeck = deck.drawCards(remainingNeeded);
        if (cardsFromDeck.isNotEmpty) {
          currentPlayer.addNewlyDrawnCards(cardsFromDeck);
          final deckCardNames = cardsFromDeck
              .map((c) => c.compactName)
              .join(', ');
          _logAction(
            'took ${cardsFromDeck.length} cards from deck to complete pickup: $deckCardNames',
          );
        }
      }
    }

    if (additionalDiscards.isNotEmpty) {
      currentPlayer.addNewlyDrawnCards(additionalDiscards);
      final additionalNames = additionalDiscards
          .map((c) => c.compactName)
          .join(', ');
      _logAction(
        'took ${additionalDiscards.length} more cards from discard pile: $additionalNames',
      );
    }

    turnPhase = TurnPhase.meld;
    discardPileFrozen = false;
    return true;
  }

  bool playMeld(List<PlayingCard> cards) {
    if (turnPhase != TurnPhase.meld) return false;

    final wasFirstMeld = !currentPlayer.hasPlayedDown;

    // Check if this would add to existing meld
    final proposedMeld = Meld.createMeld(cards);
    final existingMeldIndex = proposedMeld != null
        ? currentPlayer.findMeldByRank(proposedMeld.rank)
        : -1;
    final isAddingToExisting = existingMeldIndex != -1;

    if (currentPlayer.createMeld(
      cards,
      playDownRequirement: playDownRequirement,
    )) {
      hasMelded = true;

      final cardNames = cards.map((c) => c.compactName).join(', ');
      if (wasFirstMeld) {
        final points = cards.fold<int>(0, (sum, card) => sum + card.pointValue);
        _logAction('played down with $points points: $cardNames');
      } else if (isAddingToExisting) {
        _logAction('added to existing meld: $cardNames');
      } else {
        _logAction('created new meld: $cardNames');
      }

      // Check if hand is empty after melding and pick up foot if needed
      if (currentPlayer.isHandEmpty && !currentPlayer.hasPickedUpFoot) {
        currentPlayer.pickUpFoot();
        _logAction('picked up foot pile');
      }

      // Check if player has gone out after melding
      if (currentPlayer.canGoOut) {
        _logAction('went out and ended the round!');

        // Defensive logging for going out via playMeld
        if (kDebugMode) {
          _logAction(
            'GOING OUT DEBUG (playMeld): footSize=${currentPlayer.foot.length}, '
            'hasCleanBook=${currentPlayer.hasCleanBook}, '
            'hasDirtyBook=${currentPlayer.hasDirtyBook}',
          );
        }

        endRound();

        // Defensive check: Verify round actually ended (could be roundEnd or gameEnd if someone won)
        if (phase != GamePhase.roundEnd && phase != GamePhase.gameEnd) {
          _logAction(
            'ERROR: endRound() called from playMeld but phase is still $phase!',
          );
          print(
            'Warning: Unexpected phase after endRound() in playMeld, but continuing game',
          );
          // Don't throw exception - log warning but continue game gracefully
        }

        return true;
      }

      return true;
    }
    return false;
  }

  bool playMeldBypass(List<PlayingCard> cards) {
    if (turnPhase != TurnPhase.meld) return false;

    final wasFirstMeld = !currentPlayer.hasPlayedDown;

    // Check if this would add to existing meld
    final proposedMeld = Meld.createMeld(cards);
    final existingMeldIndex = proposedMeld != null
        ? currentPlayer.findMeldByRank(proposedMeld.rank)
        : -1;
    final isAddingToExisting = existingMeldIndex != -1;

    // Use playDownRequirement: 0 to bypass the requirement check
    if (currentPlayer.createMeld(cards, playDownRequirement: 0)) {
      hasMelded = true;

      final cardNames = cards.map((c) => c.compactName).join(', ');
      if (wasFirstMeld) {
        final points = cards.fold<int>(0, (sum, card) => sum + card.pointValue);
        _logAction('played down (multi-meld) with $points points: $cardNames');
      } else if (isAddingToExisting) {
        _logAction('added to existing meld: $cardNames');
      } else {
        _logAction('created new meld: $cardNames');
      }

      // Check if hand is empty after melding and pick up foot if needed
      if (currentPlayer.isHandEmpty && !currentPlayer.hasPickedUpFoot) {
        currentPlayer.pickUpFoot();
        _logAction('picked up foot pile');
      }

      // Check if player has gone out after melding
      if (currentPlayer.canGoOut) {
        _logAction('went out and ended the round!');

        // Defensive logging for going out via playMeldBypass
        if (kDebugMode) {
          _logAction(
            'GOING OUT DEBUG (playMeldBypass): footSize=${currentPlayer.foot.length}, '
            'hasCleanBook=${currentPlayer.hasCleanBook}, '
            'hasDirtyBook=${currentPlayer.hasDirtyBook}',
          );
        }

        endRound();

        // Defensive check: Verify round actually ended (could be roundEnd or gameEnd if someone won)
        if (phase != GamePhase.roundEnd && phase != GamePhase.gameEnd) {
          _logAction(
            'ERROR: endRound() called from playMeldBypass but phase is still $phase!',
          );
          print(
            'Warning: Unexpected phase after endRound() in playMeldBypass, but continuing game',
          );
          // Don't throw exception - log warning but continue game gracefully
        }

        return true;
      }

      return true;
    }
    return false;
  }

  bool addToMeld(int meldIndex, PlayingCard card) {
    if (!_canAddToMeld()) return false;

    final preOpState = _capturePlayerState();
    if (!_performAddToMeld(meldIndex, card)) return false;

    _handlePostMeldEffects(preOpState);
    return true;
  }

  /// Check if the current game state allows adding to meld
  bool _canAddToMeld() {
    if (turnPhase != TurnPhase.meld) return false;
    // Players must have played down before they can add cards to existing melds
    return currentPlayer.hasPlayedDown;
  }

  /// Capture the current player state for debugging purposes
  Map<String, dynamic> _capturePlayerState() {
    if (!kDebugMode) return <String, dynamic>{};

    return {
      'footSize': currentPlayer.foot.length,
      'handSize': currentPlayer.hand.length,
      'hasCleanBook': currentPlayer.hasCleanBook,
      'hasDirtyBook': currentPlayer.hasDirtyBook,
      'canGoOutWithBooks': currentPlayer.canGoOutWithBooks,
      'canGoOut': currentPlayer.canGoOut,
      'phase': phase.toString(),
    };
  }

  /// Perform the actual meld operation
  bool _performAddToMeld(int meldIndex, PlayingCard card) {
    if (!currentPlayer.addToMeld(meldIndex, card)) return false;

    hasMelded = true; // Mark that player has melded this turn
    _logAction('added ${card.compactName} to existing meld');

    // Check if hand is empty after adding to meld and pick up foot if needed
    if (currentPlayer.isHandEmpty && !currentPlayer.hasPickedUpFoot) {
      currentPlayer.pickUpFoot();
      _logAction('picked up foot pile');
    }

    return true;
  }

  /// Handle post-meld effects including going out checks
  void _handlePostMeldEffects(Map<String, dynamic> preOpState) {
    final postOpState = _capturePlayerState();

    // Check if player has gone out after adding to meld
    if (currentPlayer.canGoOut) {
      _logAction('went out and ended the round!');

      // Defensive logging: Record the going out decision
      if (kDebugMode) {
        _logAction('GOING OUT DEBUG: Pre-op: $preOpState');
        _logAction('GOING OUT DEBUG: Post-op: $postOpState');
      }

      endRound();

      // Defensive check: Verify round actually ended (could be roundEnd or gameEnd if someone won)
      if (phase != GamePhase.roundEnd && phase != GamePhase.gameEnd) {
        _logAction(
          'ERROR: endRound() called but phase is still $phase - this should not happen!',
        );
        print(
          'Warning: Unexpected phase after endRound(), but continuing game',
        );
      }
    } else {
      // Debug: Log why player can't go out when they have empty hands
      if (currentPlayer.currentHand.isEmpty && kDebugMode) {
        _logAction(
          'DEBUG: Hand empty but canGoOut=false - hasPickedUpFoot=${currentPlayer.hasPickedUpFoot}, canGoOutWithBooks=${currentPlayer.canGoOutWithBooks}, hasCleanBook=${currentPlayer.hasCleanBook}, hasDirtyBook=${currentPlayer.hasDirtyBook}',
        );
      }
    }

    // Defensive check: If player meets going out conditions but canGoOut is false, log it
    if (currentPlayer.canGoOutWithBooks &&
        currentPlayer.hasPickedUpFoot &&
        currentPlayer.foot.isEmpty) {
      _logAction(
        'WARNING: Player meets all going out conditions but canGoOut returned false!',
      );
      if (kDebugMode) {
        _logAction('DEBUG STATE: $postOpState');
      }
    }
  }

  bool discard(PlayingCard card) {
    if (turnPhase != TurnPhase.meld && turnPhase != TurnPhase.discard) {
      return false;
    }

    final removed = currentPlayer.removeCardFromHand(card);
    if (removed != null) {
      discardPile.add(removed);
      _logAction('discarded ${card.compactName}');

      // Check for 3s stalemate situation
      if (card.isThree) {
        _handleThreeDiscard();
      } else {
        // Reset stalemate tracking if a non-3 is discarded
        _resetStalemateTracking();
      }

      if (card.isWild) {
        discardPileFrozen = true;
        _logAction('discard pile frozen due to wild card');
      }

      if (currentPlayer.isHandEmpty && !currentPlayer.hasPickedUpFoot) {
        currentPlayer.pickUpFoot();
        _logAction('picked up foot pile');
      }

      if (currentPlayer.canGoOut) {
        _logAction('went out and ended the round!');
        endRound();
        return true;
      }

      nextPlayer();
      return true;
    }
    return false;
  }

  void _handleThreeDiscard() {
    // Check if discard pile only contains 3s (optimize by checking recent cards)
    // If pile is large, just check the last N cards for performance
    final cardsToCheck = discardPile.length > GameConfig.stalemateCheckCardCount
        ? discardPile
              .skip(discardPile.length - GameConfig.stalemateCheckCardCount)
              .toList()
        : discardPile;
    final onlyThreesInPile =
        cardsToCheck.isNotEmpty && cardsToCheck.every((card) => card.isThree);

    // Check if deck is running low
    final deckLow = deck.size < GameConfig.stalemateDeckThreshold;

    // Enhanced stalemate detection: also check if recent actions show repeated 3s discarding
    // even if discard pile was reshuffled
    final recentThreeDiscards = recentActions
        .where(
          (action) =>
              action.message.contains('discarded') &&
              action.message.contains('3 '),
        )
        .length;
    final recentReshuffles = recentActions
        .where((action) => action.message.contains('force reshuffled'))
        .length;

    // Detect 3s stalemate even after reshuffles if:
    // 1. Deck is low AND
    // 2. Either discard pile has only 3s OR recent actions show repeated 3s with reshuffles
    final stalemateCondition =
        deckLow &&
        (onlyThreesInPile ||
            (recentThreeDiscards >= 4 && recentReshuffles >= 1));

    if (stalemateCondition) {
      if (_stalemateStartPlayer == null) {
        // First detection - start tracking
        _stalemateStartPlayer = currentPlayerIndex;
        _stalemateDiscardCount = 1;
      } else {
        // Continue tracking
        _stalemateDiscardCount++;

        // Check if we've gone through all players once
        if (_stalemateDiscardCount == players.length) {
          // First full rotation complete - show warning
          _logAction(
            '⚠️ WARNING: Only 3s in discard pile with low deck (${deck.size} cards remaining)',
          );
          _logAction(
            'Round will end automatically if all players discard 3s again',
          );
        } else if (_stalemateDiscardCount == players.length * 2) {
          // Second full rotation complete - end round
          _logAction(
            '🛑 STALEMATE DETECTED: All players discarded 3s for two full rotations',
          );
          _emergencyEndRoundDueToStalemate();
        }
      }
    }
  }

  void _resetStalemateTracking() {
    _stalemateStartPlayer = null;
    _stalemateDiscardCount = 0;
  }

  void _emergencyEndRoundDueToStalemate() {
    _logAction('🛑 Round ended due to 3s stalemate - no cards can be drawn');
    _logAction('Only 3s were in the discard pile with insufficient deck cards');

    // Calculate penalty points for cards in hand
    for (final player in players) {
      // Record detailed score breakdown for stalemate (no one went out)
      player.recordRoundScoreBreakdown(round: round, wentOut: false);

      // Calculate total score including penalties for unplayed cards
      final meldValue = player.calculateMeldValue();
      final penalty = player.calculateAllUnplayedCardsValue();
      final roundScore = meldValue - penalty;
      player.updateScore(roundScore);

      _logAction(
        '${player.name}: +$meldValue (melds) -$penalty (cards) = $roundScore',
      );
    }

    _logAction('📊 Round $round has ended due to stalemate conditions');
    endRound();
  }

  // Check if any other player can immediately unlock with the newly discarded card
  bool canAnyPlayerImmediatelyUnlock() {
    if (discardPile.isEmpty) return false;
    final topCard = topDiscard!;
    if (topCard.isWild) return false;

    for (int i = 0; i < players.length; i++) {
      if (i == currentPlayerIndex) continue; // Skip current player

      final player = players[i];
      final matchingCards = player.currentHand
          .where((card) => card.rank == topCard.rank && !card.isWild)
          .toList();

      if (matchingCards.length >= 2) {
        return true;
      }
    }
    return false;
  }

  // Allow immediate unlock for a specific player
  bool immediateUnlock(int playerIndex) {
    if (playerIndex == currentPlayerIndex || playerIndex >= players.length) {
      return false;
    }
    if (discardPile.isEmpty) return false;

    final topCard = topDiscard!;
    if (topCard.isWild) return false;

    final player = players[playerIndex];
    final matchingCards = player.currentHand
        .where((card) => card.rank == topCard.rank && !card.isWild)
        .take(2)
        .toList();

    if (matchingCards.length < 2) return false;

    // Remove matching cards and create meld
    for (final card in matchingCards) {
      player.removeCardFromHand(card);
    }

    final discardCard = discardPile.removeLast();
    final meldCards = [...matchingCards, discardCard];
    final meld = Meld.createMeld(meldCards);
    if (meld != null) {
      player.melds.add(meld);
    }

    // Draw 5 cards from deck
    final additionalCards = deck.drawCards(5);
    player.addCardsToHand(additionalCards);

    return true;
  }

  void endRound() {
    // Prevent multiple endRound calls
    if (phase == GamePhase.roundEnd) {
      return;
    }

    phase = GamePhase.roundEnd;

    // Find the player who went out (if any)
    final playersWhoCanGoOut = players.where((p) => p.canGoOut).toList();
    final playerWhoWentOut = playersWhoCanGoOut.isEmpty
        ? null
        : playersWhoCanGoOut.first;

    for (final player in players) {
      // Record detailed score breakdown before updating total score
      player.recordRoundScoreBreakdown(
        round: round,
        wentOut: player == playerWhoWentOut,
      );

      // CRITICAL FIX: Include ALL unplayed cards (hand + foot) as negative when round ends
      var roundScore = player.calculateTotalScore(
        includeAllUnplayedCards: true,
      );

      // Add going out bonus
      if (player == playerWhoWentOut) {
        roundScore += GameConfig.goingOutBonus;
      }

      player.updateScore(roundScore);
    }

    final highestScore = players
        .map((p) => p.score)
        .reduce((a, b) => a > b ? a : b);
    if (highestScore >= 8500) {
      phase = GamePhase.gameEnd;
      winner = players.where((p) => p.score == highestScore).first;
      _logAction(
        '🏆 GAME END: ${winner!.name} wins with $highestScore points!',
      );
    } else {
      round++;
      _logAction('📊 Round $round starting (highest score: $highestScore)');
    }
  }

  /// Emergency round end when insufficient cards prevent normal gameplay
  void _emergencyEndRoundInsufficientCards() {
    _logAction(
      'emergency round end: insufficient cards - scores calculated and advancing to next round',
    );

    // End the current round immediately
    endRound();
  }

  void resetForNewRound() {
    if (phase != GamePhase.roundEnd) return;

    deck.addCards(discardPile);
    for (final player in players) {
      deck.addCards(player.hand);
      deck.addCards(player.foot);
      // Add all melded cards back to deck for reshuffling
      for (final meld in player.melds) {
        deck.addCards(meld.cards);
      }
      player.hand.clear();
      player.foot.clear();
      player.melds.clear();
    }

    deck.shuffle();
    startRound();
    dealCards();
  }

  List<Player> getPlayersInOrder() {
    final ordered = <Player>[];
    for (int i = 0; i < players.length; i++) {
      final index = (currentPlayerIndex + i) % players.length;
      ordered.add(players[index]);
    }
    return ordered;
  }

  /// Validates the current game state for consistency and logs any issues found.
  /// This is a defensive measure to catch edge cases where the game state becomes inconsistent.
  void validateGameState() {
    final validationErrors = <String>[];

    // Check if any player meets going out conditions but game is still in playing phase
    for (final player in players) {
      if (player.canGoOut && phase == GamePhase.playing) {
        validationErrors.add(
          'Player ${player.name} can go out but game phase is still playing',
        );
      }

      // Check if player has picked up foot but hand is not empty
      if (player.hasPickedUpFoot && !player.isHandEmpty) {
        validationErrors.add(
          'Player ${player.name} has picked up foot but hand is not empty',
        );
      }

      // Check for impossible meld states
      for (int i = 0; i < player.melds.length; i++) {
        final meld = player.melds[i];
        if (meld.cards.isEmpty) {
          validationErrors.add(
            'Player ${player.name} has empty meld at index $i',
          );
        }
        if (meld.cards.length < 3) {
          validationErrors.add(
            'Player ${player.name} has meld with fewer than 3 cards at index $i',
          );
        }
      }
    }

    // Check if round should have ended but hasn't
    if (phase == GamePhase.playing) {
      final playersWhoCanGoOut = players.where((p) => p.canGoOut).toList();
      if (playersWhoCanGoOut.isNotEmpty) {
        for (final player in playersWhoCanGoOut) {
          validationErrors.add(
            'CRITICAL: Player ${player.name} can go out but round has not ended!',
          );
        }
      }
    }

    // Log validation errors
    if (validationErrors.isNotEmpty) {
      _logAction('GAME STATE VALIDATION ERRORS FOUND:');
      for (final error in validationErrors) {
        _logAction('  - $error');
      }

      // Also log current game state for debugging
      _logAction(
        'CURRENT STATE: phase=$phase, currentPlayer=${currentPlayer.name}, '
        'turnPhase=$turnPhase',
      );
    }
  }

  /// Attempts to reshuffle discard pile when deck is completely empty.
  ///
  /// This is more aggressive than the normal reshuffle - will attempt to reshuffle
  /// even with minimal discard cards to prevent game from breaking.
  void _attemptReshuffleForEmptyDeck() {
    if (discardPile.isEmpty) {
      // Nothing to reshuffle
      _logAction(
        'deck empty and no discard cards to reshuffle - game may be stuck',
      );
      return;
    }

    if (discardPile.length == 1) {
      // Only one card in discard pile - this is the absolute edge case
      // Log this rare occurrence but don't reshuffle as it would leave no discard
      _logAction(
        'deck empty with only 1 discard card - cannot reshuffle safely',
      );
      return;
    }

    // We have at least 2 cards in discard pile - force reshuffle regardless of normal rules
    _forceReshuffleForEmptyDeck();

    if (!deck.isEmpty) {
      _logAction('emergency reshuffle successful - deck restored');
    } else {
      _logAction('emergency reshuffle failed - this should not happen');
    }
  }

  /// Forces a reshuffle when deck is empty, bypassing normal restrictions.
  void _forceReshuffleForEmptyDeck() {
    if (discardPile.length < 2) return;

    // Keep the top discard card (last item in the list)
    final topCard = discardPile.removeLast();

    // Take all other discard cards and add them to deck
    final cardsToShuffle = List<PlayingCard>.from(discardPile);
    discardPile.clear();
    discardPile.add(topCard);

    // Add the cards to deck and shuffle
    deck.addCards(cardsToShuffle);
    deck.shuffle();

    _logAction(
      'force reshuffled ${cardsToShuffle.length} cards from discard into deck',
    );
  }

  /// Reshuffles discard pile into deck when deck runs low.
  ///
  /// Maintains game state by keeping the top discard card in place.
  /// Requires at least [minDiscardForReshuffle] cards in discard pile to perform reshuffle.
  /// The remaining cards (excluding top card) are added to deck and shuffled.
  void _reshuffleDiscardIntoDeck() {
    if (discardPile.length <= GameConfig.minDiscardForReshuffle) {
      // Need sufficient cards in discard pile to reshuffle (keep top card)
      return;
    }

    // Keep the top discard card (last item in the list)
    final topCard = discardPile.removeLast();

    // Take all other discard cards and add them to deck
    final cardsToShuffle = List<PlayingCard>.from(discardPile);
    discardPile.clear();
    discardPile.add(topCard);

    // Add the cards to deck and shuffle
    deck.addCards(cardsToShuffle);
    deck.shuffle();

    _logAction(
      'reshuffled ${cardsToShuffle.length} cards from discard pile into deck',
    );
  }
}
