import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/widgets/turn_timer.dart';

void main() {
  const turnDurationSeconds = 5;

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('TurnTimer', () {
    testWidgets('expires after the configured duration', (tester) async {
      var timedOut = false;

      await tester.pumpWidget(
        wrap(
          TurnTimer(
            turnDurationSeconds: turnDurationSeconds,
            onTimeUp: () => timedOut = true,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: turnDurationSeconds));
      expect(timedOut, isTrue);
    });

    testWidgets('does not expire while paused', (tester) async {
      var timedOut = false;

      Widget buildTimer({required bool isPaused}) {
        return wrap(
          TurnTimer(
            turnDurationSeconds: turnDurationSeconds,
            isPaused: isPaused,
            onTimeUp: () => timedOut = true,
          ),
        );
      }

      await tester.pumpWidget(buildTimer(isPaused: false));
      await tester.pump(const Duration(seconds: 3));
      expect(timedOut, isFalse);

      // Pausing (for example while the meld modal is open) holds the clock.
      await tester.pumpWidget(buildTimer(isPaused: true));
      await tester.pump(const Duration(seconds: 30));
      expect(timedOut, isFalse);

      // Resuming continues from the remaining time rather than restarting.
      await tester.pumpWidget(buildTimer(isPaused: false));
      await tester.pump(const Duration(seconds: 2));
      expect(timedOut, isTrue);
    });

    testWidgets('resumes on its own once the pause cap expires', (
      tester,
    ) async {
      const maxPauseSeconds = 4;
      var timedOut = false;

      await tester.pumpWidget(
        wrap(
          TurnTimer(
            turnDurationSeconds: turnDurationSeconds,
            isPaused: true,
            maxPauseSeconds: maxPauseSeconds,
            onTimeUp: () => timedOut = true,
          ),
        ),
      );

      // Still paused: nothing has been consumed yet.
      await tester.pump(const Duration(seconds: maxPauseSeconds - 1));
      expect(timedOut, isFalse);
      expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);

      // The cap fires and the countdown restarts even though isPaused is
      // still set, so an abandoned modal cannot stall the turn forever.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.timer), findsOneWidget);

      await tester.pump(const Duration(seconds: turnDurationSeconds));
      expect(timedOut, isTrue);
    });

    testWidgets('a pause shorter than the cap still holds the clock', (
      tester,
    ) async {
      const maxPauseSeconds = 60;
      var timedOut = false;

      Widget buildTimer({required bool isPaused}) {
        return wrap(
          TurnTimer(
            turnDurationSeconds: turnDurationSeconds,
            isPaused: isPaused,
            maxPauseSeconds: maxPauseSeconds,
            onTimeUp: () => timedOut = true,
          ),
        );
      }

      await tester.pumpWidget(buildTimer(isPaused: false));
      await tester.pump(const Duration(seconds: 3));

      await tester.pumpWidget(buildTimer(isPaused: true));
      await tester.pump(const Duration(seconds: maxPauseSeconds - 1));
      expect(timedOut, isFalse);

      await tester.pumpWidget(buildTimer(isPaused: false));
      await tester.pump(const Duration(seconds: 2));
      expect(timedOut, isTrue);
    });

    testWidgets('shows a paused indicator while paused', (tester) async {
      await tester.pumpWidget(
        wrap(
          const TurnTimer(
            turnDurationSeconds: turnDurationSeconds,
            isPaused: true,
          ),
        ),
      );

      expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.timer), findsNothing);
    });

    testWidgets('renders nothing when inactive', (tester) async {
      await tester.pumpWidget(
        wrap(
          const TurnTimer(
            turnDurationSeconds: turnDurationSeconds,
            isActive: false,
          ),
        ),
      );

      expect(find.byIcon(Icons.timer), findsNothing);
    });
  });
}
