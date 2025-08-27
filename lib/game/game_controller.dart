import 'dart:math';
import '../models/card.dart';
import '../models/deck.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../models/meld.dart';
import '../models/round_score_breakdown.dart';
import '../services/game_save_service.dart';
import 'game_interface.dart';
import 'managers/meld_manager.dart';
import 'managers/game_serializer.dart';

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

  @override
  final int? gameSeed;

  factory GameController({required List<Player> players, int? seed}) {
    final actualSeed = seed ?? Random().nextInt(1000000);
    final gameState = GameState(
      players: players,
      deck: Deck.createHandAndFootDeck(players.length, seed: actualSeed),
    );

    return GameController._internal(gameState: gameState, seed: actualSeed);
  }

  GameController._internal({required GameState gameState, required int seed})
    : gameSeed = seed,
      _gameState = gameState {
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
  }

  @override
  bool drawFromDeck() {
    return _gameState.drawFromDeck();
  }

  @override
  bool drawFromDiscardPile() {
    return _gameState.drawFromDiscard();
  }

  @override
  bool unlockDiscardPile() {
    return _gameState.unlockDiscard();
  }

  @override
  bool canUnlockDiscard() {
    return _gameState.canUnlockDiscard();
  }

  @override
  bool discardCard(PlayingCard card) {
    final result = _gameState.discard(card);
    _gameState.validateGameState();
    return result;
  }

  @override
  void nextRound() {
    if (_gameState.phase == GamePhase.roundEnd) {
      _gameState.resetForNewRound();
    }
  }

  // ============= Meld Operations (Delegated) =============

  @override
  bool createMeld(List<PlayingCard> cards) {
    final result = _gameState.playMeld(cards);
    _gameState.validateGameState();
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
    final result = _gameState.addToMeld(meldIndex, card);
    _gameState.validateGameState();
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
    return player.canGoOut && player.hasBook();
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
  String exportGameState() {
    return GameSerializer.exportGameState(_gameState, gameSeed);
  }

  static GameController? fromExportJson(String input) {
    try {
      final data = GameSerializer.importGameState(input);
      if (data == null) return null;

      final gameSeed = data['gameSeed'] as int?;
      final gameStateData = data['gameState'] as Map<String, dynamic>;
      final playersData = data['players'] as List<dynamic>;

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

      return controller;
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
