import 'dart:math';
import '../models/card.dart';
import '../models/deck.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../models/meld.dart';
import '../models/round_score_breakdown.dart';
import '../services/game_save_service.dart';
import '../utils/debug_logger.dart';
import 'game_interface.dart';
import 'managers/meld_manager.dart';
import 'managers/game_serializer.dart';
import 'events/game_event.dart';
import 'events/game_event_bus.dart';

/// Result class for importing game state with bot personalities
class ImportResult {
  final GameController controller;
  final Map<String, String> botPersonalities;

  ImportResult(this.controller, this.botPersonalities);
}

/// Game controller that delegates responsibilities to specialized managers.
///
/// This controller maintains the core game flow and state management while
/// delegating complex operations to specialized manager classes:
/// - MeldManager: Handles all meld-related operations
/// - GameSerializer: Handles export/import of game state
///
/// This design improves maintainability, testability, and follows the
/// Single Responsibility Principle.
class GameController implements GameInterface {
  final GameState _gameState;
  late final MeldManager _meldManager;
  final GameEventBus _eventBus;

  @override
  final int? gameSeed;

  factory GameController({
    required List<Player> players,
    int? seed,
    GameEventBus? eventBus,
  }) {
    final actualSeed = seed ?? Random().nextInt(1000000);
    final gameState = GameState(
      players: players,
      deck: Deck.createHandAndFootDeck(players.length, seed: actualSeed),
    );

    return GameController._internal(
      gameState: gameState,
      seed: actualSeed,
      eventBus: eventBus ?? gameEventBus,
    );
  }

  GameController._internal({
    required GameState gameState,
    required int seed,
    required GameEventBus eventBus,
  }) : gameSeed = seed,
       _gameState = gameState,
       _eventBus = eventBus {
    _meldManager = MeldManager(_gameState);
  }

  @override
  GameState get gameState => _gameState;

  // ============= Core Game Flow =============

  @override
  void initializeGame() {
    _gameState.deck.shuffle();
    _gameState.startRound();
    _gameState.dealCards();

    // Publish round started event
    _eventBus.publish(RoundStartedEvent(roundNumber: _gameState.round));

    // Auto-save after new game initialization
    saveGame().catchError((e) => DebugLogger.error('Auto-save failed: $e'));
  }

  @override
  bool drawFromDeck() {
    final player = _gameState.currentPlayer;
    final result = _gameState.drawFromDeck();

    if (result && player.currentHand.isNotEmpty) {
      // Get the last card drawn (newest in hand)
      final drawnCard = player.currentHand.last;
      _eventBus.publish(
        CardDrawnEvent(card: drawnCard, fromDeck: true, player: player),
      );
    }

    return result;
  }

  @override
  bool drawFromDiscardPile() {
    final player = _gameState.currentPlayer;
    final topDiscard = _gameState.topDiscard;
    final result = _gameState.drawFromDiscard();

    if (result && topDiscard != null) {
      _eventBus.publish(
        CardDrawnEvent(card: topDiscard, fromDeck: false, player: player),
      );
    }

    return result;
  }

  @override
  bool unlockDiscardPile() {
    final player = _gameState.currentPlayer;
    final cardsBefore = _gameState.discardPile.length;
    final result = _gameState.unlockDiscard();

    if (result) {
      // Calculate how many cards were taken
      final cardsAfter = _gameState.discardPile.length;
      final cardsTaken = cardsBefore - cardsAfter;
      final takenCards = _gameState.currentPlayer.currentHand
          .take(cardsTaken)
          .toList();

      _eventBus.publish(
        DiscardPileUnlockedEvent(cardsTaken: takenCards, player: player),
      );
    }

    return result;
  }

  @override
  bool canUnlockDiscard() {
    return _gameState.canUnlockDiscard();
  }

  @override
  bool discardCard(PlayingCard card) {
    final player = _gameState.currentPlayer;
    final result = _gameState.discard(card);
    _gameState.validateGameState();

    if (result) {
      _eventBus.publish(CardDiscardedEvent(card: card, player: player));

      // Check if turn ended (player changed or phase changed)
      final newPlayer = _gameState.currentPlayer;
      if (newPlayer.id != player.id || _gameState.turnPhase == TurnPhase.draw) {
        _eventBus.publish(
          TurnEndedEvent(
            turnNumber: _gameState.currentPlayerIndex,
            nextPlayer: newPlayer,
            player: player,
          ),
        );
      }
    }

    // Auto-save only after human player discards in single player games
    if (result && player.type == PlayerType.human) {
      saveGame().catchError((e) => DebugLogger.error('Auto-save failed: $e'));
    }

    return result;
  }

