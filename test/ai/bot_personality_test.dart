import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_ai.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Bot Personality System Tests', () {
    test(
      'should have different strategic constants for different personalities',
      () {
        final botAI = BotAI();

        // Assign different personalities
        botAI.assignPersonality('conservative', BotPersonality.conservative);
        botAI.assignPersonality('aggressive', BotPersonality.aggressive);
        botAI.assignPersonality('bookBuilder', BotPersonality.bookBuilder);

        // Create test players
        final conservativeBot = Player(
          id: 'conservative',
          name: 'Conservative Bot',
          type: PlayerType.bot,
        );
        final aggressiveBot = Player(
          id: 'aggressive',
          name: 'Aggressive Bot',
          type: PlayerType.bot,
        );
        final bookBuilderBot = Player(
          id: 'bookBuilder',
          name: 'Book Builder Bot',
          type: PlayerType.bot,
        );

        // Create game controller with these bots
        final players = [conservativeBot, aggressiveBot, bookBuilderBot];
        final controller = GameController(players: players);
        controller.initializeGame();

        // Test conservative bot constants (should have higher thresholds)
        botAI.setCurrentPlayerContextForTest('conservative');
        expect(
          botAI.strategicBufferPoints,
          equals(30),
        ); // Higher than default 20
        expect(
          botAI.valuablePileThreshold,
          equals(140),
        ); // Higher than default 100
        expect(
          botAI.maxTurnsBeforeForcePlayDown,
          equals(7),
        ); // Higher than default 5

        // Test aggressive bot constants (should have lower thresholds)
        botAI.setCurrentPlayerContextForTest('aggressive');
        expect(
          botAI.strategicBufferPoints,
          equals(10),
        ); // Lower than default 20
        expect(
          botAI.valuablePileThreshold,
          equals(70),
        ); // Lower than default 100
        expect(
          botAI.maxTurnsBeforeForcePlayDown,
          equals(3),
        ); // Lower than default 5

        // Test book builder bot constants (should prioritize book completion)
        botAI.setCurrentPlayerContextForTest('bookBuilder');
        expect(botAI.strategicBufferPoints, equals(25)); // Moderate
        expect(
          botAI.constantsForTest.bookCompletionPriority,
          equals(100),
        ); // Highest priority
        expect(
          botAI.maxTurnsBeforeForcePlayDown,
          equals(6),
        ); // Patient for book building
      },
    );

    test('should assign adaptive personality as fallback', () {
      final botAI = BotAI();

      // Don't assign any personality - should default to adaptive
      botAI.setCurrentPlayerContextForTest('default');

      // Should get adaptive personality constants
      expect(botAI.strategicBufferPoints, equals(20)); // Adaptive default
      expect(botAI.valuablePileThreshold, equals(100)); // Adaptive default
      expect(botAI.maxTurnsBeforeForcePlayDown, equals(5)); // Adaptive default
    });

    test('should maintain different opponent analysis for different bots', () {
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot 1', type: PlayerType.bot),
        Player(id: '3', name: 'Bot 2', type: PlayerType.bot),
      ];

      final controller = GameController(players: players);
      controller.initializeGame();

      final botAI = BotAI();
      botAI.assignPersonality('2', BotPersonality.conservative);
      botAI.assignPersonality('3', BotPersonality.aggressive);

      // Make decisions for both bots to trigger opponent analysis
      final bot1 = players[1];
      final bot2 = players[2];

      // This should create opponent analysis entries
      botAI.makeDecision(bot1, controller);
      botAI.makeDecision(bot2, controller);

      // Verify opponent analysis was created
      expect(botAI.opponentAnalysis.containsKey('1'), isTrue); // Human player
      expect(botAI.opponentAnalysis.containsKey('2'), isTrue); // Other bot
    });

    test('should show personality differences in decision thresholds', () {
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Conservative Clara', type: PlayerType.bot),
        Player(id: '3', name: 'Bold Bob', type: PlayerType.bot),
      ];

      final controller = GameController(players: players);
      controller.initializeGame();

      final botAI = BotAI();
      botAI.assignPersonality('2', BotPersonality.conservative);
      botAI.assignPersonality('3', BotPersonality.aggressive);

      // Test high value pair break chance differences
      botAI.setCurrentPlayerContextForTest('2'); // Conservative
      final conservativeBreakChance = botAI.highValuePairBreakChance;

      botAI.setCurrentPlayerContextForTest('3'); // Aggressive
      final aggressiveBreakChance = botAI.highValuePairBreakChance;

      // Aggressive should be more willing to break high value pairs
      expect(aggressiveBreakChance, greaterThan(conservativeBreakChance));
      expect(conservativeBreakChance, equals(0.1)); // Conservative: 10%
      expect(aggressiveBreakChance, equals(0.35)); // Aggressive: 35%
    });
  });
}
