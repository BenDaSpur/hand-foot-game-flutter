import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/game_config.dart';
import 'package:hand_foot_game_flutter/models/perfect_grab_deal_profile.dart';
import 'package:hand_foot_game_flutter/widgets/card_back_widget.dart';
import 'package:hand_foot_game_flutter/widgets/round_start_mini_game.dart';

const _testDealInterval = Duration(milliseconds: 50);
final _testProfile = PerfectGrabDealProfile.standard();

void _setLargeTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _startPlayingPhase(WidgetTester tester) async {
  await tester.ensureVisible(find.text('GET READY'));
  await tester.tap(find.text('GET READY'));
  await tester.pump();
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> _dealCards(WidgetTester tester, int count) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(_testDealInterval);
  }
}

void main() {
  group('RoundStartMiniGame', () {
    test('pickVariant returns both modes over many rolls', () {
      final random = Random(11);
      final variants = List.generate(
        40,
        (_) => RoundStartMiniGame.pickVariant(random),
      ).toSet();

      expect(variants, contains(RoundStartMiniGameVariant.perfectGrab));
      expect(variants, contains(RoundStartMiniGameVariant.blindGrab));
    });

    testWidgets('show maps blindGrab to hidden counter UI', (tester) async {
      _setLargeTestSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    RoundStartMiniGame.show(
                      context,
                      roundNumber: 2,
                      fixedVariant: RoundStartMiniGameVariant.blindGrab,
                      fixedDealProfile: _testProfile,
                      fixedDealInterval: _testDealInterval,
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Blind Grab'), findsOneWidget);
      expect(find.text('Perfect Grab'), findsNothing);

      await _startPlayingPhase(tester);
      await _dealCards(tester, 10);

      expect(find.text('?'), findsOneWidget);
      expect(find.text('count hidden'), findsOneWidget);
      expect(find.text('10'), findsNothing);
      expect(
        find.byType(CardBackWidget),
        findsNWidgets(GameConfig.perfectGrabBlindModePileCards),
      );
    });

    testWidgets('show maps perfectGrab to visible counter UI', (tester) async {
      _setLargeTestSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    RoundStartMiniGame.show(
                      context,
                      roundNumber: 2,
                      fixedVariant: RoundStartMiniGameVariant.perfectGrab,
                      fixedDealProfile: _testProfile,
                      fixedDealInterval: _testDealInterval,
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Perfect Grab'), findsOneWidget);
      expect(find.text('Blind Grab'), findsNothing);

      await _startPlayingPhase(tester);
      await _dealCards(tester, 10);

      expect(find.text('10'), findsOneWidget);
      expect(find.text('cards grabbed'), findsOneWidget);
      expect(find.text('?'), findsNothing);
      expect(
        find.byType(CardBackWidget),
        findsNWidgets(GameConfig.perfectGrabVisibleCardCap),
      );
    });
  });
}