  /// Publish a TurnEndedEvent manually for forced turn advances.
  /// Used by BotTurnManager when it bypasses the normal discard flow.
  void publishTurnEndedEvent(Player previousPlayer) {
    _eventBus.publish(
      TurnEndedEvent(
        turnNumber: _gameState.currentPlayerIndex,
        nextPlayer: _gameState.currentPlayer,
        player: previousPlayer,
      ),
    );
  }

  @override
  void nextRound() {
    if (_gameState.phase == GamePhase.roundEnd) {
      _gameState.resetForNewRound();

      // Publish round started event
      _eventBus.publish(RoundStartedEvent(roundNumber: _gameState.round));

      // Auto-save after round transition
      saveGame().catchError((e) => DebugLogger.error('Auto-save failed: $e'));
    }
  }

  // ============= Meld Operations (Delegated) =============

  @override
  bool createMeld(List<PlayingCard> cards) {
    final player = _gameState.currentPlayer;
    final hadPlayedDown = player.hasPlayedDown;
    final hadPickedUpFoot = player.hasPickedUpFoot;
    final roundBefore = _gameState.round;
    final phaseBefore = _gameState.phase;

    final result = _gameState.playMeld(cards);
    _gameState.validateGameState();

    if (result && player.melds.isNotEmpty) {
      final newMeld = player.melds.last;
      _eventBus.publish(
        MeldCreatedEvent(meld: newMeld, cards: cards, player: player),
      );

      // Check if this is the first play-down
      if (!hadPlayedDown && player.hasPlayedDown) {
        final pointsPlayed = cards.fold<int>(
          0,
          (sum, card) => sum + card.pointValue,
        );
        _eventBus.publish(
          PlayedDownEvent(pointsPlayed: pointsPlayed, player: player),
        );
      }

      // Check if foot was picked up
      if (!hadPickedUpFoot && player.hasPickedUpFoot) {
        _eventBus.publish(FootPickedUpEvent(player: player));
      }

      // Check if player went out (round or game ended)
      if (_gameState.phase != phaseBefore) {
        if (_gameState.phase == GamePhase.roundEnd) {
          _eventBus.publish(
            PlayerWentOutEvent(roundNumber: roundBefore, player: player),
          );

          // Calculate round scores
          final roundScores = <Player, int>{};
          for (final p in _gameState.players) {
            roundScores[p] = p.score;
          }
          _eventBus.publish(
            RoundEndedEvent(roundNumber: roundBefore, roundScores: roundScores),
          );
        } else if (_gameState.phase == GamePhase.gameEnd) {
          _eventBus.publish(
            PlayerWentOutEvent(roundNumber: roundBefore, player: player),
          );

          final roundScores = <Player, int>{};
          for (final p in _gameState.players) {
            roundScores[p] = p.score;
          }
          _eventBus.publish(
            RoundEndedEvent(roundNumber: roundBefore, roundScores: roundScores),
          );

          if (_gameState.winner != null) {
            final finalScores = <Player, int>{};
            for (final p in _gameState.players) {
              finalScores[p] = p.score;
            }
            _eventBus.publish(
              GameEndedEvent(
                winner: _gameState.winner!,
                finalScores: finalScores,
              ),
            );
          }
        }
      }
    }

    return result;
  }

  @override
  bool createMeldBypass(List<PlayingCard> cards) {
    final result = _gameState.playMeldBypass(cards);
    _gameState.validateGameState();
    return result;
  }

  @override
  bool createMeldByIndices(
    List<int> cardIndices, {
    bool skipPlayDownCheck = false,
  }) {
    return _meldManager.createMeldByIndices(
      cardIndices,
      skipPlayDownCheck: skipPlayDownCheck,
    );
  }

  @override
  bool createMultipleMeldsFromIndices(
    List<List<int>> allMeldIndices, {
    bool skipPlayDownCheck = false,
  }) {
    return _meldManager.createMultipleMeldsFromIndices(
      allMeldIndices,
      skipPlayDownCheck: skipPlayDownCheck,
    );
  }

