import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/config/bot_configurations.dart';
import 'package:hand_foot_game_flutter/screens/managers/bot_turn_manager.dart';

/// Simple test for the bot personality assignment functionality
void main() {
  group('Bot Personality Assignment Fix', () {
    test('should assign correct predefined personalities based on bot names', () {
      // Create test bots with specific names that should get specific personalities
      final botPlayers = [
        Player(
          id: '2',
          name: 'Ben',
          type: PlayerType.bot,
        ), // Should be bookBuilder
        Player(
          id: '3',
          name: 'Alex',
          type: PlayerType.bot,
        ), // Should be adaptive
      ];

      // Create personality mapping from the kBotConfigurations
      final personalityMap = <String, BotPersonality>{};
      for (final config in kBotConfigurations) {
        personalityMap[config.name] = config.personality;
      }

      final botAI = EnhancedBotAI();

      // Assign personalities based on bot names (simulate the fixed logic)
      for (final bot in botPlayers) {
        final predefinedPersonality = personalityMap[bot.name];
        if (predefinedPersonality != null) {
          botAI.assignPersonality(bot.id, predefinedPersonality);
        }
      }

      // Verify that Ben gets bookBuilder personality
      final benPersonality = botAI.personalityManager.getPersonality('2');
      expect(benPersonality, equals(BotPersonality.bookBuilder));

      // Verify that Alex gets adaptive personality
      final alexPersonality = botAI.personalityManager.getPersonality('3');
      expect(alexPersonality, equals(BotPersonality.adaptive));
    });

    test(
      'should use fallback to hash-based assignment for unknown bot names',
      () {
        // Test the fallback logic for unknown bot names
        final unknownBot = Player(
          id: '2',
          name: 'UnknownBot1',
          type: PlayerType.bot,
        );

        // Create personality mapping from the kBotConfigurations
        final personalityMap = <String, BotPersonality>{};
        for (final config in kBotConfigurations) {
          personalityMap[config.name] = config.personality;
        }

        final botAI = EnhancedBotAI();

        // Simulate the fallback assignment logic
        final predefinedPersonality = personalityMap[unknownBot.name];
        if (predefinedPersonality != null) {
          botAI.assignPersonality(unknownBot.id, predefinedPersonality);
        } else {
          // Fallback to hash-based assignment for unknown bot names
          final personalities = BotPersonality.values;
          final randomPersonality =
              personalities[(unknownBot.id.hashCode % personalities.length)];
          botAI.assignPersonality(unknownBot.id, randomPersonality);
        }

        // Verify that unknown bot gets some valid personality (fallback logic)
        final unknownBotPersonality = botAI.personalityManager.getPersonality(
          '2',
        );
        expect(BotPersonality.values, contains(unknownBotPersonality));
      },
    );

    test('should assign all predefined personalities correctly', () {
      // Test all predefined personality mappings
      final testCases = [
        ('Clara', BotPersonality.conservative),
        ('Carl', BotPersonality.conservative),
        ('Bob', BotPersonality.aggressive),
        ('Rita', BotPersonality.aggressive),
        ('Ben', BotPersonality.bookBuilder),
        ('Tiana', BotPersonality.bookBuilder),
        ('Alex', BotPersonality.adaptive),
        ('Sue', BotPersonality.adaptive),
      ];

      for (final (botName, expectedPersonality) in testCases) {
        final bot = Player(id: '2', name: botName, type: PlayerType.bot);

        // Create personality mapping from the kBotConfigurations
        final personalityMap = <String, BotPersonality>{};
        for (final config in kBotConfigurations) {
          personalityMap[config.name] = config.personality;
        }

        final botAI = EnhancedBotAI();

        // Assign personality based on bot name (simulate the fixed logic)
        final predefinedPersonality = personalityMap[bot.name];
        if (predefinedPersonality != null) {
          botAI.assignPersonality(bot.id, predefinedPersonality);
        }

        final actualPersonality = botAI.personalityManager.getPersonality('2');
        expect(
          actualPersonality,
          equals(expectedPersonality),
          reason:
              '$botName should have $expectedPersonality but got $actualPersonality',
        );
      }
    });
  });
}
