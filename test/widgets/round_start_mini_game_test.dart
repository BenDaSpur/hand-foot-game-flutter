import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/widgets/round_start_mini_game.dart';

void main() {
  group('RoundStartMiniGame', () {
    test('pickVariant returns both modes over many rolls', () {
      final random = Random(11);
      final variants = List.generate(
        40,
        (_) => RoundStartMiniGame.pickVariant(random),
      ).toSet();

      expect(variants, contains(RoundStartMiniGameVariant.perfectGrab));
      expect(variants, contains(RoundStartMiniGameVariant.blindGrab));
    });
  });
}
