import 'package:flutter/foundation.dart';
import 'card.dart';
import 'deck.dart';
import 'player.dart';
import 'meld.dart';
import '../config/game_config.dart';
import '../config/solo_game_settings.dart';
import '../game/go_out_guards.dart';
import '../game/managers/game_rules_engine.dart';
import '../utils/debug_logger.dart';

enum GamePhase { setup, playing, roundEnd, gameEnd }

enum TurnPhase { draw, meld, discard }

/// Why the engine ended a round without a real go-out.
enum EmergencyRoundEndReason { insufficientCards, stalemate }

/// Parses a saved emergency-end reason. Missing or invalid values are null.
EmergencyRoundEndReason? parseEmergencyRoundEndReason(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is EmergencyRoundEndReason) {
    return value;
  }
  if (value is int) {
    if (value >= 0 && value < EmergencyRoundEndReason.values.length) {
      return EmergencyRoundEndReason.values[value];
    }
    return null;
  }
  final name = value.toString();
  for (final reason in EmergencyRoundEndReason.values) {
    if (reason.name == name) {
      return reason;
    }
  }
  return null;
}

/// Exception thrown when game state becomes inconsistent
class GameStateException implements Exception {
  final String message;
  const GameStateException(this.message);

  @override
  String toString() => 'GameStateException: $message';
}

class GameAction {
  /// Shared text for this action. This is the only part that is ever written
  /// to the multiplayer game document, so it must never reveal card identities
  /// that belong to a single player's hand.
  final String message;

  final DateTime timestamp;
  final String playerName;

  /// Card-revealing detail that is only ever shown on the acting player's own
  /// device. It may be written to a device-local save so a resumed solo game
  /// keeps its log readable, but it is deliberately excluded from the
  /// multiplayer encoding in `FirebaseService`, which opponents can read.
  final String? privateMessage;

  GameAction({
    required this.message,
    required this.playerName,
    this.privateMessage,
  }) : timestamp = DateTime.now();

  GameAction.withTimestamp({
    required this.message,
    required this.playerName,
    required this.timestamp,
    this.privateMessage,
  });

  /// Text to render locally: the private detail when this device is entitled
  /// to see it, otherwise the shared message.
  String get displayMessage => privateMessage ?? message;

  @override
  String toString() => '$playerName: $displayMessage';
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

  /// True once the current player has taken the discard pile this turn.
  ///
  /// Taking the pile is a draw-phase alternative to drawing from the deck, so
  /// it is allowed at most once per turn. [unlockDiscard] leaves the turn in
  /// [TurnPhase.meld] without setting [hasDrawnFromDeck], so this flag is what
  /// stops a second pickup when the new top card also matches two naturals.
  bool hasTakenDiscardThisTurn;

  /// How many of the most recent unlock pickup cards came from the discard pile.
  /// Transient UI metadata — not serialized.
  int lastUnlockFromDiscardCount;

  /// Unlock pickup cards in collection order (discard leftovers, then stock fill).
  /// Transient UI metadata — not serialized.
  List<PlayingCard> lastUnlockPickupCards;

  // Track 3s stalemate situation
  /// True after the first consecutive 3-discard in a low-deck all-3s pile.
  bool _stalemateTrackingActive = false;

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

  /// Set when the round ended for an empty deck or 3s stalemate (not a go-out).
  EmergencyRoundEndReason? emergencyRoundEndReason;

  /// True after a draw that leaves too few cards for another required draw.
  ///
  /// The current player still finishes this turn (meld + discard). The next
  /// player who cannot draw ends the round. Used for the last-call banner.
  bool lastCallActive = false;

  /// One-shot: UI should show the last-call modal before the player continues.
  bool lastCallAlertPending = false;

