import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/game_config.dart';
import 'package:hand_foot_game_flutter/models/perfect_grab_deal_profile.dart';

void main() {
  group('PerfectGrabDealProfile', () {
    test('standard profile matches legacy timing defaults', () {
      final profile = PerfectGrabDealProfile.standard();

      expect(profile.target, GameConfig.perfectGrabTarget);
      expect(profile.baseDealIntervalMs, 340);
      expect(profile.minDealIntervalMs, 72);
      expect(profile.intervalStepMs, 11);
      expect(profile.jitterMs, 45);
      expect(profile.stutterBeforeCard, isEmpty);
    });

    test('random profile keeps target within configured bounds', () {
      final random = Random(42);
      for (var i = 0; i < 40; i++) {
        final profile = PerfectGrabDealProfile.random(random);
        expect(
          profile.target,
          inInclusiveRange(
            GameConfig.perfectGrabTargetMin,
            GameConfig.perfectGrabTargetMax,
          ),
        );
        expect(profile.maxCards, greaterThanOrEqualTo(profile.target));
        expect(profile.maxCards, lessThanOrEqualTo(34));
      }
    });

    test('random profile can produce different targets over many rolls', () {
      final random = Random(7);
      final targets = List.generate(
        30,
        (_) => PerfectGrabDealProfile.random(random).target,
      ).toSet();

      expect(targets.length, greaterThan(1));
    });

    test('deal intervals stay above minimum floor', () {
      final profile = PerfectGrabDealProfile.random(Random(99));
      final random = Random(99);

      for (var card = 1; card <= profile.target; card++) {
        final interval = profile.dealIntervalForCard(card, random);
        expect(interval.inMilliseconds, greaterThanOrEqualTo(55));
      }
    });
  });
}
