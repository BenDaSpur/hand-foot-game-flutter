/// Reason codes for multiplayer create/join failures surfaced to the UI.
enum MultiplayerFailureReason {
  notConfigured,
  notAuthenticated,
  invalidInput,
  gameNotFound,
  gameFull,
  gameNotAccepting,
  rateLimited,
  permissionDenied,
  unknown,
}

/// User-facing message for a [MultiplayerFailureReason].
String multiplayerFailureMessage(MultiplayerFailureReason reason) {
  switch (reason) {
    case MultiplayerFailureReason.notConfigured:
      return 'Multiplayer requires Firebase configuration.';
    case MultiplayerFailureReason.notAuthenticated:
      return 'Could not sign in for multiplayer. Please try again.';
    case MultiplayerFailureReason.invalidInput:
      return 'Invalid player name or game settings.';
    case MultiplayerFailureReason.gameNotFound:
      return 'Game not found. Check the game ID and try again.';
    case MultiplayerFailureReason.gameFull:
      return 'This game is full.';
    case MultiplayerFailureReason.gameNotAccepting:
      return 'This game is no longer accepting players.';
    case MultiplayerFailureReason.rateLimited:
      return 'Too many games created. Please wait and try again.';
    case MultiplayerFailureReason.permissionDenied:
      return 'Permission denied. Check Firebase authentication settings.';
    case MultiplayerFailureReason.unknown:
      return 'Something went wrong. Please try again.';
  }
}

/// Result of attempting to create a multiplayer game.
class CreateGameResult {
  final String? gameId;
  final MultiplayerFailureReason? failureReason;

  const CreateGameResult({this.gameId, this.failureReason});

  bool get isSuccess => gameId != null && failureReason == null;

  String? get errorMessage =>
      failureReason != null ? multiplayerFailureMessage(failureReason!) : null;
}

/// Result of attempting to join (or rejoin) a multiplayer game.
class JoinGameResult {
  final bool success;
  final MultiplayerFailureReason? failureReason;

  const JoinGameResult({required this.success, this.failureReason});

  bool get isSuccess => success && failureReason == null;

  String? get errorMessage =>
      failureReason != null ? multiplayerFailureMessage(failureReason!) : null;
}
