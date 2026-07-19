import 'dart:math';

import 'package:flutter/material.dart';

import '../models/perfect_grab_deal_profile.dart';
import 'perfect_grab_mini_game.dart';

/// Shows the round-start Perfect Grab timing mini-game.
class RoundStartMiniGame {
  RoundStartMiniGame._();

  static Future<bool> show(
    BuildContext context, {
    required int roundNumber,
    PerfectGrabDealProfile? fixedDealProfile,
    Duration? fixedDealInterval,
  }) {
    final profile = fixedDealProfile ?? PerfectGrabDealProfile.random(Random());

    return PerfectGrabMiniGame.show(
      context,
      roundNumber: roundNumber,
      dealProfile: profile,
      fixedDealInterval: fixedDealInterval,
    );
  }
}
