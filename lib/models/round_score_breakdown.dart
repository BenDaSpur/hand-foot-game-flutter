/// Represents a detailed breakdown of scores for a single round.
/// This tracks all the individual components that make up a player's score
/// for that round, providing transparency for the scoreboard modal.
class RoundScoreBreakdown {
  /// Round number (1-based)
  final int round;

  /// Points earned from card values in melds (positive)
  final int cardPoints;

  /// Number of clean books (7+ cards with no wilds) achieved this round
  final int cleanBooks;

  /// Number of dirty books (7+ cards with wilds) achieved this round
  final int dirtyBooks;

  /// Penalty points from cards left in hand/foot at round end (positive value representing penalty)
  final int penaltyPoints;

  /// Bonus for going out (100 points if this player went out)
  final int goingOutBonus;

  /// Total score for this round (calculated from above components)
  final int totalRoundScore;

  const RoundScoreBreakdown({
    required this.round,
    required this.cardPoints,
    required this.cleanBooks,
    required this.dirtyBooks,
    required this.penaltyPoints,
    required this.goingOutBonus,
    required this.totalRoundScore,
  });

  /// Get bonus points from clean books
  int get cleanBookPoints => cleanBooks * 500;

  /// Get bonus points from dirty books
  int get dirtyBookPoints => dirtyBooks * 300;

  /// Get total bonus points from books
  int get totalBookPoints => cleanBookPoints + dirtyBookPoints;

  /// Get positive score components (before penalties)
  int get positivePoints => cardPoints + totalBookPoints + goingOutBonus;

  /// Create from JSON for serialization
  factory RoundScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return RoundScoreBreakdown(
      round: json['round'] ?? 0,
      cardPoints: json['cardPoints'] ?? 0,
      cleanBooks: json['cleanBooks'] ?? 0,
      dirtyBooks: json['dirtyBooks'] ?? 0,
      penaltyPoints: json['penaltyPoints'] ?? 0,
      goingOutBonus: json['goingOutBonus'] ?? 0,
      totalRoundScore: json['totalRoundScore'] ?? 0,
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'round': round,
      'cardPoints': cardPoints,
      'cleanBooks': cleanBooks,
      'dirtyBooks': dirtyBooks,
      'penaltyPoints': penaltyPoints,
      'goingOutBonus': goingOutBonus,
      'totalRoundScore': totalRoundScore,
    };
  }

  /// Create a compact representation for game serialization
  Map<String, dynamic> toCompactJson() {
    return {
      'r': round,
      'cp': cardPoints,
      'cb': cleanBooks,
      'db': dirtyBooks,
      'pp': penaltyPoints,
      'gb': goingOutBonus,
      'ts': totalRoundScore,
    };
  }

  /// Create from compact JSON representation
  factory RoundScoreBreakdown.fromCompactJson(Map<String, dynamic> json) {
    return RoundScoreBreakdown(
      round: json['r'] ?? 0,
      cardPoints: json['cp'] ?? 0,
      cleanBooks: json['cb'] ?? 0,
      dirtyBooks: json['db'] ?? 0,
      penaltyPoints: json['pp'] ?? 0,
      goingOutBonus: json['gb'] ?? 0,
      totalRoundScore: json['ts'] ?? 0,
    );
  }

  @override
  String toString() {
    return 'Round $round: Cards($cardPoints) + Clean($cleanBooks×500) + Dirty($dirtyBooks×300) + GoOut($goingOutBonus) - Penalty($penaltyPoints) = $totalRoundScore';
  }
}
