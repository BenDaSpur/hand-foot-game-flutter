import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/widgets/emergency_round_end_dialog.dart';

void main() {
  testWidgets('stalemate copy is distinct from an empty-deck go-out', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                EmergencyRoundEndDialog.show(
                  context,
                  reason: EmergencyRoundEndReason.stalemate,
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Round Ended'), findsOneWidget);
    expect(find.textContaining('could only discard 3s'), findsOneWidget);
    expect(find.textContaining('went out'), findsNothing);
    expect(find.textContaining('insufficient cards'), findsNothing);
  });

  testWidgets('empty-deck copy is distinct from a 3s stalemate', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                EmergencyRoundEndDialog.show(
                  context,
                  reason: EmergencyRoundEndReason.insufficientCards,
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Round Ended'), findsOneWidget);
    expect(find.textContaining('insufficient cards'), findsOneWidget);
    expect(find.textContaining('could only discard 3s'), findsNothing);
    expect(find.textContaining('went out'), findsNothing);
  });
}
