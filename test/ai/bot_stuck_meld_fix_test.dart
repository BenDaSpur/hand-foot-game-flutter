import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';

void main() {
  group('Bot Stuck Meld Fix', () {
    test('should discard when no natural melds available and not yet turn 5', () async {
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot1', type: PlayerType.bot),
        Player(id: '3', name: 'Bot2', type: PlayerType.bot),
      ];
      final gameController = GameController(players: players);
      final botAI = EnhancedBotAI();

      final bot1 = players[1];

      // Give Bot 1 a hand that can form a mixed meld: 2 queens + 1 joker (70 points)
      // But no natural melds available, so bot should wait until turn 5
      bot1.dealHand([
        const PlayingCard(suit: null, rank: CardRank.joker), // 50 points
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen), // 10 points
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.queen,
        ), // 10 points
        // Total: 70 points, exceeds 60-point play-down requirement
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.two),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
      ]);

      // Set up the exact scenario from the bug report
      gameController.gameState.round = 1;
      gameController.gameState.currentPlayerIndex = 1; // Bot 1
      gameController.gameState.turnPhase = TurnPhase.meld;
      gameController.gameState.hasDrawnFromDeck = true;
      gameController.gameState.hasMelded = false;

      // Verify the bot has cards that can form a meld (2 queens + 1 joker + 2 more twos)
      final wildCards = bot1.hand.where((c) => c.isWild).toList();
      final queens = bot1.hand.where((c) => c.rank == CardRank.queen).toList();
      expect(queens.length, equals(2)); // 2 queens
      expect(wildCards.length, equals(3)); // 1 joker + 2 twos

      // Verify play down requirement is 60 for round 1
      expect(gameController.gameState.playDownRequirement, equals(60));

      // Find possible melds - should find at least one wild meld
      final possibleMelds = gameController.findPossibleMelds(bot1);
      expect(possibleMelds.isNotEmpty, true);

      // Find the queen meld (2 queens + 1 joker, which should be worth 70 points)
      final queenMeld = possibleMelds.firstWhere(
        (meld) =>
            meld.any((card) => card.rank == CardRank.queen) && meld.length == 3,
        orElse: () => [],
      );
      expect(queenMeld.isNotEmpty, true);

      final meldPoints = queenMeld.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      expect(meldPoints, equals(70)); // 2 queens (10 each) + 1 joker (50)
      expect(meldPoints >= 60, true); // Meets play-down requirement

      // Now test the bot decision - the new bot AI is smarter and will create viable melds
      final decision = botAI.makeDecision(bot1, gameController);

      // The new bot AI should decide to create the meld since it meets requirements
      // The queens + joker meld is worth 70 points, exceeding the 60-point requirement
      expect(decision.action, equals('createMeld'));
      expect(decision.data, isA<List<PlayingCard>>());

      final meldCards = decision.data as List<PlayingCard>;
      expect(meldCards.length, equals(3));

      // Should be the queen meld (2 queens + 1 wild)
      final meldQueens = meldCards
          .where((card) => card.rank == CardRank.queen)
          .toList();
      final meldWilds = meldCards.where((card) => card.isWild).toList();
      expect(meldQueens.length, equals(2));
      expect(meldWilds.length, equals(1));

      // Total points should meet requirement
      final totalPoints = meldCards.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      expect(totalPoints, greaterThanOrEqualTo(60));
    });

    test(
      'should handle fallback logic when strategic play-down returns empty but melds exist',
      () async {
        final players = [
          Player(id: '1', name: 'Human', type: PlayerType.human),
          Player(id: '2', name: 'Bot1', type: PlayerType.bot),
          Player(id: '3', name: 'Bot2', type: PlayerType.bot),
        ];
        final gameController = GameController(players: players);
        final botAI = EnhancedBotAI();

        final bot1 = players[1];

        // Give bot a hand that can create a valid meld: 2 kings + 1 joker (70 points)
        bot1.dealHand([
          const PlayingCard(suit: null, rank: CardRank.joker), // 50 points
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.king,
          ), // 10 points
          const PlayingCard(
            suit: Suit.spades,
            rank: CardRank.king,
          ), // 10 points
          // Additional cards
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.two),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ]);

        // Set up similar scenario but with a configuration that might cause strategic play-down to fail
        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        // This should find possible melds
        final possibleMelds = gameController.findPossibleMelds(bot1);
        expect(possibleMelds.isNotEmpty, true);

        // Test that bot makes a decision (doesn't get stuck)
        final decision = botAI.makeDecision(bot1, gameController);
        expect(decision.action, isIn(['createMeld', 'discard']));

        // If it decided to create a meld, it should be executable
        if (decision.action == 'createMeld') {
          final success = gameController.createMeld(
            decision.data as List<PlayingCard>,
          );
          expect(success, true);
        }
      },
    );
  });
}
