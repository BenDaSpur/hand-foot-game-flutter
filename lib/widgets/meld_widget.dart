import 'package:flutter/material.dart';
import '../models/meld.dart';
import '../theme/balatro_theme.dart';
import '../utils/game_responsive_layout.dart';
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
  final double? cardWidth;
  final double? cardHeight;

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
    this.cardWidth,
    this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    final sizes = GameResponsiveLayout.cardSizes(context);
    final meldW = cardWidth ?? sizes.meldWidth;
    final meldH = cardHeight ?? sizes.meldHeight;
    final isPhone = GameResponsiveLayout.isPhone(
      MediaQuery.of(context).size.width,
    );
    final outerMargin = isPhone ? 4.0 : 8.0;

    Color borderColor;
    Color backgroundColor;
    if (canAcceptSelectedCard) {
      borderColor = BalatroTheme.neonBlue;
      backgroundColor = BalatroTheme.neonBlue.withValues(alpha: 0.15);
    } else if (canAddCards) {
      borderColor = BalatroTheme.neonGreen;
      backgroundColor = BalatroTheme.neonGreen.withValues(alpha: 0.1);
    } else {
      borderColor = BalatroTheme.cardBorder.withValues(alpha: 0.6);
      backgroundColor = BalatroTheme.darkPurple.withValues(alpha: 0.85);
    }

    return GestureDetector(
      onTap: onTap != null ? () => onTap!(meldIndex) : null,
      child: Container(
        margin: EdgeInsets.all(outerMargin),
        padding: EdgeInsets.all(isPhone ? 6 : 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
            color: borderColor,
            width: canAcceptSelectedCard || canAddCards ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: canAcceptSelectedCard
              ? [
                  BoxShadow(
                    color: BalatroTheme.neonBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    meld.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: BalatroTheme.primaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
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
                      fontSize: 11,
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
                      color: meld.isClean
                          ? BalatroTheme.neonGreen
                          : BalatroTheme.neonPink,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      meld.isClean ? 'CLEAN' : 'DIRTY',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (canAddCards && compatibleCardsInHand > 0) ...[
                  const SizedBox(width: 6),
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
                        color: BalatroTheme.neonBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        compatibleCardsAreWilds
                            ? '+$compatibleCardsInHand wilds'
                            : '+$compatibleCardsInHand',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 3,
              runSpacing: 3,
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
                        width: meldW,
                        height: meldH,
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
        return BalatroTheme.neonGreen;
      case MeldType.mixed:
        return BalatroTheme.neonOrange;
    }
  }
}
