import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_decision.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/screens/managers/bot_turn_manager.dart';

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
      gameController = GameController(players: players, seed: 454749);
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
  });
}
