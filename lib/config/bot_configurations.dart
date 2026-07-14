import '../ai/bot_personality.dart';
import '../models/player.dart';
import '../utils/debug_logger.dart';
import 'solo_game_settings.dart';

/// Bot configuration with display name and personality mapping.
class BotConfig {
  final String name;
  final BotPersonality personality;

  const BotConfig(this.name, this.personality);
}

/// Shared bot configurations with predefined personality mappings.
const List<BotConfig> kBotConfigurations = [
  BotConfig('Clara', BotPersonality.conservative),
  BotConfig('Carl', BotPersonality.conservative),
  BotConfig('Bob', BotPersonality.aggressive),
  BotConfig('Rita', BotPersonality.aggressive),
  BotConfig('Ben', BotPersonality.bookBuilder),
  BotConfig('Tiana', BotPersonality.bookBuilder),
  BotConfig('Alex', BotPersonality.adaptive),
  BotConfig('Sue', BotPersonality.adaptive),
];

/// Name → personality lookup for known solo bots.
final Map<String, BotPersonality> kBotPersonalityByName = {
  for (final config in kBotConfigurations) config.name: config.personality,
};

/// Human-readable labels for bot personalities.
String botPersonalityLabel(BotPersonality personality) {
  switch (personality) {
    case BotPersonality.conservative:
      return 'Conservative';
    case BotPersonality.aggressive:
      return 'Aggressive';
    case BotPersonality.bookBuilder:
      return 'Book Builder';
    case BotPersonality.adaptive:
      return 'Adaptive';
  }
}

/// Resolve bot personalities for save/restore.
///
/// Preference order:
/// 1. [preferred] map (live runtime / explicit save)
/// 2. [settings] personalities matched to bot order
/// 3. Known name mapping from [kBotConfigurations]
/// 4. [BotPersonality.adaptive] fallback
Map<String, BotPersonality> resolveBotPersonalities({
  required List<Player> players,
  SoloGameSettings? settings,
  Map<String, BotPersonality>? preferred,
}) {
  final bots = players.where((p) => p.type == PlayerType.bot).toList();
  final fromSettings = settings?.normalizedPersonalities ?? const [];
  final result = <String, BotPersonality>{};

  for (var i = 0; i < bots.length; i++) {
    final bot = bots[i];
    final preferredPersonality = preferred?[bot.id];
    if (preferredPersonality != null) {
      result[bot.id] = preferredPersonality;
      continue;
    }
    if (i < fromSettings.length) {
      result[bot.id] = fromSettings[i];
      continue;
    }
    result[bot.id] = kBotPersonalityByName[bot.name] ?? BotPersonality.adaptive;
  }

  return result;
}

/// Serialize personalities as `BotPersonality.<name>` strings for save formats.
Map<String, String> serializeBotPersonalities(
  Map<String, BotPersonality> personalities,
) {
  return {
    for (final entry in personalities.entries)
      entry.key: entry.value.toString(),
  };
}

/// Parse `BotPersonality.<name>` or bare enum name strings from saves.
BotPersonality parseBotPersonalityString(String value) {
  for (final personality in BotPersonality.values) {
    if (personality.toString() == value || personality.name == value) {
      return personality;
    }
  }
  DebugLogger.warning(
    'Unknown bot personality "$value", falling back to adaptive',
  );
  return BotPersonality.adaptive;
}
