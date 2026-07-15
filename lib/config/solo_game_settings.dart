import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../ai/bot_personality.dart';
import '../models/player.dart';
import 'bot_configurations.dart';
import 'game_config.dart';

/// How a solo game should pick opponents and deck seed at launch.
class SoloGameLaunchOptions {
  const SoloGameLaunchOptions({this.useConfiguredBots = false, this.gameSeed});

  /// When true, use personalities from [SoloGameSettings] (user configured them).
  /// When false, shuffle the full bot roster for variety.
  final bool useConfiguredBots;

  /// Explicit deck seed. When null, [GameController] generates a random seed.
  final int? gameSeed;
}

/// Configurable settings for a solo (human vs bots) game.
class SoloGameSettings {
  static const int minBotCount = 1;
  static const int maxBotCount = 5;
  static const String preferencesKey = 'solo_game_settings';

  final int botCount;
  final List<BotPersonality> botPersonalities;
  final bool enableGoingOutBonus;
  final bool enableFinalTurnAfterGoingOut;

  SoloGameSettings({
    required int botCount,
    required this.botPersonalities,
    required this.enableGoingOutBonus,
    required this.enableFinalTurnAfterGoingOut,
  }) : botCount = _clampBotCount(botCount);

  static int _clampBotCount(int count) {
    return count.clamp(minBotCount, maxBotCount);
  }

  static final SoloGameSettings defaults = SoloGameSettings(
    botCount: 2,
    botPersonalities: [BotPersonality.adaptive, BotPersonality.conservative],
    enableGoingOutBonus: true,
    enableFinalTurnAfterGoingOut: true,
  );

  /// Disables final-turn phase; useful for legacy tests expecting immediate round end.
  static final SoloGameSettings immediateRoundEnd = SoloGameSettings(
    botCount: 2,
    botPersonalities: [BotPersonality.adaptive, BotPersonality.conservative],
    enableGoingOutBonus: true,
    enableFinalTurnAfterGoingOut: false,
  );

  int get goingOutBonusPoints =>
      enableGoingOutBonus ? GameConfig.goingOutBonus : 0;

  /// Returns personalities padded or trimmed to match [botCount].
  List<BotPersonality> get normalizedPersonalities {
    if (botPersonalities.length == botCount) {
      return List<BotPersonality>.from(botPersonalities);
    }
    if (botPersonalities.length > botCount) {
      return botPersonalities.take(botCount).toList();
    }
    final result = List<BotPersonality>.from(botPersonalities);
    final fallback = BotPersonality.values;
    var index = 0;
    while (result.length < botCount) {
      result.add(fallback[index % fallback.length]);
      index++;
    }
    return result;
  }

  SoloGameSettings copyWith({
    int? botCount,
    List<BotPersonality>? botPersonalities,
    bool? enableGoingOutBonus,
    bool? enableFinalTurnAfterGoingOut,
  }) {
    final nextBotCount = botCount ?? this.botCount;
    return SoloGameSettings(
      botCount: nextBotCount,
      botPersonalities: botPersonalities ?? this.botPersonalities,
      enableGoingOutBonus: enableGoingOutBonus ?? this.enableGoingOutBonus,
      enableFinalTurnAfterGoingOut:
          enableFinalTurnAfterGoingOut ?? this.enableFinalTurnAfterGoingOut,
    )._normalized();
  }

  SoloGameSettings _normalized() {
    return SoloGameSettings(
      botCount: botCount,
      botPersonalities: normalizedPersonalities,
      enableGoingOutBonus: enableGoingOutBonus,
      enableFinalTurnAfterGoingOut: enableFinalTurnAfterGoingOut,
    );
  }

  /// Preview bot names for the setup UI (deterministic for current personalities).
  List<String> get previewBotNames => _assignBotNames(
    normalizedPersonalities,
    random: Random(normalizedPersonalities.join().hashCode),
  );

