import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/tutorial/learn_to_play_session.dart';

void main() {
  test('session starts at draw with scripted play-down hand', () {
    final session = LearnToPlaySession.create();
    expect(session.controller.gameState.turnPhase, TurnPhase.draw);
    expect(session.human.hand.length, 7);

    final kings = session.human.hand
        .where((c) => c.rank == CardRank.king)
        .toList();
    expect(kings.length, 6);

    final points = kings.fold<int>(0, (sum, c) => sum + c.pointValue);
    expect(points, 60);
  });

  test('normalizeHandAfterDraw restores teachable king meld', () {
    final session = LearnToPlaySession.create();
    expect(session.controller.drawFromDeck(), isTrue);
    session.normalizeHandAfterDraw();
    expect(session.kingIndicesInHand().length, 6);
    expect(session.discardTargetIndex(), isNotNull);
  });

  test('scripted meld and discard picks up the foot', () {
    final session = LearnToPlaySession.create();
    expect(session.controller.drawFromDeck(), isTrue);
    session.normalizeHandAfterDraw();

    final kings = session.kingIndicesInHand();
    expect(session.controller.createMeldByIndices(kings), isTrue);
    expect(session.human.hasPlayedDown, isTrue);
    expect(session.human.hand.length, 1);

    final discardIndex = session.discardTargetIndex();
    expect(discardIndex, isNotNull);
    final card = session.human.currentHand[discardIndex!];
    expect(session.controller.discardCard(card), isTrue);
    expect(session.human.hasPickedUpFoot, isTrue);
  });
}
