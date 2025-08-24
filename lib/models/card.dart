import '../config/game_config.dart';

enum Suit { hearts, diamonds, clubs, spades }

enum CardRank {
  ace,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
  joker,
}

class PlayingCard {
  final Suit? suit;
  final CardRank rank;

  const PlayingCard({this.suit, required this.rank});

  bool get isJoker => rank == CardRank.joker;
  bool get isWild => rank == CardRank.two || isJoker;
  bool get isRed => suit == Suit.hearts || suit == Suit.diamonds;
  bool get isBlack => suit == Suit.clubs || suit == Suit.spades;
  bool get isThree => rank == CardRank.three;
  bool get isRedThree => isThree && isRed;
  bool get isBlackThree => isThree && isBlack;

  int get pointValue {
    switch (rank) {
      case CardRank.joker:
        return GameConfig.jokerValue;
      case CardRank.two:
        return GameConfig.twoValue;
      case CardRank.ace:
        return GameConfig.aceValue;
      case CardRank.king:
      case CardRank.queen:
      case CardRank.jack:
        return GameConfig.faceCardValue;
      case CardRank.ten:
      case CardRank.nine:
        return GameConfig.highNumberValue;
      case CardRank.three:
        if (isRed) {
          return GameConfig.red3Penalty; // Red 3 penalty
        } else {
          return GameConfig.black3Penalty; // Black 3 penalty
        }
      default: // 4, 5, 6, 7, 8
        return GameConfig.lowNumberValue;
    }
  }

  int get meldValue {
    switch (rank) {
      case CardRank.two:
        return 2;
      case CardRank.three:
        return 3;
      case CardRank.four:
        return 4;
      case CardRank.five:
        return 5;
      case CardRank.six:
        return 6;
      case CardRank.seven:
        return 7;
      case CardRank.eight:
        return 8;
      case CardRank.nine:
        return 9;
      case CardRank.ten:
        return 10;
      case CardRank.jack:
        return 11;
      case CardRank.queen:
        return 12;
      case CardRank.king:
        return 13;
      case CardRank.ace:
        return 14;
      case CardRank.joker:
        return 0;
    }
  }

  /// Display order for cards in hand: 3s → 4-K → Aces → 2s (wilds) → Jokers
  int get displayOrder {
    switch (rank) {
      case CardRank.three:
        return 1;
      case CardRank.four:
        return 2;
      case CardRank.five:
        return 3;
      case CardRank.six:
        return 4;
      case CardRank.seven:
        return 5;
      case CardRank.eight:
        return 6;
      case CardRank.nine:
        return 7;
      case CardRank.ten:
        return 8;
      case CardRank.jack:
        return 9;
      case CardRank.queen:
        return 10;
      case CardRank.king:
        return 11;
      case CardRank.ace:
        return 12;
      case CardRank.two:
        return 13; // Wild card
      case CardRank.joker:
        return 14; // Wild card
    }
  }

  String get displayName {
    if (isJoker) return 'Joker';
    final rankName = rank.name[0].toUpperCase() + rank.name.substring(1);
    return '$rankName of ${suit?.name ?? ''}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayingCard &&
          runtimeType == other.runtimeType &&
          suit == other.suit &&
          rank == other.rank;

  @override
  int get hashCode => suit.hashCode ^ rank.hashCode;

  @override
  String toString() => displayName;
}
