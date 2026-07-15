import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/theme/balatro_theme.dart';
import 'package:hand_foot_game_flutter/widgets/game_hand_display.dart';
import 'package:hand_foot_game_flutter/widgets/playing_card_widget.dart';

void main() {
  // Exact export from session_17841239000980098 (user report: first 8 not
  // highlighted while neighbors glow). Mid-hand 8♣ must keep an in-face
  // playable cue because fan overlap buries outer/side glow.
  const export =
      'eyJ2IjozLCJzIjo5NjM2OTYsImciOnsicCI6MSwidCI6MSwiciI6MSwiYyI6MCwiZiI6ZmFsc2UsImQiOnRydWUsIm0iOmZhbHNlLCJxIjo2MH0sInBsYXllcnMiOlt7ImlkIjoiMSIsIm4iOiJZb3UiLCJ0IjowLCJzYyI6MTAwLCJwZCI6dHJ1ZSwiZnQiOmZhbHNlLCJtZWxkcyI6W3sidCI6MCwiYyI6WyIxMiwyIiwiMTIsMyIsIjEyLDIiXX0seyJ0IjowLCJjIjpbIjEwLDMiLCIxMCwwIiwiMTAsMSJdfSx7InQiOjAsImMiOlsiNywwIiwiNywyIiwiNywwIl19XSwiaCI6WyIzLDAiLCIzLDMiLCIzLDAiLCI0LDEiLCI0LDIiLCI3LDIiLCI3LDMiLCI4LDEiLCI4LDIiLCI5LDMiLCI5LDMiLCIxMSwyIiwiMTEsMCIsIjEyLDAiLCIxMiwyIiwiMCwzIiwiMSwyIiwiMSwxIl0sImYiOlsiNSwyIiwiMTEsMyIsIjksMSIsIjksMSIsIjUsMSIsIjIsMiIsIjAsMSIsIjYsMSIsIjEwLDIiLCI1LDIiLCIxMiwzIl0sInJzaCI6W119LHsiaWQiOiIyIiwibiI6IlN1ZSIsInQiOjEsInNjIjowLCJwZCI6dHJ1ZSwiZnQiOmZhbHNlLCJtZWxkcyI6W3sidCI6MSwiYyI6WyI1LDMiLCI1LDEiLCIxLDEiLCIxMywiLCI1LDMiXX0seyJ0IjoxLCJjIjpbIjExLDAiLCIxMSwzIiwiMTEsMCIsIjEsMSIsIjExLDMiXX0seyJ0IjowLCJjIjpbIjEwLDIiLCIxMCwwIiwiMTAsMiJdfSx7InQiOjAsImMiOlsiNCwyIiwiNCwxIiwiNCwwIiwiNCwzIl19LHsidCI6MCwiYyI6WyI4LDIiLCI4LDEiLCI4LDMiXX1dLCJoIjpbIjYsMiIsIjYsMyIsIjcsMSIsIjEyLDEiLCIwLDMiXSwiZiI6WyI0LDIiLCIxMywiLCIxMywiLCI0LDMiLCIxMSwyIiwiNCwzIiwiOSwzIiwiMCwzIiwiMywzIiwiNCwxIiwiMTAsMyJdLCJyc2giOltdfSx7ImlkIjoiMyIsIm4iOiJDbGFyYSIsInQiOjEsInNjIjowLCJwZCI6dHJ1ZSwiZnQiOnRydWUsIm1lbGRzIjpbeyJ0IjoxLCJjIjpbIjgsMSIsIjgsMyIsIjEsMCIsIjEzLCIsIjgsMCIsIjEsMyJdfSx7InQiOjEsImMiOlsiMTEsMSIsIjExLDEiLCIxLDAiLCIxMywiXX0seyJ0IjoxLCJjIjpbIjYsMCIsIjYsMyIsIjYsMSIsIjEzLCIsIjEsMyJdfSx7InQiOjAsImMiOlsiMCwyIiwiMCwwIiwiMCwwIl19LHsidCI6MSwiYyI6WyI1LDAiLCI1LDIiLCIxLDIiXX1dLCJoIjpbXSwiZiI6WyIzLDEiLCIzLDAiLCIzLDEiLCI1LDAiLCI2LDIiLCI3LDIiLCI5LDAiLCI5LDMiLCIxMCwzIiwiMTAsMiIsIjAsMSJdLCJyc2giOltdfV0sImRlY2siOnsic3oiOjkxLCJzIjo5NjM2OTYsInRvcCI6IjEwLDEifSwiZHAiOlsiNywwIiwiMiwxIiwiNCwwIiwiMiwxIiwiMiwwIiwiNywxIiwiNCwyIiwiMiwwIiwiOCwwIiwiMywyIiwiMiwzIiwiMywxIiwiMiwwIiwiMiwyIiwiOSwwIiwiOSwyIiwiNSwzIiwiOSwwIiwiMiwwIl0sInJhIjpbeyJtIjoi4o+t77iPIGNob3NlIG5vdCB0byBtZWxkIiwicCI6IkNsYXJhIiwidCI6MTc4NDEyNDExMzQ2Nn0seyJtIjoi8J+Xke+4jyBkaXNjYXJkZWQgMTAg4pmjIiwicCI6IkNsYXJhIiwidCI6MTc4NDEyNDExNjQ3OH0seyJtIjoi8J+RoCBwaWNrZWQgdXAgZm9vdCBwaWxlIiwicCI6IkNsYXJhIiwidCI6MTc4NDEyNDExNjQ3OH0seyJtIjoi8J+OryBkcmV3OiBLIOKZoywgNSDimaMiLCJwIjoiWW91IiwidCI6MTc4NDEyNDEyMDM3NH0seyJtIjoi8J+Xke+4jyBkaXNjYXJkZWQgNiDimaAiLCJwIjoiWW91IiwidCI6MTc4NDEyNDEyNzAwN30seyJtIjoi8J+OtCBkcmV3IDIgY2FyZHMgZnJvbSBkZWNrIiwicCI6IlN1ZSIsInQiOjE3ODQxMjQxMjc1MTV9LHsibSI6IvCfk4sgY3JlYXRlZCBuZXcgbWVsZDogOSDimaMsIDkg4pmmLCA5IOKZoCIsInAiOiJTdWUiLCJ0IjoxNzg0MTI0MTI5ODE5fSx7Im0iOiLij63vuI8gY2hvc2Ugbm90IHRvIG1lbGQiLCJwIjoiU3VlIiwidCI6MTc4NDEyNDEzMDYyM30seyJtIjoi8J+Xke+4jyBkaXNjYXJkZWQgMTAg4pmlIiwicCI6IlN1ZSIsInQiOjE3ODQxMjQxMzM2MjZ9LHsibSI6IvCfjrQgZHJldyAyIGNhcmRzIGZyb20gZGVjayIsInAiOiJDbGFyYSIsInQiOjE3ODQxMjQxMzcxMzN9LHsibSI6IuKelSBhZGRlZCAyIOKZoCB0byBleGlzdGluZyBtZWxkIiwicCI6IkNsYXJhIiwidCI6MTc4NDEyNDEzNzEzM30seyJtIjoi8J+Xke+4jyBkaXNjYXJkZWQgMyDimaUiLCJwIjoiQ2xhcmEiLCJ0IjoxNzg0MTI0MTM3MTMzfSx7Im0iOiJjb21wbGV0ZWQgdHVybiB3aXRoIGRpc2NhcmQiLCJwIjoiQ2xhcmEiLCJ0IjoxNzg0MTI0MTM3MTMzfSx7Im0iOiLwn46vIGRyZXc6IDEwIOKZoCwgMiDimaYiLCJwIjoiWW91IiwidCI6MTc4NDEyNDEzODE1OX1dLCJicCI6eyIyIjoiQm90UGVyc29uYWxpdHkuYWRhcHRpdmUiLCIzIjoiQm90UGVyc29uYWxpdHkuY29uc2VydmF0aXZlIn19';

  testWidgets('session mid-hand first 8 keeps in-face playable stripe', (
    tester,
  ) async {
    final result = GameController.fromExportJson(export);
    expect(result, isNotNull);
    final gc = result!.controller;
    final human = gc.gameState.players.first;
    final playable = gc.getPlayableCardIndices(human);

    expect(human.currentHand[5].rank, CardRank.eight);
    expect(human.currentHand[5].suit, Suit.clubs);
    expect(playable.contains(5), isTrue);
    expect(playable.contains(6), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.testTheme,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 200,
            child: GameHandDisplay(
              player: human,
              selectedCardIndices: const [],
              playableCardIndices: playable,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final cards = tester
        .widgetList<PlayingCardWidget>(find.byType(PlayingCardWidget))
        .toList();
    expect(cards, hasLength(human.currentHand.length));
    expect(cards[5].isPlayable, isTrue);
    expect(cards[5].isSelected, isFalse);
    expect(cards[6].isPlayable, isTrue);

    // One in-face stripe per unselected playable card.
    final stripeCount = find
        .byKey(PlayingCardWidget.playableFaceStripeKey)
        .evaluate()
        .length;
    expect(stripeCount, playable.length);

    // With neighbors selected, first 8 stays unselected but still striped.
    await tester.pumpWidget(
      MaterialApp(
        theme: BalatroTheme.testTheme,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 200,
            child: GameHandDisplay(
              player: human,
              selectedCardIndices: const [0, 1, 2, 3, 4, 6, 7, 8],
              playableCardIndices: playable,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final afterSelect = tester
        .widgetList<PlayingCardWidget>(find.byType(PlayingCardWidget))
        .toList();
    expect(afterSelect[5].isSelected, isFalse);
    expect(afterSelect[5].isPlayable, isTrue);
    expect(afterSelect[6].isSelected, isTrue);

    // Selected playable cards drop the stripe; unselected keep it.
    final stripedAfter = find
        .byKey(PlayingCardWidget.playableFaceStripeKey)
        .evaluate()
        .length;
    final selectedPlayable = playable
        .where((i) => const {0, 1, 2, 3, 4, 6, 7, 8}.contains(i))
        .length;
    expect(stripedAfter, playable.length - selectedPlayable);
  }, tags: ['widget']);
}
