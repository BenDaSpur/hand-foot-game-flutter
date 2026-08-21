import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/debug_logger.dart';
import 'ads_config.dart';
import 'ads_eligibility.dart';
import 'ads_service.dart';

/// Android / iOS AdMob implementation. Never throw — ads must not crash play.
class MobileAdsService extends AdsService {
  bool _initialized = false;
  bool _initializing = false;
  bool _sdkReady = false;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  bool _interstitialLoadInFlight = false;
  InterstitialAd? _interstitialAd;
  DateTime? _lastInterstitialShownAt;

  @override
  bool get isBannerAvailable => _sdkReady && _canRequestAds;

  @override
  bool get shouldShowPrivacyOptions => _privacyOptionsRequired;

  @override
  Future<void> initialize() async {
    if (_initialized || _initializing) {
      return;
    }
    _initializing = true;
    try {
      await _loadPersistedCooldown();
      await _gatherConsent();
      await _refreshConsentFlags();
      if (_canRequestAds) {
        await MobileAds.instance.initialize();
        _sdkReady = true;
        preloadInterstitial();
      }
      _initialized = true;
      notifyListeners();
    } catch (e) {
      DebugLogger.warning('Ads initialization failed: $e');
    } finally {
      _initializing = false;
    }
  }

  Future<void> _gatherConsent() async {
    final completer = Completer<void>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            if (formError != null) {
              DebugLogger.warning(
                'UMP consent form error ${formError.errorCode}: '
                '${formError.message}',
              );
            }
            if (!completer.isCompleted) {
              completer.complete();
            }
          });
        },
        (FormError error) {
          DebugLogger.warning(
            'UMP consent update failed ${error.errorCode}: ${error.message}',
          );
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );
    } catch (e) {
      DebugLogger.warning('UMP consent request failed: $e');
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    await completer.future;
  }

  Future<void> _refreshConsentFlags() async {
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      _privacyOptionsRequired =
          status == PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      DebugLogger.warning('UMP consent flag refresh failed: $e');
      _canRequestAds = false;
      _privacyOptionsRequired = false;
    }
  }

  Future<void> _loadPersistedCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt(AdsConfig.lastInterstitialPrefKey);
      if (millis != null && millis > 0) {
        _lastInterstitialShownAt = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    } catch (e) {
      DebugLogger.warning('Failed to load interstitial cooldown: $e');
    }
  }

  Future<void> _persistLastShown(DateTime shownAt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        AdsConfig.lastInterstitialPrefKey,
        shownAt.millisecondsSinceEpoch,
      );
    } catch (e) {
      DebugLogger.warning('Failed to persist interstitial cooldown: $e');
    }
  }

  @override
  void preloadInterstitial() {
    if (!_sdkReady || !_canRequestAds || _interstitialLoadInFlight) {
      return;
    }
    if (_interstitialAd != null) {
      return;
    }
    _interstitialLoadInFlight = true;
    unawaited(_loadInterstitialAd());
  }

  Future<void> _loadInterstitialAd() async {
    try {
      await InterstitialAd.load(
        adUnitId: AdsConfig.interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _interstitialLoadInFlight = false;
          },
          onAdFailedToLoad: (error) {
            DebugLogger.debug('Interstitial failed to load: $error');
            _interstitialAd = null;
            _interstitialLoadInFlight = false;
          },
        ),
      );
    } catch (e) {
      DebugLogger.warning('Interstitial load threw: $e');
      _interstitialLoadInFlight = false;
    }
  }

  @override
  Future<void> showInterstitialIfEligible({
    required bool isSolo,
    required bool isLearnToPlay,
  }) async {
    try {
      if (!_sdkReady) {
        return;
      }
      if (!AdsEligibility.canShowInterstitial(
        isSolo: isSolo,
        isLearnToPlay: isLearnToPlay,
        canRequestAds: _canRequestAds,
        lastShownAt: _lastInterstitialShownAt,
        now: DateTime.now(),
      )) {
        return;
      }

      final ad = _interstitialAd;
      if (ad == null) {
        preloadInterstitial();
        return;
      }
      _interstitialAd = null;

      final presented = Completer<bool>();
      final dismissed = Completer<void>();

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) {
          if (!presented.isCompleted) {
            presented.complete(true);
          }
        },
        onAdDismissedFullScreenContent: (shownAd) {
          shownAd.dispose();
          if (!presented.isCompleted) {
            presented.complete(true);
          }
          if (!dismissed.isCompleted) {
            dismissed.complete();
          }
        },
        onAdFailedToShowFullScreenContent: (shownAd, error) {
          DebugLogger.debug('Interstitial failed to show: $error');
          shownAd.dispose();
          if (!presented.isCompleted) {
            presented.complete(false);
          }
          if (!dismissed.isCompleted) {
            dismissed.complete();
          }
        },
      );

      await ad.show();

      final didPresent = await presented.future.timeout(
        AdsConfig.interstitialPresentTimeout,
        onTimeout: () => false,
      );
      if (!didPresent) {
        preloadInterstitial();
        return;
      }

      final shownAt = DateTime.now();
      _lastInterstitialShownAt = shownAt;
      await _persistLastShown(shownAt);

      await dismissed.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {},
      );
    } catch (e) {
      DebugLogger.warning('Interstitial show failed: $e');
    } finally {
      preloadInterstitial();
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    try {
      final completer = Completer<void>();
      ConsentForm.showPrivacyOptionsForm((formError) {
        if (formError != null) {
          DebugLogger.warning(
            'Privacy options form error ${formError.errorCode}: '
            '${formError.message}',
          );
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      await completer.future;
      await _refreshConsentFlags();
      if (_canRequestAds && !_sdkReady) {
        await MobileAds.instance.initialize();
        _sdkReady = true;
        preloadInterstitial();
      }
      notifyListeners();
    } catch (e) {
      DebugLogger.warning('Privacy options failed: $e');
    }
  }

  @override
  Widget buildBanner(BuildContext context) {
    if (!isBannerAvailable) {
      return const SizedBox.shrink();
    }
    return _MobileMenuBanner(adUnitId: AdsConfig.bannerUnitId);
  }
}

class _MobileMenuBanner extends StatefulWidget {
  const _MobileMenuBanner({required this.adUnitId});

  final String adUnitId;

  @override
  State<_MobileMenuBanner> createState() => _MobileMenuBannerState();
}

class _MobileMenuBannerState extends State<_MobileMenuBanner> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (_banner != null) {
      return;
    }
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width <= 0) {
      return;
    }
    AdSize? size;
    try {
      size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    } catch (e) {
      DebugLogger.warning('Adaptive banner size failed: $e');
      return;
    }
    if (size == null || !mounted) {
      return;
    }

    final banner = BannerAd(
      adUnitId: widget.adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _banner = ad as BannerAd;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          DebugLogger.debug('Banner failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _loaded = false;
              _banner = null;
            });
          }
        },
      ),
    );
    _banner = banner;
    try {
      await banner.load();
    } catch (e) {
      DebugLogger.warning('Banner load threw: $e');
      banner.dispose();
      _banner = null;
    }
  }

  @override
  void dispose() {
    _banner?.dispose();
    _banner = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (!_loaded || banner == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: banner.size.width.toDouble(),
      height: banner.size.height.toDouble(),
      child: AdWidget(ad: banner),
    );
  }
}
