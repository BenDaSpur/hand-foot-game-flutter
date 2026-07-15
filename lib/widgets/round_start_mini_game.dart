import 'dart:math';

import 'package:flutter/material.dart';

import '../models/perfect_grab_deal_profile.dart';
import 'perfect_grab_mini_game.dart';

enum RoundStartMiniGameVariant { perfectGrab, blindGrab }

/// Picks and shows the round-start timing mini-game.
class RoundStartMiniGame {
  RoundStartMiniGame._();

  @visibleForTesting
  static RoundStartMiniGameVariant pickVariant(Random random) {
    return random.nextDouble() < 0.55
        ? RoundStartMiniGameVariant.perfectGrab
        : RoundStartMiniGameVariant.blindGrab;
  }

  static Future<bool> show(
    BuildContext context, {
    required int roundNumber,
    PerfectGrabDealProfile? fixedDealProfile,
    RoundStartMiniGameVariant? fixedVariant,
    Duration? fixedDealInterval,
  }) {
    final random = Random();
    final profile = fixedDealProfile ?? PerfectGrabDealProfile.random(random);
    final variant = fixedVariant ?? pickVariant(random);
    final hideCounter = variant == RoundStartMiniGameVariant.blindGrab;

    return PerfectGrabMiniGame.show(
      context,
      roundNumber: roundNumber,
      dealProfile: profile,
      hideCounter: hideCounter,
      title: hideCounter ? 'Blind Grab' : 'Perfect Grab',
      fixedDealInterval: fixedDealInterval,
    );
  }
}
