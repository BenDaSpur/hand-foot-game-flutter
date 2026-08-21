import 'package:flutter/widgets.dart';

import 'ads_service_stub.dart'
    if (dart.library.io) 'ads_service_io.dart'
    as ads_impl;

/// Facade for AdMob. Web, desktop, and tests use [NoOpAdsService].
abstract class AdsService extends ChangeNotifier {
  static AdsService? _instance;

  static AdsService get instance => _instance ??= ads_impl.createAdsService();

  @visibleForTesting
  static set instance(AdsService value) => _instance = value;

  @visibleForTesting
  static void debugReset() {
    _instance = null;
  }

  /// UMP consent then Mobile Ads SDK init. Never throws. Safe to call
  /// without awaiting before [runApp].
  Future<void> initialize();

  /// Prefetch an interstitial so round-end can fail open if none is ready.
  void preloadInterstitial();

  /// Show a ready interstitial at a solo round break, or return immediately.
  Future<void> showInterstitialIfEligible({
    required bool isSolo,
    required bool isLearnToPlay,
  });

  /// True when a menu banner should occupy layout (SDK ready + consent).
  bool get isBannerAvailable;

  /// True when UMP requires a publisher-rendered privacy options entry.
  bool get shouldShowPrivacyOptions;

  Future<void> showPrivacyOptions();

  Widget buildBanner(BuildContext context);
}

/// Used on web, desktop, and as the test double default.
class NoOpAdsService extends AdsService {
  @override
  Future<void> initialize() async {}

  @override
  void preloadInterstitial() {}

  @override
  Future<void> showInterstitialIfEligible({
    required bool isSolo,
    required bool isLearnToPlay,
  }) async {}

  @override
  bool get isBannerAvailable => false;

  @override
  bool get shouldShowPrivacyOptions => false;

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Widget buildBanner(BuildContext context) => const SizedBox.shrink();
}
