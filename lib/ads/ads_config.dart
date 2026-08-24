import 'package:flutter/foundation.dart';

/// AdMob application / unit IDs and timing knobs.
///
/// Debug and profile always use Google sample IDs. Release uses the Hand &
/// Foot production units below unless overridden with `--dart-define`
/// (see `docs/ADMOB.md`). App IDs in native manifests are separate.
abstract final class AdsConfig {
  static const Duration interstitialCooldown = Duration(minutes: 2);
  static const Duration interstitialPresentTimeout = Duration(seconds: 1);

  static const String lastInterstitialPrefKey = 'ads.last_interstitial_ms';

  static const String googleTestAndroidAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String googleTestIosAppId =
      'ca-app-pub-3940256099942544~1458002511';

  static const String googleTestAndroidInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String googleTestIosInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';

  static const String googleTestAndroidBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String googleTestIosBannerId =
      'ca-app-pub-3940256099942544/2934735716';

  static const String publisherId = 'pub-8788020871095245';

  /// Production interstitial (`solo_round_end_interstitial`).
  static const String productionInterstitialId =
      'ca-app-pub-8788020871095245/2472333204';

  /// Production banner (`main_menu_banner`).
  static const String productionBannerId =
      'ca-app-pub-8788020871095245/7317465770';

  static bool get useTestAds {
    const forceTest = bool.fromEnvironment(
      'ADMOB_USE_TEST_ADS',
      defaultValue: false,
    );
    if (forceTest) {
      return true;
    }
    return !kReleaseMode;
  }

  static bool get isIos => defaultTargetPlatform == TargetPlatform.iOS;

  static String get interstitialUnitId {
    if (useTestAds) {
      return isIos
          ? googleTestIosInterstitialId
          : googleTestAndroidInterstitialId;
    }
    const androidId = String.fromEnvironment('ADMOB_ANDROID_INTERSTITIAL_ID');
    const iosId = String.fromEnvironment('ADMOB_IOS_INTERSTITIAL_ID');
    final configured = isIos ? iosId : androidId;
    if (configured.isNotEmpty) {
      return configured;
    }
    return productionInterstitialId;
  }

  static String get bannerUnitId {
    if (useTestAds) {
      return isIos ? googleTestIosBannerId : googleTestAndroidBannerId;
    }
    const androidId = String.fromEnvironment('ADMOB_ANDROID_BANNER_ID');
    const iosId = String.fromEnvironment('ADMOB_IOS_BANNER_ID');
    final configured = isIos ? iosId : androidId;
    if (configured.isNotEmpty) {
      return configured;
    }
    return productionBannerId;
  }
}
