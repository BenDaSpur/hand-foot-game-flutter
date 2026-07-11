import 'package:flutter/foundation.dart';
import 'card.dart';
import 'deck.dart';
import 'player.dart';
import 'meld.dart';
import '../config/game_config.dart';
import '../config/solo_game_settings.dart';
import '../game/managers/game_rules_engine.dart';

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

  /// Solo game rule settings (bot count is reflected in [players] length).
  SoloGameSettings soloSettings;

  /// True while other players take one final turn after someone goes out.
  bool finalTurnPhaseActive;

  /// Player index who went out this round (used for scoring).
  int? playerWhoWentOutIndex;

  /// Player indices still owed a final turn after a go-out.
  final Set<int> playersAwaitingFinalTurn;

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
    SoloGameSettings? soloSettings,
    this.finalTurnPhaseActive = false,
    this.playerWhoWentOutIndex,
    Set<int>? playersAwaitingFinalTurn,
    bool isMultiplayer = false,
    String? viewerId,
  }) : discardPile = discardPile ?? [],
       recentActions = recentActions ?? [],
       soloSettings = soloSettings ?? SoloGameSettings.defaults,
       playersAwaitingFinalTurn = playersAwaitingFinalTurn ?? {},
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

  void logPerfectGrabBonus(String playerName) {
    _logAction(
      '🎯 $playerName perfect 22-card grab! +${GameConfig.perfectGrabBonus} bonus points',
      showCardDetails: false,
    );
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

  /// Checks if the current player can unlock the discard pile.
  ///
  /// Delegates to [GameRulesEngine] for rule validation.
  bool canUnlockDiscard() {
    return GameRulesEngine.canUnlockDiscard(this);
  }

  /// Checks if the current player can end their turn.
  ///
  /// Delegates to [GameRulesEngine] for rule validation.
  bool get canEndTurn => GameRulesEngine.canEndTurn(this);

  int get playDownRequirement {
    return GameConfig.getPlayDownRequirement(round);
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

  /// Complete the active turn, advance play, and end the round if final turns are done.
  ///
  /// Returns true when [endRound] was triggered (round or game ended).
  bool completeTurn() {
    final finishedIndex = currentPlayerIndex;
    nextPlayer();

    if (finalTurnPhaseActive) {
      playersAwaitingFinalTurn.remove(finishedIndex);
      if (playersAwaitingFinalTurn.isEmpty) {
        _logAction('Final turns complete — round ending');
        endRound();
        return true;
      }
    }

    return phase == GamePhase.roundEnd || phase == GamePhase.gameEnd;
  }

  /// Handle a player meeting go-out conditions.
  ///
  /// Returns true if the round ended immediately; false if final-turn phase started.
  bool handlePlayerWentOut() {
    if (finalTurnPhaseActive) {
      _logAction('🏆 went out!');
      nextPlayer();
      return false;
    }

    playerWhoWentOutIndex = currentPlayerIndex;

    if (!soloSettings.enableFinalTurnAfterGoingOut) {
      _logAction('🏆 went out and ended the round!');
      endRound();
      return true;
    }

    _logAction('🏆 went out!');
    finalTurnPhaseActive = true;
    playersAwaitingFinalTurn.clear();
    for (var i = 0; i < players.length; i++) {
      if (i != playerWhoWentOutIndex) {
        playersAwaitingFinalTurn.add(i);
      }
    }
    for (var i = 0; i < players.length; i++) {
      if (i != playerWhoWentOutIndex) {
        playersAwaitingFinalTurn.add(i);
      }
    }

    if (playersAwaitingFinalTurn.isEmpty) {
      _logAction('🏆 went out and ended the round!');
      endRound();
      return true;
    }

    _logAction('Final turns — one last chance for other players');
    nextPlayer();
    return false;
  }

  void _resetFinalTurnState() {
    finalTurnPhaseActive = false;
    playerWhoWentOutIndex = null;
    playersAwaitingFinalTurn.clear();
  }

  void startRound() {
    phase = GamePhase.playing;
    currentPlayerIndex = 0;
    turnPhase = TurnPhase.draw;
    discardPileFrozen = false;
    hasDrawnFromDeck = false;
    hasMelded = false;

    _resetFinalTurnState();

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

    // Only show specific cards drawn for human players to prevent cheating
    if (currentPlayer.type == PlayerType.human) {
      final cardNames = cardsDrawn.map((c) => c.compactName).join(', ');
      _logAction('🎯 drew: $cardNames');
    } else {
      // For bot players, only show that they drew cards, not which ones
      _logAction('🎴 drew ${cardsDrawn.length} cards from deck');
    }

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
        _logAction('🔓 unlocked discard pile and melded: $meldCardNames');
      }
    }

    currentPlayer.hasPlayedDown = true; // Ensure play-down status is set

    // Take the next 5 cards from discard pile (or what's available)
    // Per official rules: only take from discard pile, NOT from deck
    final additionalDiscards = <PlayingCard>[];
    for (
      int i = 0;
      i < GameConfig.additionalDiscardPickup && discardPile.isNotEmpty;
      i++
    ) {
      additionalDiscards.add(discardPile.removeLast());
    }

    if (additionalDiscards.isNotEmpty) {
      currentPlayer.addNewlyDrawnCards(additionalDiscards);

      // Only show specific cards for human players to prevent cheating
      if (currentPlayer.type == PlayerType.human) {
        final additionalNames = additionalDiscards
            .map((c) => c.compactName)
            .join(', ');
        _logAction(
          'took ${additionalDiscards.length} more cards from discard pile: $additionalNames',
        );
      } else {
        // For bot players, only show count, not which cards
        _logAction(
          'took ${additionalDiscards.length} more cards from discard pile',
        );
      }
    } else {
      _logAction('no additional cards available in discard pile');
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
        _logAction('🎴 played down with $points points: $cardNames');
      } else if (isAddingToExisting) {
        _logAction('➕ added to existing meld: $cardNames');
      } else {
        _logAction('📋 created new meld: $cardNames');
      }

      // Check if hand is empty after melding and pick up foot if needed
      if (currentPlayer.isHandEmpty && !currentPlayer.hasPickedUpFoot) {
        currentPlayer.pickUpFoot();
        _logAction('👠 picked up foot pile');
      }

      // Check if player has gone out after melding
      if (currentPlayer.canGoOut) {
        if (kDebugMode) {
          _logAction(
            'GOING OUT DEBUG (playMeld): footSize=${currentPlayer.foot.length}, '
            'hasCleanBook=${currentPlayer.hasCleanBook}, '
            'hasDirtyBook=${currentPlayer.hasDirtyBook}',
          );
        }

        handlePlayerWentOut();
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
        _logAction(
          '🎴 played down (multi-meld) with $points points: $cardNames',
        );
      } else if (isAddingToExisting) {
        _logAction('➕ added to existing meld: $cardNames');
      } else {
        _logAction('📋 created new meld: $cardNames');
      }

      // Check if hand is empty after melding and pick up foot if needed
      if (currentPlayer.isHandEmpty && !currentPlayer.hasPickedUpFoot) {
        currentPlayer.pickUpFoot();
        _logAction('👠 picked up foot pile');
      }

      // Check if player has gone out after melding
      if (currentPlayer.canGoOut) {
        if (kDebugMode) {
          _logAction(
            'GOING OUT DEBUG (playMeldBypass): footSize=${currentPlayer.foot.length}, '
            'hasCleanBook=${currentPlayer.hasCleanBook}, '
            'hasDirtyBook=${currentPlayer.hasDirtyBook}',
          );
        }

        handlePlayerWentOut();
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
    _logAction('➕ added ${card.compactName} to existing meld');

    // Check if hand is empty after adding to meld and pick up foot if needed
    if (currentPlayer.isHandEmpty && !currentPlayer.hasPickedUpFoot) {
      currentPlayer.pickUpFoot();
      _logAction('👠 picked up foot pile');
    }

    return true;
  }

  /// Handle post-meld effects including going out checks
  void _handlePostMeldEffects(Map<String, dynamic> preOpState) {
    final postOpState = _capturePlayerState();

    // Check if player has gone out after adding to meld
    if (currentPlayer.canGoOut) {
      if (kDebugMode) {
        _logAction('GOING OUT DEBUG: Pre-op: $preOpState');
        _logAction('GOING OUT DEBUG: Post-op: $postOpState');
      }

      handlePlayerWentOut();
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
      _logAction('🗑️ discarded ${card.compactName}');

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
        _logAction('👠 picked up foot pile');
      }

      if (currentPlayer.canGoOut) {
        handlePlayerWentOut();
        return true;
      }

      // Log helpful feedback when someone tries to go out but can't
      if (currentPlayer.hasPickedUpFoot && currentPlayer.currentHand.isEmpty) {
        _logAction('❌ Cannot go out - missing required books!');
        _logAction(
          'Need: Clean book (7+ no wilds) AND Dirty book (7+ with wilds)',
        );
        _logAction(
          'You have: Clean books: ${currentPlayer.hasCleanBook ? 'YES' : 'NO'}, Dirty books: ${currentPlayer.hasDirtyBook ? 'YES' : 'NO'}',
        );
        if (!currentPlayer.hasCleanBook) {
          _logAction(
            'Missing: Clean book - build a meld to 7+ cards with NO wild cards (2s/Jokers)',
          );
        }
        if (!currentPlayer.hasDirtyBook) {
          _logAction(
            'Missing: Dirty book - build a meld to 7+ cards WITH wild cards (2s/Jokers)',
          );
        }
      }

      completeTurn();
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
      player.recordRoundScoreBreakdown(
        round: round,
        wentOut: false,
        goingOutBonusPoints: soloSettings.goingOutBonusPoints,
      );

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

  /// Checks if any other player can immediately unlock with the newly discarded card.
  ///
  /// Delegates to [GameRulesEngine] for rule validation.
  bool canAnyPlayerImmediatelyUnlock() {
    return GameRulesEngine.canAnyPlayerImmediatelyUnlock(this);
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
    final Player? playerWhoWentOut = playerWhoWentOutIndex != null
        ? players[playerWhoWentOutIndex!]
        : (playersWhoCanGoOut.isEmpty ? null : playersWhoCanGoOut.first);

    final goingOutBonus = soloSettings.goingOutBonusPoints;

    for (final player in players) {
      // Record detailed score breakdown before updating total score
      player.recordRoundScoreBreakdown(
        round: round,
        wentOut: player == playerWhoWentOut,
        goingOutBonusPoints: goingOutBonus,
      );

      // CRITICAL FIX: Include ALL unplayed cards (hand + foot) as negative when round ends
      var roundScore = player.calculateTotalScore(
        includeAllUnplayedCards: true,
      );

      // Add going out bonus
      if (player == playerWhoWentOut) {
        roundScore += goingOutBonus;
      }

      player.updateScore(roundScore);
    }

    _resetFinalTurnState();

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

  void resetForNewRound({bool dealCardsAfterReset = true}) {
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
    if (dealCardsAfterReset) {
      dealCards();
    }
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
}
