/// Specific error types for better multiplayer error handling
class MultiplayerError implements Exception {
  final String message;
  final dynamic originalError;

  const MultiplayerError(this.message, [this.originalError]);

  @override
  String toString() => 'MultiplayerError: $message';
}

/// Network connectivity and Firebase communication errors
class NetworkError extends MultiplayerError {
  const NetworkError(super.message, [super.originalError]);

  @override
  String toString() => 'Network Error: $message';
}

/// Game state validation and consistency errors
class ValidationError extends MultiplayerError {
  const ValidationError(super.message, [super.originalError]);

  @override
  String toString() => 'Validation Error: $message';
}

/// Player disconnect and session management errors
class PlayerError extends MultiplayerError {
  final String? playerId;

  const PlayerError(super.message, [this.playerId, super.originalError]);

  @override
  String toString() =>
      'Player Error: $message${playerId != null ? " (Player: $playerId)" : ""}';
}

/// Firebase synchronization and state management errors
class SyncError extends MultiplayerError {
  final String gameId;

  const SyncError(super.message, this.gameId, [super.originalError]);

  @override
  String toString() => 'Sync Error: $message (Game: $gameId)';
}

/// Game lifecycle and cleanup errors
class GameLifecycleError extends MultiplayerError {
  const GameLifecycleError(super.message, [super.originalError]);

  @override
  String toString() => 'Game Lifecycle Error: $message';
}
