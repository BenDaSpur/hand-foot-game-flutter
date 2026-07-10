import '../utils/game_responsive_layout.dart';

/// Shared layout constants for the human player's hand and draw animations.
/// Legacy static values match tablet+ sizes; use [forWidth] for responsive sizing.
class HandLayoutConstants {
  HandLayoutConstants._();

  static const double cardWidth = 70;
  static const double cardHeight = 98;
  static const double cardOffset = 50;
  static const double selectionLift = 12;

  /// Responsive layout derived from screen width.
  static GameCardSizes forWidth(double width) {
    return GameResponsiveLayout.cardSizesForWidth(width);
  }

  static double handStackWidth(int cardCount, [GameCardSizes? sizes]) {
    final s = sizes ?? GameCardSizes.tabletPlus;
    return s.handStackWidth(cardCount);
  }

  static double handCardLeft(int index, [GameCardSizes? sizes]) {
    final s = sizes ?? GameCardSizes.tabletPlus;
    return s.handCardLeft(index);
  }
}