  /// Builds 1 human + N bot players from these settings.
  List<Player> buildPlayers({Random? random}) {
    final personalities = normalizedPersonalities;
    final botNames = _assignBotNames(personalities, random: random);

    final players = <Player>[
      Player(id: '1', name: 'You', type: PlayerType.human),
    ];

    for (var i = 0; i < botCount; i++) {
      players.add(
        Player(id: '${i + 2}', name: botNames[i], type: PlayerType.bot),
      );
    }

    return players;
  }

  Map<String, dynamic> toJson() {
    return {
      'botCount': botCount,
      'botPersonalities': botPersonalities.map((p) => p.name).toList(),
      'enableGoingOutBonus': enableGoingOutBonus,
      'enableFinalTurnAfterGoingOut': enableFinalTurnAfterGoingOut,
    };
  }

  factory SoloGameSettings.fromJson(Map<String, dynamic> json) {
    final personalities = (json['botPersonalities'] as List<dynamic>? ?? [])
        .map((value) => _parsePersonality(value as String))
        .toList();

    return SoloGameSettings(
      botCount: _clampBotCount(json['botCount'] as int? ?? defaults.botCount),
      botPersonalities: personalities.isEmpty
          ? defaults.botPersonalities
          : personalities,
      enableGoingOutBonus:
          json['enableGoingOutBonus'] as bool? ?? defaults.enableGoingOutBonus,
      enableFinalTurnAfterGoingOut:
          json['enableFinalTurnAfterGoingOut'] as bool? ??
          defaults.enableFinalTurnAfterGoingOut,
    )._normalized();
  }

  static BotPersonality _parsePersonality(String value) {
    for (final personality in BotPersonality.values) {
      if (personality.name == value) {
        return personality;
      }
    }
    return BotPersonality.adaptive;
  }

  static Future<SoloGameSettings> loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(preferencesKey);
      if (jsonString == null) {
        return defaults;
      }
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return SoloGameSettings.fromJson(jsonMap);
    } catch (_) {
      return defaults;
    }
  }

  Future<void> saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(preferencesKey, jsonEncode(toJson()));
    } catch (_) {
      // Preferences are optional — ignore failures.
    }
  }

  static List<String> _assignBotNames(
    List<BotPersonality> personalities, {
    Random? random,
  }) {
    final rng = random ?? Random();
    final available = List<BotConfig>.from(kBotConfigurations)..shuffle(rng);
    final usedNames = <String>{};
    final names = <String>[];

    for (final personality in personalities) {
      final matching = available
          .where(
            (config) =>
                config.personality == personality &&
                !usedNames.contains(config.name),
          )
          .toList();

      if (matching.isNotEmpty) {
        names.add(matching.first.name);
        usedNames.add(matching.first.name);
        continue;
      }

      final fallback = available
          .where((config) => !usedNames.contains(config.name))
          .toList();
      if (fallback.isNotEmpty) {
        names.add(fallback.first.name);
        usedNames.add(fallback.first.name);
      } else {
        names.add('Bot ${names.length + 1}');
      }
    }

    return names;
  }

  /// Randomizes bot personalities for all bot slots.
  static List<BotPersonality> randomPersonalities(int count, {Random? random}) {
    final rng = random ?? Random();
    final values = BotPersonality.values;
    return List<BotPersonality>.generate(
      count,
      (_) => values[rng.nextInt(values.length)],
    );
  }

  /// Picks unique bots by shuffling the full roster (name + personality pairs).
  static List<BotConfig> randomBotConfigurations(int count, {Random? random}) {
    final rng = random ?? Random();
    final options = List<BotConfig>.from(kBotConfigurations)..shuffle(rng);
    return options.take(count.clamp(0, options.length)).toList();
  }

  /// Builds 1 human + N bots from pre-selected [BotConfig] entries.
  static List<Player> buildPlayersFromBotConfigs(List<BotConfig> configs) {
    final players = <Player>[
      Player(id: '1', name: 'You', type: PlayerType.human),
    ];

    for (var i = 0; i < configs.length; i++) {
      players.add(
        Player(id: '${i + 2}', name: configs[i].name, type: PlayerType.bot),
      );
    }

    return players;
  }
}
