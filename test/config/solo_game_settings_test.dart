import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/config/solo_game_settings.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('SoloGameSettings', () {
    test('defaults match expected solo configuration', () {
      expect(SoloGameSettings.defaults.botCount, 2);
      expect(SoloGameSettings.defaults.enableGoingOutBonus, isTrue);
      expect(SoloGameSettings.defaults.enableFinalTurnAfterGoingOut, isTrue);
      expect(SoloGameSettings.defaults.normalizedPersonalities, hasLength(2));
    });

    test('copyWith pads personalities when bot count increases', () {
      final settings = SoloGameSettings.defaults.copyWith(botCount: 4);
      expect(settings.normalizedPersonalities, hasLength(4));
    });

    test('copyWith trims personalities when bot count decreases', () {
      final settings = SoloGameSettings.defaults.copyWith(botCount: 1);
      expect(settings.normalizedPersonalities, hasLength(1));
    });

    test('goingOutBonusPoints respects toggle', () {
      expect(SoloGameSettings.defaults.goingOutBonusPoints, 100);
      expect(
        SoloGameSettings.defaults
            .copyWith(enableGoingOutBonus: false)
            .goingOutBonusPoints,
        0,
      );
    });

    test('buildPlayers creates one human and configured bots', () {
      final settings = SoloGameSettings.defaults.copyWith(botCount: 3);
      final players = settings.buildPlayers();

      expect(players, hasLength(4));
      expect(players.first.type, PlayerType.human);
      expect(players.where((p) => p.type == PlayerType.bot), hasLength(3));
      expect(players.map((p) => p.name).toSet(), hasLength(4));
    });

    test('toJson and fromJson round-trip', () {
      final original = SoloGameSettings(
        botCount: 3,
        botPersonalities: [
          BotPersonality.aggressive,
          BotPersonality.bookBuilder,
          BotPersonality.conservative,
        ],
        enableGoingOutBonus: false,
        enableFinalTurnAfterGoingOut: false,
      );

      final restored = SoloGameSettings.fromJson(original.toJson());
      expect(restored.botCount, 3);
      expect(
        restored.normalizedPersonalities,
        original.normalizedPersonalities,
      );
      expect(restored.enableGoingOutBonus, isFalse);
      expect(restored.enableFinalTurnAfterGoingOut, isFalse);
    });

    test('previewBotNames returns one name per bot', () {
      final settings = SoloGameSettings.defaults.copyWith(botCount: 3);
      expect(settings.previewBotNames, hasLength(3));
    });
  });
}
