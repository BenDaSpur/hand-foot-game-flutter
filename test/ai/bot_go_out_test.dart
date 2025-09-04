import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Bot Go Out Logic', () {
    late EnhancedBotAI botAI;
    late GameController gameController;
    late Player botPlayer;

    setUp(() {
      botAI = EnhancedBotAI();
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];
      gameController = GameController(players: players);
      botPlayer = players[1]; // Bot player
    });

    test(
      'should return goOut decision when bot has no cards and can go out',
      () {
        // Set up bot with no cards and required books to go out
        botPlayer.hand.clear();
        botPlayer.foot.clear();
        botPlayer.hasPlayedDown = true;
        botPlayer.hasPickedUpFoot = true;

        // Add required melds (clean and dirty books)
        botPlayer.melds.clear();
        botPlayer.melds.add(
          Meld(
            rank: CardRank.ace,
            cards: [
              const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
              const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
              const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
            ],
            type: MeldType.natural,
          ),
        );

        botPlayer.melds.add(
          Meld(
            rank: CardRank.king,
            cards: [
              const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
              const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // Wild
              const PlayingCard(suit: Suit.spades, rank: CardRank.king),
              const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
            ],
            type: MeldType.mixed,
          ),
        );

        // Set game state to discard phase (proper phase for going out)
        gameController.gameState.turnPhase = TurnPhase.discard;
        gameController.gameState.currentPlayerIndex = 1; // Bot's turn

        // Verify bot can go out
        expect(botPlayer.currentHand.isEmpty, isTrue);
        expect(botPlayer.canGoOut, isTrue);

        // Make decision
        final decision = botAI.makeDecision(botPlayer, gameController);

        // Should return goOut decision
        expect(decision.action, equals('goOut'));
      },
    );

    test(
      'should return error decision when bot has no cards but cannot go out',
      () {
        // Set up bot with no cards but missing required books
        botPlayer.hand.clear();
        botPlayer.foot.clear();
        botPlayer.hasPlayedDown = true;
        botPlayer.hasPickedUpFoot = true;

        // Add only one meld (missing required clean/dirty book combination)
        botPlayer.melds.clear();
        botPlayer.melds.add(
          Meld(
            rank: CardRank.ace,
            cards: [
              const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
              const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
              const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
            ],
            type: MeldType.natural,
          ),
        );

        // Set game state to meld phase
        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.currentPlayerIndex = 1; // Bot's turn

        // Verify bot has no cards but cannot go out
        expect(botPlayer.currentHand.isEmpty, isTrue);
        expect(botPlayer.canGoOut, isFalse);

        // Make decision
        final decision = botAI.makeDecision(botPlayer, gameController);

        // Should return safe fallback decision (enhanced error handling)
        expect(decision.action, equals('noMeld'));
      },
    );

    test('should proceed normally when bot has cards available', () {
      // Set up bot with cards available
      botPlayer.hand.clear();
      botPlayer.foot.clear();
      botPlayer.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
      ]);
      botPlayer.hasPlayedDown = true;

      // Set game state to meld phase
      gameController.gameState.turnPhase = TurnPhase.meld;
      gameController.gameState.currentPlayerIndex = 1; // Bot's turn

      // Verify bot has cards
      expect(botPlayer.currentHand.isEmpty, isFalse);

      // Make decision
      final decision = botAI.makeDecision(botPlayer, gameController);

      // Should return discard decision (since no melds possible with 3s)
      expect(decision.action, equals('discard'));
      expect(decision.data, isA<PlayingCard>());
    });
  });
}
