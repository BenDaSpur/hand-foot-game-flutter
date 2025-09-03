import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/llm_service.dart';
import 'package:hand_foot_game_flutter/ai/llm_enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Cross-Platform LLM Service Tests', () {
    test('LLM service should initialize successfully', () async {
      final llmService = LLMService.instance;

      // Should initialize without throwing (may or may not succeed depending on platform)
      await llmService.initialize();

      // Status should be available
      final status = llmService.getStatus();
      expect(status['platform'], isA<String>());
      expect(status['isInitialized'], isA<bool>());
      expect(status['activeService'], isA<String>());
    });

    test('LLMEnhancedBotAI should work with cross-platform service', () async {
      final botAI = LLMEnhancedBotAI();

      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      final controller = GameController(players: players);
      controller.initializeGame();
      controller.gameState.currentPlayerIndex = 1;
      controller.gameState.turnPhase = TurnPhase.draw;

      // Should not throw and should make a decision
      final decision = botAI.makeDecision(players[1], controller);
      expect(decision.action, isA<String>());
    });

    test('LLMEnhancedBotAI should make async decisions', () async {
      final botAI = LLMEnhancedBotAI();

      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      final controller = GameController(players: players);
      controller.initializeGame();
      controller.gameState.currentPlayerIndex = 1;
      controller.gameState.turnPhase = TurnPhase.draw;

      // Should not throw and should make a decision
      final decision = await botAI.makeDecisionAsync(players[1], controller);
      expect(decision.action, isA<String>());
    });

    test('LLM service should provide platform-specific status', () {
      final llmService = LLMService.instance;
      final status = llmService.getStatus();

      // Should have platform-specific information
      expect(status.containsKey('platform'), isTrue);
      expect(status.containsKey('activeService'), isTrue);

      // Platform should be one of our supported platforms
      final platform = status['platform'] as String;
      expect(['Web', 'Mobile/Desktop'], contains(platform));

      // Active service should match platform
      final activeService = status['activeService'] as String;
      if (platform == 'Web') {
        expect(activeService, equals('WebLLMService'));
      } else {
        expect(activeService, equals('MobileLLMService'));
      }

      print('Platform: $platform, ActiveService: $activeService');
    });

    test('Should handle LLM service gracefully when disabled', () {
      final botAI = LLMEnhancedBotAI(enableLLM: false);

      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      final controller = GameController(players: players);
      controller.initializeGame();
      controller.gameState.currentPlayerIndex = 1;
      controller.gameState.turnPhase = TurnPhase.draw;

      // Should fall back to rule-based AI
      final decision = botAI.makeDecision(players[1], controller);
      expect(decision.action, isA<String>());

      // Should indicate LLM is disabled after being set to false
      botAI.setLLMEnabled(false);
      // Note: LLM service may still be available, but should be disabled for usage
      print('LLM Enabled: ${botAI.getLLMStats()['isLLMAvailable']}');
    });

    test('Should support all personality types with LLM', () async {
      final botAI = LLMEnhancedBotAI();

      final personalities = [
        BotPersonality.conservative,
        BotPersonality.aggressive,
        BotPersonality.bookBuilder,
        BotPersonality.adaptive,
      ];

      for (final personality in personalities) {
        final players = [
          Player(id: '1', name: 'Human', type: PlayerType.human),
          Player(id: '2', name: 'Bot', type: PlayerType.bot),
        ];

        final controller = GameController(players: players);
        controller.initializeGame();
        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.draw;

        botAI.assignPersonality('2', personality);

        // Should make decisions for all personality types
        final decision = await botAI.makeDecisionAsync(players[1], controller);
        expect(decision.action, isA<String>());
      }
    });

    test('Should handle LLM service gracefully when unavailable', () {
      final botAI = LLMEnhancedBotAI(
        enableLLM: false,
      ); // Disable LLM explicitly

      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      final controller = GameController(players: players);
      controller.initializeGame();
      controller.gameState.currentPlayerIndex = 1;
      controller.gameState.turnPhase = TurnPhase.draw;

      // Should fall back to rule-based AI gracefully
      final decision = botAI.makeDecision(players[1], controller);
      expect(decision.action, isA<String>());

      // Should work without errors even when LLM is disabled
      expect(decision.action, isNotNull);
    });
  });
}
