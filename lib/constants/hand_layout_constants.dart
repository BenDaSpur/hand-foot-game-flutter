/// Shared layout constants for the human player's hand and draw animations.
class HandLayoutConstants {
  HandLayoutConstants._();

  static const double cardWidth = 70;
  static const double cardHeight = 98;
  static const double cardOffset = 50;
  static const double selectionLift = 12;

  static double handStackWidth(int cardCount) {
    if (cardCount <= 0) {
      return cardWidth;
    }
    return (cardCount - 1) * cardOffset + cardWidth;
  }

  static double handCardLeft(int index) {
    return index * cardOffset;
  }
}
