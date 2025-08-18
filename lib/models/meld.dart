import 'card.dart';

enum MeldType { natural, mixed }

class Meld {
  final CardRank rank;
  final List<PlayingCard> cards;
  @Deprecated(
    'Use currentType instead - this field may not reflect dynamic changes',
  )
  final MeldType type;

  /// Creates a new meld with the given rank, cards, and initial type.
  ///
  /// Note: The [type] parameter is deprecated. In future versions, this constructor
  /// will be refactored to only require rank and cards, with type determined dynamically.
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
  // This is the preferred way to check meld type as it reflects the current state
  MeldType get currentType {
    return cards.any((card) => card.isWild) ? MeldType.mixed : MeldType.natural;
  }

  /// Calculates the total point value of this meld, including book bonuses.
  ///
  /// Thread-safe: Caches the current type at method start to ensure consistent
  /// calculations even if cards are modified during execution.
  int get pointValue {
    // Cache the current type to avoid race conditions
    final meldType = currentType;

    int total = 0;
    for (final card in cards) {
      total += card.pointValue;
    }

    // Book bonuses (7+ cards) - use cached type for consistency
    if (cards.length >= 7) {
      if (meldType == MeldType.natural) {
        total += 500; // Clean book bonus
      } else if (meldType == MeldType.mixed) {
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
