import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/game_config.dart';
import 'package:hand_foot_game_flutter/widgets/perfect_grab_mini_game.dart';

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
  });
}
