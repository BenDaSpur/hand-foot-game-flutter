import 'ads_config.dart';

/// Pure rules for when a solo interstitial may be shown.
///
/// Keep this free of the Mobile Ads SDK so unit tests can cover it on every
/// platform, including web.
abstract final class AdsEligibility {
  static bool canShowInterstitial({
    required bool isSolo,
    required bool isLearnToPlay,
    required bool canRequestAds,
    required DateTime? lastShownAt,
    required DateTime now,
    Duration cooldown = AdsConfig.interstitialCooldown,
  }) {
    if (!isSolo) {
      return false;
    }
    if (isLearnToPlay) {
      return false;
    }
    if (!canRequestAds) {
      return false;
    }
    if (lastShownAt != null && now.difference(lastShownAt) < cooldown) {
      return false;
    }
    return true;
  }
}
