import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hand_foot_game_flutter/ads/ads_banner.dart';
import 'package:hand_foot_game_flutter/ads/ads_service.dart';
import 'package:hand_foot_game_flutter/ads/ads_service_mobile.dart';

void main() {
  tearDown(() {
    AdsService.debugReset();
    MobileMenuBannerDebug.reset();
  });

  testWidgets('AdsBanner shrinks when ads are unavailable', (tester) async {
    AdsService.instance = NoOpAdsService();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AdsBanner())),
    );
    await tester.pump();

    final size = tester.getSize(find.byType(AdsBanner));
    expect(size.height, 0);
    expect(size.width, 0);
  });

  testWidgets(
    'MediaQuery change does not start a second banner while load is pending',
    (tester) async {
      final loadedAds = <BannerAd>[];
      MobileMenuBannerDebug.resolveSize = (width) async {
        return AdSize(width: width, height: 50);
      };
      MobileMenuBannerDebug.loadAd = (ad) async {
        loadedAds.add(ad);
      };

      Widget app(double width) {
        return MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 800)),
            child: const Scaffold(
              body: MobileMenuBanner(adUnitId: 'test-banner'),
            ),
          ),
        );
      }

      await tester.pumpWidget(app(320));
      await tester.pump();
      await tester.pump();
      expect(loadedAds, hasLength(1));

      await tester.pumpWidget(app(400));
      await tester.pump();
      await tester.pump();
      expect(loadedAds, hasLength(1));
    },
  );
}
