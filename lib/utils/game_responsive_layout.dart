import 'package:material_ui/material_ui.dart';

import '../config/game_config.dart';
import '../constants/ui_constants.dart';

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

  /// Phone tier includes iPhone Duo cover (~466pt) so it does not get tablet cards.
  static const double normalPhoneBreakpoint = 500;

  /// Short viewports (SE / Duo cover portrait): tighten chrome.
  static const double shortHeightBreakpoint = 700;

  /// Ultra-short viewports (Duo cover landscape ~466pt tall): densest dock.
  static const double ultraShortHeightBreakpoint = 520;

  /// Duo cover logical size is about 466×678 (portrait or landscape).
  ///
  /// A normal phone in landscape is shorter than 440pt or longer than 720pt,
  /// and the inner display's shortest side is about 669pt.
  static const double duoCoverMinShortestSide = 440;
  static const double duoCoverMaxShortestSide = 500;
  static const double duoCoverMinLongestSide = 640;
  static const double duoCoverMaxLongestSide = 720;

  /// Slim trailing column for turn actions on the Duo cover and book pose.
  static const double trailingActionRailWidth = 84;

  /// Open Duo landscape (~951×669). Taller canvases (iPad) and wider
  /// canvases (desktop) keep the leading rail.
  static const double duoInnerLandscapeMaxHeight = 720;
  static const double duoInnerLandscapeMaxWidth = 1100;

  /// Max content width for menus on regular-width / inner Duo displays.
  static const double menuContentMaxWidth = 520;

  /// Max width for the action button row on tablet+.
  static const double actionDockMaxWidthSingle = 520;
  static const double actionDockMaxWidthMulti = 640;

  /// Max width for centered player score chips on tablet+.
  static const double playerScoresMaxWidth = 720;

  /// Left rail width in the two-pane wide board layout.
  static const double wideBoardRailWidth = 320;

  /// Slightly wider rail on large inner / desktop canvases so the board is less sparse.
  static const double wideBoardRailWidthLarge = 360;

  /// Target fill of the hand strip for dynamic tablet hand sizing.
  static const double handStripFillRatio = 0.80;

  /// Horizontal padding inside the hand strip: the hand container (8 + 8)
  /// plus the scroller glow inset on each side.
  ///
  /// Must stay in sync with the hand display padding so a fitted fan does not
  /// scroll.
  static const double handStripHorizontalChrome =
      16 + UIConstants.handGlowPadding * 2;

  /// Smallest tablet hand card. Matches [GameCardSizes.smallPhone].
  /// Below this, the fan scrolls inside the dock instead of shrinking further.
  static const double minScaledHandWidth = 60;

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

  /// Two-pane board (rail + main) for iPad landscape / macOS / Duo inner landscape.
  static bool useWideBoardLayout(double width) {
    return width >= GameConfig.tabletLandscapeBreakpoint;
  }

  /// Closed Duo cover, where turn actions move to a slim trailing column.
  static bool isDuoCover(Size size) {
    final shortest = size.shortestSide;
    final longest = size.longestSide;
    return shortest >= duoCoverMinShortestSide &&
        shortest <= duoCoverMaxShortestSide &&
        longest >= duoCoverMinLongestSide &&
        longest <= duoCoverMaxLongestSide;
  }

  /// Open Duo landscape: the wide context rail sits on the trailing edge,
  /// under the Control Center / status strip.
  static bool useTrailingWideRail(Size size) {
    return size.width >= GameConfig.tabletLandscapeBreakpoint &&
        size.height < duoInnerLandscapeMaxHeight &&
        size.width < duoInnerLandscapeMaxWidth;
  }

  /// Regular-width “inner class” chrome (Duo open portrait, iPad) without forcing the rail.
  static bool isInnerClass(Size size) {
    return size.shortestSide >= GameConfig.tabletPortraitBreakpoint;
  }

  static bool isShortHeight(double height) {
    return height < shortHeightBreakpoint;
  }

  static bool isUltraShortHeight(double height) {
    return height <= ultraShortHeightBreakpoint;
  }

  static double wideBoardRailWidthFor(double width) {
    if (width >= GameConfig.desktopBreakpoint) {
      return wideBoardRailWidthLarge;
    }
    return wideBoardRailWidth;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width <=
        GameConfig.tabletPortraitBreakpoint;
  }

  static bool isSmallMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width <= compactPhoneBreakpoint;
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

  /// Tighter hand chrome on ultra-short covers (Duo cover landscape).
  static const double handDisplayChromeHeightUltraShort = 28;

  static double handChromeHeightFor(double viewportHeight) {
    if (isUltraShortHeight(viewportHeight)) {
      return handDisplayChromeHeightUltraShort;
    }
    return handDisplayChromeHeight;
  }

  /// Hand cards on phone prioritize readability (horizontal scroll is expected).
  /// On tablet+, scales toward filling [handStripFillRatio] of the hand strip.
  static GameCardSizes handSizes(
    BuildContext context, {
    int cardCount = 11,
    double? availableWidth,
    double? availableHeight,
  }) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final chrome = handChromeHeightFor(size.height);
    final base = cardSizesForWidth(width);
    if (isPhone(width)) {
      return _fitHandToHeight(
        base.copyWithHand(
          handWidth: base.handWidth,
          handHeight: base.handWidth / GameConfig.cardAspectRatio,
          handOffset: base.handOffset,
        ),
        availableHeight: availableHeight,
        chromeHeight: chrome,
      );
    }

    return scaledHandSizes(
      base: base,
      screenWidth: width,
      cardCount: cardCount,
      availableWidth:
          availableWidth ?? _estimatedHandStripWidth(context, width),
      availableHeight: availableHeight,
      chromeHeight: chrome,
    );
  }

  /// Strip width when the hand has not been measured yet (draw animations).
  ///
  /// Subtracts safe-area insets so a trailing Duo status inset does not size
  /// flying cards for a pane wider than the one the hand actually gets.
  static double _estimatedHandStripWidth(BuildContext context, double width) {
    final layoutWidth = (width - MediaQuery.paddingOf(context).horizontal)
        .clamp(0.0, width);
    if (useWideBoardLayout(width)) {
      return layoutWidth - wideBoardRailWidthFor(width) - 24;
    }
    return layoutWidth * 0.92;
  }

  /// Pure helper for tests and callers that already know strip width.
  static GameCardSizes scaledHandSizes({
    required GameCardSizes base,
    required double screenWidth,
    int cardCount = 11,
    double? availableWidth,
    double? availableHeight,
    double chromeHeight = handDisplayChromeHeight,
  }) {
    final stripWidth =
        availableWidth ??
        (useWideBoardLayout(screenWidth)
            ? screenWidth - wideBoardRailWidthFor(screenWidth) - 24
            : screenWidth * 0.92);
    final usableStrip = stripWidth > handStripHorizontalChrome
        ? stripWidth - handStripHorizontalChrome
        : stripWidth;
    final targetFill = usableStrip * handStripFillRatio;
    final count = cardCount <= 0 ? 1 : cardCount;
    final offsetRatio = base.handOffset / base.handWidth;
    final computedWidth = targetFill / ((count - 1) * offsetRatio + 1);
    final maxHandWidth = isLargeTablet(screenWidth)
        ? GameConfig.maxCardWidth
        : GameConfig.maxCardWidth * 0.92;
    final minHandWidth = base.handWidth < minScaledHandWidth
        ? base.handWidth
        : minScaledHandWidth;
    var handWidth = computedWidth.clamp(minHandWidth, maxHandWidth);
    // Keep the tier's design size when that fan already fits (iPad / desktop).
    // Shrink below it only when the fan would otherwise spill out of the
    // strip — Duo inner landscape is wide enough for the rail but not for a
    // 13-card large-tablet fan.
    if (_fanWidth(base.handWidth, offsetRatio, count) <= usableStrip &&
        handWidth < base.handWidth) {
      handWidth = base.handWidth.clamp(minHandWidth, maxHandWidth);
    }
    final handOffset = handWidth * offsetRatio;
    return _fitHandToHeight(
      base.copyWithHand(
        handWidth: handWidth,
        handHeight: handWidth / GameConfig.cardAspectRatio,
        handOffset: handOffset,
      ),
      availableHeight: availableHeight,
      chromeHeight: chromeHeight,
    );
  }

  static double _fanWidth(double handWidth, double offsetRatio, int count) {
    return (count - 1) * handWidth * offsetRatio + handWidth;
  }

  /// Shrinks hand cards when the dock height cannot fit the scaled size.
  static GameCardSizes _fitHandToHeight(
    GameCardSizes sizes, {
    double? availableHeight,
    double chromeHeight = handDisplayChromeHeight,
  }) {
    if (availableHeight == null || !availableHeight.isFinite) {
      return sizes;
    }
    final maxStackHeight = (availableHeight - chromeHeight).clamp(
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
