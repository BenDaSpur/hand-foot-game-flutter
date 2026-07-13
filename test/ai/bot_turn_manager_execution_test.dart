import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_decision.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/config/solo_game_settings.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/screens/managers/bot_turn_manager.dart';

final _immediateRoundEndSettings = SoloGameSettings(
  botCount: 1,
  botPersonalities: [BotPersonality.adaptive],
  enableGoingOutBonus: true,
  enableFinalTurnAfterGoingOut: false,
);

void main() {
  group('BotTurnManager execution', () {
    late GameController gameController;
    late Player botPlayer;
    late BotTurnManager turnManager;

    setUp(() {
      final players = [
        Player(id: 'human', name: 'You', type: PlayerType.human),
        Player(id: 'bot1', name: 'Clara', type: PlayerType.bot),
      ];
      gameController = GameController(
        players: players,
        seed: 454749,
        soloSettings: _immediateRoundEndSettings,
      );
      gameController.initializeGame();
      botPlayer = players[1];
      botPlayer.hasPlayedDown = true;
      gameController.gameState.currentPlayerIndex = 1;

      turnManager = BotTurnManager(
        gameController: gameController,
        botAI: EnhancedBotAI(seed: 454749),
        onStateChanged: () {},
        logHumanAction: (_) {},
        logBotDecision:
            ({
              required String botId,
              required String decision,
              required String reasoning,
              Map<String, dynamic>? context,
              GameState? gameStateSnapshot,
            }) {},
      );
    });

    test('executes unlockDiscardPile without failing', () {
      gameController.gameState.turnPhase = TurnPhase.draw;
      gameController.gameState.discardPile.add(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
      );
      botPlayer.dealHand([
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
      ]);
      botPlayer.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ])!,
      );

      final success = turnManager.executeBotDecision(
        BotDecision(action: 'unlockDiscardPile'),
        botPlayer,
      );

      expect(success, isTrue);
      expect(gameController.gameState.turnPhase, TurnPhase.meld);
    });

    test('discards using rank+suit match for duplicate deck cards', () {
      final kingOne = const PlayingCard(suit: Suit.hearts, rank: CardRank.king);
      final kingTwo = const PlayingCard(suit: Suit.hearts, rank: CardRank.king);
      botPlayer.dealHand([kingOne, kingTwo]);
      gameController.gameState.turnPhase = TurnPhase.discard;
      gameController.gameState.hasDrawnFromDeck = true;

      final duplicateReference = PlayingCard(
        suit: Suit.hearts,
        rank: CardRank.king,
      );

      final success = turnManager.executeBotDecision(
        BotDecision(action: 'discard', data: duplicateReference),
        botPlayer,
      );

      expect(success, isTrue);
      expect(botPlayer.currentHand.length, 1);
    });

    test('error decision recovers by completing turn instead of failing', () {
      botPlayer.dealHand([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        const PlayingCard(suit: Suit.spades, rank: CardRank.six),
      ]);
      gameController.gameState.turnPhase = TurnPhase.discard;
      gameController.gameState.hasDrawnFromDeck = true;
      final startingPlayerIndex = gameController.gameState.currentPlayerIndex;

      final success = turnManager.executeBotDecision(
        BotDecision(action: 'error'),
        botPlayer,
      );

      expect(success, isTrue);
      expect(
        gameController.gameState.currentPlayerIndex,
        isNot(startingPlayerIndex),
      );
    });

    test('tryForceMeld adds to existing meld before force discard', () {
      botPlayer.dealHand([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
      ]);
      botPlayer.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
          const PlayingCard(suit: Suit.spades, rank: CardRank.eight),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
        ])!,
      );
      gameController.gameState.turnPhase = TurnPhase.meld;
      gameController.gameState.hasDrawnFromDeck = true;
      final meldSizeBefore = botPlayer.melds.first.cards.length;

      final melded = turnManager.tryForceMeld(botPlayer);

      expect(melded, isTrue);
      expect(botPlayer.melds.first.cards.length, greaterThan(meldSizeBefore));
    });

    test('endRoundForBot ends round and is idempotent', () {
      _setupBotToGoOut(botPlayer);
      var stateChangedCount = 0;
      turnManager = BotTurnManager(
        gameController: gameController,
        botAI: EnhancedBotAI(seed: 454749),
        onStateChanged: () {
          stateChangedCount++;
        },
        logHumanAction: (_) {},
        logBotDecision:
            ({
              required String botId,
              required String decision,
              required String reasoning,
              Map<String, dynamic>? context,
              GameState? gameStateSnapshot,
            }) {},
      );

      turnManager.endRoundForBot(botPlayer);

      expect(gameController.gameState.phase, GamePhase.roundEnd);
      expect(gameController.gameState.round, 2);
      expect(stateChangedCount, 1);

      turnManager.endRoundForBot(botPlayer);

      expect(gameController.gameState.phase, GamePhase.roundEnd);
      expect(gameController.gameState.round, 2);
      expect(stateChangedCount, 1);
    });

    test('goOut decision ends round through endRoundForBot', () {
      _setupBotToGoOut(botPlayer);

      final success = turnManager.executeBotDecision(
        BotDecision(action: 'goOut'),
        botPlayer,
      );

      expect(success, isTrue);
      expect(gameController.gameState.phase, GamePhase.roundEnd);
      expect(gameController.gameState.round, 2);
    });

    test('error recovery ends round when bot can go out', () {
      _setupBotToGoOut(botPlayer);
      botPlayer.hand.clear();
      botPlayer.foot.clear();
      gameController.gameState.turnPhase = TurnPhase.draw;

      final success = turnManager.executeBotDecision(
        BotDecision(action: 'error'),
        botPlayer,
      );

      expect(success, isTrue);
      expect(gameController.gameState.phase, GamePhase.roundEnd);
      expect(gameController.gameState.round, 2);
    });
  });

  group('EnhancedBotAI error propagation', () {
    late GameController gameController;
    late Player botPlayer;
    late EnhancedBotAI botAI;

    setUp(() {
      final players = [
        Player(id: 'human', name: 'You', type: PlayerType.human),
        Player(id: 'bot1', name: 'Clara', type: PlayerType.bot),
      ];
      gameController = GameController(players: players, seed: 1);
      gameController.initializeGame();
      botPlayer = players[1];
      botAI = EnhancedBotAI(seed: 1);
      botPlayer.hand.clear();
      botPlayer.foot.clear();
      botPlayer.hasPlayedDown = true;
      botPlayer.hasPickedUpFoot = true;
      gameController.gameState.currentPlayerIndex = 1;
      gameController.gameState.turnPhase = TurnPhase.discard;
      gameController.gameState.hasDrawnFromDeck = true;
    });

    test('preserves error decision for empty hand without books', () {
      final decision = botAI.makeDecision(botPlayer, gameController);

      expect(decision.action, equals('error'));
    });
  });
}

void _setupBotToGoOut(Player player) {
  player.hand.clear();
  player.foot.clear();
  player.melds.clear();

  player.melds.add(
    Meld.createMeld([
      const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
      const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
      const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
      const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
    ])!,
  );
  player.melds.add(
    Meld.createMeld([
      const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
      const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
      const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
      const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
      const PlayingCard(suit: Suit.spades, rank: CardRank.two),
      const PlayingCard(rank: CardRank.joker),
    ])!,
  );
  player.hasPlayedDown = true;
  player.hasPickedUpFoot = true;
}
