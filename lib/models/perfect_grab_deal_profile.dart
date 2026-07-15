import 'dart:math';

import '../config/game_config.dart';

/// Randomized deal timing for the perfect-grab mini-game.
///
/// Each round uses a different target count and acceleration curve so players
/// cannot rely on memorized timing from prior attempts.
class PerfectGrabDealProfile {
  final int target;
  final int baseDealIntervalMs;
  final int minDealIntervalMs;
  final int intervalStepMs;
  final int jitterMs;
  final Set<int> stutterBeforeCard;

  const PerfectGrabDealProfile({
    required this.target,
    required this.baseDealIntervalMs,
    required this.minDealIntervalMs,
    required this.intervalStepMs,
    required this.jitterMs,
    this.stutterBeforeCard = const {},
  });

  /// Default profile used in tests and as a stable fallback.
  factory PerfectGrabDealProfile.standard() {
    return const PerfectGrabDealProfile(
      target: GameConfig.perfectGrabTarget,
      baseDealIntervalMs: 340,
      minDealIntervalMs: 72,
      intervalStepMs: 11,
      jitterMs: 45,
    );
  }

  factory PerfectGrabDealProfile.random(Random random) {
    final target =
        GameConfig.perfectGrabTargetMin +
        random.nextInt(
          GameConfig.perfectGrabTargetMax - GameConfig.perfectGrabTargetMin + 1,
        );

    return PerfectGrabDealProfile(
      target: target,
      baseDealIntervalMs: 270 + random.nextInt(120),
      minDealIntervalMs: 58 + random.nextInt(35),
      intervalStepMs: 8 + random.nextInt(8),
      jitterMs: 55 + random.nextInt(45),
      stutterBeforeCard: _randomStutters(random, target),
    );
  }

  static Set<int> _randomStutters(Random random, int target) {
    final stutterCount = random.nextInt(3);
    final stutters = <int>{};
    while (stutters.length < stutterCount) {
      final cardIndex = 3 + random.nextInt(max(1, target - 3));
      stutters.add(cardIndex);
    }
    return stutters;
  }

  int get maxCards => min(34, target + 10);

  Duration dealIntervalForCard(int nextCardIndex, Random random) {
    final baseMs = max(
      minDealIntervalMs,
      baseDealIntervalMs - ((nextCardIndex - 1) * intervalStepMs),
    );
    final jitter = random.nextInt(jitterMs * 2 + 1) - jitterMs;
    return Duration(milliseconds: max(55, baseMs + jitter));
  }

  Duration stutterDelay(Random random) {
    return Duration(milliseconds: 120 + random.nextInt(180));
  }
}
