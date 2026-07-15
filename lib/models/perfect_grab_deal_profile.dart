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
      baseDealIntervalMs: GameConfig.perfectGrabStandardBaseDealIntervalMs,
      minDealIntervalMs: GameConfig.perfectGrabStandardMinDealIntervalMs,
      intervalStepMs: GameConfig.perfectGrabStandardIntervalStepMs,
      jitterMs: GameConfig.perfectGrabStandardJitterMs,
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
      baseDealIntervalMs:
          GameConfig.perfectGrabRandomBaseDealIntervalMinMs +
          random.nextInt(GameConfig.perfectGrabRandomBaseDealIntervalRangeMs),
      minDealIntervalMs:
          GameConfig.perfectGrabRandomMinDealIntervalMinMs +
          random.nextInt(GameConfig.perfectGrabRandomMinDealIntervalRangeMs),
      intervalStepMs:
          GameConfig.perfectGrabRandomIntervalStepMinMs +
          random.nextInt(GameConfig.perfectGrabRandomIntervalStepRangeMs),
      jitterMs:
          GameConfig.perfectGrabRandomJitterMinMs +
          random.nextInt(GameConfig.perfectGrabRandomJitterRangeMs),
      stutterBeforeCard: _randomStutters(random, target),
    );
  }

  static Set<int> _randomStutters(Random random, int target) {
    final stutterCount = random.nextInt(GameConfig.perfectGrabMaxStutters + 1);
    final stutters = <int>{};
    while (stutters.length < stutterCount) {
      final cardIndex =
          GameConfig.perfectGrabMinStutterCardIndex +
          random.nextInt(
            max(1, target - GameConfig.perfectGrabMinStutterCardIndex),
          );
      stutters.add(cardIndex);
    }
    return stutters;
  }

  int get maxCards => min(
    GameConfig.perfectGrabMaxCardsCap,
    target + GameConfig.perfectGrabMaxCardsAboveTarget,
  );

  Duration dealIntervalForCard(int nextCardIndex, Random random) {
    final baseMs = max(
      minDealIntervalMs,
      baseDealIntervalMs - ((nextCardIndex - 1) * intervalStepMs),
    );
    final jitter = random.nextInt(jitterMs * 2 + 1) - jitterMs;
    return Duration(
      milliseconds: max(
        GameConfig.perfectGrabDealIntervalFloorMs,
        baseMs + jitter,
      ),
    );
  }

  Duration stutterDelay(Random random) {
    return Duration(
      milliseconds:
          GameConfig.perfectGrabStutterDelayMinMs +
          random.nextInt(GameConfig.perfectGrabStutterDelayRangeMs),
    );
  }
}
