import 'dart:math';
import '../config/game_config.dart';
import '../models/card.dart';
import '../models/deck.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../models/meld.dart';
import '../models/round_score_breakdown.dart';
import '../services/game_save_service.dart';
import '../utils/debug_logger.dart';
import '../config/solo_game_settings.dart';
import 'game_interface.dart';
import 'meld_undo_record.dart';
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
  final List<MeldUndoRecord> _meldUndoStack = [];

  @override
  final int? gameSeed;

  /// When false, [saveGame] is a no-op (used by Learn to Play).
  bool autosaveEnabled = true;

  /// Personalities restored from local autosave (playerId → enum toString).
  /// Applied by GameScreen when continuing a saved solo game.
  Map<String, String> restoredBotPersonalities = {};

  factory GameController({
    required List<Player> players,
    int? seed,
    GameEventBus? eventBus,
    SoloGameSettings? soloSettings,
  }) {
    final actualSeed = seed ?? Random().nextInt(1000000);
    final gameState = GameState(
      players: players,
      deck: Deck.createHandAndFootDeck(players.length, seed: actualSeed),
      soloSettings: soloSettings,
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
  void initializeGame({bool dealCards = true}) {
    _gameState.deck.shuffle();
    _gameState.startRound();
    if (dealCards) {
      _completeRoundStart(earnedPerfectGrabBonus: false);
    }
  }

  /// Shuffles and resets play state for the next round without dealing cards.
  /// Call [completeRoundStart] after the perfect-grab mini-game finishes.
  void prepareNewRoundDeal() {
    if (_gameState.phase == GamePhase.roundEnd) {
      _gameState.resetForNewRound(dealCardsAfterReset: false);
    }
  }

  /// Deals cards and optionally awards the perfect-grab bonus to the human player.
  void completeRoundStart({required bool earnedPerfectGrabBonus}) {
    _completeRoundStart(earnedPerfectGrabBonus: earnedPerfectGrabBonus);
  }

  void _completeRoundStart({required bool earnedPerfectGrabBonus}) {
    _gameState.dealCards();

    if (earnedPerfectGrabBonus) {
      final humanPlayers = _gameState.players
          .where((player) => player.type == PlayerType.human)
          .toList();
      if (humanPlayers.isEmpty) {
        DebugLogger.warning(
          'Perfect grab bonus skipped: no human player in game',
        );
      } else {
        final humanPlayer = humanPlayers.first;
        humanPlayer.updateScore(GameConfig.perfectGrabBonus);
        _gameState.logPerfectGrabBonus(humanPlayer.name);
      }
    }

    _eventBus.publish(RoundStartedEvent(roundNumber: _gameState.round));
    saveGame().catchError((e) => DebugLogger.error('Auto-save failed: $e'));
  }

  @override
  bool drawFromDeck() {
    final handSizeBefore = _gameState.currentPlayer.currentHand.length;
    final phaseBefore = _gameState.phase;
    final roundBefore = _gameState.round;
    // Capture before draw: stuck go-out recovery clears playerWhoWentOutIndex
    // inside endRound(), and the acting player may not be who went out.
    Player? stuckGoOutPlayer;
    for (final player in _gameState.players) {
      if (player.canGoOut) {
        stuckGoOutPlayer = player;
        break;
      }
    }
    final result = _gameState.drawFromDeck();

    if (result) {
      final player = _gameState.currentPlayer;
      final drawnCards = _cardsFromNewlyDrawnIndices(player);
      if (drawnCards.isEmpty && player.currentHand.length > handSizeBefore) {
        drawnCards.addAll(player.currentHand.sublist(handSizeBefore));
      }
      if (drawnCards.isNotEmpty) {
        _eventBus.publish(
          CardDrawnEvent(cards: drawnCards, fromDeck: true, player: player),
        );
      }
    } else if (phaseBefore == GamePhase.playing &&
        (_gameState.phase == GamePhase.roundEnd ||
            _gameState.phase == GamePhase.gameEnd)) {
      if (stuckGoOutPlayer != null &&
          _gameState.emergencyRoundEndReason == null) {
        // Stuck go-out recovery inside GameState.drawFromDeck ended the round.
        _publishRoundOrGameEndEvents(stuckGoOutPlayer, roundBefore);
      } else {
        _publishEmergencyRoundEndEvents(roundBefore);
      }
    }

    return result;
  }

  /// End the round because the deck cannot deal — never credits a go-out.
  void emergencyEndRoundForInsufficientCards() {
    if (_gameState.phase == GamePhase.roundEnd ||
        _gameState.phase == GamePhase.gameEnd) {
      return;
    }
    final roundBefore = _gameState.round;
    _gameState.emergencyEndRoundForInsufficientCards();
    _publishEmergencyRoundEndEvents(roundBefore);
  }

  @override
  bool drawFromDiscardPile() {
    final player = _gameState.currentPlayer;
    final unlockContext = _captureDiscardUnlockContext(player);
    final result = _gameState.drawFromDiscard();

    if (result) {
      _publishDiscardUnlockedEvent(player, unlockContext);
    }

    return result;
  }

  @override
  bool unlockDiscardPile() {
    final player = _gameState.currentPlayer;
    final unlockContext = _captureDiscardUnlockContext(player);
    final result = _gameState.unlockDiscard();

    if (result) {
      _publishDiscardUnlockedEvent(player, unlockContext);
    }

    return result;
  }

  _DiscardUnlockContext _captureDiscardUnlockContext(Player player) {
    final topCard = _gameState.topDiscard;
    if (topCard == null) {
      return const _DiscardUnlockContext(
        matchingCards: [],
        meldIndex: -1,
        topDiscard: null,
      );
    }

    final matchingCards = player.currentHand
        .where((card) => card.rank == topCard.rank && !card.isWild)
        .take(2)
        .toList();
    final existingMeldIndex = player.findMeldByRank(topCard.rank);

    return _DiscardUnlockContext(
      matchingCards: matchingCards,
      meldIndex: existingMeldIndex,
      topDiscard: topCard,
    );
  }

  void _publishDiscardUnlockedEvent(
    Player player,
    _DiscardUnlockContext unlockContext,
  ) {
    final handPickupCards = _cardsFromNewlyDrawnIndices(player);

    final meldIndex = unlockContext.meldIndex != -1
        ? unlockContext.meldIndex
        : player.melds.length - 1;
    final meldedCards = unlockContext.topDiscard == null
        ? <PlayingCard>[]
        : [...unlockContext.matchingCards, unlockContext.topDiscard!];

    _eventBus.publish(
      DiscardPileUnlockedEvent(
        handPickupCards: handPickupCards,
        meldedCards: meldedCards,
        meldIndex: meldIndex,
        player: player,
      ),
    );
  }

  List<PlayingCard> _cardsFromNewlyDrawnIndices(Player player) {
    final cards = <PlayingCard>[];
    for (final index in player.newlyDrawnCardIndices) {
      if (index >= 0 && index < player.currentHand.length) {
        cards.add(player.currentHand[index]);
      }
    }
    return cards;
  }

  @override
  bool canUnlockDiscard() {
    return _gameState.canUnlockDiscard();
  }

  /// Ends the current round when a player goes out and publishes UI events.
  /// Returns true if the round ended immediately; false if final-turn phase started.
  bool endRoundForPlayer(Player player) {
    if (_gameState.phase == GamePhase.roundEnd ||
        _gameState.phase == GamePhase.gameEnd) {
      return true;
    }

    final roundBefore = _gameState.round;
    final roundEndingPlayer = _captureRoundEndingPlayer(player);
    final roundEnded = _gameState.handlePlayerWentOut();
    if (roundEnded) {
      _publishRoundOrGameEndEvents(roundEndingPlayer, roundBefore);
    } else {
      publishTurnEndedEvent(player);
    }
    return roundEnded;
  }

  SoloGameSettings get soloSettings => _gameState.soloSettings;

  /// Snapshot the player credited with going out before state resets it.
  Player _captureRoundEndingPlayer(Player actingPlayer) {
    final wentOutIndex = _gameState.playerWhoWentOutIndex;
    if (wentOutIndex != null &&
        wentOutIndex >= 0 &&
        wentOutIndex < _gameState.players.length) {
      return _gameState.players[wentOutIndex];
    }
    return actingPlayer;
  }

  void _publishRoundOrGameEndEvents(Player player, int roundBefore) {
    _publishRoundEndEvents(roundBefore, wentOutPlayer: player);
  }

  /// Round/game end without [PlayerWentOutEvent] (empty deck or stalemate).
  void _publishEmergencyRoundEndEvents(int roundBefore) {
    _publishRoundEndEvents(roundBefore);
  }

  void _publishRoundEndEvents(int roundBefore, {Player? wentOutPlayer}) {
    final phase = _gameState.phase;
    if (phase != GamePhase.roundEnd && phase != GamePhase.gameEnd) {
      return;
    }

    if (wentOutPlayer != null) {
      _eventBus.publish(
        PlayerWentOutEvent(roundNumber: roundBefore, player: wentOutPlayer),
      );
    }

    final roundScores = <Player, int>{};
    for (final p in _gameState.players) {
      roundScores[p] = p.score;
    }
    _eventBus.publish(
      RoundEndedEvent(roundNumber: roundBefore, roundScores: roundScores),
    );

    if (phase == GamePhase.gameEnd && _gameState.winner != null) {
      _eventBus.publish(
        GameEndedEvent(winner: _gameState.winner!, finalScores: roundScores),
      );
    }
  }

  void _publishPostActionEvents({
    required GamePhase phaseBefore,
    required int roundBefore,
    required Player actingPlayer,
    required Player roundEndingPlayer,
    required int currentIndexBefore,
  }) {
    if (_gameState.phase != phaseBefore) {
      if (_gameState.emergencyRoundEndReason != null) {
        _publishEmergencyRoundEndEvents(roundBefore);
      } else {
        _publishRoundOrGameEndEvents(roundEndingPlayer, roundBefore);
      }
      return;
    }

    if (_gameState.finalTurnPhaseActive &&
        _gameState.currentPlayerIndex != currentIndexBefore) {
      publishTurnEndedEvent(actingPlayer);
    }
  }

  @override
  bool discardCard(PlayingCard card) {
    final player = _gameState.currentPlayer;
    final phaseBefore = _gameState.phase;
    final roundBefore = _gameState.round;
    final roundEndingPlayer = _captureRoundEndingPlayer(player);
    final currentIndexBefore = _gameState.currentPlayerIndex;
    final result = _gameState.discard(card);
    _gameState.validateGameState();

    if (result) {
      clearMeldUndoStack();
      _eventBus.publish(CardDiscardedEvent(card: card, player: player));

      _publishPostActionEvents(
        phaseBefore: phaseBefore,
        roundBefore: roundBefore,
        actingPlayer: player,
        roundEndingPlayer: roundEndingPlayer,
        currentIndexBefore: currentIndexBefore,
      );

      if (_gameState.phase == phaseBefore &&
          (!_gameState.finalTurnPhaseActive ||
              _gameState.currentPlayerIndex == currentIndexBefore)) {
        // Check if turn ended (player changed or phase changed)
        final newPlayer = _gameState.currentPlayer;
        if (newPlayer.id != player.id ||
            _gameState.turnPhase == TurnPhase.draw) {
          _eventBus.publish(
            TurnEndedEvent(
              turnNumber: _gameState.currentPlayerIndex,
              nextPlayer: newPlayer,
              player: player,
            ),
          );
        }
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

  /// Advance play after a completed turn, publishing turn-end or round-end events.
  ///
  /// Returns true when the round or game ended.
  bool advanceTurnAfterAction(Player previousPlayer) {
    final phaseBefore = _gameState.phase;
    final roundBefore = _gameState.round;
    final roundEndingPlayer = _captureRoundEndingPlayer(previousPlayer);
    final roundEnded = _gameState.completeTurn();
    clearMeldUndoStack();

    if (_gameState.phase != phaseBefore) {
      _publishRoundOrGameEndEvents(roundEndingPlayer, roundBefore);
      return true;
    }

    if (!roundEnded) {
      publishTurnEndedEvent(previousPlayer);
    }

    return roundEnded;
  }

  @override
  void nextRound({bool dealCards = true}) {
    clearMeldUndoStack();
    if (_gameState.phase == GamePhase.roundEnd) {
      _gameState.resetForNewRound(dealCardsAfterReset: dealCards);
      if (dealCards) {
        _eventBus.publish(RoundStartedEvent(roundNumber: _gameState.round));
        saveGame().catchError((e) => DebugLogger.error('Auto-save failed: $e'));
      }
    }
  }

  // ============= Meld Operations (Delegated) =============

  @override
  bool createMeld(List<PlayingCard> cards) {
    final player = _gameState.currentPlayer;
    final hadPlayedDown = player.hasPlayedDown;
    final hadPickedUpFoot = player.hasPickedUpFoot;
    final meldCountBefore = player.melds.length;
    final roundBefore = _gameState.round;
    final phaseBefore = _gameState.phase;
    final roundEndingPlayer = _captureRoundEndingPlayer(player);
    final currentIndexBefore = _gameState.currentPlayerIndex;

    final result = _gameState.playMeld(cards);
    _gameState.validateGameState();

    if (result && player.melds.isNotEmpty) {
      _recordHumanMeldUndo(
        player: player,
        cards: cards,
        meldCountBefore: meldCountBefore,
        hadPlayedDown: hadPlayedDown,
        hadPickedUpFoot: hadPickedUpFoot,
      );

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
      _publishPostActionEvents(
        phaseBefore: phaseBefore,
        roundBefore: roundBefore,
        actingPlayer: player,
        roundEndingPlayer: roundEndingPlayer,
        currentIndexBefore: currentIndexBefore,
      );
    }

    return result;
  }

  @override
  bool createMeldBypass(List<PlayingCard> cards) {
    final player = _gameState.currentPlayer;
    final hadPlayedDown = player.hasPlayedDown;
    final hadPickedUpFoot = player.hasPickedUpFoot;
    final meldCountBefore = player.melds.length;

    final result = _gameState.playMeldBypass(cards);
    _gameState.validateGameState();

    if (result) {
      _recordHumanMeldUndo(
        player: player,
        cards: cards,
        meldCountBefore: meldCountBefore,
        hadPlayedDown: hadPlayedDown,
        hadPickedUpFoot: hadPickedUpFoot,
      );
    }

    return result;
  }

  @override
  bool createMeldByIndices(
    List<int> cardIndices, {
    bool skipPlayDownCheck = false,
  }) {
    final player = _gameState.currentPlayer;
    for (final index in cardIndices) {
      if (index < 0 || index >= player.currentHand.length) {
        return false;
      }
    }

    final hadPlayedDown = player.hasPlayedDown;
    final hadPickedUpFoot = player.hasPickedUpFoot;
    final meldCountBefore = player.melds.length;
    final cards = cardIndices
        .map((index) => player.currentHand[index])
        .toList();

    final result = _meldManager.createMeldByIndices(
      cardIndices,
      skipPlayDownCheck: skipPlayDownCheck,
    );

    if (result) {
      _recordHumanMeldUndo(
        player: player,
        cards: cards,
        meldCountBefore: meldCountBefore,
        hadPlayedDown: hadPlayedDown,
        hadPickedUpFoot: hadPickedUpFoot,
      );
    }

    return result;
  }

  @override
  bool createMultipleMeldsFromIndices(
    List<List<int>> allMeldIndices, {
    bool skipPlayDownCheck = false,
  }) {
    final player = _gameState.currentPlayer;
    for (final indices in allMeldIndices) {
      for (final index in indices) {
        if (index < 0 || index >= player.currentHand.length) {
          return false;
        }
      }
    }

    final hadPlayedDown = player.hasPlayedDown;
    final hadPickedUpFoot = player.hasPickedUpFoot;
    final meldsSnapshot = _snapshotMelds(player);
    final cards = <PlayingCard>[];
    for (final indices in allMeldIndices) {
      for (final index in indices) {
        cards.add(player.currentHand[index]);
      }
    }

    final result = _meldManager.createMultipleMeldsFromIndices(
      allMeldIndices,
      skipPlayDownCheck: skipPlayDownCheck,
    );

    if (result && player.type == PlayerType.human) {
      _meldUndoStack.add(
        MeldUndoRecord(
          cardsReturnedToHand: cards,
          meldsSnapshotBefore: meldsSnapshot,
          unsetPlayedDown: !hadPlayedDown && player.hasPlayedDown,
          unsetPickedUpFoot: !hadPickedUpFoot && player.hasPickedUpFoot,
        ),
      );
    }

    return result;
  }

  @override
  bool addCardToMeld(int meldIndex, PlayingCard card) {
    final player = _gameState.currentPlayer;
    final hadPickedUpFoot = player.hasPickedUpFoot;
    final hadPlayedDown = player.hasPlayedDown;
    final roundBefore = _gameState.round;
    final phaseBefore = _gameState.phase;
    final roundEndingPlayer = _captureRoundEndingPlayer(player);
    final currentIndexBefore = _gameState.currentPlayerIndex;
    final meld = player.melds[meldIndex];
    final result = _gameState.addToMeld(meldIndex, card);
    _gameState.validateGameState();

    if (result) {
      if (player.type == PlayerType.human) {
        _meldUndoStack.add(
          MeldUndoRecord(
            cardsReturnedToHand: [card],
            meldIndex: meldIndex,
            wasNewMeld: false,
            unsetPlayedDown: !hadPlayedDown && player.hasPlayedDown,
            unsetPickedUpFoot: !hadPickedUpFoot && player.hasPickedUpFoot,
          ),
        );
      }

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
      _publishPostActionEvents(
        phaseBefore: phaseBefore,
        roundBefore: roundBefore,
        actingPlayer: player,
        roundEndingPlayer: roundEndingPlayer,
        currentIndexBefore: currentIndexBefore,
      );
    }

    return result;
  }

  @override
  bool get canUndoMeld => _meldUndoStack.isNotEmpty;

  @override
  bool undoLastMeld() {
    if (_meldUndoStack.isEmpty) {
      return false;
    }

    if (_gameState.phase == GamePhase.roundEnd ||
        _gameState.phase == GamePhase.gameEnd) {
      return false;
    }

    final player = _gameState.currentPlayer;
    if (player.type != PlayerType.human) {
      return false;
    }

    final record = _meldUndoStack.removeLast();
    final success = _applyMeldUndo(player, record);
    if (!success) {
      _meldUndoStack.add(record);
    }
    return success;
  }

  /// Clears turn-local meld undo history (discard, turn advance, round end).
  void clearMeldUndoStack() {
    _meldUndoStack.clear();
  }

  void _recordHumanMeldUndo({
    required Player player,
    required List<PlayingCard> cards,
    required int meldCountBefore,
    required bool hadPlayedDown,
    required bool hadPickedUpFoot,
  }) {
    if (player.type != PlayerType.human) {
      return;
    }

    final wasNewMeld = player.melds.length > meldCountBefore;
    var meldIndex = -1;
    if (wasNewMeld) {
      meldIndex = player.melds.length - 1;
    } else {
      final naturalCards = cards.where((card) => !card.isWild).toList();
      if (naturalCards.isNotEmpty) {
        meldIndex = player.findMeldByRank(naturalCards.first.rank);
      }
    }

    if (meldIndex < 0) {
      return;
    }

    _meldUndoStack.add(
      MeldUndoRecord(
        cardsReturnedToHand: List<PlayingCard>.from(cards),
        meldIndex: meldIndex,
        wasNewMeld: wasNewMeld,
        unsetPlayedDown: !hadPlayedDown && player.hasPlayedDown,
        unsetPickedUpFoot: !hadPickedUpFoot && player.hasPickedUpFoot,
      ),
    );
  }

  List<Meld> _snapshotMelds(Player player) {
    return player.melds
        .map((meld) => Meld(rank: meld.rank, cards: List.from(meld.cards)))
        .toList();
  }

  bool _applyMeldUndo(Player player, MeldUndoRecord record) {
    if (record.meldsSnapshotBefore != null) {
      player.melds
        ..clear()
        ..addAll(record.meldsSnapshotBefore!);
    } else {
      final meldIndex = record.meldIndex;
      if (meldIndex == null ||
          meldIndex < 0 ||
          meldIndex >= player.melds.length) {
        return false;
      }

      if (record.wasNewMeld) {
        player.melds.removeAt(meldIndex);
      } else {
        final meld = player.melds[meldIndex];
        for (final card in record.cardsReturnedToHand) {
          final cardIndex = meld.cards.lastIndexWhere(
            (meldCard) =>
                meldCard.rank == card.rank && meldCard.suit == card.suit,
          );
          if (cardIndex >= 0) {
            meld.cards.removeAt(cardIndex);
          }
        }
        if (meld.cards.length < GameConfig.minTotalCardsForMeld) {
          player.melds.removeAt(meldIndex);
        }
      }
    }

    if (record.unsetPickedUpFoot) {
      player.hasPickedUpFoot = false;
      player.hand.addAll(record.cardsReturnedToHand);
    } else {
      player.currentHand.addAll(record.cardsReturnedToHand);
    }

    if (record.unsetPlayedDown) {
      player.hasPlayedDown = player.melds.isNotEmpty;
    }

    if (_meldUndoStack.isEmpty) {
      _gameState.hasMelded = false;
    }

    _gameState.logAction('undid last meld action');
    return true;
  }

  @override
  List<List<PlayingCard>> findPossibleMelds(Player player) {
    return _meldManager.findPossibleMelds(player);
  }

  @override
  List<PlayingCard> getPlayableCards() {
    return _meldManager.getPlayableCards(_gameState.currentPlayer);
  }

  @override
  Set<int> getPlayableCardIndices(Player player) {
    return _meldManager.getPlayableCardIndices(player);
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
    gameState.hasTakenDiscardThisTurn =
        data['hasTakenDiscardThisTurn'] as bool? ?? false;

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
    if (!autosaveEnabled) {
      return;
    }
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

class _DiscardUnlockContext {
  final List<PlayingCard> matchingCards;
  final int meldIndex;
  final PlayingCard? topDiscard;

  const _DiscardUnlockContext({
    required this.matchingCards,
    required this.meldIndex,
    required this.topDiscard,
  });
}
