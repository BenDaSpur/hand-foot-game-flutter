import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ads/ads_banner.dart';
import 'package:hand_foot_game_flutter/ads/ads_service.dart';

void main() {
  tearDown(AdsService.debugReset);

  testWidgets('AdsBanner shrinks when ads are unavailable', (tester) async {
    AdsService.instance = NoOpAdsService();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AdsBanner())),
    );
    await tester.pump();

    final size = tester.getSize(find.byType(AdsBanner));
    expect(size.height, 0);
    expect(size.width, 0);
  });
}
