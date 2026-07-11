import '../ai/bot_personality.dart';

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
