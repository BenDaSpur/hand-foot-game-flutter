import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ads/ads_eligibility.dart';

void main() {
  final now = DateTime.utc(2026, 8, 21, 12);

  test('allows a solo interstitial when consent and cooldown are clear', () {
    expect(
      AdsEligibility.canShowInterstitial(
        isSolo: true,
        isLearnToPlay: false,
        canRequestAds: true,
        lastShownAt: null,
        now: now,
      ),
      isTrue,
    );
  });

  test('skips Learn to Play', () {
    expect(
      AdsEligibility.canShowInterstitial(
        isSolo: true,
        isLearnToPlay: true,
        canRequestAds: true,
        lastShownAt: null,
        now: now,
      ),
      isFalse,
    );
  });

  test('skips multiplayer / non-solo', () {
    expect(
      AdsEligibility.canShowInterstitial(
        isSolo: false,
        isLearnToPlay: false,
        canRequestAds: true,
        lastShownAt: null,
        now: now,
      ),
      isFalse,
    );
  });

  test('skips when consent does not allow ads', () {
    expect(
      AdsEligibility.canShowInterstitial(
        isSolo: true,
        isLearnToPlay: false,
        canRequestAds: false,
        lastShownAt: null,
        now: now,
      ),
      isFalse,
    );
  });

  test('skips inside the two-minute cooldown', () {
    expect(
      AdsEligibility.canShowInterstitial(
        isSolo: true,
        isLearnToPlay: false,
        canRequestAds: true,
        lastShownAt: now.subtract(const Duration(seconds: 90)),
        now: now,
      ),
      isFalse,
    );
  });

  test('allows after the two-minute cooldown', () {
    expect(
      AdsEligibility.canShowInterstitial(
        isSolo: true,
        isLearnToPlay: false,
        canRequestAds: true,
        lastShownAt: now.subtract(const Duration(minutes: 2)),
        now: now,
      ),
      isTrue,
    );
  });
}
