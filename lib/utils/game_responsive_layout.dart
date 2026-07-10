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
    handWidth: 60,
    handHeight: 84,
    handOffset: 32,
    meldWidth: 38,
    meldHeight: 53,
    pileWidth: 48,
    pileHeight: 67,
  );

  /// Normal phone (≤430px)
  static const normalPhone = GameCardSizes(
    handWidth: 68,
    handHeight: 95,
    handOffset: 36,
    meldWidth: 40,
    meldHeight: 56,
    pileWidth: 52,
    pileHeight: 73,
  );

  /// Tablet and desktop (>430px)
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

  GameCardSizes copyWithHand({
    required double handWidth,
    required double handHeight,
    required double handOffset,
  }) {
    return GameCardSizes(
      handWidth: handWidth,
      handHeight: handHeight,
      handOffset: handOffset,
      meldWidth: meldWidth,
      meldHeight: meldHeight,
      pileWidth: pileWidth,
      pileHeight: pileHeight,
      selectionLift: selectionLift,
    );
  }
}

/// Shared responsive layout helpers for in-game and modal UI.
class GameResponsiveLayout {
  GameResponsiveLayout._();

  static const double smallPhoneBreakpoint = 360;
  static const double compactPhoneBreakpoint = 400;
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
    return MediaQuery.of(context).size.width <= compactPhoneBreakpoint;
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

  /// Hand cards on phone prioritize readability (horizontal scroll is expected).
  static GameCardSizes handSizes(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final base = cardSizesForWidth(width);
    if (!isPhone(width)) {
      return base;
    }

    return base.copyWithHand(
      handWidth: base.handWidth,
      handHeight: base.handWidth / GameConfig.cardAspectRatio,
      handOffset: base.handOffset,
    );
  }

  static int getGridCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth <= smallPhoneBreakpoint) {
      return 4;
    }
    if (screenWidth <= compactPhoneBreakpoint) {
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
