import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/meld.dart';
import '../theme/balatro_theme.dart';
import '../utils/game_responsive_layout.dart';
import 'playing_card_widget.dart';

class _MeldLayout {
  static const double phoneOuterMargin = 4;
  static const double tabletOuterMargin = 8;
  static const double phonePadding = 6;
  static const double tabletPadding = 8;
  static const double borderRadius = 12;
  static const double badgeBorderRadius = 4;
  static const double activeBorderWidth = 2;
  static const double inactiveBorderWidth = 1;
  static const double titleFontSize = 13;
  static const double badgeFontSize = 11;
  static const double bookBadgeFontSize = 9;
  static const double addButtonFontSize = 9;
  static const double addButtonFontSizeTouch = 13;
  static const double addButtonMinHeightTouch = 36;
  static const double addButtonMinWidthTouch = 44;
  static const double addButtonPaddingHTouch = 10;
  static const double addButtonPaddingVTouch = 6;
  static const double headerSpacing = 6;
  static const double bookSpacing = 4;
  static const double cardsTopSpacing = 6;
  static const double cardWrapSpacing = 3;
}

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
    final outerMargin = isPhone
        ? _MeldLayout.phoneOuterMargin
        : _MeldLayout.tabletOuterMargin;

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
        padding: EdgeInsets.all(
          isPhone ? _MeldLayout.phonePadding : _MeldLayout.tabletPadding,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
            color: borderColor,
            width: canAcceptSelectedCard || canAddCards
                ? _MeldLayout.activeBorderWidth
                : _MeldLayout.inactiveBorderWidth,
          ),
          borderRadius: BorderRadius.circular(_MeldLayout.borderRadius),
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
                      fontSize: _MeldLayout.titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: BalatroTheme.primaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: _MeldLayout.headerSpacing),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _MeldLayout.headerSpacing,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getMeldTypeColor(),
                    borderRadius: BorderRadius.circular(
                      _MeldLayout.badgeBorderRadius,
                    ),
                  ),
                  child: Text(
                    '${meld.pointValue} pts',
                    style: const TextStyle(
                      fontSize: _MeldLayout.badgeFontSize,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (meld.isBook) ...[
                  SizedBox(width: _MeldLayout.bookSpacing),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _MeldLayout.headerSpacing,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: meld.isClean
                          ? BalatroTheme.neonGreen
                          : BalatroTheme.neonPink,
                      borderRadius: BorderRadius.circular(
                        _MeldLayout.badgeBorderRadius,
                      ),
                    ),
                    child: Text(
                      meld.isClean ? 'CLEAN' : 'DIRTY',
                      style: const TextStyle(
                        fontSize: _MeldLayout.bookBadgeFontSize,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (canAddCards && compatibleCardsInHand > 0) ...[
                  SizedBox(width: _MeldLayout.headerSpacing),
                  _CompatibleCardsAddButton(
                    count: compatibleCardsInHand,
                    areWilds: compatibleCardsAreWilds,
                    useTouchTarget: _preferTouchSizedAddButton(context),
                    onTap: onSelectAllCards != null
                        ? () => onSelectAllCards!(meldIndex)
                        : null,
                  ),
                ],
              ],
            ),
            SizedBox(height: _MeldLayout.cardsTopSpacing),
            Wrap(
              spacing: _MeldLayout.cardWrapSpacing,
              runSpacing: _MeldLayout.cardWrapSpacing,
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

/// Compact on desktop/web mouse; larger min size for native / phone / touch.
@visibleForTesting
bool preferTouchSizedMeldAddButton({
  required bool isWeb,
  required double width,
}) {
  // Native iOS/Android: always use a finger-sized target.
  if (!isWeb) {
    return true;
  }
  // Web: enlarge on phone-width (mobile browsers); keep compact on desktop.
  return GameResponsiveLayout.isPhone(width);
}

bool _preferTouchSizedAddButton(BuildContext context) {
  return preferTouchSizedMeldAddButton(
    isWeb: kIsWeb,
    width: MediaQuery.sizeOf(context).width,
  );
}

class _CompatibleCardsAddButton extends StatelessWidget {
  final int count;
  final bool areWilds;
  final bool useTouchTarget;
  final VoidCallback? onTap;

  const _CompatibleCardsAddButton({
    required this.count,
    required this.areWilds,
    required this.useTouchTarget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = areWilds ? '+$count wilds' : '+$count';

    if (!useTouchTarget) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: _MeldLayout.headerSpacing,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: BalatroTheme.neonBlue,
            borderRadius: BorderRadius.circular(_MeldLayout.badgeBorderRadius),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: _MeldLayout.addButtonFontSize,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Material(
      color: BalatroTheme.neonBlue,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _MeldLayout.addButtonMinWidthTouch,
            minHeight: _MeldLayout.addButtonMinHeightTouch,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _MeldLayout.addButtonPaddingHTouch,
              vertical: _MeldLayout.addButtonPaddingVTouch,
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: _MeldLayout.addButtonFontSizeTouch,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
