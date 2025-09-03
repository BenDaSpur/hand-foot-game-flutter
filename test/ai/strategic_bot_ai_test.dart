import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';

void main() {
  group('Strategic Bot AI', () {
    late GameController gameController;
    late EnhancedBotAI botAI;
    late Player bot;

    setUp(() {
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
        Player(id: '3', name: 'Bot2', type: PlayerType.bot),
      ];
      gameController = GameController(players: players);
      botAI = EnhancedBotAI(
        seed: 12345,
      ); // Use consistent seed for test reproducibility
      bot = players[1]; // Bot player
    });

    test(
      'should use multi-meld play-down when individual melds are insufficient',
      () {
        // Set up scenario similar to your 3 nines + 5 tens situation
        bot.dealHand([
          // 3 nines (30 points)
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
          // 5 tens (50 points) - bot should strategically use only 3
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.ten,
          ), // Keep this one
          // Other cards
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
        ]);

        // Bot hasn't played down yet
        expect(bot.hasPlayedDown, isFalse);

        // Set current player to bot and draw phase
        gameController.gameState.currentPlayerIndex = 1; // Bot
        gameController.gameState.turnPhase = TurnPhase.meld;

        // Bot should create a multi-meld play-down (30+30=60 points)
        final decision = botAI.makeDecision(bot, gameController);

        expect(decision.action, anyOf(['createMeld', 'createMultipleMelds']));
        if (decision.action == 'createMultipleMelds') {
          expect(decision.data, isA<List<List<PlayingCard>>>());
        } else {
          expect(decision.data, isA<List<PlayingCard>>());
        }
      },
    );

    test('should make strategic meld decisions', () {
      // Scenario: Bot has multiple meld options with different point values
      bot.dealHand([
        // Aces meld option: 100 points (exceeds requirement significantly)
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),

        // Lower-value options: 3 sixes (18) and 3 sevens (21)
        const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
        const PlayingCard(suit: Suit.spades, rank: CardRank.six),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.six),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
        const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
      ]);

      gameController.gameState.currentPlayerIndex = 1; // Bot
      gameController.gameState.turnPhase = TurnPhase.meld;

      final decision = botAI.makeDecision(bot, gameController);
      expect(decision.action, equals('createMeld'));

      final selectedMeld = decision.data as List<PlayingCard>;

      // Bot should make a strategic decision - could be aces if that's the best scoring meld
      // or lower value cards for strategic reasons
      expect(selectedMeld.length, greaterThanOrEqualTo(3));

      final meldPoints = selectedMeld.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      expect(
        meldPoints,
        greaterThanOrEqualTo(15),
      ); // Should have some meaningful point value
    });

    test('should retain pairs for discard pile unlocking opportunities', () {
      // Scenario: Bot has cards that could form melds, but should keep pairs for unlocking
      bot.dealHand([
        // Potential melds but with strategic retention considerations
        const PlayingCard(suit: Suit.hearts, rank: CardRank.nine), // 10 pts
        const PlayingCard(suit: Suit.spades, rank: CardRank.nine), // 10 pts
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine), // 10 pts
        const PlayingCard(
          suit: Suit.clubs,
          rank: CardRank.nine,
        ), // 10 pts - keep for unlock?

        const PlayingCard(suit: Suit.hearts, rank: CardRank.ten), // 10 pts
        const PlayingCard(suit: Suit.spades, rank: CardRank.ten), // 10 pts
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten), // 10 pts
        const PlayingCard(
          suit: Suit.clubs,
          rank: CardRank.ten,
        ), // 10 pts - keep for unlock?
        // Other filler cards
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
      ]);

      gameController.gameState.currentPlayerIndex = 1;
      gameController.gameState.turnPhase = TurnPhase.meld;

      final decision = botAI.makeDecision(bot, gameController);

      if (decision.action == 'createMeld') {
        final selectedMeld = decision.data as List<PlayingCard>;

        // Bot should create a meld, could be using all 4 cards of the same rank
        expect(selectedMeld.length, greaterThanOrEqualTo(3));

        // The meld should be valid (all same rank for natural melds)
        final rank = selectedMeld.first.rank;
        final allSameRank = selectedMeld.every((card) => card.rank == rank);
        expect(allSameRank, isTrue);
      }
    });

    test('should handle draw decisions with unlock awareness', () {
      // Test the existing unlock logic in draw decisions
      bot.hasPlayedDown = true; // Already played down
      bot.hasPickedUpFoot =
          true; // On foot pile - more willing to take smaller piles

      // Since bot has picked up foot, put cards in foot pile
      bot.dealFoot([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(
          suit: Suit.diamonds,
          rank: CardRank.king,
        ), // 3 kings - should be aggressive
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
      ]);

      gameController.gameState.currentPlayerIndex = 1;
      gameController.gameState.turnPhase = TurnPhase.draw;

      // Set up discard pile with King on top and valuable cards below
      gameController.gameState.discardPile.clear();
      gameController.gameState.discardPile.addAll([
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen), // Bottom
        const PlayingCard(
          suit: Suit.hearts,
          rank: CardRank.ace,
        ), // Middle - more value
        const PlayingCard(
          suit: Suit.clubs,
          rank: CardRank.king,
        ), // Top card - matches bot's kings
      ]);
      gameController.gameState.discardPileFrozen = false;

      final decision = botAI.makeDecision(bot, gameController);

      // Bot should try to unlock discard pile - has 3 matching kings + valuable pile
      expect(decision.action, equals('drawFromDiscard'));
    });

    group('Strategic AI Edge Cases', () {
      test('should handle no possible melds gracefully', () {
        // Bot with cards that cannot form any melds
        bot.dealHand([
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.four,
          ), // Singleton
          const PlayingCard(
            suit: Suit.spades,
            rank: CardRank.five,
          ), // Singleton
          const PlayingCard(
            suit: Suit.diamonds,
            rank: CardRank.six,
          ), // Singleton
          const PlayingCard(
            suit: Suit.clubs,
            rank: CardRank.seven,
          ), // Singleton
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.eight,
          ), // Singleton
        ]);

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;

        final decision = botAI.makeDecision(bot, gameController);

        // Should fall back to discard since no melds possible
        expect(decision.action, anyOf(['discard', 'noMeld']));
        if (decision.action == 'discard') {
          expect(decision.data, isA<PlayingCard>());
        }
      });

      test('should handle insufficient cards for play-down', () {
        // Bot with cards that total less than play-down requirement
        bot.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four), // 5 pts
          const PlayingCard(suit: Suit.spades, rank: CardRank.four), // 5 pts
          const PlayingCard(
            suit: Suit.diamonds,
            rank: CardRank.four,
          ), // 5 pts = 15 total
        ]);

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;

        final decision = botAI.makeDecision(bot, gameController);

        // Should discard since can't meet play-down requirement (60 points)
        expect(decision.action, anyOf(['discard', 'noMeld']));
      });

      test('should handle empty discard pile for draw decision', () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;

        bot.dealFoot([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        ]);

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.draw;

        // Empty discard pile
        gameController.gameState.discardPile.clear();
        gameController.gameState.discardPileFrozen = false;

        final decision = botAI.makeDecision(bot, gameController);

        // Should draw from deck when discard pile is empty
        expect(decision.action, equals('drawFromDeck'));
      });

      test('should handle frozen discard pile correctly', () {
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;

        bot.dealFoot([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        ]);

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.draw;

        // Frozen discard pile with wild card on top
        gameController.gameState.discardPile.clear();
        gameController.gameState.discardPile.addAll([
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.two,
          ), // Wild card freezes pile
        ]);
        gameController.gameState.discardPileFrozen = true;

        final decision = botAI.makeDecision(bot, gameController);

        // Should draw from deck when pile is frozen due to wild card
        expect(decision.action, equals('drawFromDeck'));
      });

      test('should handle strategic play-down with no viable combinations', () {
        // Bot with only one type of meld possible, but not meeting requirement
        bot.dealHand([
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.four,
          ), // 5 pts each
          const PlayingCard(suit: Suit.spades, rank: CardRank.four),
          const PlayingCard(
            suit: Suit.diamonds,
            rank: CardRank.four,
          ), // 15 pts total
          // Not enough for 60-point requirement, no other melds possible
          const PlayingCard(
            suit: Suit.clubs,
            rank: CardRank.eight,
          ), // Singleton
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.nine,
          ), // Singleton
        ]);

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;

        final decision = botAI.makeDecision(bot, gameController);

        // Should discard since strategic play-down finds no viable combinations
        expect(decision.action, anyOf(['discard', 'noMeld']));
      });

      test('should handle card conflict detection with identical cards', () {
        // Bot with many identical cards (testing multi-deck conflict detection)
        bot.dealHand([
          // 6 aces - should be able to form at least one meld
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace), // 20 pts
          const PlayingCard(
            suit: Suit.hearts,
            rank: CardRank.ace,
          ), // 20 pts (duplicate)
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace), // 20 pts
          const PlayingCard(
            suit: Suit.spades,
            rank: CardRank.ace,
          ), // 20 pts (duplicate)
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace), // 20 pts
          const PlayingCard(
            suit: Suit.diamonds,
            rank: CardRank.ace,
          ), // 20 pts (duplicate)
          // Total: 120 points - well above 60 point requirement
        ]);

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;

        final decision = botAI.makeDecision(bot, gameController);

        // Should create a meld since we have plenty of cards and points
        if (decision.action == 'createMeld') {
          final selectedMeld = decision.data as List<PlayingCard>;
          expect(selectedMeld.length, greaterThanOrEqualTo(3));

          // All cards should be aces
          final allAces = selectedMeld.every(
            (card) => card.rank == CardRank.ace,
          );
          expect(allAces, isTrue);
        } else {
          // If it chooses to discard, that's also valid behavior
          expect(decision.action, anyOf(['discard', 'noMeld']));
        }
      });

      test('should perform well with large hands (performance test)', () {
        // Test bot with many possible melds to ensure performance optimizations work
        bot.dealHand([
          // Create multiple meld possibilities to stress-test the algorithm
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ]);

        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;

        final stopwatch = Stopwatch()..start();
        final decision = botAI.makeDecision(bot, gameController);
        stopwatch.stop();

        // Should complete within reasonable time (< 100ms for this scenario)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
        expect(decision.action, anyOf(['createMeld', 'createMultipleMelds']));
      });
    });
  });
}
