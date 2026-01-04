import '../models/card.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../game/game_interface.dart';

/// Read-only interface for bot AI to access game state and query action validity.
///
/// This interface decouples bot AI from the concrete GameController implementation,
/// making bot AI testable in isolation and enabling different game controller
/// implementations (singleplayer, multiplayer, test mocks).
///
/// The interface provides:
/// - Read-only access to game state
/// - Query methods to check if actions are valid
/// - Optional controller reference for methods that need to call controller APIs
class BotGameContext {
  /// The current game state (read-only access)
  final GameState gameState;

  /// Optional controller reference for methods that need to call controller APIs
  /// (e.g., findPossibleMelds). Can be null for pure test contexts.
  final GameInterface? _controller;

  BotGameContext(this.gameState, [this._controller]);

  /// Gets the current player
  Player get currentPlayer => gameState.currentPlayer;

  /// Gets the current turn phase
  TurnPhase get turnPhase => gameState.turnPhase;

  /// Gets the current round number
  int get round => gameState.round;

  /// Checks if the current player can unlock the discard pile
  bool canUnlockDiscard() {
    return gameState.canUnlockDiscard();
  }

  /// Checks if the current player can go out
  bool canPlayerGoOut() {
    return gameState.currentPlayer.canGoOut;
  }

  /// Gets the play-down requirement for the current round
  int get playDownRequirement => gameState.playDownRequirement;

  /// Checks if discard pile is frozen
  bool get discardPileFrozen => gameState.discardPileFrozen;

  /// Checks if player has already drawn from deck this turn
  bool get hasDrawnFromDeck => gameState.hasDrawnFromDeck;

  /// Gets the top discard card (null if discard pile is empty)
  PlayingCard? get topDiscard => gameState.topDiscard;

  /// Gets the size of the discard pile
  int get discardPileSize => gameState.discardPile.length;

  /// Gets the size of the deck
  int get deckSize => gameState.deck.size;

  /// Gets all players in the game
  List<Player> get players => gameState.players;

  /// Gets the current player index
  int get currentPlayerIndex => gameState.currentPlayerIndex;

  /// Gets the controller if available (for methods that need to call controller APIs)
  /// Returns null if controller was not provided (e.g., in test contexts)
  GameInterface? get controller => _controller;
}
