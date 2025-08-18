import 'card.dart';
import 'deck.dart';
import 'player.dart';
import 'meld.dart';

enum GamePhase { setup, playing, roundEnd, gameEnd }

enum TurnPhase { draw, meld, discard }

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
  }) : discardPile = discardPile ?? [],
       recentActions = recentActions ?? [];

  Player get currentPlayer => players[currentPlayerIndex];

  PlayingCard? get topDiscard => discardPile.isEmpty ? null : discardPile.last;

  void _logAction(String message, {bool showCardDetails = true}) {
    // Determine if card details should be shown based on player type and action visibility
    final isHuman = currentPlayer.type == PlayerType.human;
    final isPublicAction =
        message.contains('discard') ||
        message.contains('meld') ||
        message.contains('unlocked') ||
        message.contains('picked up foot') ||
        message.contains('went out');

    final shouldShowDetails = showCardDetails && (isHuman || isPublicAction);
    final finalMessage = shouldShowDetails
        ? message
        : _sanitizeMessage(message);

    recentActions.add(
      GameAction(message: finalMessage, playerName: currentPlayer.name),
    );

    // Keep only the last 10 actions to avoid memory issues
    if (recentActions.length > 10) {
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
  }

  void startRound() {
    phase = GamePhase.playing;
    currentPlayerIndex = 0;
    turnPhase = TurnPhase.draw;
    discardPileFrozen = false;
    hasDrawnFromDeck = false;
    hasMelded = false;

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

  bool drawFromDeck() {
    if (hasDrawnFromDeck || deck.isEmpty) return false;

    // Draw 2 cards from deck by default
    final cards = deck.drawCards(2);
    if (cards.isNotEmpty) {
      currentPlayer.addCardsToHand(cards);
      hasDrawnFromDeck = true;
      turnPhase = TurnPhase.meld;

      final cardNames = cards.map((c) => c.displayName).join(', ');
      _logAction('drew: $cardNames');

      return true;
    }
    return false;
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
          final cardName = card.displayName;
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
          final cardName = card.displayName;
          final meldRank = existingMeld.rank.name;
          _logAction(
            'ERROR: Failed to add $cardName to $meldRank meld during unlock',
          );
          return false;
        }
      }
      final meldCardNames = meldCards.map((c) => c.displayName).join(', ');
      _logAction(
        'unlocked discard pile and added to existing meld: $meldCardNames',
      );
    } else {
      // Create new meld
      final meld = Meld.createMeld(meldCards);
      if (meld != null) {
        currentPlayer.melds.add(meld);
        final meldCardNames = meldCards.map((c) => c.displayName).join(', ');
        _logAction('unlocked discard pile and melded: $meldCardNames');
      }
    }

    currentPlayer.hasPlayedDown = true; // Ensure play-down status is set

    // Take the next 5 cards from discard pile (or what's available)
    final additionalDiscards = <PlayingCard>[];
    for (int i = 0; i < 5 && discardPile.isNotEmpty; i++) {
      additionalDiscards.add(discardPile.removeLast());
    }
    if (additionalDiscards.isNotEmpty) {
      currentPlayer.addCardsToHand(additionalDiscards);
      final additionalNames = additionalDiscards
          .map((c) => c.displayName)
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

      final cardNames = cards.map((c) => c.displayName).join(', ');
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

      final cardNames = cards.map((c) => c.displayName).join(', ');
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

      return true;
    }
    return false;
  }

  bool addToMeld(int meldIndex, PlayingCard card) {
    if (turnPhase != TurnPhase.meld) return false;

    if (currentPlayer.addToMeld(meldIndex, card)) {
      _logAction('added ${card.displayName} to existing meld');

      // Check if hand is empty after adding to meld and pick up foot if needed
      if (currentPlayer.isHandEmpty && !currentPlayer.hasPickedUpFoot) {
        currentPlayer.pickUpFoot();
        _logAction('picked up foot pile');
      }

      return true;
    }
    return false;
  }

  bool discard(PlayingCard card) {
    if (turnPhase != TurnPhase.meld && turnPhase != TurnPhase.discard) {
      return false;
    }

    final removed = currentPlayer.removeCardFromHand(card);
    if (removed != null) {
      discardPile.add(removed);
      _logAction('discarded ${card.displayName}');

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
    phase = GamePhase.roundEnd;

    // Find the player who went out (if any)
    final playersWhoCanGoOut = players.where((p) => p.canGoOut).toList();
    final playerWhoWentOut = playersWhoCanGoOut.isEmpty
        ? null
        : playersWhoCanGoOut.first;

    for (final player in players) {
      var roundScore = player.calculateTotalScore();

      // Add going out bonus
      if (player == playerWhoWentOut) {
        roundScore += 100;
      }

      player.updateScore(roundScore);
    }

    final highestScore = players
        .map((p) => p.score)
        .reduce((a, b) => a > b ? a : b);
    if (highestScore >= 8500) {
      phase = GamePhase.gameEnd;
      winner = players.where((p) => p.score == highestScore).first;
    } else {
      round++;
    }
  }

  void resetForNewRound() {
    if (phase != GamePhase.roundEnd) return;

    deck.addCards(discardPile);
    for (final player in players) {
      deck.addCards(player.hand);
      deck.addCards(player.foot);
      player.hand.clear();
      player.foot.clear();
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
}
