import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/tutorial/learn_to_play_coordinator.dart';
import 'package:hand_foot_game_flutter/tutorial/learn_to_play_step.dart';

void main() {
  test('starts on welcome continue step', () {
    final coordinator = LearnToPlayCoordinator();
    expect(coordinator.currentStep.id, 'welcome');
    expect(coordinator.canPerform(LearnToPlayAction.continueInfo), isTrue);
    expect(coordinator.canPerform(LearnToPlayAction.draw), isFalse);
  });

  test('wrong action does not advance', () {
    final coordinator = LearnToPlayCoordinator();
    expect(coordinator.advanceOn(LearnToPlayAction.draw), isFalse);
    expect(coordinator.currentStep.id, 'welcome');
  });

  test('advances through basics into how-to-win then complete', () {
    final coordinator = LearnToPlayCoordinator();

    expect(coordinator.advanceOn(LearnToPlayAction.continueInfo), isTrue);
    expect(coordinator.currentStep.id, 'draw');
    expect(coordinator.advanceOn(LearnToPlayAction.draw), isTrue);
    expect(coordinator.currentStep.id, 'meld');
    expect(coordinator.advanceOn(LearnToPlayAction.meld), isTrue);
    expect(coordinator.currentStep.id, 'discard');
    expect(coordinator.advanceOn(LearnToPlayAction.discard), isTrue);
    expect(coordinator.currentStep.id, 'foot');
    expect(coordinator.currentStep.phase, LearnToPlayPhase.basics);

    expect(coordinator.advanceOn(LearnToPlayAction.continueInfo), isTrue);
    expect(coordinator.currentStep.phase, LearnToPlayPhase.howToWin);

    // clean, dirty, going_out, tips
    for (var i = 0; i < 4; i++) {
      expect(coordinator.advanceOn(LearnToPlayAction.continueInfo), isTrue);
    }
    expect(coordinator.currentStep.id, 'done');
    expect(coordinator.isComplete, isTrue);
  });
}
