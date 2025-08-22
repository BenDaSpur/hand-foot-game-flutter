import 'dart:convert';
import 'dart:math';
import '../models/card.dart';
import '../models/deck.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../models/meld.dart';
import '../services/game_save_service.dart';

class GameController {
  final GameState _gameState;
  final int? gameSeed;

  factory GameController({required List<Player> players, int? seed}) {
    final actualSeed = seed ?? Random().nextInt(1000000);
    return GameController._internal(
      players: players,
      seed: actualSeed,
      gameState: GameState(
        players: players,
        deck: Deck.createHandAndFootDeck(players.length, seed: actualSeed),
      ),
    );
  }

  GameController._internal({
    required List<Player> players,
    required int seed,
    required GameState gameState,
  }) : gameSeed = seed,
       _gameState = gameState;

  GameState get gameState => _gameState;

  void initializeGame() {
    _gameState.deck.shuffle();
    _gameState.startRound();
    _gameState.dealCards();
  }

  bool drawFromDeck() {
    return _gameState.drawFromDeck();
  }

  bool drawFromDiscardPile() {
    return _gameState.drawFromDiscard();
  }

  bool unlockDiscardPile() {
    return _gameState.unlockDiscard();
  }

  bool canUnlockDiscard() {
    return _gameState.canUnlockDiscard();
  }

  bool createMeld(List<PlayingCard> cards) {
    final result = _gameState.playMeld(cards);

    // Defensive validation after potentially critical game state change
    _gameState.validateGameState();

    return result;
  }

  bool createMeldBypass(List<PlayingCard> cards) {
    final result = _gameState.playMeldBypass(cards);

    // Defensive validation after potentially critical game state change
    _gameState.validateGameState();

    return result;
  }

  /// Creates multiple melds at once from card indices to avoid index shifting issues
  bool createMultipleMeldsFromIndices(
    List<List<int>> allMeldIndices, {
    bool skipPlayDownCheck = false,
  }) {
    final humanPlayer = _gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // First validate all indices are within bounds
    for (final meldIndices in allMeldIndices) {
      for (final index in meldIndices) {
        if (index < 0 || index >= humanPlayer.currentHand.length) {
          return false; // Invalid index
        }
      }
    }

    // Convert all indices to actual cards before any removal
    final allMeldCards = <List<PlayingCard>>[];
    final allIndicesSorted = <List<int>>[];

    for (final meldIndices in allMeldIndices) {
      final cards = meldIndices
          .map((index) => humanPlayer.currentHand[index])
          .toList();
      allMeldCards.add(cards);

      // Sort indices in descending order for safe removal
      final sortedIndices = List<int>.from(meldIndices)
        ..sort((a, b) => b.compareTo(a));
      allIndicesSorted.add(sortedIndices);
    }

    // Validate all melds can be created
    for (final cards in allMeldCards) {
      if (Meld.createMeld(cards) == null) {
        return false; // Invalid meld
      }
    }

    // Check total play down requirement if needed
    if (!skipPlayDownCheck && !humanPlayer.hasPlayedDown) {
      final totalPoints = allMeldCards
          .expand((cards) => cards)
          .fold<int>(0, (sum, card) => sum + card.pointValue);

      if (totalPoints < _gameState.playDownRequirement) {
        return false; // Doesn't meet play down requirement
      }
    }

    // Now remove all cards from hand (sorted indices prevent shifting issues)
    // We need to collect all indices first and sort them in descending order
    final allIndicesToRemove = <int>[];
    for (final meldIndices in allMeldIndices) {
      allIndicesToRemove.addAll(meldIndices);
    }
    allIndicesToRemove.sort((a, b) => b.compareTo(a)); // Sort descending

    // Remove duplicates while preserving order
    final uniqueIndices = <int>[];
    for (final index in allIndicesToRemove) {
      if (!uniqueIndices.contains(index)) {
        uniqueIndices.add(index);
      }
    }

    // Remove cards from hand
    humanPlayer.removeCardsByIndices(uniqueIndices);

    // Create all melds and add to existing melds where appropriate
    int meldsCreated = 0;
    final cardNamesCreated = <String>[];

    for (int i = 0; i < allMeldCards.length; i++) {
      final cards = allMeldCards[i];
      final naturalCards = cards.where((card) => !card.isWild).toList();

      // Check if we should add to existing meld
      if (naturalCards.isNotEmpty) {
        final rank = naturalCards.first.rank;
        final existingMeldIndex = humanPlayer.findMeldByRank(rank);

        if (existingMeldIndex != -1) {
          // Add to existing meld
          final existingMeld = humanPlayer.melds[existingMeldIndex];
          for (final card in cards) {
            existingMeld.addCard(card);
          }
          cardNamesCreated.add(
            'added to ${rank.name}: ${cards.map((c) => c.displayName).join(', ')}',
          );
        } else {
          // Create new meld
          final meld = Meld.createMeld(cards)!; // We already validated this
          humanPlayer.melds.add(meld);
          cardNamesCreated.add(
            'new ${rank.name}: ${cards.map((c) => c.displayName).join(', ')}',
          );
          meldsCreated++;
        }
      }
    }

    if (meldsCreated > 0 || cardNamesCreated.isNotEmpty) {
      // Log actions
      final wasFirstPlayDown = !humanPlayer.hasPlayedDown;

      // Update game state
      _gameState.hasMelded = true;
      humanPlayer.hasPlayedDown = true;

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

      // Check for foot pickup
      if (humanPlayer.isHandEmpty && !humanPlayer.hasPickedUpFoot) {
        humanPlayer.pickUpFoot();
        _gameState.logAction('picked up foot pile');
      }

      return true;
    }

    return false;
  }

