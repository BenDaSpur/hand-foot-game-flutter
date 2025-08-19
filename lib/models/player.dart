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
  final Set<int>
  newlyDrawnCardIndices; // Track indices of cards drawn this turn
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
    Set<int>? newlyDrawnCardIndices,
    this.hasPickedUpFoot = false,
    this.hasPlayedDown = false,
    this.score = 0,
  }) : hand = hand ?? [],
       foot = foot ?? [],
       melds = melds ?? [],
       newlyDrawnCardIndices = newlyDrawnCardIndices ?? {};

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

  void addNewlyDrawnCard(PlayingCard card) {
    final newIndex = currentHand.length;
    currentHand.add(card);
    newlyDrawnCardIndices.add(newIndex);
  }

  void addNewlyDrawnCards(List<PlayingCard> cards) {
    final startIndex = currentHand.length;
    currentHand.addAll(cards);
    for (int i = 0; i < cards.length; i++) {
      newlyDrawnCardIndices.add(startIndex + i);
    }
  }

  void clearNewlyDrawnCards() {
    newlyDrawnCardIndices.clear();
  }

  bool isCardNewlyDrawn(PlayingCard card) {
    // Find the index of this specific card instance in the current hand
    for (int i = 0; i < currentHand.length; i++) {
      if (identical(currentHand[i], card)) {
        return newlyDrawnCardIndices.contains(i);
      }
    }
    return false;
  }

  bool isCardIndexNewlyDrawn(int index) {
    return newlyDrawnCardIndices.contains(index);
  }

  PlayingCard? removeCardFromHand(PlayingCard card) {
    // Find the exact index of this card instance
    for (int i = 0; i < currentHand.length; i++) {
      if (identical(currentHand[i], card)) {
        final removedCard = currentHand.removeAt(i);
        _updateIndicesAfterRemoval([i]);
        return removedCard;
      }
    }
    return null;
  }

  List<PlayingCard> removeCardsByIndices(List<int> indices) {
    final removedCards = <PlayingCard>[];
    // Sort indices in descending order to remove from end to start
    // This prevents index shifting issues
    final sortedIndices = List<int>.from(indices)
      ..sort((a, b) => b.compareTo(a));

    for (final index in sortedIndices) {
      if (index >= 0 && index < currentHand.length) {
        final card = currentHand.removeAt(index);
        removedCards.add(card);
      }
    }

    // Update newly drawn indices after all removals
    _updateIndicesAfterRemoval(indices);

    // Return in original order (reverse since we removed in reverse)
    return removedCards.reversed.toList();
  }

  /// Update newly drawn card indices after card removal
  /// Handles index shifting when cards are removed from the hand
  void _updateIndicesAfterRemoval(List<int> removedIndices) {
    final sortedRemovedIndices = List<int>.from(removedIndices)..sort();

    final updatedIndices = <int>{};

    for (final drawnIndex in newlyDrawnCardIndices) {
      // Count how many removed indices are less than this drawn index
      int shiftAmount = 0;
      for (final removedIndex in sortedRemovedIndices) {
        if (removedIndex < drawnIndex) {
          shiftAmount++;
        } else {
          break;
        }
      }

      // If this drawn index wasn't removed, shift it left by the removal count
      if (!removedIndices.contains(drawnIndex)) {
        updatedIndices.add(drawnIndex - shiftAmount);
      }
      // If it was removed, don't add it to the updated set (it's no longer newly drawn)
    }

    newlyDrawnCardIndices.clear();
    newlyDrawnCardIndices.addAll(updatedIndices);
  }

  void pickUpFoot() {
    if (!hasPickedUpFoot && hand.isEmpty) {
      hasPickedUpFoot = true;
    }
  }

  bool createMeld(List<PlayingCard> cards, {int playDownRequirement = 0}) {
    // Early validation
    if (cards.isEmpty) return false;

    // Check if we should add to existing meld or create new one
    if (_shouldAddToExistingMeld(cards)) {
      return _addToExistingMeld(cards);
    } else {
      return _createNewMeld(cards, playDownRequirement);
    }
  }

  /// Determines if cards should be added to an existing meld
  bool _shouldAddToExistingMeld(List<PlayingCard> cards) {
    final naturalCards = cards
        .where((card) => !card.isWild && !card.isThree)
        .toList();
    if (naturalCards.isEmpty) return false;

    final targetRank = naturalCards.first.rank;
    return findMeldByRank(targetRank) != -1;
  }

  /// Adds cards to an existing meld
  bool _addToExistingMeld(List<PlayingCard> cards) {
    final naturalCards = cards
        .where((card) => !card.isWild && !card.isThree)
        .toList();
    final targetRank = naturalCards.first.rank;
    final existingMeldIndex = findMeldByRank(targetRank);
    final existingMeld = melds[existingMeldIndex];

    // Validate that all cards can be added to the existing meld
    if (!cards.every((card) => existingMeld.canAddCard(card))) {
      return false;
    }

    // Find indices of cards to remove from hand
    final indicesToRemove = _findCardIndices(cards);
    if (indicesToRemove.length != cards.length) {
      return false; // Not all cards found in hand
    }

    // Add all cards to the existing meld
    for (final card in cards) {
      if (!existingMeld.addCard(card)) {
        return false; // This shouldn't happen since we validated above
      }
    }

    // Remove cards from hand using indices (handles duplicates correctly)
    removeCardsByIndices(indicesToRemove);
    hasPlayedDown = true;
    return true;
  }

  /// Creates a new meld from cards
  bool _createNewMeld(List<PlayingCard> cards, int playDownRequirement) {
    final meld = Meld.createMeld(cards);
    if (meld == null) return false;

    // Check play down requirement if player hasn't played down yet
    bool meetsPlayDownRequirement = true;
    if (!hasPlayedDown && playDownRequirement > 0 && melds.isEmpty) {
      final cardPointValue = cards.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      if (cardPointValue < playDownRequirement) {
        return false;
      }
      meetsPlayDownRequirement = true;
    } else if (!hasPlayedDown && melds.isEmpty) {
      // First meld but no requirement check (bypass mode)
      meetsPlayDownRequirement = false;
    }

    // Find indices of cards to remove from hand
    final indicesToRemove = _findCardIndices(cards);
    if (indicesToRemove.length != cards.length) {
      return false; // Not all cards found in hand
    }

    // Remove cards from hand using indices (handles duplicates correctly)
    removeCardsByIndices(indicesToRemove);
    melds.add(meld);

    // Only mark as played down if this is first meld AND requirement was met
    if (!hasPlayedDown && meetsPlayDownRequirement) {
      hasPlayedDown = true;
    }

    return true;
  }

  /// Finds the indices of specific cards in the current hand
  /// Handles duplicate cards correctly by tracking which instances have been used
  List<int> _findCardIndices(List<PlayingCard> cardsToFind) {
    final indices = <int>[];

    // Create a map for O(1) lookups - using string key for card identity
    final cardToFindMap = <String, int>{};
    for (final card in cardsToFind) {
      final key = '${card.rank.name}_${card.suit?.name ?? 'joker'}';
      cardToFindMap[key] = (cardToFindMap[key] ?? 0) + 1;
    }

    // Single pass through hand - O(n) complexity
    for (int handIndex = 0; handIndex < currentHand.length; handIndex++) {
      final handCard = currentHand[handIndex];
      final key = '${handCard.rank.name}_${handCard.suit?.name ?? 'joker'}';

      final count = cardToFindMap[key];
      if (count != null && count > 0) {
        indices.add(handIndex);
        cardToFindMap[key] = count - 1;

        // Early exit if we've found all cards
        if (indices.length == cardsToFind.length) {
          break;
        }
      }
    }

    return indices;
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
