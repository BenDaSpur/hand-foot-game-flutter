import 'card.dart';

enum MeldType { natural, mixed }

class Meld {
  final CardRank rank;
  final List<PlayingCard> cards;
  final MeldType type;

  Meld({required this.rank, required this.cards, required this.type});

  static Meld? createMeld(List<PlayingCard> cards) {
    if (cards.length < 3) return null;

    // 3s cannot be melded at all
    if (cards.any((card) => card.isThree)) return null;

    final naturalCards = cards.where((card) => !card.isWild).toList();
    final wildCards = cards.where((card) => card.isWild).toList();

    // Wild cards (2s and Jokers) cannot form their own melds
    // They can only be used to supplement natural card melds (4-A)
    if (naturalCards.isEmpty) return null;

    final rank = naturalCards.first.rank;
    final allNaturalSameRank = naturalCards.every((card) => card.rank == rank);

    if (!allNaturalSameRank) return null;

    if (wildCards.isEmpty) {
      return Meld(rank: rank, cards: List.from(cards), type: MeldType.natural);
    }

    if (wildCards.length <= naturalCards.length) {
      return Meld(rank: rank, cards: List.from(cards), type: MeldType.mixed);
    }

    return null;
  }

  bool canAddCard(PlayingCard card) {
    // 3s cannot be added to any meld
    if (card.isThree) return false;

    if (card.isWild) {
      final wildCards = cards.where((c) => c.isWild).length;
      final naturalCards = cards.where((c) => !c.isWild).length;
      return wildCards <
          naturalCards; // Can add wild only if it won't exceed naturals
    }

    return card.rank == rank;
  }

  bool addCard(PlayingCard card) {
    if (canAddCard(card)) {
      cards.add(card);
      return true;
    }
    return false;
  }

  // Dynamic type detection based on current cards
  MeldType get currentType {
    return cards.any((card) => card.isWild) ? MeldType.mixed : MeldType.natural;
  }

  int get pointValue {
    int total = 0;
    for (final card in cards) {
      total += card.pointValue;
    }

    // Book bonuses (7+ cards) - use current type
    if (cards.length >= 7) {
      if (currentType == MeldType.natural) {
        total += 500; // Clean book bonus
      } else if (currentType == MeldType.mixed) {
        total += 300; // Dirty book bonus
      }
    }

    return total;
  }

  bool get isBook => cards.length >= 7;

  // Dynamic clean/dirty detection based on current cards
  bool get isClean => isBook && !cards.any((card) => card.isWild);
  bool get isDirty => isBook && cards.any((card) => card.isWild);

  @override
  String toString() {
    final rankStr = '${rank.name[0].toUpperCase()}${rank.name.substring(1)}';
    return '$rankStr (${cards.length} cards)';
  }
}
