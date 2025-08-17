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
        return 50;
      case CardRank.two:
        return 20;
      case CardRank.ace:
        return 20;
      case CardRank.king:
      case CardRank.queen:
      case CardRank.jack:
      case CardRank.ten:
      case CardRank.nine:
        return 10;
      case CardRank.three:
        if (isRed) {
          return -300; // Red 3 penalty
        } else {
          return -5; // Black 3 penalty
        }
      default: // 4, 5, 6, 7, 8
        return 5;
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