  bool createMeldByIndices(
    List<int> cardIndices, {
    bool skipPlayDownCheck = false,
  }) {
    final humanPlayer = _gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Validate all indices first - must be within bounds and non-negative
    for (final index in cardIndices) {
      if (index < 0 || index >= humanPlayer.currentHand.length) {
        return false; // Invalid index
      }
    }

    // Get the actual cards at these indices
    final cards = cardIndices
        .map((index) => humanPlayer.currentHand[index])
        .toList();

    // Check play down requirement if player hasn't played down yet
    // Skip this check when creating multiple melds (UI already validated total)
    if (!skipPlayDownCheck && !humanPlayer.hasPlayedDown) {
      final cardPointValue = cards.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      if (cardPointValue < _gameState.playDownRequirement) {
        return false;
      }
    }

    // First, check if we should add to an existing meld
    final naturalCards = cards.where((card) => !card.isWild).toList();
    if (naturalCards.isNotEmpty) {
      final rank = naturalCards.first.rank;
      final existingMeldIndex = humanPlayer.findMeldByRank(rank);

      if (existingMeldIndex != -1) {
        // Add to existing meld
        final existingMeld = humanPlayer.melds[existingMeldIndex];

        // Validate all cards can be added to existing meld
        for (final card in cards) {
          if (!existingMeld.canAddCard(card)) {
            return false; // Can't add this card to existing meld
          }
        }

        // Remove cards from hand first
        humanPlayer.removeCardsByIndices(cardIndices);

        // Add all cards to existing meld
        for (final card in cards) {
          existingMeld.addCard(card);
        }

        // Use the game state method to handle all side effects properly
        _gameState.hasMelded = true;

        // Log the action
        final cardNames = cards.map((c) => c.displayName).join(', ');
        _gameState.logAction('added to existing meld: $cardNames');

        // Check for foot pickup
        if (humanPlayer.isHandEmpty && !humanPlayer.hasPickedUpFoot) {
          humanPlayer.pickUpFoot();
          _gameState.logAction('picked up foot pile');
        }

        humanPlayer.hasPlayedDown = true;
        return true;
      }
    }

    // No existing meld, try to create new meld
    final meld = Meld.createMeld(cards);
    if (meld != null) {
      // Create new meld
      humanPlayer.removeCardsByIndices(cardIndices);
      humanPlayer.melds.add(meld);

      // Use the game state method to handle all side effects properly
      _gameState.hasMelded = true;

      // Log the action
      final cardNames = cards.map((c) => c.displayName).join(', ');
      final wasFirstMeld = !humanPlayer.hasPlayedDown;
      if (wasFirstMeld) {
        final points = cards.fold<int>(0, (sum, card) => sum + card.pointValue);
        _gameState.logAction('played down with $points points: $cardNames');
      } else {
        _gameState.logAction('created new meld: $cardNames');
      }

      // Check for foot pickup
      if (humanPlayer.isHandEmpty && !humanPlayer.hasPickedUpFoot) {
        humanPlayer.pickUpFoot();
        _gameState.logAction('picked up foot pile');
      }

      humanPlayer.hasPlayedDown = true;
      return true;
    }
    return false;
  }

