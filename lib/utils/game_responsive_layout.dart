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

  /// Tablet / iPad portrait (430–900px)
  static const tablet = GameCardSizes(
    handWidth: 88,
    handHeight: 126,
    handOffset: 42,
    meldWidth: 48,
    meldHeight: 69,
    pileWidth: 64,
    pileHeight: 91,
  );

  /// Large tablet / macOS / iPad landscape (>900px)
  static const largeTablet = GameCardSizes(
    handWidth: 104,
    handHeight: 149,
    handOffset: 48,
    meldWidth: 56,
    meldHeight: 80,
    pileWidth: 72,
    pileHeight: 103,
  );

  /// Legacy alias for callers that still reference tablet+.
  static const tabletPlus = tablet;

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

  /// Max width for the action button row on tablet+.
  static const double actionDockMaxWidthSingle = 520;
  static const double actionDockMaxWidthMulti = 640;

  /// Max width for centered player score chips on tablet+.
  static const double playerScoresMaxWidth = 720;

  /// Left rail width in the two-pane wide board layout.
  static const double wideBoardRailWidth = 320;

  /// Target fill of the hand strip for dynamic tablet hand sizing.
  static const double handStripFillRatio = 0.80;

  static bool isPhone(double width) {
    return width <= normalPhoneBreakpoint;
  }

  static bool isSmallPhone(double width) {
    return width <= smallPhoneBreakpoint;
  }

  static bool isTabletOrLarger(double width) {
    return width > normalPhoneBreakpoint;
  }

  static bool isLargeTablet(double width) {
    return width > GameConfig.tabletLandscapeBreakpoint;
  }

  /// Two-pane board (rail + main) for iPad landscape / macOS.
  static bool useWideBoardLayout(double width) {
    return width >= GameConfig.tabletLandscapeBreakpoint;
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
    if (width <= GameConfig.tabletLandscapeBreakpoint) {
      return GameCardSizes.tablet;
    }
    return GameCardSizes.largeTablet;
  }

  static GameCardSizes cardSizes(BuildContext context) {
    return cardSizesForWidth(MediaQuery.of(context).size.width);
  }

  /// Approximate vertical chrome around the hand stack (label + padding).
  static const double handDisplayChromeHeight = 48;

  /// Hand cards on phone prioritize readability (horizontal scroll is expected).
  /// On tablet+, scales toward filling [handStripFillRatio] of the hand strip.
  static GameCardSizes handSizes(
    BuildContext context, {
    int cardCount = 11,
    double? availableWidth,
    double? availableHeight,
  }) {
    final width = MediaQuery.of(context).size.width;
    final base = cardSizesForWidth(width);
    if (isPhone(width)) {
      return _fitHandToHeight(
        base.copyWithHand(
          handWidth: base.handWidth,
          handHeight: base.handWidth / GameConfig.cardAspectRatio,
          handOffset: base.handOffset,
        ),
        availableHeight: availableHeight,
      );
    }

    return scaledHandSizes(
      base: base,
      screenWidth: width,
      cardCount: cardCount,
      availableWidth: availableWidth,
      availableHeight: availableHeight,
    );
  }

  /// Pure helper for tests and callers that already know strip width.
  static GameCardSizes scaledHandSizes({
    required GameCardSizes base,
    required double screenWidth,
    int cardCount = 11,
    double? availableWidth,
    double? availableHeight,
  }) {
    final stripWidth =
        availableWidth ??
        (useWideBoardLayout(screenWidth)
            ? screenWidth - wideBoardRailWidth - 24
            : screenWidth * 0.92);
    final targetFill = stripWidth * handStripFillRatio;
    final count = cardCount <= 0 ? 1 : cardCount;
    final offsetRatio = base.handOffset / base.handWidth;
    final computedWidth = targetFill / ((count - 1) * offsetRatio + 1);
    final maxHandWidth = isLargeTablet(screenWidth)
        ? GameConfig.maxCardWidth
        : GameConfig.maxCardWidth * 0.92;
    final handWidth = computedWidth.clamp(base.handWidth, maxHandWidth);
    final handOffset = handWidth * offsetRatio;
    return _fitHandToHeight(
      base.copyWithHand(
        handWidth: handWidth,
        handHeight: handWidth / GameConfig.cardAspectRatio,
        handOffset: handOffset,
      ),
      availableHeight: availableHeight,
    );
  }

  /// Shrinks hand cards when the dock height cannot fit the scaled size.
  static GameCardSizes _fitHandToHeight(
    GameCardSizes sizes, {
    double? availableHeight,
  }) {
    if (availableHeight == null || !availableHeight.isFinite) {
      return sizes;
    }
    final maxStackHeight = (availableHeight - handDisplayChromeHeight).clamp(
      40.0,
      availableHeight,
    );
    final maxHandHeight = (maxStackHeight - sizes.selectionLift - 4).clamp(
      36.0,
      sizes.handHeight,
    );
    if (maxHandHeight >= sizes.handHeight - 0.5) {
      return sizes;
    }
    final handWidth = maxHandHeight * GameConfig.cardAspectRatio;
    final offsetRatio = sizes.handOffset / sizes.handWidth;
    return sizes.copyWithHand(
      handWidth: handWidth,
      handHeight: maxHandHeight,
      handOffset: handWidth * offsetRatio,
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
