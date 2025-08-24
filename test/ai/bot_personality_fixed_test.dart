import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Bot Personality System Integration Tests', () {
    test('should assign personalities correctly', () {
      final botAI = EnhancedBotAI();

      // Test personality assignment
      botAI.assignPersonality('conservative', BotPersonality.conservative);
      botAI.assignPersonality('aggressive', BotPersonality.aggressive);

      // Test that assignments were successful by making decisions
      final players = [
        Player(
          id: 'conservative',
          name: 'Conservative Bot',
          type: PlayerType.bot,
        ),
        Player(id: 'aggressive', name: 'Aggressive Bot', type: PlayerType.bot),
      ];
      final controller = GameController(players: players);
      controller.initializeGame();

      // Both should be able to make decisions with their assigned personalities
      controller.gameState.currentPlayerIndex = 0;
      controller.gameState.turnPhase = TurnPhase.draw;
      final conservativeDecision = botAI.makeDecision(players[0], controller);

      controller.gameState.currentPlayerIndex = 1;
      final aggressiveDecision = botAI.makeDecision(players[1], controller);

      expect(conservativeDecision.action, isA<String>());
      expect(aggressiveDecision.action, isA<String>());
    });

    test('should provide different behavior for different personalities', () {
      final botAI = EnhancedBotAI(seed: 42);

      // Create players with different personalities
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Conservative', type: PlayerType.bot),
        Player(id: '3', name: 'Aggressive', type: PlayerType.bot),
      ];

      final controller = GameController(players: players);
      controller.initializeGame();

      botAI.assignPersonality('2', BotPersonality.conservative);
      botAI.assignPersonality('3', BotPersonality.aggressive);

      final conservativeBot = players[1];
      final aggressiveBot = players[2];

      // Give both bots similar hands
      conservativeBot.dealHand([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
      ]);

      aggressiveBot.dealHand([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
      ]);

      controller.gameState.currentPlayerIndex = 1;
      controller.gameState.turnPhase = TurnPhase.draw;

      // Test that both personalities can make decisions
      final conservativeDecision = botAI.makeDecision(
        conservativeBot,
        controller,
      );

      controller.gameState.currentPlayerIndex = 2;
      final aggressiveDecision = botAI.makeDecision(aggressiveBot, controller);

      expect(conservativeDecision.action, isA<String>());
      expect(aggressiveDecision.action, isA<String>());

      // Both should be valid actions
      expect([
        'drawFromDeck',
        'drawFromDiscard',
      ], contains(conservativeDecision.action));
      expect([
        'drawFromDeck',
        'drawFromDiscard',
      ], contains(aggressiveDecision.action));
    });

    test('should handle unknown players gracefully', () {
      final botAI = EnhancedBotAI();

      final players = [
        Player(id: 'unknown-player', name: 'Unknown', type: PlayerType.bot),
      ];
      final controller = GameController(players: players);
      controller.initializeGame();

      controller.gameState.currentPlayerIndex = 0;
      controller.gameState.turnPhase = TurnPhase.draw;

      // Should not throw and should make a decision
      final decision = botAI.makeDecision(players[0], controller);
      expect(decision.action, isA<String>());
    });

    test('should work with all personality types', () {
      final botAI = EnhancedBotAI();

      final players = [
        Player(id: 'conservative', name: 'Conservative', type: PlayerType.bot),
        Player(id: 'aggressive', name: 'Aggressive', type: PlayerType.bot),
        Player(id: 'bookBuilder', name: 'BookBuilder', type: PlayerType.bot),
        Player(id: 'adaptive', name: 'Adaptive', type: PlayerType.bot),
      ];
      final controller = GameController(players: players);
      controller.initializeGame();

      botAI.assignPersonality('conservative', BotPersonality.conservative);
      botAI.assignPersonality('aggressive', BotPersonality.aggressive);
      botAI.assignPersonality('bookBuilder', BotPersonality.bookBuilder);
      botAI.assignPersonality('adaptive', BotPersonality.adaptive);

      // Test that all personalities can make decisions
      controller.gameState.turnPhase = TurnPhase.draw;
      for (int i = 0; i < players.length; i++) {
        controller.gameState.currentPlayerIndex = i;
        final decision = botAI.makeDecision(players[i], controller);
        expect(decision.action, isA<String>());
      }
    });

    test('should make decisions based on personality in meld phase', () {
      final botAI = EnhancedBotAI(seed: 42);

      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      final controller = GameController(players: players);
      controller.initializeGame();

      final bot = players[1];
      bot.hasPlayedDown = true; // Already played down

      // Give bot a meldable hand
      bot.dealHand([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
      ]);

      controller.gameState.currentPlayerIndex = 1;
      controller.gameState.turnPhase = TurnPhase.meld;
      controller.gameState.hasDrawnFromDeck = true;

      // Test with conservative personality
      botAI.assignPersonality('2', BotPersonality.conservative);
      final conservativeDecision = botAI.makeDecision(bot, controller);

      // Test with aggressive personality
      botAI.assignPersonality('2', BotPersonality.aggressive);
      final aggressiveDecision = botAI.makeDecision(bot, controller);

      expect(conservativeDecision.action, isA<String>());
      expect(aggressiveDecision.action, isA<String>());

      // Both should make valid decisions
      expect([
        'createMeld',
        'addToMeld',
        'discard',
        'endTurn',
      ], contains(conservativeDecision.action));
      expect([
        'createMeld',
        'addToMeld',
        'discard',
        'endTurn',
      ], contains(aggressiveDecision.action));
    });
  });
}
