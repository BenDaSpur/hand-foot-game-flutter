import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/widgets/final_turn_banner.dart';

void main() {
  group('FinalTurnBanner', () {
    late GameState gameState;
    late Player human;
    late Player bot;

    setUp(() {
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bot = Player(id: 'bot', name: 'Bot 1', type: PlayerType.bot);
      gameState = GameState(
        players: [human, bot],
        deck: Deck.createHandAndFootDeck(2),
      );
    });

    testWidgets('hidden when final turn phase is inactive', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FinalTurnBanner(gameState: gameState)),
        ),
      );

      expect(find.text('YOUR FINAL TURN'), findsNothing);
      expect(find.text('FINAL TURNS IN PROGRESS'), findsNothing);
    });

    testWidgets('shows urgent message for local player final turn', (
      tester,
    ) async {
      gameState.finalTurnPhaseActive = true;
      gameState.playerWhoWentOutIndex = 1;
      gameState.playersAwaitingFinalTurn.add(0);
      gameState.currentPlayerIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinalTurnBanner(
              gameState: gameState,
              localPlayerId: human.id,
            ),
          ),
        ),
      );

      expect(find.text('YOUR FINAL TURN'), findsOneWidget);
      expect(find.textContaining('Bot 1 went out'), findsOneWidget);
      expect(find.textContaining('Meld every card you can'), findsOneWidget);
    });

    testWidgets('shows waiting message when local player already went out', (
      tester,
    ) async {
      gameState.finalTurnPhaseActive = true;
      gameState.playerWhoWentOutIndex = 0;
      gameState.playersAwaitingFinalTurn.add(1);
      gameState.currentPlayerIndex = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FinalTurnBanner(
              gameState: gameState,
              localPlayerId: human.id,
            ),
          ),
        ),
      );

      expect(find.text('FINAL TURNS IN PROGRESS'), findsOneWidget);
      expect(find.textContaining('You went out'), findsOneWidget);
      expect(find.textContaining('1 remaining'), findsOneWidget);
    });
  });
}
