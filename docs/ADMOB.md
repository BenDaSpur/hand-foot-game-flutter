# AdMob (native iOS / Android)

Hand & Foot shows ads only in **native iOS and Android** builds. Web
(`playhandfoot.com`), the PWA, desktop GitHub releases, Learn to Play, and
in-match multiplayer stay ad-free. `google_mobile_ads` has no Flutter web
implementation; ads code is a no-op on those platforms.

Publisher ID (also in [`web/app-ads.txt`](../web/app-ads.txt)):
`pub-8788020871095245`.

## Ad units to create

In the AdMob console, create **two units per app** (iOS and Android). Skip
Rewarded, Rewarded interstitial, Native advanced, and App open.

| Format | Suggested name | Where it shows |
| --- | --- | --- |
| Interstitial | `solo_round_end_interstitial` | After the solo round scoreboard Continue tap, before Perfect Grab or the winner dialog |
| Banner | `main_menu_banner` | Anchored adaptive banner at the bottom of the main menu |

Banner units are created as **Banner**; adaptive sizing is a request size, not a
separate AdMob format.

Also create a **GDPR** privacy message (and **IDFA / ATT** on iOS) under
Privacy & messaging. UMP will not show a consent form until those messages
exist.

## Test vs production IDs

Debug and profile builds always use Google sample IDs so the AdMob account is
not flagged for invalid traffic.

| Platform | Test app ID | Test interstitial | Test banner |
| --- | --- | --- | --- |
| Android | `ca-app-pub-3940256099942544~3347511713` | `ca-app-pub-3940256099942544/1033173712` | `ca-app-pub-3940256099942544/6300978111` |
| iOS | `ca-app-pub-3940256099942544~1458002511` | `ca-app-pub-3940256099942544/4411468910` | `ca-app-pub-3940256099942544/2934735716` |

Native manifests (`AndroidManifest.xml` `APPLICATION_ID` and iOS
`GADApplicationIdentifier`) default to those test app IDs. Replace them with
your real app IDs before a store release, or the SDK will not serve production
ads.

Release Dart unit IDs are Google test IDs until you pass production values:

```bash
flutter build apk --release \
  --dart-define=ADMOB_ANDROID_INTERSTITIAL_ID=ca-app-pub-8788020871095245/YOUR_INT \
  --dart-define=ADMOB_ANDROID_BANNER_ID=ca-app-pub-8788020871095245/YOUR_BANNER

flutter build ipa --release \
  --dart-define=ADMOB_IOS_INTERSTITIAL_ID=ca-app-pub-8788020871095245/YOUR_INT \
  --dart-define=ADMOB_IOS_BANNER_ID=ca-app-pub-8788020871095245/YOUR_BANNER
```

Android app ID override at Gradle time:

```bash
./gradlew assembleRelease -PADMOB_ANDROID_APP_ID=ca-app-pub-8788020871095245~YOUR_APP
```

iOS app ID: set `GADApplicationIdentifier` in `ios/Runner/Info.plist` (or
`ADMOB_IOS_APP_ID` in `ios/Flutter/AdMob.xcconfig`).

AdMob app and unit IDs are public in the binary. Do not put them in `.env`.

## Placement rules (implemented)

- Interstitial: solo `GameScreen` only, after `ScoreboardModal` Continue.
- Banner: `MainMenuScreen` only.
- Never during `GamePhase.playing`, Learn to Play, or multiplayer matches.
- Skip the interstitial if one is not already loaded, consent is missing, or
  the last interstitial was less than two minutes ago.
- Fail open: a missing or slow ad never blocks the next round.
