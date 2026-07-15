import 'package:flutter_test/flutter_test.dart';
import 'dart:math';
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

    test('fromJson clamps out-of-range botCount', () {
      final restored = SoloGameSettings.fromJson({'botCount': 99});
      expect(restored.botCount, SoloGameSettings.maxBotCount);
    });

    test('copyWith clamps out-of-range botCount', () {
      final settings = SoloGameSettings.defaults.copyWith(botCount: 0);
      expect(settings.botCount, SoloGameSettings.minBotCount);
    });

    test('previewBotNames returns one name per bot', () {
      final settings = SoloGameSettings.defaults.copyWith(botCount: 3);
      expect(settings.previewBotNames, hasLength(3));
    });

    test('buildPlayers uses preview-name seed for deterministic names', () {
      final settings = SoloGameSettings.defaults;
      final nameSeed = settings.normalizedPersonalities.join().hashCode;
      final players = settings.buildPlayers(random: Random(nameSeed));
      final botNames = players
          .where((p) => p.type == PlayerType.bot)
          .map((p) => p.name)
          .toList();
      expect(botNames, settings.previewBotNames);
    });

    test('randomBotConfigurations returns unique bots up to roster size', () {
      final configs = SoloGameSettings.randomBotConfigurations(
        3,
        random: Random(42),
      );

      expect(configs, hasLength(3));
      expect(configs.map((config) => config.name).toSet(), hasLength(3));
    });

    test('buildPlayersFromBotConfigs maps bot names from configs', () {
      final configs = SoloGameSettings.randomBotConfigurations(
        2,
        random: Random(7),
      );
      final players = SoloGameSettings.buildPlayersFromBotConfigs(configs);

      expect(players, hasLength(3));
      expect(players.first.name, 'You');
      expect(
        players.skip(1).map((player) => player.name).toList(),
        configs.map((config) => config.name).toList(),
      );
    });

    test('randomBotConfigurations is seed-deterministic', () {
      final first = SoloGameSettings.randomBotConfigurations(
        2,
        random: Random(99),
      );
      final second = SoloGameSettings.randomBotConfigurations(
        2,
        random: Random(99),
      );
      final third = SoloGameSettings.randomBotConfigurations(
        2,
        random: Random(100),
      );

      expect(
        first.map((config) => config.name),
        second.map((config) => config.name),
      );
      expect(
        first.map((config) => config.name),
        isNot(equals(third.map((config) => config.name))),
      );
    });
  });
}
