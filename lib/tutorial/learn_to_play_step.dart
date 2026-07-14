/// Actions the learner may be asked to perform in a guided step.
enum LearnToPlayAction { continueInfo, draw, meld, discard, complete }

/// Phase of the two-part Learn to Play flow.
enum LearnToPlayPhase { basics, howToWin, complete }

/// One coach step in the Learn to Play curriculum.
class LearnToPlayStep {
  final String id;
  final String title;
  final String coachMessage;
  final LearnToPlayAction requiredAction;
  final LearnToPlayPhase phase;

  const LearnToPlayStep({
    required this.id,
    required this.title,
    required this.coachMessage,
    required this.requiredAction,
    required this.phase,
  });
}
