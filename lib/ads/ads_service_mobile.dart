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
  bool _sdkStarting = false;
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
      await _ensureSdkStarted();
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
    var timedOut = false;

    void finishConsent() {
      if (!completer.isCompleted) {
        completer.complete();
      }
      if (timedOut) {
        unawaited(_applyLateConsent());
      }
    }

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
            finishConsent();
          });
        },
        (FormError error) {
          DebugLogger.warning(
            'UMP consent update failed ${error.errorCode}: ${error.message}',
          );
          finishConsent();
        },
      );
    } catch (e) {
      DebugLogger.warning('UMP consent request failed: $e');
      finishConsent();
    }
    await completer.future.timeout(
      AdsConfig.consentGatherTimeout,
      onTimeout: () {
        timedOut = true;
        DebugLogger.warning('UMP consent timed out');
      },
    );
  }

  Future<void> _applyLateConsent() async {
    try {
      final couldRequest = _canRequestAds;
      final sdkReady = _sdkReady;
      final privacyRequired = _privacyOptionsRequired;
      await _refreshConsentFlags();
      await _ensureSdkStarted();
      if (!_initialized) {
        return;
      }
      if (couldRequest == _canRequestAds &&
          sdkReady == _sdkReady &&
          privacyRequired == _privacyOptionsRequired) {
        return;
      }
      notifyListeners();
    } catch (e) {
      DebugLogger.warning('Late UMP consent handling failed: $e');
    }
  }

  Future<void> _ensureSdkStarted() async {
    if (_sdkReady || _sdkStarting || !_canRequestAds) {
      return;
    }
    _sdkStarting = true;
    try {
      await MobileAds.instance.initialize();
      _sdkReady = true;
      preloadInterstitial();
    } catch (e) {
      DebugLogger.warning('Mobile Ads SDK init failed: $e');
    } finally {
      _sdkStarting = false;
    }
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

      try {
        await Future.any<void>([
          presented.future.then((_) {}),
          dismissed.future,
        ]).timeout(AdsConfig.interstitialDismissTimeout);
      } on TimeoutException {
        preloadInterstitial();
        return;
      }
      final didPresent = presented.isCompleted && await presented.future;
      if (!didPresent) {
        preloadInterstitial();
        return;
      }

      final shownAt = DateTime.now();
      _lastInterstitialShownAt = shownAt;
      await _persistLastShown(shownAt);

      if (!dismissed.isCompleted) {
        await dismissed.future.timeout(
          AdsConfig.interstitialDismissTimeout,
          onTimeout: () {},
        );
      }
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
      await _ensureSdkStarted();
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
    return MobileMenuBanner(adUnitId: AdsConfig.bannerUnitId);
  }
}

/// Test seams so widget tests can skip AdMob platform channels.
@visibleForTesting
class MobileMenuBannerDebug {
  static Future<AdSize?> Function(int width)? resolveSize;
  static Future<void> Function(BannerAd ad)? loadAd;

  static void reset() {
    resolveSize = null;
    loadAd = null;
  }
}

/// Anchored menu banner used by [MobileAdsService.buildBanner].
@visibleForTesting
class MobileMenuBanner extends StatefulWidget {
  const MobileMenuBanner({super.key, required this.adUnitId});

  final String adUnitId;

  @override
  State<MobileMenuBanner> createState() => _MobileMenuBannerState();
}

class _MobileMenuBannerState extends State<MobileMenuBanner> {
  BannerAd? _banner;
  BannerAd? _pendingBanner;
  bool _loaded = false;
  bool _loadInFlight = false;
  int? _loadedWidth;
  int? _pendingWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAd();
  }

  int _currentWidth() => MediaQuery.sizeOf(context).width.truncate();

  void _clearInFlight(BannerAd? ad) {
    if (ad != null && identical(_pendingBanner, ad)) {
      _pendingBanner = null;
    }
    _loadInFlight = false;
    _pendingWidth = null;
  }

  void _disposeLoadedBanner() {
    final old = _banner;
    _banner = null;
    _loaded = false;
    _loadedWidth = null;
    old?.dispose();
  }

  void _reloadIfWidthChanged() {
    if (!mounted) {
      return;
    }
    final width = _currentWidth();
    if (width > 0 && width != _loadedWidth) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    final width = _currentWidth();
    if (width <= 0) {
      return;
    }
    if (_loadInFlight && _pendingWidth == width) {
      return;
    }
    if (_loadInFlight) {
      return;
    }
    if (_banner != null && _loadedWidth == width) {
      return;
    }

    if (_banner != null) {
      _disposeLoadedBanner();
      if (mounted) {
        setState(() {});
      }
    }

    _loadInFlight = true;
    _pendingWidth = width;
    try {
      AdSize? size;
      try {
        final resolveSize = MobileMenuBannerDebug.resolveSize;
        size = resolveSize != null
            ? await resolveSize(width)
            : await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      } catch (e) {
        DebugLogger.warning('Adaptive banner size failed: $e');
        _clearInFlight(null);
        return;
      }
      if (!mounted) {
        _clearInFlight(null);
        return;
      }
      if (size == null) {
        _clearInFlight(null);
        return;
      }

      final requestedWidth = width;
      final banner = BannerAd(
        adUnitId: widget.adUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            final loaded = ad as BannerAd;
            _clearInFlight(loaded);
            if (!mounted) {
              loaded.dispose();
              return;
            }
            if (_currentWidth() != requestedWidth) {
              loaded.dispose();
              _reloadIfWidthChanged();
              return;
            }
            final previous = _banner;
            setState(() {
              _banner = loaded;
              _loaded = true;
              _loadedWidth = requestedWidth;
            });
            if (previous != null && !identical(previous, loaded)) {
              previous.dispose();
            }
          },
          onAdFailedToLoad: (ad, error) {
            DebugLogger.debug('Banner failed to load: $error');
            final failed = ad as BannerAd;
            _clearInFlight(failed);
            failed.dispose();
            if (mounted) {
              setState(() {
                _loaded = false;
                _banner = null;
                _loadedWidth = null;
              });
            }
            if (mounted && _currentWidth() != requestedWidth) {
              _reloadIfWidthChanged();
            }
          },
        ),
      );
      _pendingBanner = banner;
      try {
        final loadAd = MobileMenuBannerDebug.loadAd;
        if (loadAd != null) {
          await loadAd(banner);
        } else {
          await banner.load();
        }
      } catch (e) {
        DebugLogger.warning('Banner load threw: $e');
        banner.dispose();
        _clearInFlight(banner);
        return;
      }
      // load() returning does not mean the load callback ran. Keep
      // _loadInFlight true until onAdLoaded / onAdFailedToLoad.
    } catch (e) {
      DebugLogger.warning('Banner load failed: $e');
      _clearInFlight(null);
    }
  }

  @override
  void dispose() {
    _pendingBanner?.dispose();
    _pendingBanner = null;
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
      child: MobileMenuBannerDebug.loadAd == null
          ? AdWidget(ad: banner)
          : const SizedBox.expand(),
    );
  }
}
