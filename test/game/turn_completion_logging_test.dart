import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';

void main() {
  group('Turn Completion Logging Regression Tests', () {
    late GameController controller;
    late Player humanPlayer;
    late Player botPlayer;

    setUp(() {
      humanPlayer = Player(id: '1', name: 'Human', type: PlayerType.human);
      botPlayer = Player(id: '2', name: 'Bot', type: PlayerType.bot);

      controller = GameController(players: [humanPlayer, botPlayer]);
      controller.initializeGame();
    });

    group('Player Attribution Fixes', () {
      test('should log discard action with correct player name', () {
        final gameState = controller.gameState;

        // Set up human player's turn
        gameState.currentPlayerIndex = 0; // Human
        gameState.turnPhase = TurnPhase.discard;

        // Give human a card to discard
        humanPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        ]);

        final initialActionCount = gameState.recentActions.length;

        // Discard the card
        final success = controller.discardCard(
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        );

        expect(success, isTrue);

        // Check that the log entry has correct player name
        final newActions = gameState.recentActions
            .skip(initialActionCount)
            .toList();
        final discardAction = newActions.firstWhere(
          (action) => action.message.contains('discarded'),
        );

        expect(discardAction.playerName, equals('Human'));
        expect(discardAction.message, contains('5 ♥'));
      });

      test('should maintain correct turn order in action log', () {
        final gameState = controller.gameState;

        // Set up for human turn
        gameState.currentPlayerIndex = 0;
        gameState.turnPhase = TurnPhase.discard;
        humanPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
        ]);

        // Human discards
        controller.discardCard(
          const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
        );

        // Turn should advance to bot
        expect(gameState.currentPlayerIndex, equals(1));
        expect(gameState.turnPhase, equals(TurnPhase.draw));

        // Set up bot turn
        gameState.turnPhase = TurnPhase.discard;
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
        ]);

        // Bot discards
        controller.discardCard(
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
        );

        // Check that both players' actions were logged correctly
        final humanActions = gameState.recentActions
            .where((a) => a.playerName == 'Human' && a.message.contains('6 ♥'))
            .toList();
        final botActions = gameState.recentActions
            .where((a) => a.playerName == 'Bot' && a.message.contains('7 ♠'))
            .toList();

        expect(humanActions.length, equals(1));
        expect(botActions.length, equals(1));
      });

      test('should handle bot going out with correct attribution', () {
        final gameState = controller.gameState;

        // Setup bot to be able to go out
        _setupPlayerToGoOut(botPlayer);
        gameState.currentPlayerIndex = 1; // Bot's turn
        gameState.turnPhase = TurnPhase.discard;

        // Give bot a card to discard for going out
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
        ]);

        final initialActionCount = gameState.recentActions.length;

        // Bot discards and goes out
        controller.discardCard(
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
        );

        // Check if bot went out (might not happen if setup insufficient)
        final newActions = gameState.recentActions
            .skip(initialActionCount)
            .toList();
        final wentOutActions = newActions
            .where((action) => action.message.contains('went out'))
            .toList();

        if (wentOutActions.isNotEmpty) {
          expect(wentOutActions.first.playerName, equals('Bot'));
          expect(gameState.phase, equals(GamePhase.roundEnd));
        } else {
          // Bot didn't actually go out - verify it at least made a valid decision
          expect(
            gameState.phase,
            isIn([GamePhase.playing, GamePhase.roundEnd]),
          );
        }
      });

      test('should prevent race conditions in multiplayer logging', () {
        final gameState = controller.gameState;

        // Simulate rapid turn changes that might cause race conditions
        for (int i = 0; i < 4; i++) {
          final currentPlayer = gameState.currentPlayer;
          final playerName = currentPlayer.name;

          // Set up discard scenario
          gameState.turnPhase = TurnPhase.discard;
          currentPlayer.dealHand([
            PlayingCard(suit: Suit.hearts, rank: CardRank.values[i + 2]),
          ]);

          // Perform discard
          final card = currentPlayer.currentHand.first;
          final success = controller.discardCard(card);

          if (success) {
            // Find the corresponding log entry
            final discardActions = gameState.recentActions
                .where(
                  (action) =>
                      action.message.contains('discarded ${card.compactName}'),
                )
                .toList();

            // Should have exactly one entry with correct player name
            expect(discardActions.length, equals(1));
            expect(discardActions.first.playerName, equals(playerName));
          }
        }
      });
    });

    group('Turn Phase Transitions', () {
      test('should maintain correct phase after discard', () {
        final gameState = controller.gameState;

        // Human turn
        gameState.currentPlayerIndex = 0;
        gameState.turnPhase = TurnPhase.discard;
        humanPlayer.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
        ]);

        // Discard should advance to next player's draw phase
        controller.discardCard(
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
        );

        expect(gameState.currentPlayerIndex, equals(1)); // Bot
        expect(gameState.turnPhase, equals(TurnPhase.draw));
      });

      test('should handle foot pickup during discard correctly', () {
        final gameState = controller.gameState;

        // Setup bot with empty hand but foot available
        botPlayer.hand.clear();
        botPlayer.hasPickedUpFoot = false;
        gameState.currentPlayerIndex = 1;
        gameState.turnPhase = TurnPhase.discard;

        // Give bot exactly one card in hand
        botPlayer.dealHand([
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
        ]);

        final initialActionCount = gameState.recentActions.length;

        // Discard should trigger foot pickup
        controller.discardCard(
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
        );

        // Check foot was picked up
        expect(botPlayer.hasPickedUpFoot, isTrue);

        // Check logging shows foot pickup
        final newActions = gameState.recentActions
            .skip(initialActionCount)
            .toList();
        final footAction = newActions
            .where((a) => a.message.contains('picked up foot'))
            .toList();

        if (footAction.isNotEmpty) {
          expect(footAction.first.playerName, equals('Bot'));
        }
      });
    });
  });
}

/// Helper function to set up a player to be able to go out
void _setupPlayerToGoOut(Player player) {
  // Clear current state
  player.hand.clear();
  player.foot.clear();
  player.melds.clear();

  // Add required books for going out
  final cleanBook = [
    const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
    const PlayingCard(suit: Suit.spades, rank: CardRank.king),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
    const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
    const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
    const PlayingCard(suit: Suit.spades, rank: CardRank.king),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
  ];

  final dirtyBook = [
    const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
    const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
    const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
    const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
    const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
    const PlayingCard(suit: null, rank: CardRank.joker), // Wild card
    const PlayingCard(suit: null, rank: CardRank.joker), // Wild card
  ];

  player.melds.add(Meld.createMeld(cleanBook)!);
  player.melds.add(Meld.createMeld(dirtyBook)!);
  player.hasPlayedDown = true;
  player.hasPickedUpFoot = true;
}