  @override
  bool addCardToMeld(int meldIndex, PlayingCard card) {
    final player = _gameState.currentPlayer;
    final hadPickedUpFoot = player.hasPickedUpFoot;
    final roundBefore = _gameState.round;
    final phaseBefore = _gameState.phase;
    final meld = player.melds[meldIndex];
    final result = _gameState.addToMeld(meldIndex, card);
    _gameState.validateGameState();

    if (result) {
      _eventBus.publish(
        CardAddedToMeldEvent(
          meldIndex: meldIndex,
          card: card,
          meld: meld,
          player: player,
        ),
      );

      // Check if foot was picked up
      if (!hadPickedUpFoot && player.hasPickedUpFoot) {
        _eventBus.publish(FootPickedUpEvent(player: player));
      }

      // Check if player went out (round or game ended)
      if (_gameState.phase != phaseBefore) {
        if (_gameState.phase == GamePhase.roundEnd) {
          _eventBus.publish(
            PlayerWentOutEvent(roundNumber: roundBefore, player: player),
          );

          final roundScores = <Player, int>{};
          for (final p in _gameState.players) {
            roundScores[p] = p.score;
          }
          _eventBus.publish(
            RoundEndedEvent(roundNumber: roundBefore, roundScores: roundScores),
          );
        } else if (_gameState.phase == GamePhase.gameEnd) {
          _eventBus.publish(
            PlayerWentOutEvent(roundNumber: roundBefore, player: player),
          );

          final roundScores = <Player, int>{};
          for (final p in _gameState.players) {
            roundScores[p] = p.score;
          }
          _eventBus.publish(
            RoundEndedEvent(roundNumber: roundBefore, roundScores: roundScores),
          );

          if (_gameState.winner != null) {
            final finalScores = <Player, int>{};
            for (final p in _gameState.players) {
              finalScores[p] = p.score;
            }
            _eventBus.publish(
              GameEndedEvent(
                winner: _gameState.winner!,
                finalScores: finalScores,
              ),
            );
          }
        }
      }
    }

    return result;
  }

  @override
  List<List<PlayingCard>> findPossibleMelds(Player player) {
    return _meldManager.findPossibleMelds(player);
  }

  @override
  List<PlayingCard> getPlayableCards() {
    return _meldManager.getPlayableCards(_gameState.currentPlayer);
  }

  // ============= Game Status and Queries =============

  @override
  bool canPlayerGoOut() {
    final player = _gameState.currentPlayer;
    return player.canGoOut;
  }

  @override
  bool get isGameOver => _gameState.phase == GamePhase.gameEnd;

  @override
  Player? get winner => _gameState.winner;

  @override
  int get currentRound => _gameState.round;

  @override
  List<Player> get leaderboard {
    final sortedPlayers = List<Player>.from(_gameState.players);
    sortedPlayers.sort((a, b) => b.score.compareTo(a.score));
    return sortedPlayers;
  }

  @override
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

  // ============= Serialization (Delegated) =============

  @override
  String exportGameState([Map<String, String>? botPersonalities]) {
    return GameSerializer.exportGameState(
      _gameState,
      gameSeed,
      botPersonalities,
    );
  }

  static ImportResult? fromExportJson(String input) {
    try {
      final data = GameSerializer.importGameState(input);
      if (data == null) return null;

      final gameSeed = data['gameSeed'] as int?;
      final gameStateData = data['gameState'] as Map<String, dynamic>;
      final playersData = data['players'] as List<dynamic>;
      final botPersonalities =
          data['botPersonalities'] as Map<String, String>? ??
          <String, String>{};

      // Recreate players
      final players = <Player>[];
      for (final playerData in playersData) {
        final player = _createPlayerFromData(playerData);
        players.add(player);
      }

      // Create controller
      final controller = GameController(players: players, seed: gameSeed);

      // Restore game state
      _restoreGameState(controller._gameState, gameStateData);

      // Restore discard pile
      final discardPile = data['discardPile'] as List<dynamic>;
      controller._gameState.discardPile.clear();
      for (final card in discardPile) {
        if (card is PlayingCard) {
          controller._gameState.discardPile.add(card);
        }
      }

      // Restore deck
      if (gameSeed != null) {
        GameSerializer.restoreDeckFromSeed(
          controller._gameState,
          gameSeed,
          players.length,
        );
      }

      // Restore recent actions
      _restoreRecentActions(controller._gameState, data['recentActions']);

      return ImportResult(controller, botPersonalities);
    } catch (e) {
      print('[GameController] Import error: $e');
      return null;
    }
  }

