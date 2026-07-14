import 'learn_to_play_step.dart';

/// Ordered curriculum for Learn to Play (basics → how-to-win → complete).
abstract final class LearnToPlayCurriculum {
  static const List<LearnToPlayStep> steps = [
    LearnToPlayStep(
      id: 'welcome',
      title: 'Welcome',
      coachMessage:
          'You play with a Hand and a Foot (11 cards each). '
          'Melds are 3+ cards of the same rank. Follow each tip and tap the highlighted control.',
      requiredAction: LearnToPlayAction.continueInfo,
      phase: LearnToPlayPhase.basics,
    ),
    LearnToPlayStep(
      id: 'draw',
      title: 'Draw',
      coachMessage:
          'Every turn starts by drawing 2 cards from the deck. Tap Draw from deck.',
      requiredAction: LearnToPlayAction.draw,
      phase: LearnToPlayPhase.basics,
    ),
    LearnToPlayStep(
      id: 'meld',
      title: 'Play down',
      coachMessage:
          'Tap Play Cards to open the meld selector. Group your Kings into a '
          'meld worth at least 60 points for Round 1, then confirm.',
      requiredAction: LearnToPlayAction.meld,
      phase: LearnToPlayPhase.basics,
    ),
    LearnToPlayStep(
      id: 'discard',
      title: 'Discard',
      coachMessage:
          'End your turn by discarding one card. Select the highlighted card and tap Discard. '
          'Emptying your Hand picks up your Foot.',
      requiredAction: LearnToPlayAction.discard,
      phase: LearnToPlayPhase.basics,
    ),
    LearnToPlayStep(
      id: 'foot',
      title: 'The Foot',
      coachMessage:
          'Nice — you picked up your Foot. Keep playing until both books and an empty Foot let you go out.',
      requiredAction: LearnToPlayAction.continueInfo,
      phase: LearnToPlayPhase.basics,
    ),
    LearnToPlayStep(
      id: 'clean_book',
      title: 'Clean books',
      coachMessage:
          'A clean book is 7+ natural cards of one rank (no wilds). Clean books score a big bonus.',
      requiredAction: LearnToPlayAction.continueInfo,
      phase: LearnToPlayPhase.howToWin,
    ),
    LearnToPlayStep(
      id: 'dirty_book',
      title: 'Dirty books',
      coachMessage:
          'A dirty book is 7+ cards of one rank that include wilds (2s or Jokers). '
          'You need both a clean and a dirty book to go out.',
      requiredAction: LearnToPlayAction.continueInfo,
      phase: LearnToPlayPhase.howToWin,
    ),
    LearnToPlayStep(
      id: 'going_out',
      title: 'Going out',
      coachMessage:
          'To go out: play from your Foot, finish both book types, and discard your last card. '
          'Going out ends the round and scores a bonus.',
      requiredAction: LearnToPlayAction.continueInfo,
      phase: LearnToPlayPhase.howToWin,
    ),
    LearnToPlayStep(
      id: 'tips',
      title: 'Winning tips',
      coachMessage:
          'Save unlock potential, dump 3s when entering the Foot, and race books late. '
          'You are ready to try a real game!',
      requiredAction: LearnToPlayAction.continueInfo,
      phase: LearnToPlayPhase.howToWin,
    ),
    LearnToPlayStep(
      id: 'done',
      title: 'Lesson complete',
      coachMessage: 'Great job — you finished Learn to Play.',
      requiredAction: LearnToPlayAction.complete,
      phase: LearnToPlayPhase.complete,
    ),
  ];
}
