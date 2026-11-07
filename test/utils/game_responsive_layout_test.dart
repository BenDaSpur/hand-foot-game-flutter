import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/game_config.dart';
import 'package:hand_foot_game_flutter/utils/game_responsive_layout.dart';

void main() {
  group('GameResponsiveLayout size tiers', () {
    test('classifies phone tablet and large tablet widths', () {
      expect(GameResponsiveLayout.isPhone(390), isTrue);
      // iPhone Duo cover (~466) must stay phone-tier, not tablet cards.
      expect(GameResponsiveLayout.isPhone(466), isTrue);
      expect(GameResponsiveLayout.isPhone(500), isTrue);
      expect(GameResponsiveLayout.isPhone(501), isFalse);
      expect(GameResponsiveLayout.isTabletOrLarger(390), isFalse);
      expect(GameResponsiveLayout.isTabletOrLarger(669), isTrue);
      expect(GameResponsiveLayout.isTabletOrLarger(768), isTrue);
      expect(GameResponsiveLayout.isLargeTablet(768), isFalse);
      expect(GameResponsiveLayout.isLargeTablet(1024), isTrue);
      expect(GameResponsiveLayout.useWideBoardLayout(899), isFalse);
      expect(GameResponsiveLayout.useWideBoardLayout(951), isTrue);
      expect(
        GameResponsiveLayout.useWideBoardLayout(
          GameConfig.tabletLandscapeBreakpoint,
        ),
        isTrue,
      );
      expect(GameResponsiveLayout.isUltraShortHeight(466), isTrue);
      expect(GameResponsiveLayout.isUltraShortHeight(678), isFalse);
      expect(GameResponsiveLayout.isInnerClass(const Size(669, 951)), isTrue);
      expect(GameResponsiveLayout.isInnerClass(const Size(466, 678)), isFalse);
      expect(GameResponsiveLayout.isDuoCover(const Size(466, 678)), isTrue);
      expect(GameResponsiveLayout.isDuoCover(const Size(678, 466)), isTrue);
      expect(GameResponsiveLayout.isDuoCover(const Size(390, 844)), isFalse);
      expect(GameResponsiveLayout.isDuoCover(const Size(852, 393)), isFalse);
      expect(GameResponsiveLayout.isDuoCover(const Size(669, 951)), isFalse);
      expect(
        GameResponsiveLayout.useTrailingWideRail(const Size(951, 669)),
        isTrue,
      );
      expect(
        GameResponsiveLayout.useTrailingWideRail(const Size(1024, 768)),
        isFalse,
      );
      expect(
        GameResponsiveLayout.useTrailingWideRail(const Size(1440, 900)),
        isFalse,
      );
      expect(
        GameResponsiveLayout.useTrailingWideRail(const Size(669, 951)),
        isFalse,
      );
    });

    test('cardSizesForWidth returns distinct tablet tiers', () {
      final phone = GameResponsiveLayout.cardSizesForWidth(390);
      final duoCover = GameResponsiveLayout.cardSizesForWidth(466);
      final tablet = GameResponsiveLayout.cardSizesForWidth(768);
      final large = GameResponsiveLayout.cardSizesForWidth(1024);

      expect(phone.handWidth, GameCardSizes.normalPhone.handWidth);
      expect(duoCover.handWidth, GameCardSizes.normalPhone.handWidth);
      expect(tablet.handWidth, GameCardSizes.tablet.handWidth);
      expect(large.handWidth, GameCardSizes.largeTablet.handWidth);
      expect(tablet.handWidth, greaterThan(phone.handWidth));
      expect(large.handWidth, greaterThan(tablet.handWidth));
      expect(large.pileWidth, greaterThan(tablet.pileWidth));
    });

    test('scaledHandSizes shrinks when available height is tight', () {
      final base = GameCardSizes.tablet;
      final unconstrained = GameResponsiveLayout.scaledHandSizes(
        base: base,
        screenWidth: 800,
        cardCount: 11,
        availableWidth: 800,
      );
      final fitted = GameResponsiveLayout.scaledHandSizes(
        base: base,
        screenWidth: 800,
        cardCount: 11,
        availableWidth: 800,
        availableHeight: 200,
      );

      expect(fitted.handHeight, lessThan(unconstrained.handHeight));
      expect(
        fitted.handHeight +
            fitted.selectionLift +
            GameResponsiveLayout.handDisplayChromeHeight +
            4,
        lessThanOrEqualTo(200),
      );
    });

    testWidgets('handSizes on phone keeps phone tier width', (tester) async {
      late GameCardSizes sizes;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              sizes = GameResponsiveLayout.handSizes(context, cardCount: 11);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(sizes.handWidth, GameCardSizes.normalPhone.handWidth);
    });

    test('opening hand fits the Duo inner landscape pane', () {
      final base = GameResponsiveLayout.cardSizesForWidth(951);
      // Play pane beside the wide rail, and the same pane with a trailing status inset.
      for (final strip in <double>[630, 550]) {
        final sizes = GameResponsiveLayout.scaledHandSizes(
          base: base,
          screenWidth: 951,
          cardCount: 13,
          availableWidth: strip,
        );
        final usable = strip - GameResponsiveLayout.handStripHorizontalChrome;

        expect(
          sizes.handStackWidth(13),
          lessThanOrEqualTo(usable + 0.01),
          reason: 'strip $strip',
        );
        expect(
          sizes.handWidth,
          greaterThanOrEqualTo(GameResponsiveLayout.minScaledHandWidth),
        );
        expect(sizes.handWidth, lessThan(GameCardSizes.largeTablet.handWidth));
      }
    });

    test('very large hand stops at the readable floor', () {
      final sizes = GameResponsiveLayout.scaledHandSizes(
        base: GameCardSizes.largeTablet,
        screenWidth: 951,
        cardCount: 40,
        availableWidth: 600,
      );

      expect(
        sizes.handWidth,
        closeTo(GameResponsiveLayout.minScaledHandWidth, 0.01),
      );
    });

    testWidgets('handSizes on large tablet exceeds tablet base', (
      tester,
    ) async {
      late GameCardSizes sizes;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1024, 768)),
          child: Builder(
            builder: (context) {
              sizes = GameResponsiveLayout.handSizes(context, cardCount: 11);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        sizes.handWidth,
        greaterThanOrEqualTo(GameCardSizes.largeTablet.handWidth),
      );
    });
  });
}
