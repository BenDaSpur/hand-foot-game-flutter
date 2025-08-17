import 'card.dart';
import 'meld.dart';

enum PlayerType { human, bot }

class Player {
  final String id;
  final String name;
  final PlayerType type;
  final List<PlayingCard> hand;
  final List<PlayingCard> foot;
  final List<Meld> melds;
  bool hasPickedUpFoot;
  bool hasPlayedDown;
  int score;

  Player({
    required this.id,
    required this.name,
    required this.type,
    List<PlayingCard>? hand,
    List<PlayingCard>? foot,
    List<Meld>? melds,
    this.hasPickedUpFoot = false,
    this.hasPlayedDown = false,
    this.score = 0,
  }) : hand = hand ?? [],
       foot = foot ?? [],
       melds = melds ?? [];

  List<PlayingCard> get currentHand => hasPickedUpFoot ? foot : hand;

  bool get isHandEmpty => hand.isEmpty;
  bool get isFootEmpty => foot.isEmpty;
  bool get canGoOut => hasPickedUpFoot && foot.isEmpty && canGoOutWithBooks;

  void dealHand(List<PlayingCard> cards) {
    hand.clear();
    hand.addAll(cards);
  }

  void dealFoot(List<PlayingCard> cards) {
    foot.clear();
    foot.addAll(cards);
  }

  void addCardToHand(PlayingCard card) {
    currentHand.add(card);
  }

  void addCardsToHand(List<PlayingCard> cards) {
    currentHand.addAll(cards);
  }

  PlayingCard? removeCardFromHand(PlayingCard card) {
    final removed = currentHand.remove(card);
    return removed ? card : null;
  }

  List<PlayingCard> removeCardsByIndices(List<int> indices) {
    final removedCards = <PlayingCard>[];
    // Sort indices in descending order to remove from end to start
    // This prevents index shifting issues
    final sortedIndices = List<int>.from(indices)
      ..sort((a, b) => b.compareTo(a));

    for (final index in sortedIndices) {
      if (index >= 0 && index < currentHand.length) {
        removedCards.add(currentHand.removeAt(index));
      }
    }

    // Return in original order (reverse since we removed in reverse)
    return removedCards.reversed.toList();
  }

  void pickUpFoot() {
    if (!hasPickedUpFoot && hand.isEmpty) {
      hasPickedUpFoot = true;
    }
  }

  bool createMeld(List<PlayingCard> cards, {int playDownRequirement = 0}) {
    if (cards.isEmpty) return false;

    // First check if we can add to existing melds
    final naturalCards = cards
        .where((card) => !card.isWild && !card.isThree)
        .toList();
    if (naturalCards.isNotEmpty) {
      final targetRank = naturalCards.first.rank;
      final existingMeldIndex = findMeldByRank(targetRank);

      if (existingMeldIndex != -1) {
        // Found existing meld - try to add cards to it
        final existingMeld = melds[existingMeldIndex];

        // Validate that all cards can be added to the existing meld
        for (final card in cards) {
          if (!existingMeld.canAddCard(card)) {
            return false; // Cannot add this card to existing meld
          }
        }

        // Add all cards to the existing meld
        for (final card in cards) {
          if (!existingMeld.addCard(card)) {
            return false;
          }
          // Remove card from hand
          final index = currentHand.indexOf(card);
          if (index != -1) {
            currentHand.removeAt(index);
          } else {
            return false;
          }
        }

        hasPlayedDown = true;
        return true;
      }
    }

    // No existing meld found - try to create a new meld
    final meld = Meld.createMeld(cards);
    if (meld == null) return false;

    // Check play down requirement if player hasn't played down yet
    // Only check if this is their very first meld (no existing melds)
    if (!hasPlayedDown && playDownRequirement > 0 && melds.isEmpty) {
      final cardPointValue = cards.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      if (cardPointValue < playDownRequirement) {
        return false; // Not enough points to play down
      }
    }

    // Remove cards from hand - handle duplicates correctly
    final cardsToRemove = List<PlayingCard>.from(cards);
    for (final card in cardsToRemove) {
      // Find and remove the first matching card from hand
      final index = currentHand.indexOf(card);
      if (index != -1) {
        currentHand.removeAt(index);
      } else {
        // This shouldn't happen if the cards were properly selected
        return false;
      }
    }

    melds.add(meld);
    hasPlayedDown = true;
    return true;
  }

  bool addToMeld(int meldIndex, PlayingCard card) {
    if (meldIndex >= 0 && meldIndex < melds.length) {
      if (melds[meldIndex].addCard(card)) {
        removeCardFromHand(card);
        return true;
      }
    }
    return false;
  }

  int calculateHandValue() {
    int total = 0;
    for (final card in currentHand) {
      total += card.pointValue;
    }
    return total;
  }

  int calculateMeldValue() {
    int total = 0;
    for (final meld in melds) {
      total += meld.pointValue;
    }
    return total;
  }

  int calculateTotalScore() {
    return calculateMeldValue() - calculateHandValue();
  }

  void updateScore(int points) {
    score += points;
  }

  bool hasBook() {
    return melds.any((meld) => meld.isBook);
  }

  int get bookCount => melds.where((meld) => meld.isBook).length;

  bool get hasCleanBook => melds.any((meld) => meld.isBook && meld.isClean);

  bool get hasDirtyBook => melds.any((meld) => meld.isBook && meld.isDirty);

  bool get canGoOutWithBooks => hasCleanBook && hasDirtyBook;

  void sortHandByRank() {
    currentHand.sort((a, b) {
      if (a.isJoker && b.isJoker) return 0;
      if (a.isJoker) return 1;
      if (b.isJoker) return -1;
      return a.meldValue.compareTo(b.meldValue);
    });
  }

  void sortHandBySuit() {
    currentHand.sort((a, b) {
      if (a.isJoker && b.isJoker) return 0;
      if (a.isJoker) return 1;
      if (b.isJoker) return -1;

      final suitComparison = (a.suit?.index ?? 4).compareTo(b.suit?.index ?? 4);
      if (suitComparison != 0) return suitComparison;
      return a.meldValue.compareTo(b.meldValue);
    });
  }

  void sortHandByValue() {
    currentHand.sort((a, b) {
      return a.pointValue.compareTo(b.pointValue);
    });
  }

  // Helper method to find existing meld by rank
  int findMeldByRank(CardRank rank) {
    for (int i = 0; i < melds.length; i++) {
      if (melds[i].rank == rank) {
        return i;
      }
    }
    return -1; // Not found
  }

  @override
  String toString() => '$name (${type.name})';
}
