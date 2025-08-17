import 'dart:convert';
import 'dart:math';
import '../models/card.dart';
import '../models/deck.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../models/meld.dart';

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
    return _gameState.playMeld(cards);
  }

  bool createMeldBypass(List<PlayingCard> cards) {
    return _gameState.playMeldBypass(cards);
  }

  bool createMeldByIndices(
    List<int> cardIndices, {
    bool skipPlayDownCheck = false,
  }) {
    final humanPlayer = _gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );

    // Get the actual cards at these indices
    final cards = cardIndices
        .where((index) => index < humanPlayer.currentHand.length)
        .map((index) => humanPlayer.currentHand[index])
        .toList();

    final meld = Meld.createMeld(cards);
    if (meld != null) {
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

      // Remove cards by indices (this handles duplicates correctly)
      humanPlayer.removeCardsByIndices(cardIndices);
      humanPlayer.melds.add(meld);
      humanPlayer.hasPlayedDown = true;

      return true;
    }
    return false;
  }

  bool addCardToMeld(int meldIndex, PlayingCard card) {
    return _gameState.addToMeld(meldIndex, card);
  }

  bool discardCard(PlayingCard card) {
    return _gameState.discard(card);
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

    if (wildCards.length >= 3) {
      possibleMelds.add(wildCards.take(3).toList());
    }

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
}
