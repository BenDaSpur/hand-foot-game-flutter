import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/game_config.dart';
import 'package:hand_foot_game_flutter/widgets/perfect_grab_mini_game.dart';

const _testDealInterval = Duration(milliseconds: 50);
const _resultDismissDelay = Duration(milliseconds: 2200);

Future<void> _startPlayingPhase(WidgetTester tester) async {
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

Future<void> _dismissResult(WidgetTester tester) async {
  await tester.pump(_resultDismissDelay);
  await tester.pump();
}

void main() {
  group('PerfectGrabMiniGame', () {
    testWidgets('shows intro and can be skipped without bonus', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await PerfectGrabMiniGame.show(
                      context,
                      roundNumber: 2,
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
      expect(
        find.textContaining('grab exactly ${GameConfig.perfectGrabTarget}'),
        findsOneWidget,
      );
      expect(find.text('GET READY'), findsOneWidget);
      expect(find.text('GRAB!'), findsNothing);

      await tester.tap(find.text('Skip (no bonus)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(result, isFalse);
    });

    testWidgets('enters playing phase with GRAB button after countdown', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PerfectGrabMiniGame(
            roundNumber: 1,
            fixedDealInterval: _testDealInterval,
            onComplete: (_) {},
          ),
        ),
      );

      await _startPlayingPhase(tester);

      expect(find.text('GRAB!'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('cards grabbed'), findsOneWidget);
    });

    testWidgets('exact-target grab returns true', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: PerfectGrabMiniGame(
            roundNumber: 1,
            fixedDealInterval: _testDealInterval,
            onComplete: (earnedBonus) {
              result = earnedBonus;
            },
          ),
        ),
      );

      await _startPlayingPhase(tester);
      await _dealCards(tester, GameConfig.perfectGrabTarget);

      expect(find.text('${GameConfig.perfectGrabTarget}'), findsOneWidget);

      await tester.tap(find.text('GRAB!'));
      await tester.pump();

      expect(find.text('Perfect Grab!'), findsOneWidget);
      expect(
        find.textContaining('+${GameConfig.perfectGrabBonus}'),
        findsOneWidget,
      );

      await _dismissResult(tester);
      expect(result, isTrue);
    });

    testWidgets('forced max-card path returns false', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: PerfectGrabMiniGame(
            roundNumber: 1,
            fixedDealInterval: _testDealInterval,
            onComplete: (earnedBonus) {
              result = earnedBonus;
            },
          ),
        ),
      );

      await _startPlayingPhase(tester);
      await _dealCards(tester, 34);

      expect(find.text('So Close...'), findsOneWidget);
      expect(find.textContaining('Need exactly'), findsOneWidget);

      await _dismissResult(tester);
      expect(result, isFalse);
    });
  });
}