  static Player _createPlayerFromData(Map<String, dynamic> playerData) {
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
    for (final card in handData) {
      if (card is PlayingCard) {
        player.hand.add(card);
      } else if (card is Map<String, dynamic>) {
        player.hand.add(_createCardFromData(card));
      }
    }

    // Restore foot
    final footData = playerData['foot'] as List<dynamic>;
    for (final card in footData) {
      if (card is PlayingCard) {
        player.foot.add(card);
      } else if (card is Map<String, dynamic>) {
        player.foot.add(_createCardFromData(card));
      }
    }

    // Restore melds
    final meldsData = playerData['melds'] as List<dynamic>;
    for (final meldData in meldsData) {
      final meldCards = <PlayingCard>[];
      final cardsData = meldData['cards'] as List<dynamic>;

      for (final card in cardsData) {
        if (card is PlayingCard) {
          meldCards.add(card);
        } else if (card is Map<String, dynamic>) {
          meldCards.add(_createCardFromData(card));
        }
      }

      final meld = Meld.createMeld(meldCards);
      if (meld != null) {
        player.melds.add(meld);
      }
    }

    // Restore round score history
    final roundScoreHistoryData = playerData['roundScoreHistory'];
    if (roundScoreHistoryData is List<RoundScoreBreakdown>) {
      player.roundScoreHistory.addAll(roundScoreHistoryData);
    }

    return player;
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

  static void _restoreGameState(
    GameState gameState,
    Map<String, dynamic> data,
  ) {
    gameState.currentPlayerIndex = data['currentPlayerIndex'] as int;
    gameState.round = data['round'] as int;
    gameState.discardPileFrozen = data['discardPileFrozen'] as bool;
    gameState.hasDrawnFromDeck = data['hasDrawnFromDeck'] as bool;
    gameState.hasMelded = data['hasMelded'] as bool;

    final phaseName = data['phase'] as String;
    gameState.phase = GamePhase.values.firstWhere(
      (e) => e.name == phaseName,
      orElse: () => GamePhase.playing,
    );

    final turnPhaseName = data['turnPhase'] as String;
    gameState.turnPhase = TurnPhase.values.firstWhere(
      (e) => e.name == turnPhaseName,
      orElse: () => TurnPhase.draw,
    );
  }

  static void _restoreRecentActions(
    GameState gameState,
    List<dynamic>? actionsData,
  ) {
    if (actionsData == null) return;

    gameState.recentActions.clear();
    for (final actionData in actionsData) {
      if (actionData is Map<String, dynamic>) {
        final message = actionData['message'] as String;
        final playerName = actionData['playerName'] as String;
        final timestampMs = actionData['timestamp'] as int?;
        final timestamp = timestampMs != null
            ? DateTime.fromMillisecondsSinceEpoch(timestampMs)
            : DateTime.now();

        gameState.recentActions.add(
          GameAction.withTimestamp(
            message: message,
            playerName: playerName,
            timestamp: timestamp,
          ),
        );
      }
    }
  }

  // ============= Persistence =============

  @override
  Future<void> saveGame() async {
    await GameSaveService.saveGame(_gameState, gameSeed);
  }

  static Future<GameController?> loadSavedGame() async {
    final savedData = await GameSaveService.loadGame();
    if (savedData != null) {
      final controller = GameSaveService.restoreGameController(savedData);
      if (controller is GameController) {
        return controller;
      }
    }
    return null;
  }

  static Future<bool> hasSavedGame() async {
    return await GameSaveService.hasSavedGame();
  }

  static Future<void> clearSavedGame() async {
    await GameSaveService.clearSavedGame();
  }

  // ============= Utility Methods =============

  @override
  void clearAllNewlyDrawnCards() {
    for (final player in _gameState.players) {
      player.clearNewlyDrawnCards();
    }
  }

  void dispose() {
    // Cleanup resources if needed
  }
}
