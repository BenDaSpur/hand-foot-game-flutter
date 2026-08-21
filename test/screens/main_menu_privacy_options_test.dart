import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ads/ads_service.dart';
import 'package:hand_foot_game_flutter/screens/main_menu_screen.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';

class _FakeAdsService extends NoOpAdsService {
  _FakeAdsService({required this.privacyOptionsRequired});

  final bool privacyOptionsRequired;
  int privacyOptionsShown = 0;

  @override
  bool get shouldShowPrivacyOptions => privacyOptionsRequired;

  @override
  Future<void> showPrivacyOptions() async {
    privacyOptionsShown++;
  }
}

void main() {
  tearDown(AdsService.debugReset);

  testWidgets('hides Privacy options when UMP does not require it', (
    tester,
  ) async {
    AdsService.instance = _FakeAdsService(privacyOptionsRequired: false);

    await tester.pumpWidget(
      MaterialApp(theme: BalatroTheme.testTheme, home: const MainMenuScreen()),
    );
    await tester.pump();

    expect(find.text('Privacy options'), findsNothing);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets('Privacy options on the menu opens the UMP form hook', (
    tester,
  ) async {
    final ads = _FakeAdsService(privacyOptionsRequired: true);
    AdsService.instance = ads;

    await tester.pumpWidget(
      MaterialApp(theme: BalatroTheme.testTheme, home: const MainMenuScreen()),
    );
    await tester.pump();

    final options = find.text('Privacy options');
    expect(options, findsOneWidget);
    await tester.ensureVisible(options);
    await tester.pumpAndSettle();
    await tester.tap(options);
    await tester.pump();

    expect(ads.privacyOptionsShown, 1);
  });
}
