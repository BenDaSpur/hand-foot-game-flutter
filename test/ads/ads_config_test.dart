import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ads/ads_config.dart';

void main() {
  test('debug/profile builds use Google sample unit IDs', () {
    expect(AdsConfig.useTestAds, isTrue);
    expect(
      AdsConfig.interstitialUnitId,
      anyOf(
        AdsConfig.googleTestAndroidInterstitialId,
        AdsConfig.googleTestIosInterstitialId,
      ),
    );
    expect(
      AdsConfig.bannerUnitId,
      anyOf(
        AdsConfig.googleTestAndroidBannerId,
        AdsConfig.googleTestIosBannerId,
      ),
    );
    expect(AdsConfig.publisherId, 'pub-8788020871095245');
    expect(AdsConfig.interstitialCooldown, const Duration(minutes: 2));
  });

  test('production unit IDs match the AdMob console units', () {
    expect(
      AdsConfig.productionInterstitialId,
      'ca-app-pub-8788020871095245/2472333204',
    );
    expect(
      AdsConfig.productionBannerId,
      'ca-app-pub-8788020871095245/7317465770',
    );
  });
}
