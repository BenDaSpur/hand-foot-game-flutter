import 'package:flutter/material.dart';
import '../models/meld.dart';
import 'playing_card_widget.dart';

class MeldWidget extends StatelessWidget {
  final Meld meld;
  final bool canAddCards;
  final Function(int meldIndex)? onCardDrop;
  final Function(int meldIndex)? onTap;
  final Function(int meldIndex)? onSelectAllCards;
  final bool canAcceptSelectedCard;
  final int meldIndex;
  final int compatibleCardsInHand;
  final bool compatibleCardsAreWilds;

  const MeldWidget({
    super.key,
    required this.meld,
    required this.meldIndex,
    this.canAddCards = false,
    this.onCardDrop,
    this.onTap,
    this.onSelectAllCards,
    this.canAcceptSelectedCard = false,
    this.compatibleCardsInHand = 0,
    this.compatibleCardsAreWilds = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap != null ? () => onTap!(meldIndex) : null,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: canAcceptSelectedCard ? Colors.blue[50] : Colors.grey[100],
          border: Border.all(
            color: canAcceptSelectedCard
                ? Colors.blue
                : canAddCards
                ? Colors.green
                : Colors.grey,
            width: canAcceptSelectedCard || canAddCards ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  meld.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getMeldTypeColor(),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${meld.pointValue} pts',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (meld.isBook) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: meld.isClean ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      meld.isClean ? 'CLEAN BOOK' : 'DIRTY BOOK',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (canAddCards && compatibleCardsInHand > 0) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onSelectAllCards != null
                        ? () => onSelectAllCards!(meldIndex)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        compatibleCardsAreWilds
                            ? 'Select $compatibleCardsInHand wilds'
                            : 'Select $compatibleCardsInHand',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: () {
                final sortedCards = [...meld.cards];
                sortedCards.sort(
                  (a, b) => a.displayOrder.compareTo(b.displayOrder),
                );
                return sortedCards
                    .asMap()
                    .entries
                    .map(
                      (entry) => PlayingCardWidget(
                        key: ValueKey('meld-$meldIndex-${entry.key}'),
                        card: entry.value,
                        width: 40,
                        height: 56,
                        isInMeld: true,
                      ),
                    )
                    .toList();
              }(),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMeldTypeColor() {
    switch (meld.type) {
      case MeldType.natural:
        return Colors.green;
      case MeldType.mixed:
        return Colors.orange;
    }
  }
}
