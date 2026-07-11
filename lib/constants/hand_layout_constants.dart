import 'package:flutter/material.dart';
import '../utils/game_responsive_layout.dart';
import '../widgets/playing_card_widget.dart';

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

  static double handCardLeft(int index, [GameCardSizes? sizes]) {
    final s = sizes ?? GameCardSizes.tabletPlus;
    return s.handCardLeft(index);
  }

  /// Total margin applied by [PlayingCardWidget] on both axes.
  static double get cardWidgetMargin => PlayingCardWidget.cardMargin * 2;

  static double handCardWidgetWidth(GameCardSizes sizes) {
    return sizes.handWidth + cardWidgetMargin;
  }

  static double handCardWidgetHeight(GameCardSizes sizes) {
    return sizes.handHeight + cardWidgetMargin;
  }

  /// Center of a bottom-aligned hand card inside the hand stack.
  static Offset handCardCenterInStack(
    int index,
    GameCardSizes sizes,
    double stackHeight,
  ) {
    return Offset(
      handCardLeft(index, sizes) + handCardWidgetWidth(sizes) / 2,
      stackHeight - handCardWidgetHeight(sizes) / 2,
    );
  }
}
