import 'package:flutter/material.dart';
import '../config/game_config.dart';

/// Responsive card dimensions for in-game UI elements.
class GameCardSizes {
  final double handWidth;
  final double handHeight;
  final double handOffset;
  final double meldWidth;
  final double meldHeight;
  final double pileWidth;
  final double pileHeight;
  final double selectionLift;

  const GameCardSizes({
    required this.handWidth,
    required this.handHeight,
    required this.handOffset,
    required this.meldWidth,
    required this.meldHeight,
    required this.pileWidth,
    required this.pileHeight,
    this.selectionLift = 12,
  });

  /// Small phone (≤360px)
  static const smallPhone = GameCardSizes(
    handWidth: 56,
    handHeight: 78,
    handOffset: 40,
    meldWidth: 34,
    meldHeight: 48,
    pileWidth: 46,
    pileHeight: 64,
  );

  /// Normal phone (≤430px)
  static const normalPhone = GameCardSizes(
    handWidth: 62,
    handHeight: 87,
    handOffset: 44,
    meldWidth: 36,
    meldHeight: 50,
    pileWidth: 50,
    pileHeight: 70,
  );

  /// Tablet and desktop (>430px) — matches legacy fixed sizes
  static const tabletPlus = GameCardSizes(
    handWidth: 70,
    handHeight: 98,
    handOffset: 50,
    meldWidth: 40,
    meldHeight: 56,
    pileWidth: 56,
    pileHeight: 78,
  );

  double handStackWidth(int cardCount) {
    if (cardCount <= 0) {
      return handWidth;
    }
    return (cardCount - 1) * handOffset + handWidth;
  }

  double handCardLeft(int index) {
    return index * handOffset;
  }
}

/// Shared responsive layout helpers for in-game and modal UI.
class GameResponsiveLayout {
  GameResponsiveLayout._();

  static const double smallPhoneBreakpoint = 360;
  static const double normalPhoneBreakpoint = 430;

  static bool isPhone(double width) {
    return width <= normalPhoneBreakpoint;
  }

  static bool isSmallPhone(double width) {
    return width <= smallPhoneBreakpoint;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width <=
        GameConfig.tabletPortraitBreakpoint;
  }

  static bool isSmallMobile(BuildContext context) {
    return MediaQuery.of(context).size.width <= 400.0;
  }

  static GameCardSizes cardSizesForWidth(double width) {
    if (width <= smallPhoneBreakpoint) {
      return GameCardSizes.smallPhone;
    }
    if (width <= normalPhoneBreakpoint) {
      return GameCardSizes.normalPhone;
    }
    return GameCardSizes.tabletPlus;
  }

  static GameCardSizes cardSizes(BuildContext context) {
    return cardSizesForWidth(MediaQuery.of(context).size.width);
  }

  static int getGridCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth <= 360.0) {
      return 4;
    }
    if (screenWidth <= 400.0) {
      return 5;
    }

    if (screenWidth > GameConfig.ultraWideBreakpoint) {
      return GameConfig.gridCrossAxisCounts['ultra_wide']!;
    }
    if (screenWidth > GameConfig.desktopBreakpoint) {
      return GameConfig.gridCrossAxisCounts['desktop']!;
    }
    if (screenWidth > GameConfig.tabletLandscapeBreakpoint) {
      return GameConfig.gridCrossAxisCounts['tablet_landscape']!;
    }
    if (screenWidth > GameConfig.tabletPortraitBreakpoint) {
      return GameConfig.gridCrossAxisCounts['tablet_portrait']!;
    }
    return GameConfig.gridCrossAxisCounts['mobile']!;
  }

  static double getModalCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = getGridCrossAxisCount(context);

    final modalWidthRatio = isMobile(context)
        ? GameConfig.mobileModalWidthRatio
        : GameConfig.modalWidthRatio;

    final availableWidth =
        screenWidth * modalWidthRatio - (isMobile(context) ? 20 : 40);
    final totalSpacing = GameConfig.cardSpacing * (crossAxisCount - 1);
    final cardWidthFromGrid = (availableWidth - totalSpacing) / crossAxisCount;

    final maxWidth = isSmallMobile(context)
        ? GameConfig.maxCardWidth * 0.67
        : GameConfig.maxCardWidth * 0.83;
    final minWidth = isSmallMobile(context)
        ? GameConfig.minCardWidth * 0.9
        : GameConfig.minCardWidth;

    return cardWidthFromGrid.clamp(minWidth, maxWidth);
  }

  static double getModalCardHeight(BuildContext context) {
    return getModalCardWidth(context) / GameConfig.cardAspectRatio;
  }

  static double getOptimizedAspectRatio(BuildContext context) {
    final cardWidth = getModalCardWidth(context);
    final cardHeight = getModalCardHeight(context);
    return cardWidth / cardHeight;
  }

  static EdgeInsets getModalPadding(BuildContext context) {
    return EdgeInsets.all(isMobile(context) ? 12.0 : 20.0);
  }

  static double getModalBorderRadius(BuildContext context) {
    return isMobile(context) ? 16.0 : 20.0;
  }

  static double getFontSize(BuildContext context, double baseSize) {
    return isSmallMobile(context) ? baseSize - 2 : baseSize;
  }
}