  /// One-shot: UI should show the 3s-stalemate warning modal.
  bool stalemateAlertPending = false;

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
    this.hasTakenDiscardThisTurn = false,
    this.lastUnlockFromDiscardCount = 0,
    List<PlayingCard>? lastUnlockPickupCards,
    SoloGameSettings? soloSettings,
    this.finalTurnPhaseActive = false,
    this.playerWhoWentOutIndex,
    Set<int>? playersAwaitingFinalTurn,
    bool isMultiplayer = false,
    String? viewerId,
  }) : discardPile = discardPile ?? [],
       recentActions = recentActions ?? [],
       lastUnlockPickupCards = lastUnlockPickupCards ?? [],
       soloSettings = soloSettings ?? SoloGameSettings.defaults,
       playersAwaitingFinalTurn = playersAwaitingFinalTurn ?? {},
       _isMultiplayer = isMultiplayer,
       _viewerId = viewerId;

  Player get currentPlayer => players[currentPlayerIndex];

  PlayingCard? get topDiscard => discardPile.isEmpty ? null : discardPile.last;

  /// Player who went out this round, if any.
  Player? get playerWhoWentOut {
    final index = playerWhoWentOutIndex;
    if (index == null || index < 0 || index >= players.length) {
      return null;
    }
    return players[index];
  }

  /// Whether [currentPlayer] is taking their one final turn after a go-out.
  bool get isCurrentPlayerFinalTurn =>
      finalTurnPhaseActive &&
      playersAwaitingFinalTurn.contains(currentPlayerIndex);

  /// Whether the given [player] still has a final turn owed.
  bool isPlayerAwaitingFinalTurn(Player player) {
    final index = players.indexWhere((p) => p.id == player.id);
    if (index < 0) {
      return false;
    }
    return playersAwaitingFinalTurn.contains(index);
  }

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

  /// Logs a game action.
  ///
  /// [message] is the shared text and must be safe for every player to read.
  /// [privateMessage] is an optional card-revealing variant that is attached
  /// only when this device is entitled to see the detail; it is omitted from
  /// the multiplayer encoding, so it cannot leak through the sync.
  void _logAction(
    String message, {
    bool showCardDetails = true,
    String? privateMessage,
  }) {
    // Determine if card details should be shown based on player type and action visibility
    final isHuman = currentPlayer.type == PlayerType.human;
    final isPublicAction =
        message.contains('discard') ||
        message.contains('meld') ||
        message.contains('unlocked') ||
        message.contains('picked up foot') ||
        message.contains('went out');

    // Whether the acting player is the person sitting at this device.
    // In multiplayer that is the viewer; in single player it is the human.
    final isLocalActingPlayer = _isMultiplayer && _viewerId != null
        ? currentPlayer.id == _viewerId
        : isHuman;

    final shouldShowDetails =
        showCardDetails && (isLocalActingPlayer || isPublicAction);

    // Private details are for the acting player's eyes only, so unlike
    // [shouldShowDetails] they are never unlocked by an action being public.
    final shouldAttachPrivateDetail = showCardDetails && isLocalActingPlayer;

    final finalMessage = shouldShowDetails
        ? message
        : _sanitizeMessage(message);

    recentActions.add(
      GameAction(
        message: finalMessage,
        playerName: currentPlayer.name,
        privateMessage: shouldAttachPrivateDetail ? privateMessage : null,
      ),
    );

    // Keep only the last N actions to avoid memory issues
    if (recentActions.length > GameConfig.maxRecentActions) {
      recentActions.removeAt(0);
    }
  }

  /// Public method for logging game actions with proper privacy controls
  void logAction(
    String message, {
    bool showCardDetails = true,
    String? privateMessage,
  }) {
    _logAction(
      message,
      showCardDetails: showCardDetails,
      privateMessage: privateMessage,
    );
  }

  void logPerfectGrabBonus(String playerName) {
    _logAction(
      '🎯 $playerName perfect 22-card grab! +${GameConfig.perfectGrabBonus} bonus points',
      showCardDetails: false,
    );
  }

  /// Markers that precede a card list in a log message.
  ///
  /// Each marker ends with `:` so the trailing colon and following card names
  /// can be stripped while the non-sensitive action text is preserved.
  static const List<String> _cardDetailMarkers = [
    'drew:',
    'from discard pile:',
    'from draw pile to complete unlock:',
  ];

  /// Strips card details from a log message that must not reveal them.
  ///
  /// Also applied to log entries arriving from the network, so a client that
  /// predates the privacy rules cannot make an updated client render the cards
  /// it wrote into the shared document.
  static String sanitizeLogMessage(String message) {
    // Remove specific card details from actions that shouldn't be visible.
    // Matched anywhere in the message so emoji-prefixed variants such as
    // '🎯 drew: Q ♠' and legacy discard-pickup leaks are sanitized too.
    for (final marker in _cardDetailMarkers) {
      final markerIndex = message.indexOf(marker);
      if (markerIndex >= 0) {
        final kept = marker.endsWith(':')
            ? marker.substring(0, marker.length - 1)
            : marker;
        return '${message.substring(0, markerIndex)}$kept'.trimRight();
      }
    }
    return message;
  }

  String _sanitizeMessage(String message) => sanitizeLogMessage(message);

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
    if (finalTurnPhaseActive) {
      _advanceToNextAwaitingFinalTurnPlayer();
      return;
    }

    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    _beginCurrentPlayerTurn();
  }

  void _beginCurrentPlayerTurn() {
    turnPhase = TurnPhase.draw;
    hasDrawnFromDeck = false;
    hasMelded = false;
    hasTakenDiscardThisTurn = false;

    // Clear newly drawn cards from the NEW current player at the start of their turn
    // This clears highlights from their PREVIOUS turn when it's their turn again
    currentPlayer.clearNewlyDrawnCards();
  }

  void _advanceToNextAwaitingFinalTurnPlayer() {
    if (playersAwaitingFinalTurn.isEmpty) {
      return;
    }

    final playerCount = players.length;
    var nextIndex = (currentPlayerIndex + 1) % playerCount;

    for (var i = 0; i < playerCount; i++) {
      if (playersAwaitingFinalTurn.contains(nextIndex)) {
        currentPlayerIndex = nextIndex;
        _beginCurrentPlayerTurn();
        return;
      }
      nextIndex = (nextIndex + 1) % playerCount;
    }

    DebugLogger.warning(
      'No player awaiting final turn found; awaiting=$playersAwaitingFinalTurn',
    );
  }

  /// Complete the active turn, advance play, and end the round if final turns are done.
  ///
  /// Returns true when [endRound] was triggered (round or game ended).
  bool completeTurn() {
    final finishedIndex = currentPlayerIndex;

    if (finalTurnPhaseActive) {
      playersAwaitingFinalTurn.remove(finishedIndex);
      if (playersAwaitingFinalTurn.isEmpty) {
        _logAction('Final turns complete — round ending');
        endRound();
        return true;
      }
      _advanceToNextAwaitingFinalTurnPlayer();
      return false;
    }

    nextPlayer();
    return phase == GamePhase.roundEnd || phase == GamePhase.gameEnd;
  }

  /// Handle a player meeting go-out conditions.
  ///
  /// Returns true if the round ended immediately; false if final-turn phase started.
  bool handlePlayerWentOut() {
    if (phase == GamePhase.roundEnd || phase == GamePhase.gameEnd) {
      return true;
    }

    if (finalTurnPhaseActive) {
      _logAction('🏆 went out!');
      playersAwaitingFinalTurn.remove(currentPlayerIndex);
      if (playersAwaitingFinalTurn.isEmpty) {
        _logAction('Final turns complete — round ending');
        endRound();
        return true;
      }
      _advanceToNextAwaitingFinalTurnPlayer();
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
    _resetStalemateTracking();
    playersAwaitingFinalTurn.clear();
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
    _advanceToNextAwaitingFinalTurnPlayer();
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
    hasTakenDiscardThisTurn = false;

    _resetFinalTurnState();
    emergencyRoundEndReason = null;
    _resetLastCallTracking();

    // Reset stalemate tracking for new round
    _resetStalemateTracking();
    stalemateAlertPending = false;

    discardPile.clear();
    for (final player in players) {
      player.melds.clear();
      player.hasPickedUpFoot = false;
      player.hasPlayedDown = false;
      // startRound does not call _beginCurrentPlayerTurn, so leftover
      // highlights from the previous round would otherwise stick to the
      // newly dealt hand and inflate the next deck-draw animation.
      player.clearNewlyDrawnCards();
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

    // Heal desynced online games where someone already went out but the round
    // never ended (final-turn fields dropped from Firestore). Do not deal more
    // cards onto an empty winning hand.
    if (recoverStuckGoOutIfNeeded()) {
      return false;
    }

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

    // Replace leftover highlights so CardDrawnEvent / fly-in animation
    // include only the cards taken on this draw.
    currentPlayer.clearNewlyDrawnCards();
    currentPlayer.addNewlyDrawnCards(cardsDrawn);
    hasDrawnFromDeck = true;
    turnPhase = TurnPhase.meld;

    // The shared log only ever records how many cards were drawn. The card
    // names are attached as a private detail so the drawing player still sees
    // them locally without them reaching opponents through the sync.
    final cardNames = cardsDrawn.map((c) => c.compactName).join(', ');
    _logAction(
      '🎴 drew ${cardsDrawn.length} cards from deck',
      privateMessage: '🎯 drew: $cardNames',
    );

    _maybeActivateLastCallAfterDraw();

    return true;
  }

  /// Whether a [GameConfig.requiredDrawCount] draw can be completed now,
  /// optionally after [extraDiscardCards] more cards land on the discard pile.
  ///
  /// Models the next player's draw after the current player discards: the
  /// stock is used first, then an emergency reshuffle that keeps the top
  /// discard and feeds the rest back into the deck.
  bool canFulfillRequiredDraw({int extraDiscardCards = 0}) {
    if (extraDiscardCards < 0) {
      extraDiscardCards = 0;
    }

    final deckSize = deck.size;
    if (deckSize >= GameConfig.requiredDrawCount) {
      return true;
    }

    final discardAfter = discardPile.length + extraDiscardCards;
    if (discardAfter < GameConfig.minDiscardForReshuffle) {
      return false;
    }

    final afterReshuffle = deckSize + (discardAfter - 1);
    return afterReshuffle >= GameConfig.requiredDrawCount;
  }

  /// Marks this turn as the last playable one when the next draw cannot land.
  void _maybeActivateLastCallAfterDraw() {
    if (canFulfillRequiredDraw(extraDiscardCards: 1)) {
      lastCallActive = false;
      lastCallAlertPending = false;
      return;
    }

    lastCallActive = true;
    lastCallAlertPending = true;
    _logAction(
      '⚠️ LAST CALL: Not enough cards remain for another draw. '
      'Play remaining cards this turn — the round will end after you discard.',
    );
  }

  void _resetLastCallTracking() {
    lastCallActive = false;
    lastCallAlertPending = false;
  }

  /// Returns true once when the last-call modal should be shown.
  bool consumeLastCallAlert() {
    if (!lastCallAlertPending) {
      return false;
    }
    lastCallAlertPending = false;
    return true;
  }

  /// Returns true once when the 3s-stalemate warning modal should be shown.
  bool consumeStalemateAlert() {
    if (!stalemateAlertPending) {
      return false;
    }
    stalemateAlertPending = false;
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

    // Take leftover discard cards first, then fill from the draw pile so
    // the unlock pickup still totals [GameConfig.additionalDiscardPickup]
    // when cards remain.
    final pickup = _collectUnlockPickupCards();
    final additionalCards = pickup.cards;
    final fromDiscardCount = pickup.fromDiscardCount;
    lastUnlockFromDiscardCount = fromDiscardCount;
    lastUnlockPickupCards = List<PlayingCard>.from(additionalCards);

    if (additionalCards.isNotEmpty) {
      currentPlayer.addNewlyDrawnCards(additionalCards);

      // Same privacy rule as drawing: the shared log records only the count,
      // while the card names stay a device-local detail for the acting player.
      if (fromDiscardCount > 0) {
        final discardNames = additionalCards
            .take(fromDiscardCount)
            .map((c) => c.compactName)
            .join(', ');
        _logAction(
          'took $fromDiscardCount more cards from discard pile',
          privateMessage:
              'took $fromDiscardCount more cards from discard pile: $discardNames',
        );
      }

      final fromDeckCount = additionalCards.length - fromDiscardCount;
      if (fromDeckCount > 0) {
        final deckNames = additionalCards
            .skip(fromDiscardCount)
            .map((c) => c.compactName)
            .join(', ');
        _logAction(
          'took $fromDeckCount more cards from draw pile to complete unlock',
          privateMessage:
              'took $fromDeckCount more cards from draw pile to complete unlock: $deckNames',
        );
      }
    } else {
      _logAction('no additional cards available in discard pile or draw pile');
    }

    turnPhase = TurnPhase.meld;
    discardPileFrozen = false;
    hasTakenDiscardThisTurn = true;
    return true;
  }

  bool playMeld(List<PlayingCard> cards) {
    if (turnPhase != TurnPhase.meld) return false;

    if (GoOutGuards.wouldCreateMeldLeaveUnfinishable(currentPlayer, cards)) {
      _logAction(
        'Cannot meld — would leave too few cards without both books to go out',
      );
      return false;
    }

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

    if (GoOutGuards.wouldCreateMeldLeaveUnfinishable(currentPlayer, cards)) {
      _logAction(
        'Cannot meld — would leave too few cards without both books to go out',
      );
      return false;
    }

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

    if (GoOutGuards.wouldAddToMeldLeaveUnfinishable(
      currentPlayer,
      meldIndex,
      card,
    )) {
      _logAction(
        'Cannot add to meld — would leave too few cards without both books '
        'to go out',
      );
      return false;
    }

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

      // Emergency ends (stalemate / empty deck) must not credit a go-out.
      if (phase == GamePhase.roundEnd || phase == GamePhase.gameEnd) {
        return true;
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
    // Only consecutive *current* 3-discards while the deck is low count.
    // Scanning the whole recentActions buffer (older 3s + any reshuffle)
    // produced false stalemates (session_17870997145344534).
    if (deck.size >= GameConfig.stalemateDeckThreshold) {
      _resetStalemateTracking();
      return;
    }

    final cardsToCheck = discardPile.length > GameConfig.stalemateCheckCardCount
        ? discardPile
              .skip(discardPile.length - GameConfig.stalemateCheckCardCount)
              .toList()
        : discardPile;
    final onlyThreesInPile =
        cardsToCheck.isNotEmpty && cardsToCheck.every((card) => card.isThree);
    if (!onlyThreesInPile) {
      _resetStalemateTracking();
      return;
    }

    if (!_stalemateTrackingActive) {
      _stalemateTrackingActive = true;
      _stalemateDiscardCount = 1;
      return;
    }

    final previousCount = _stalemateDiscardCount;
    _stalemateDiscardCount++;

    final warningAt = players.length;
    final endAt = players.length * GameConfig.stalemateEndRotations;
    if (_stalemateDiscardCount >= endAt && previousCount < endAt) {
      _logAction(
        '🛑 STALEMATE DETECTED: All players discarded 3s for two full rotations',
      );
      _emergencyEndRoundDueToStalemate();
    } else if (_stalemateDiscardCount >= warningAt &&
        previousCount < warningAt) {
      stalemateAlertPending = true;
      _logAction(
        '⚠️ WARNING: Only 3s in discard pile with low deck (${deck.size} cards remaining)',
      );
      _logAction(
        'Round will end automatically if all players discard 3s again',
      );
    }
  }

  void _resetStalemateTracking() {
    _stalemateTrackingActive = false;
    _stalemateDiscardCount = 0;
  }

  void _emergencyEndRoundDueToStalemate() {
    if (phase == GamePhase.roundEnd || phase == GamePhase.gameEnd) {
      return;
    }

    emergencyRoundEndReason = EmergencyRoundEndReason.stalemate;
    playerWhoWentOutIndex = null;
    _logAction('🛑 Round ended due to 3s stalemate - no cards can be drawn');
    _logAction('Only 3s were in the discard pile with insufficient deck cards');
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

    final pickup = _collectUnlockPickupCards();
    lastUnlockFromDiscardCount = pickup.fromDiscardCount;
    lastUnlockPickupCards = List<PlayingCard>.from(pickup.cards);
    if (pickup.cards.isNotEmpty) {
      player.addCardsToHand(pickup.cards);
    }

    return true;
  }

  /// Takes leftover discard cards first, then fills from the draw pile so
  /// the unlock pickup totals [GameConfig.additionalDiscardPickup] when
  /// cards remain.
  ({List<PlayingCard> cards, int fromDiscardCount})
  _collectUnlockPickupCards() {
    final additionalCards = <PlayingCard>[];
    for (
      int i = 0;
      i < GameConfig.additionalDiscardPickup && discardPile.isNotEmpty;
      i++
    ) {
      additionalCards.add(discardPile.removeLast());
    }

    final fromDiscardCount = additionalCards.length;
    final neededFromDeck =
        GameConfig.additionalDiscardPickup - fromDiscardCount;
    if (neededFromDeck > 0) {
      additionalCards.addAll(_drawUnlockFillFromDeck(neededFromDeck));
    }
    return (cards: additionalCards, fromDiscardCount: fromDiscardCount);
  }

  void endRound() {
    // Prevent multiple endRound calls (including after the game already ended)
    if (phase == GamePhase.roundEnd || phase == GamePhase.gameEnd) {
      return;
    }

    phase = GamePhase.roundEnd;

    // Emergency ends are not go-outs. Only credit a go-out that was recorded,
    // or (for normal play) a player who actually emptied their hand.
    Player? playerWhoWentOut;
    if (emergencyRoundEndReason == null) {
      if (playerWhoWentOutIndex != null &&
          playerWhoWentOutIndex! >= 0 &&
          playerWhoWentOutIndex! < players.length) {
        playerWhoWentOut = players[playerWhoWentOutIndex!];
      } else {
        final playersWhoCanGoOut = players.where((p) => p.canGoOut).toList();
        playerWhoWentOut = playersWhoCanGoOut.isEmpty
            ? null
            : playersWhoCanGoOut.first;
      }
    }

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
    if (highestScore >= GameConfig.winningScore) {
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

  /// Public emergency end for an empty / unusable deck (not a go-out).
  void emergencyEndRoundForInsufficientCards() {
    if (phase == GamePhase.roundEnd || phase == GamePhase.gameEnd) {
      return;
    }
    _emergencyEndRoundInsufficientCards();
  }

  /// Emergency round end when insufficient cards prevent normal gameplay
  void _emergencyEndRoundInsufficientCards() {
    emergencyRoundEndReason = EmergencyRoundEndReason.insufficientCards;
    playerWhoWentOutIndex = null;
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

  /// Ends the round when a player already meets go-out conditions but the
  /// playing phase never transitioned (e.g. multiplayer sync lost final-turn
  /// fields). Returns true when recovery ended the round.
  ///
  /// Uses an immediate round end — opponents may already have taken turns
  /// while the go-out flag was missing.
  bool recoverStuckGoOutIfNeeded() {
    if (phase != GamePhase.playing || finalTurnPhaseActive) {
      return false;
    }

    final stuckIndex = players.indexWhere((player) => player.canGoOut);
    if (stuckIndex < 0) {
      return false;
    }

    playerWhoWentOutIndex = stuckIndex;
    _logAction(
      'Recovered stuck go-out for ${players[stuckIndex].name} — ending round',
    );
    endRound();
    return true;
  }

  /// Validates the current game state for consistency and logs any issues found.
  /// This is a defensive measure to catch edge cases where the game state becomes inconsistent.
  void validateGameState() {
    final validationErrors = <String>[];

    // Check if any player meets going out conditions but game is still in playing phase
    for (final player in players) {
      final playerIndex = players.indexOf(player);
      final isExpectedWentOutDuringFinalTurn =
          finalTurnPhaseActive && playerIndex == playerWhoWentOutIndex;
      if (player.canGoOut &&
          phase == GamePhase.playing &&
          !isExpectedWentOutDuringFinalTurn) {
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

    // Check if round should have ended but hasn't (skip expected final-turn state)
    if (phase == GamePhase.playing && !finalTurnPhaseActive) {
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

  /// Draws up to [count] cards from the deck to complete an unlock pickup.
  ///
  /// Reshuffles leftover discard cards if the deck is empty. Returns whatever
  /// is available rather than ending the round — the unlock meld already
  /// happened, and a short stock just means a smaller pickup.
  List<PlayingCard> _drawUnlockFillFromDeck(int count) {
    final drawn = <PlayingCard>[];
    if (count <= 0) {
      return drawn;
    }

    if (deck.size < count) {
      _attemptReshuffleForEmptyDeck();
    }

    for (int i = 0; i < count; i++) {
      PlayingCard? card;
      if (!deck.isEmpty) {
        card = deck.drawCard();
      } else {
        _attemptReshuffleForEmptyDeck();
        if (!deck.isEmpty) {
          card = deck.drawCard();
        }
      }

      if (card == null) {
        break;
      }
      drawn.add(card);
    }

    return drawn;
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
    _resetStalemateTracking();

    _logAction(
      'force reshuffled ${cardsToShuffle.length} cards from discard into deck',
    );
  }
}