  bool addCardToMeld(int meldIndex, PlayingCard card) {
    final result = _gameState.addToMeld(meldIndex, card);

    // Defensive validation after potentially critical game state change
    _gameState.validateGameState();

    return result;
  }

  bool discardCard(PlayingCard card) {
    final result = _gameState.discard(card);

    // Defensive validation after potentially critical game state change
    _gameState.validateGameState();

    return result;
  }

  bool canPlayerGoOut() {
    final player = _gameState.currentPlayer;
    return player.canGoOut && player.hasBook();
  }

  List<List<PlayingCard>> findPossibleMelds(Player player) {
    final possibleMelds = <List<PlayingCard>>[];
    final hand = List<PlayingCard>.from(player.currentHand);

    final cardsByRank = <CardRank, List<PlayingCard>>{};
    final wildCards = <PlayingCard>[];

    for (final card in hand) {
      if (card.isWild) {
        wildCards.add(card);
      } else {
        cardsByRank.putIfAbsent(card.rank, () => []).add(card);
      }
    }

    for (final entry in cardsByRank.entries) {
      final naturalCards = entry.value;

      // Skip 3s - they cannot be melded in Hand & Foot
      if (entry.key == CardRank.three) {
        continue;
      }

      if (naturalCards.length >= 3) {
        possibleMelds.add(naturalCards);
      } else if (naturalCards.length >= 2 && wildCards.isNotEmpty) {
        final meldCards = List<PlayingCard>.from(naturalCards);
        final wildsNeeded = 3 - naturalCards.length;
        final availableWilds = wildCards.take(wildsNeeded).toList();
        if (availableWilds.length == wildsNeeded) {
          meldCards.addAll(availableWilds);
          possibleMelds.add(meldCards);
        }
      }
    }

    // Note: Wild-only melds are not allowed in Hand & Foot rules
    // Wild cards can only supplement natural card melds

    return possibleMelds;
  }

