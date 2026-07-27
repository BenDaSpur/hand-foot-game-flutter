/// Constants for Firebase service
class FirebaseConstants {
  // Collection names
  static const String gamesCollection = 'games';
  static const String playersCollection = 'players';
  static const String userLimitsCollection = 'userLimits';

  // Game status values
  static const String gameStatusWaiting = 'waiting';
  static const String gameStatusPlaying = 'playing';
  static const String gameStatusFinished = 'finished';
  static const String gameStatusCompleted = 'completed';
  static const String gameStatusCancelled = 'cancelled';

  // Rate limiting constants
  static const int maxGamesPerUserPerHour = 50;
  static const int maxGamesPerUserPerDay = 200;

  // Validation limits
  static const int minPlayerNameLength = 2;
  static const int maxPlayerNameLength = 20;
  static const int minPlayersPerGame = 2;
  static const int maxPlayersPerGame = 6;
  static const int minGameIdLength = 10;

  // Reserved words for player names
  static const List<String> reservedPlayerNames = [
    'admin',
    'null',
    'undefined',
    'system',
    'bot',
    'ai',
    'moderator',
    'guest',
  ];
}
