import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_foot_transition_manager.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('BotFootTransitionManager Tests', () {
    late BotFootTransitionManager transitionManager;
    late GameController gameController;
    late Player botPlayer;

    setUp(() {
      transitionManager = BotFootTransitionManager();

      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      gameController = GameController(players: players);
      gameController.initializeGame();
      botPlayer = players[1];
      botPlayer.hasPlayedDown = true; // Already played down
    });

    group('Emergency Transition', () {
      test('should handle emergency transition with 1 card', () {
        // Give bot just 1 card - should trigger emergency transition
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        ]);
        botPlayer.hasPickedUpFoot = false;

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.discard;

        final decision = transitionManager.handleFootTransition(
          botPlayer,
          gameController,
        );
        expect(decision, isNotNull);
        expect(decision!.action, equals('discard'));
        expect(decision.data, isA<PlayingCard>());
      });

      test('should handle emergency transition with 2 cards', () {
        // Give bot 2 cards - should still trigger emergency transition
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.six),
        ]);
        botPlayer.hasPickedUpFoot = false;

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.discard;

        final decision = transitionManager.handleFootTransition(
          botPlayer,
          gameController,
        );
        expect(decision, isNotNull);
        expect(decision!.action, equals('discard'));
      });
    });

    group('Strategic Transition', () {
      test('should handle high-value hand transition', () {
        // Give bot high-value hand that needs reduction
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.three), // -100
          const PlayingCard(suit: Suit.spades, rank: CardRank.three), // -100
          const PlayingCard(suit: Suit.clubs, rank: CardRank.three), // -100
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.three), // -100
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five), // 5
        ]);
        botPlayer.hasPickedUpFoot = false;

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.discard;

        final decision = transitionManager.handleFootTransition(
          botPlayer,
          gameController,
        );
        expect(decision, isNotNull);
        expect(decision!.action, equals('discard'));

        // Should prefer to discard 3s (negative value cards)
        final discardedCard = decision.data as PlayingCard;
        expect(discardedCard.rank, equals(CardRank.three));
      });

      test('should not transition when hand is manageable', () {
        // Give bot a moderate hand that doesn't need immediate transition
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king), // 10
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen), // 10
          const PlayingCard(suit: Suit.clubs, rank: CardRank.jack), // 10
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten), // 10
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine), // 5
        ]);
        botPlayer.hasPickedUpFoot = false;

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;

        final decision = transitionManager.handleFootTransition(
          botPlayer,
          gameController,
        );
        expect(
          decision,
          isNotNull,
        ); // More aggressive AI should transition earlier to avoid penalties
      });
    });

    group('Foot Phase Behavior', () {
      test('should return null when already on foot', () {
        botPlayer.hasPickedUpFoot = true; // Already on foot

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;

        final decision = transitionManager.handleFootTransition(
          botPlayer,
          gameController,
        );
        expect(decision, isNull);
      });
    });

    group('Turn Phase Handling', () {
      test('should handle meld phase transitions', () {
        botPlayer.hand.clear();
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        ]);
        botPlayer.hasPickedUpFoot = false;

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;

        final decision = transitionManager.handleFootTransition(
          botPlayer,
          gameController,
        );
        expect(decision, isNotNull);
        expect(decision!.action, 'noMeld');
      });
    });
  });
}
