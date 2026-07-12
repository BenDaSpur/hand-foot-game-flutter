import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Adaptive personality constant overrides', () {
    late EnhancedBotAI botAI;
    late GameController gameController;
    late Player adaptiveBot;
    late Player human;

    setUp(() {
      botAI = EnhancedBotAI(seed: 42);
      human = Player(id: '1', name: 'You', type: PlayerType.human);
      adaptiveBot = Player(id: '2', name: 'Alex', type: PlayerType.bot);
      gameController = GameController(players: [human, adaptiveBot], seed: 42);
      gameController.initializeGame();
      botAI.assignPersonality(adaptiveBot.id, BotPersonality.adaptive);
    });

    test('applyConstantOverrides changes maxTurnsBeforeForcePlayDown', () {
      final manager = botAI.personalityManager;
      final baseline = manager.getConstants(adaptiveBot.id);
      expect(baseline.maxTurnsBeforeForcePlayDown, 4);

      manager.applyConstantOverrides(adaptiveBot.id, 'speed_counter', {
        'maxTurnsBeforeForcePlayDown': 1,
        'aggressivenessMultiplier': 1.8,
      });

      final overridden = manager.getConstants(adaptiveBot.id);
      expect(overridden.maxTurnsBeforeForcePlayDown, 1);
      expect(overridden.aggressivenessMultiplier, 1.8);
      expect(manager.getAdaptiveStrategy(adaptiveBot.id), 'speed_counter');
    });

    test('resetAdaptiveConstants restores baseline adaptive values', () {
      final manager = botAI.personalityManager;
      manager.applyConstantOverrides(adaptiveBot.id, 'book_matcher', {
        'maxTurnsBeforeForcePlayDown': 9,
        'bookCompletionPriority': 300,
      });

      manager.resetAdaptiveConstants(adaptiveBot.id);

      final restored = manager.getConstants(adaptiveBot.id);
      expect(restored.maxTurnsBeforeForcePlayDown, 4);
      expect(restored.bookCompletionPriority, 150);
      expect(manager.getAdaptiveStrategy(adaptiveBot.id), isEmpty);
    });

    test(
      'adaptive bot switches to speed_counter when human hoards 20+ cards',
      () {
        human.hand.clear();
        for (int i = 0; i < 22; i++) {
          human.addCardToHand(
            const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          );
        }
        human.hasPlayedDown = false;
        gameController.gameState.round = 2;
        gameController.gameState.turnPhase = TurnPhase.draw;
        gameController.gameState.currentPlayerIndex = 1;

        botAI.makeDecision(adaptiveBot, gameController);

        final constants = botAI.personalityManager.getConstants(adaptiveBot.id);
        expect(constants.maxTurnsBeforeForcePlayDown, 1);
        expect(constants.aggressivenessMultiplier, closeTo(1.8, 0.01));
      },
    );

    test('overrides do not apply to non-adaptive personalities', () {
      final manager = botAI.personalityManager;
      final conservative = Player(id: '3', name: 'Carl', type: PlayerType.bot);
      botAI.assignPersonality(conservative.id, BotPersonality.conservative);

      manager.applyConstantOverrides(conservative.id, 'speed_counter', {
        'maxTurnsBeforeForcePlayDown': 1,
      });

      expect(
        manager.getConstants(conservative.id).maxTurnsBeforeForcePlayDown,
        3,
      );
    });
  });
}
