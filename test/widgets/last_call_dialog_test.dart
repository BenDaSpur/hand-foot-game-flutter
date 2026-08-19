import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/game_action_feedback.dart';
import 'package:hand_foot_game_flutter/widgets/last_call_banner.dart';
import 'package:hand_foot_game_flutter/widgets/last_call_dialog.dart';

void main() {
  testWidgets('empty-deck last call tells the local player to dump cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                LastCallDialog.showEmptyDeck(context, isLocalPlayerTurn: true);
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text(GameActionFeedback.lastCallTitle), findsOneWidget);
    expect(find.textContaining('last turn of the round'), findsOneWidget);
    expect(find.text('Play Cards'), findsOneWidget);
    expect(find.textContaining('insufficient cards'), findsNothing);
  }, tags: ['widget']);

  testWidgets(
    'stalemate warning is distinct from the empty-deck last call',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  LastCallDialog.showStalemateWarning(context);
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.text(GameActionFeedback.stalemateWarningTitle),
        findsOneWidget,
      );
      expect(
        find.textContaining('Only 3s are being discarded'),
        findsOneWidget,
      );
      expect(find.text(GameActionFeedback.lastCallTitle), findsNothing);
      expect(find.textContaining('insufficient cards'), findsNothing);
    },
    tags: ['widget'],
  );

  testWidgets(
    'last-call banner stays visible after the modal is dismissed',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LastCallBanner(isLocalPlayerTurn: true)),
        ),
      );

      expect(
        find.text(
          GameActionFeedback.lastCallBannerHeadline(isLocalPlayerTurn: true),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Deck is empty'), findsOneWidget);
    },
    tags: ['widget'],
  );
}
