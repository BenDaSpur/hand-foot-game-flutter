import 'learn_to_play_curriculum.dart';
import 'learn_to_play_step.dart';

/// Advances through [LearnToPlayCurriculum] when the correct action occurs.
class LearnToPlayCoordinator {
  int _stepIndex = 0;

  int get stepIndex => _stepIndex;

  LearnToPlayStep get currentStep => LearnToPlayCurriculum.steps[_stepIndex];

  bool get isComplete => currentStep.phase == LearnToPlayPhase.complete;

  bool get isInfoStep =>
      currentStep.requiredAction == LearnToPlayAction.continueInfo;

  bool canPerform(LearnToPlayAction action) {
    if (isComplete && action != LearnToPlayAction.complete) {
      return false;
    }
    return currentStep.requiredAction == action;
  }

  /// Advances when [action] matches the current step. Returns true if advanced.
  bool advanceOn(LearnToPlayAction action) {
    if (!canPerform(action)) {
      return false;
    }
    if (_stepIndex < LearnToPlayCurriculum.steps.length - 1) {
      _stepIndex++;
      return true;
    }
    return false;
  }

  double get progress {
    final total = LearnToPlayCurriculum.steps.length;
    if (total <= 1) {
      return 1;
    }
    return _stepIndex / (total - 1);
  }
}
