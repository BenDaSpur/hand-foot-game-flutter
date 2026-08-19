import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/card.dart';
import '../models/meld.dart';
import '../game/game_controller.dart';
import '../ai/bot_personality.dart';
import '../config/bot_configurations.dart';
import '../config/solo_game_settings.dart';

class GameSaveService {
  static const String _saveKey = 'hand_foot_game_save';
  static final _log = Logger('GameSaveService');

  /// Shared FIFO queue so instance [saveGame] and [clearSavedGame] cannot
  /// race on the same SharedPreferences key.
  static Future<void> _persistenceQueue = Future<void>.value();

  static Future<void> _enqueuePersistence(Future<void> Function() operation) {
    final previous = _persistenceQueue;
    final current = previous.then((_) => operation());
    _persistenceQueue = current.then((_) {}, onError: (_) {});
    return current;
  }

  /// Save the current game state to local storage
  static Future<void> saveGame(
    GameState gameState,
    int? gameSeed, {
    Map<String, BotPersonality>? botPersonalities,
  }) {
    return _enqueuePersistence(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final gameData = _serializeGameState(
          gameState,
          gameSeed,
          botPersonalities: botPersonalities,
        );
        final jsonString = jsonEncode(gameData);

        await prefs.setString(_saveKey, jsonString);
        _log.info('Game saved to local storage');
      } catch (e) {
        _log.severe('Failed to save game: $e');
      }
    });
  }

  /// Load the saved game state from local storage
  static Future<Map<String, dynamic>?> loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_saveKey);

      if (jsonString == null) {
        _log.info('No saved game found');
        return null;
      }

      final gameData = jsonDecode(jsonString) as Map<String, dynamic>;
      _log.info('Game loaded from local storage');
      return gameData;
    } catch (e) {
      _log.severe('Failed to load game: $e');
      return null;
    }
  }

  /// Check if there is a saved game available
  static Future<bool> hasSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_saveKey);
    } catch (e) {
      _log.severe('Failed to check for saved game: $e');
      return false;
    }
  }

  /// Clear the saved game from local storage
  static Future<void> clearSavedGame() {
    return _enqueuePersistence(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_saveKey);
        _log.info('Saved game cleared');
      } catch (e) {
        _log.severe('Failed to clear saved game: $e');
      }
    });
  }

  /// Serialize game state to a JSON-compatible map
  static Map<String, dynamic> _serializeGameState(
    GameState gameState,
    int? gameSeed, {
    Map<String, BotPersonality>? botPersonalities,
  }) {
    final resolved = resolveBotPersonalities(
      players: gameState.players,
      settings: gameState.soloSettings,
      preferred: botPersonalities,
    );
    return {
      'gameSeed': gameSeed,
      'timestamp': DateTime.now().toIso8601String(),
      'players': gameState.players.map(_serializePlayer).toList(),
      'deck': _serializeDeck(gameState.deck.cards),
      'discardPile': gameState.discardPile.map(_serializeCard).toList(),
      // This save never leaves the device, so the card-revealing detail is
      // persisted here to keep a resumed solo log readable. FirebaseService
      // owns the separate multiplayer encoding that other players can read;
      // privateMessage must never be added there.
      'recentActions': gameState.recentActions
          .map(
            (action) => {
              'message': action.message,
              'playerName': action.playerName,
              'timestamp': action.timestamp.toIso8601String(),
              'privateMessage': action.privateMessage,
            },
          )
          .toList(),
      'currentPlayerIndex': gameState.currentPlayerIndex,
      'phase': gameState.phase.name,
      'turnPhase': gameState.turnPhase.name,
      'round': gameState.round,
      'winner': gameState.winner?.id,
      'discardPileFrozen': gameState.discardPileFrozen,
      'hasDrawnFromDeck': gameState.hasDrawnFromDeck,
      'hasMelded': gameState.hasMelded,
      'hasTakenDiscardThisTurn': gameState.hasTakenDiscardThisTurn,
      'soloSettings': gameState.soloSettings.toJson(),
      'botPersonalities': serializeBotPersonalities(resolved),
      'finalTurnPhaseActive': gameState.finalTurnPhaseActive,
      'playerWhoWentOutIndex': gameState.playerWhoWentOutIndex,
      'playersAwaitingFinalTurn': gameState.playersAwaitingFinalTurn.toList(),
      'emergencyRoundEndReason': gameState.emergencyRoundEndReason?.name,
    };
  }

  /// Serialize a player to a JSON-compatible map
  static Map<String, dynamic> _serializePlayer(Player player) {
    return {
      'id': player.id,
      'name': player.name,
      'type': player.type.name,
      'hand': player.hand.map(_serializeCard).toList(),
      'foot': player.foot.map(_serializeCard).toList(),
      'melds': player.melds.map(_serializeMeld).toList(),
      'hasPickedUpFoot': player.hasPickedUpFoot,
      'hasPlayedDown': player.hasPlayedDown,
      'score': player.score,
    };
  }

  /// Serialize a meld to a JSON-compatible map
  static Map<String, dynamic> _serializeMeld(Meld meld) {
    return {
      'rank': meld.rank.name,
      'cards': meld.cards.map(_serializeCard).toList(),
      'type': meld.type.name,
    };
  }

  /// Serialize a card to a JSON-compatible map
  static Map<String, dynamic> _serializeCard(PlayingCard card) {
    return {'rank': card.rank.name, 'suit': card.suit?.name};
  }

  /// Serialize deck cards to a JSON-compatible list
  static List<Map<String, dynamic>> _serializeDeck(List<PlayingCard> cards) {
    return cards.map(_serializeCard).toList();
  }

  /// Create a GameController from saved game data
  static GameController? restoreGameController(Map<String, dynamic> savedData) {
    try {
      final players = (savedData['players'] as List)
          .map(
            (playerData) =>
                _deserializePlayer(playerData as Map<String, dynamic>),
          )
          .toList();

      final gameSeed = savedData['gameSeed'] as int?;
      final soloSettings = savedData['soloSettings'] != null
          ? SoloGameSettings.fromJson(
              savedData['soloSettings'] as Map<String, dynamic>,
            )
          : SoloGameSettings.defaults;

      // Create game controller with restored players and seed
      final gameController = GameController(
        players: players,
        seed: gameSeed,
        soloSettings: soloSettings,
      );

      // Restore game state
      _restoreGameState(gameController.gameState, savedData);

      // Clear newly drawn cards since they're not serialized properly
      // This prevents incorrect highlighting after game restore
      gameController.clearAllNewlyDrawnCards();

      // Restore bot personalities from save, or derive for legacy saves
      final savedPersonalities =
          (savedData['botPersonalities'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          <String, String>{};

      if (savedPersonalities.isNotEmpty) {
        gameController.restoredBotPersonalities = savedPersonalities;
      } else {
        final derived = resolveBotPersonalities(
          players: players,
          settings: soloSettings,
        );
        gameController.restoredBotPersonalities = serializeBotPersonalities(
          derived,
        );
      }

      return gameController;
    } catch (e) {
      _log.severe('Failed to restore game controller: $e');
      return null;
    }
  }

  /// Restore game state from saved data
  static void _restoreGameState(
    GameState gameState,
    Map<String, dynamic> savedData,
  ) {
    // Restore deck
    final deckCards = (savedData['deck'] as List)
        .map((cardData) => _deserializeCard(cardData as Map<String, dynamic>))
        .toList();
    gameState.deck.replaceCards(deckCards);

    // Restore discard pile
    gameState.discardPile.clear();
    gameState.discardPile.addAll(
      (savedData['discardPile'] as List).map(
        (cardData) => _deserializeCard(cardData as Map<String, dynamic>),
      ),
    );

    // Restore recent actions
    gameState.recentActions.clear();
    gameState.recentActions.addAll(
      (savedData['recentActions'] as List).map(
        (actionData) => GameAction.withTimestamp(
          message: actionData['message'] as String,
          playerName: actionData['playerName'] as String,
          timestamp: DateTime.parse(actionData['timestamp'] as String),
          // Absent in saves written before the log became privacy-aware.
          privateMessage: actionData['privateMessage'] as String?,
        ),
      ),
    );

    // Restore game state properties
    gameState.currentPlayerIndex = savedData['currentPlayerIndex'] as int;
    gameState.phase = _parseGamePhase(savedData['phase'] as String);
    gameState.turnPhase = _parseTurnPhase(savedData['turnPhase'] as String);
    gameState.round = savedData['round'] as int;
    gameState.discardPileFrozen = savedData['discardPileFrozen'] as bool;
    gameState.hasDrawnFromDeck = savedData['hasDrawnFromDeck'] as bool;
    gameState.hasMelded = savedData['hasMelded'] as bool;
    // Absent in saves written before the once-per-turn pickup rule existed.
    gameState.hasTakenDiscardThisTurn =
        savedData['hasTakenDiscardThisTurn'] as bool? ?? false;

    if (savedData['soloSettings'] != null) {
      gameState.soloSettings = SoloGameSettings.fromJson(
        savedData['soloSettings'] as Map<String, dynamic>,
      );
    }
    gameState.finalTurnPhaseActive =
        savedData['finalTurnPhaseActive'] as bool? ?? false;
    gameState.playerWhoWentOutIndex =
        savedData['playerWhoWentOutIndex'] as int?;
    gameState.playersAwaitingFinalTurn.clear();
    final awaiting = savedData['playersAwaitingFinalTurn'] as List<dynamic>?;
    if (awaiting != null) {
      gameState.playersAwaitingFinalTurn.addAll(
        awaiting.map((value) => value as int),
      );
    }

    gameState.emergencyRoundEndReason = parseEmergencyRoundEndReason(
      savedData['emergencyRoundEndReason'],
    );

    // Find winner if exists
    final winnerId = savedData['winner'] as String?;
    if (winnerId != null) {
      gameState.winner = gameState.players.firstWhere((p) => p.id == winnerId);
    }
  }

  /// Deserialize a player from saved data
  static Player _deserializePlayer(Map<String, dynamic> playerData) {
    final hand = (playerData['hand'] as List)
        .map((cardData) => _deserializeCard(cardData as Map<String, dynamic>))
        .toList();

    final foot = (playerData['foot'] as List)
        .map((cardData) => _deserializeCard(cardData as Map<String, dynamic>))
        .toList();

    final melds = (playerData['melds'] as List)
        .map((meldData) => _deserializeMeld(meldData as Map<String, dynamic>))
        .toList();

    return Player(
      id: playerData['id'] as String,
      name: playerData['name'] as String,
      type: _parsePlayerType(playerData['type'] as String),
      hand: hand,
      foot: foot,
      melds: melds,
      hasPickedUpFoot: playerData['hasPickedUpFoot'] as bool,
      hasPlayedDown: playerData['hasPlayedDown'] as bool,
      score: playerData['score'] as int,
    );
  }

  /// Deserialize a meld from saved data
  static Meld _deserializeMeld(Map<String, dynamic> meldData) {
    final cards = (meldData['cards'] as List)
        .map((cardData) => _deserializeCard(cardData as Map<String, dynamic>))
        .toList();

    return Meld(
      rank: _parseCardRank(meldData['rank'] as String),
      cards: cards,
      type: _parseMeldType(meldData['type'] as String),
    );
  }

  /// Deserialize a card from saved data
  static PlayingCard _deserializeCard(Map<String, dynamic> cardData) {
    return PlayingCard(
      rank: _parseCardRank(cardData['rank'] as String),
      suit: _parseSuit(cardData['suit'] as String?),
    );
  }

  /// Parse CardRank from string
  static CardRank _parseCardRank(String rankString) {
    return CardRank.values.firstWhere((rank) => rank.name == rankString);
  }

  /// Parse Suit from string
  static Suit? _parseSuit(String? suitString) {
    if (suitString == null) return null;
    return Suit.values.firstWhere((suit) => suit.name == suitString);
  }

  /// Parse PlayerType from string
  static PlayerType _parsePlayerType(String typeString) {
    return PlayerType.values.firstWhere((type) => type.name == typeString);
  }

  /// Parse MeldType from string
  static MeldType _parseMeldType(String typeString) {
    return MeldType.values.firstWhere((type) => type.name == typeString);
  }

  /// Parse GamePhase from string
  static GamePhase _parseGamePhase(String phaseString) {
    return GamePhase.values.firstWhere((phase) => phase.name == phaseString);
  }

  /// Parse TurnPhase from string
  static TurnPhase _parseTurnPhase(String phaseString) {
    return TurnPhase.values.firstWhere((phase) => phase.name == phaseString);
  }
}
