/// Lifecycle signals for multiplayer games that are not part of GameState.
enum MultiplayerLifecycleEvent {
  /// Host ended the game for everyone (`status == cancelled`).
  gameCancelled,

  /// Game document was deleted (legacy host leave / cleanup).
  gameDeleted,
}
