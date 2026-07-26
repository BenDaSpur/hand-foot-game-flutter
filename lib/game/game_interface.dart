import '../models/card.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../models/multiplayer_lifecycle.dart';

/// Common interface for all game controllers (singleplayer and multiplayer)
/// This enables the UI to work seamlessly with any game type
abstract class GameInterface {
  // Game state access
  GameState get gameState;
  bool get isGameOver;
  Player? get winner;
  int get currentRound;
  List<Player> get leaderboard;

  // Game actions
  bool drawFromDeck();
  bool drawFromDiscardPile();
  bool unlockDiscardPile();
  bool createMeld(List<PlayingCard> cards);
  bool createMeldBypass(List<PlayingCard> cards);
  bool createMeldByIndices(
    List<int> cardIndices, {
    bool skipPlayDownCheck = false,
  });
  bool createMultipleMeldsFromIndices(
    List<List<int>> allMeldIndices, {
    bool skipPlayDownCheck = false,
  });
  bool addCardToMeld(int meldIndex, PlayingCard card);
  bool discardCard(PlayingCard card);

  // Game queries
  bool canUnlockDiscard();
  bool canPlayerGoOut();
  List<List<PlayingCard>> findPossibleMelds(Player player);
  List<PlayingCard> getPlayableCards();
  Set<int> getPlayableCardIndices(Player player);

  // Game management
  void initializeGame();
  void nextRound();
  Future<void> saveGame();

  // State management
  Map<String, dynamic> getGameStatus();
  String? exportGameState([Map<String, String>? botPersonalities]);
  void clearAllNewlyDrawnCards();
  int? get gameSeed;
}

/// Extended interface for multiplayer games with turn management
abstract class MultiplayerGameInterface extends GameInterface {
  // Multiplayer-specific properties
  bool get isHost;
  String get userId;
  bool get isOnline;
  bool get isMyTurn;

  // Turn management
  List<String> getAvailableActions();
  bool canPerformAction(String action);
  Map<String, dynamic> getTurnStatus();

  // Streams for reactive UI
  Stream<GameState> get gameStateStream;
  Stream<bool> get connectionStream;

  // Multiplayer game management
  Future<bool> startMultiplayerGame();
  Future<bool> leaveGame();

  /// Host-only: cancel the game for all connected players.
  Future<bool> endGameForEveryone({String endReason = 'host_ended'});

  /// Emits when the remote game is cancelled or deleted.
  Stream<MultiplayerLifecycleEvent> get lifecycleStream;

  Player? getCurrentUserPlayer();
}
