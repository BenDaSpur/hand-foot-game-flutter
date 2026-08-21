import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ads/ads_service.dart';

void main() {
  tearDown(AdsService.debugReset);

  test('factory is a no-op outside Android and iOS', () {
    AdsService.debugReset();
    expect(AdsService.instance, isA<NoOpAdsService>());
  });

  test('NoOpAdsService never throws and returns immediately', () async {
    final ads = NoOpAdsService();
    await ads.initialize();
    ads.preloadInterstitial();
    await ads.showInterstitialIfEligible(isSolo: true, isLearnToPlay: false);
    await ads.showPrivacyOptions();

    expect(ads.isBannerAvailable, isFalse);
    expect(ads.shouldShowPrivacyOptions, isFalse);
  });

  testWidgets('NoOp banner widget is a shrink box', (tester) async {
    final ads = NoOpAdsService();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (context) => ads.buildBanner(context)),
      ),
    );
    expect(find.byType(SizedBox), findsOneWidget);
    final box = tester.widget<SizedBox>(find.byType(SizedBox));
    expect(box.width ?? 0, 0);
    expect(box.height ?? 0, 0);
  });
}
