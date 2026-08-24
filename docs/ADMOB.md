# AdMob (native iOS / Android)

Hand & Foot shows ads only in **native iOS and Android** builds. Web
(`playhandfoot.com`), the PWA, desktop GitHub releases, Learn to Play, and
in-match multiplayer stay ad-free. `google_mobile_ads` has no Flutter web
implementation; ads code is a no-op on those platforms.

Publisher ID (also in [`web/app-ads.txt`](../web/app-ads.txt)):
`pub-8788020871095245`.

## Production ad units

These units are compiled into release builds (`lib/ads/ads_config.dart`).
Skip Rewarded, Rewarded interstitial, Native advanced, and App open.

| Format | Name | Unit ID | Where it shows |
| --- | --- | --- | --- |
| Interstitial | `solo_round_end_interstitial` | `ca-app-pub-8788020871095245/2472333204` | After the solo round scoreboard Continue tap, before Perfect Grab or the winner dialog |
| Banner | `main_menu_banner` | `ca-app-pub-8788020871095245/7317465770` | Anchored adaptive banner at the bottom of the main menu |

Banner units are created as **Banner**; adaptive sizing is a request size, not a
separate AdMob format.

Also create a **GDPR** privacy message (and **IDFA / ATT** on iOS) under
Privacy & messaging. Set the privacy-policy URL to
https://playhandfoot.com/privacy.html. UMP will not show a consent form until
those messages exist.

## Test vs production IDs

Debug and profile builds always use Google sample IDs so the AdMob account is
not flagged for invalid traffic.

| Platform | Test app ID | Test interstitial | Test banner |
| --- | --- | --- | --- |
| Android | `ca-app-pub-3940256099942544~3347511713` | `ca-app-pub-3940256099942544/1033173712` | `ca-app-pub-3940256099942544/6300978111` |
| iOS | `ca-app-pub-3940256099942544~1458002511` | `ca-app-pub-3940256099942544/4411468910` | `ca-app-pub-3940256099942544/2934735716` |

Android sets `com.google.android.gms.ads.APPLICATION_ID` in
`AndroidManifest.xml` from the Gradle property `ADMOB_ANDROID_APP_ID`. iOS
sets `GADApplicationIdentifier` from `ADMOB_IOS_APP_ID`. Debug and profile
default to Google sample app IDs. Release builds require a real app ID
(`-PADMOB_ANDROID_APP_ID=...` / `ADMOB_IOS_APP_ID=...`), or the SDK will not
serve production ads.

Release Dart builds use the production unit IDs above. Override per platform
only if you later create separate Android/iOS units:

```bash
flutter build apk --release \
  --dart-define=ADMOB_ANDROID_INTERSTITIAL_ID=ca-app-pub-8788020871095245/OTHER_INT \
  --dart-define=ADMOB_ANDROID_BANNER_ID=ca-app-pub-8788020871095245/OTHER_BANNER

flutter build ipa --release \
  --dart-define=ADMOB_IOS_INTERSTITIAL_ID=ca-app-pub-8788020871095245/OTHER_INT \
  --dart-define=ADMOB_IOS_BANNER_ID=ca-app-pub-8788020871095245/OTHER_BANNER
```

Android app ID override at Gradle time (required for release):

```bash
./gradlew assembleRelease -PADMOB_ANDROID_APP_ID=ca-app-pub-8788020871095245~YOUR_APP
```

Store CI can set the same value as secret `ADMOB_ANDROID_APP_ID` (`ORG_GRADLE_PROJECT_ADMOB_ANDROID_APP_ID`). Debug/profile keep the Google sample app ID if the property is omitted.

iOS app ID: `Info.plist` reads `GADApplicationIdentifier` from
`ADMOB_IOS_APP_ID`. Debug and profile set the Google sample ID via
`ios/Flutter/AdMob.xcconfig`. Release archives do not include that fallback —
pass a real `ADMOB_IOS_APP_ID` to `xcodebuild` or set it in the Release
configuration.

AdMob app and unit IDs are public in the binary. Do not put them in `.env`.

## Placement rules (implemented)

- Interstitial: solo `GameScreen` only, after `ScoreboardModal` Continue.
- Banner: `MainMenuScreen` only.
- Never during `GamePhase.playing`, Learn to Play, or multiplayer matches.
- Skip the interstitial if one is not already loaded, consent is missing, or
  the last interstitial was less than two minutes ago.
- Fail open: a missing or slow ad never blocks the next round.