  List<PlayingCard> getPlayableCards() {
    final player = _gameState.currentPlayer;
    final playableCards = <PlayingCard>[];

    if (_gameState.turnPhase == TurnPhase.meld) {
      final possibleMelds = findPossibleMelds(player);
      for (final meld in possibleMelds) {
        playableCards.addAll(meld);
      }

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

  void nextRound() {
    if (_gameState.phase == GamePhase.roundEnd) {
      _gameState.resetForNewRound();
    }
  }

  bool get isGameOver => _gameState.phase == GamePhase.gameEnd;

  Player? get winner => _gameState.winner;

  int get currentRound => _gameState.round;

  List<Player> get leaderboard {
    final sortedPlayers = List<Player>.from(_gameState.players);
    sortedPlayers.sort((a, b) => b.score.compareTo(a.score));
    return sortedPlayers;
  }

  Map<String, dynamic> getGameStatus() {
    return {
      'phase': _gameState.phase.name,
      'turnPhase': _gameState.turnPhase.name,
      'currentPlayer': _gameState.currentPlayer.name,
      'round': _gameState.round,
      'deckSize': _gameState.deck.size,
      'discardPileSize': _gameState.discardPile.length,
      'topDiscard': _gameState.topDiscard?.displayName,
      'canDrawFromDiscard': _gameState.canDrawFromDiscard,
      'discardPileFrozen': _gameState.discardPileFrozen,
    };
  }

  String exportGameState() {
    final export = {
      'gameSeed': gameSeed ?? -1, // -1 indicates legacy game without seed
      'gameState': {
        'phase': _gameState.phase.name,
        'turnPhase': _gameState.turnPhase.name,
        'round': _gameState.round,
        'currentPlayerIndex': _gameState.currentPlayerIndex,
        'discardPileFrozen': _gameState.discardPileFrozen,
        'hasDrawnFromDeck': _gameState.hasDrawnFromDeck,
        'hasMelded': _gameState.hasMelded,
        'playDownRequirement': _gameState.playDownRequirement,
      },
      'players': _gameState.players
          .map(
            (player) => {
              'id': player.id,
              'name': player.name,
              'type': player.type.name,
              'score': player.score,
              'hasPlayedDown': player.hasPlayedDown,
              'roundScore': player.calculateTotalScore(),
              'handSize': player.hand.length,
              'footSize': player.foot.length,
              'currentHandSize': player.currentHand.length,
              'usingFoot': player.hasPickedUpFoot,
              'canGoOut': player.canGoOut,
              'melds': player.melds
                  .map(
                    (meld) => {
                      'type': meld.type.name,
                      'cards': meld.cards
                          .map(
                            (card) => {
                              'suit': card.suit?.name,
                              'rank': card.rank.name,
                            },
                          )
                          .toList(),
                    },
                  )
                  .toList(),
              'hand': player.hand
                  .map(
                    (card) => {'suit': card.suit?.name, 'rank': card.rank.name},
                  )
                  .toList(),
              'foot': player.foot
                  .map(
                    (card) => {'suit': card.suit?.name, 'rank': card.rank.name},
                  )
                  .toList(),
            },
          )
          .toList(),
      'deck': {
        'size': _gameState.deck.size,
        'seed': _gameState.deck.seed,
        'topCard': _gameState.deck.topCard != null
            ? {
                'suit': _gameState.deck.topCard!.suit?.name,
                'rank': _gameState.deck.topCard!.rank.name,
              }
            : null,
      },
      'discardPile': _gameState.discardPile
          .map((card) => {'suit': card.suit?.name, 'rank': card.rank.name})
          .toList(),
      'recentActions': _gameState.recentActions
          .map(
            (action) => {
              'message': action.message,
              'playerName': action.playerName,
              'timestamp': action.timestamp.toIso8601String(),
            },
          )
          .toList(),
      'exportedAt': DateTime.now().toIso8601String(),
      'debugInfo': _generateDebugInfo(),
    };

    return const JsonEncoder.withIndent('  ').convert(export);
  }

  Map<String, dynamic> _generateDebugInfo() {
    final currentPlayer = _gameState.currentPlayer;
    final debugInfo = <String, dynamic>{
      'currentPlayerDebug': {
        'name': currentPlayer.name,
        'type': currentPlayer.type.name,
        'turnPhase': _gameState.turnPhase.name,
      },
    };

    // Add bot-specific debugging for current player
    if (currentPlayer.type == PlayerType.bot) {
      final possibleMelds = findPossibleMelds(currentPlayer);
      debugInfo['botDebug'] = {
        'possibleMeldsCount': possibleMelds.length,
        'possibleMelds': possibleMelds.map((meld) {
          final points = meld.fold<int>(
            0,
            (sum, card) => sum + card.pointValue,
          );
          return {
            'cards': meld
                .map((c) => '${c.rank.name} of ${c.suit?.name ?? 'joker'}')
                .toList(),
            'points': points,
            'meetsPlayDown': points >= _gameState.playDownRequirement,
          };
        }).toList(),
        'canUnlockDiscardPile': _gameState.canDrawFromDiscard,
        'hasPlayedDown': currentPlayer.hasPlayedDown,
        'playDownRequirement': _gameState.playDownRequirement,
      };

      // Add discard pile analysis if relevant
      if (_gameState.discardPile.isNotEmpty) {
        final topDiscard = _gameState.topDiscard!;
        final matchingNaturals = currentPlayer.currentHand
            .where((card) => card.rank == topDiscard.rank && !card.isWild)
            .length;
        debugInfo['botDebug']['discardPileAnalysis'] = {
          'topCard':
              '${topDiscard.rank.name} of ${topDiscard.suit?.name ?? 'joker'}',
          'matchingNaturals': matchingNaturals,
          'canUnlock': matchingNaturals >= 2,
          'pileSize': _gameState.discardPile.length,
          'pileValue': _gameState.discardPile.fold<int>(
            0,
            (sum, card) => sum + card.pointValue,
          ),
        };
      }
    }

    return debugInfo;
  }

  static GameController? fromExportJson(String jsonString) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);

      // Extract basic info
      final gameSeed = data['gameSeed'] as int?;
      final gameStateData = data['gameState'] as Map<String, dynamic>;
      final playersData = data['players'] as List<dynamic>;

      // Recreate players
      final players = <Player>[];
      for (final playerData in playersData) {
        final player = Player(
          id: playerData['id'] as String,
          name: playerData['name'] as String,
          type: PlayerType.values.firstWhere(
            (e) => e.name == playerData['type'],
            orElse: () => PlayerType.bot,
          ),
          score: playerData['score'] as int,
        );

        player.hasPlayedDown = playerData['hasPlayedDown'] as bool;
        player.hasPickedUpFoot = playerData['usingFoot'] as bool;

        // Restore hand
        final handData = playerData['hand'] as List<dynamic>;
        for (final cardData in handData) {
          player.hand.add(
            _createCardFromData(cardData as Map<String, dynamic>),
          );
        }

        // Restore foot
        final footData = playerData['foot'] as List<dynamic>;
        for (final cardData in footData) {
          player.foot.add(
            _createCardFromData(cardData as Map<String, dynamic>),
          );
        }

        // Restore melds
        final meldsData = playerData['melds'] as List<dynamic>;
        for (final meldData in meldsData) {
          final meldCards = <PlayingCard>[];
          final cardsData = meldData['cards'] as List<dynamic>;
          for (final cardData in cardsData) {
            meldCards.add(
              _createCardFromData(cardData as Map<String, dynamic>),
            );
          }
          final meld = Meld.createMeld(meldCards);
          if (meld != null) {
            player.melds.add(meld);
          }
        }

        players.add(player);
      }

      // Create controller with restored state
      final controller = GameController(players: players, seed: gameSeed);

      // Restore game state properties
      final gameState = controller._gameState;
      gameState.currentPlayerIndex = gameStateData['currentPlayerIndex'] as int;
      gameState.round = gameStateData['round'] as int;
      gameState.discardPileFrozen = gameStateData['discardPileFrozen'] as bool;
      gameState.hasDrawnFromDeck = gameStateData['hasDrawnFromDeck'] as bool;
      gameState.hasMelded = gameStateData['hasMelded'] as bool;

      // Set phases
      final phaseName = gameStateData['phase'] as String;
      gameState.phase = GamePhase.values.firstWhere(
        (e) => e.name == phaseName,
        orElse: () => GamePhase.playing,
      );

      final turnPhaseName = gameStateData['turnPhase'] as String;
      gameState.turnPhase = TurnPhase.values.firstWhere(
        (e) => e.name == turnPhaseName,
        orElse: () => TurnPhase.draw,
      );

      // Restore discard pile
      final discardData = data['discardPile'] as List<dynamic>;
      gameState.discardPile.clear();
      for (final cardData in discardData) {
        gameState.discardPile.add(
          _createCardFromData(cardData as Map<String, dynamic>),
        );
      }

      // Restore deck accurately using seed
      if (gameSeed != null) {
        _restoreDeckFromSeed(gameState, gameSeed, players.length);
      }

      return controller;
    } catch (e) {
      // Return null to indicate failure - error handling done in UI
      return null;
    }
  }

  static PlayingCard _createCardFromData(Map<String, dynamic> cardData) {
    final rankName = cardData['rank'] as String;
    final suitName = cardData['suit'] as String?;

    final rank = CardRank.values.firstWhere(
      (r) => r.name == rankName,
      orElse: () => CardRank.ace,
    );

    if (rank == CardRank.joker) {
      return const PlayingCard(rank: CardRank.joker);
    }

    final suit = Suit.values.firstWhere(
      (s) => s.name == suitName,
      orElse: () => Suit.clubs,
    );

    return PlayingCard(suit: suit, rank: rank);
  }

  static void _restoreDeckFromSeed(
    GameState gameState,
    int seed,
    int playerCount,
  ) {
    // Create a fresh deck with the same seed and shuffle it the same way
    final originalDeck = Deck.createHandAndFootDeck(playerCount, seed: seed);
    originalDeck.shuffle();

    // Get all cards from the original shuffled deck
    final allOriginalCards = List<PlayingCard>.from(originalDeck.cards);

    // Collect all cards that have been dealt out
    final dealtCards = <PlayingCard>[];

    // Add all player hand and foot cards
    for (final player in gameState.players) {
      dealtCards.addAll(player.hand);
      dealtCards.addAll(player.foot);

      // Add all cards from melds
      for (final meld in player.melds) {
        dealtCards.addAll(meld.cards);
      }
    }

    // Add discard pile cards
    dealtCards.addAll(gameState.discardPile);

    // Remove dealt cards from the original deck to get remaining cards
    final remainingCards = <PlayingCard>[];
    final dealtCardsCopy = List<PlayingCard>.from(dealtCards);

    for (final originalCard in allOriginalCards) {
      bool found = false;
      for (int i = 0; i < dealtCardsCopy.length; i++) {
        if (_cardsEqual(originalCard, dealtCardsCopy[i])) {
          dealtCardsCopy.removeAt(i);
          found = true;
          break;
        }
      }
      if (!found) {
        remainingCards.add(originalCard);
      }
    }

    // Replace the deck's cards with the remaining cards in correct order
    gameState.deck.replaceCards(remainingCards);
  }

  static bool _cardsEqual(PlayingCard a, PlayingCard b) {
    return a.rank == b.rank && a.suit == b.suit;
  }

  /// Save the current game state to local storage
  Future<void> saveGame() async {
    await GameSaveService.saveGame(_gameState, gameSeed);
  }

  /// Load a saved game from local storage
  static Future<GameController?> loadSavedGame() async {
    final savedData = await GameSaveService.loadGame();
    if (savedData != null) {
      return GameSaveService.restoreGameController(savedData);
    }
    return null;
  }

  /// Check if there is a saved game available
  static Future<bool> hasSavedGame() async {
    return await GameSaveService.hasSavedGame();
  }

  /// Clear the saved game from local storage
  static Future<void> clearSavedGame() async {
    await GameSaveService.clearSavedGame();
  }

  /// Clear newly drawn card highlighting for all players
  /// Useful when game state becomes inconsistent after export/import
  void clearAllNewlyDrawnCards() {
    for (final player in _gameState.players) {
      player.clearNewlyDrawnCards();
    }
  }
}
