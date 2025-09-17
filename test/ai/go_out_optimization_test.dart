import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/ai/bot_end_game_manager.dart';

/// Tests for the go-out optimization logic that handles edge cases
/// like Ben's scenario where he should meld Q♦ and discard a 5
/// instead of discarding Q♦.
void main() {
  group('Go-Out Optimization Tests', () {
    test('should optimize Ben edge case: meld Queen, discard 5', () {
      // Create Ben's exact scenario from the game state
      final ben = Player(id: '3', name: 'Ben', type: PlayerType.bot);

      // Set up Ben's melds (he has required books)
      ben.melds.addAll([
        // Dirty book: Aces with wilds (13 cards)
        Meld.createMeld([
          PlayingCard(rank: CardRank.ace, suit: Suit.clubs),
          PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.joker, suit: null),
          PlayingCard(rank: CardRank.joker, suit: null),
          PlayingCard(rank: CardRank.ace, suit: Suit.spades),
          PlayingCard(rank: CardRank.ace, suit: Suit.spades),
          PlayingCard(rank: CardRank.ace, suit: Suit.spades),
          PlayingCard(rank: CardRank.two, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.two, suit: Suit.clubs),
          PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
          PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.ace, suit: Suit.clubs),
          PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
        ])!,
        // Clean book: 8s (7 cards)
        Meld.createMeld([
          PlayingCard(rank: CardRank.eight, suit: Suit.clubs),
          PlayingCard(rank: CardRank.eight, suit: Suit.clubs),
          PlayingCard(rank: CardRank.eight, suit: Suit.hearts),
          PlayingCard(rank: CardRank.eight, suit: Suit.spades),
          PlayingCard(rank: CardRank.eight, suit: Suit.spades),
          PlayingCard(rank: CardRank.eight, suit: Suit.hearts),
          PlayingCard(rank: CardRank.eight, suit: Suit.diamonds),
        ])!,
        // Clean book: Kings (7 cards)
        Meld.createMeld([
          PlayingCard(rank: CardRank.king, suit: Suit.spades),
          PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.king, suit: Suit.clubs),
          PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.king, suit: Suit.spades),
          PlayingCard(rank: CardRank.king, suit: Suit.hearts),
        ])!,
        // Queen meld (3 cards - can add more)
        Meld.createMeld([
          PlayingCard(rank: CardRank.queen, suit: Suit.hearts),
          PlayingCard(rank: CardRank.queen, suit: Suit.clubs),
          PlayingCard(rank: CardRank.queen, suit: Suit.hearts),
        ])!,
      ]);

      // Ben's foot has 2 cards: Q♦ (meldable) and 5♥ (less optimal to meld)
      ben.foot.addAll([
        PlayingCard(
          rank: CardRank.queen,
          suit: Suit.diamonds,
        ), // Can add to Queen meld
        PlayingCard(
          rank: CardRank.five,
          suit: Suit.hearts,
        ), // Discard candidate
      ]);

      // Ben is on foot (empty hand)
      ben.hasPickedUpFoot = true;
      ben.hasPlayedDown = true;

      // Create minimal game controller for testing
      final gameController = GameController(players: [ben]);

      final endGameManager = BotEndGameManager();

      // Test the go-out timeline calculation
      final turnsToGoOut = endGameManager.calculateTurnsToGoOut(
        ben,
        gameController,
      );
      expect(
        turnsToGoOut,
        equals(1),
        reason:
            'Ben should be able to go out in 1 turn by melding Q♦ and discarding 5♥',
      );

      // Test the optimization decision
      final decision = endGameManager.handleEndGame(ben, gameController);
      expect(decision, isNotNull, reason: 'Should return a decision for Ben');
      expect(
        decision!.action,
        equals('addToMeld'),
        reason: 'Should choose to meld the Queen',
      );

      final data = decision.data as Map<String, dynamic>;
      final cardToMeld = data['card'] as PlayingCard;
      expect(
        cardToMeld.rank,
        equals(CardRank.queen),
        reason: 'Should choose to meld the Queen over the 5',
      );
      expect(
        cardToMeld.suit,
        equals(Suit.diamonds),
        reason: 'Should meld the Q♦',
      );
    });

    test('should calculate correct turns for various hand scenarios', () {
      final bot = Player(id: '1', name: 'TestBot', type: PlayerType.bot);

      // Set up required books
      bot.melds.addAll([
        // Clean book
        Meld.createMeld([
          PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.king, suit: Suit.clubs),
          PlayingCard(rank: CardRank.king, suit: Suit.spades),
          PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.king, suit: Suit.clubs),
        ])!,
        // Dirty book
        Meld.createMeld([
          PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
          PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.ace, suit: Suit.clubs),
          PlayingCard(rank: CardRank.ace, suit: Suit.spades),
          PlayingCard(rank: CardRank.two, suit: Suit.hearts),
          PlayingCard(rank: CardRank.two, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.joker, suit: null),
        ])!,
      ]);

      bot.hasPickedUpFoot = true;
      bot.hasPlayedDown = true;

      final gameController = GameController(players: [bot]);
      final endGameManager = BotEndGameManager();

      // Test with empty hand
      bot.hand.clear();
      bot.foot.clear();
      expect(
        endGameManager.calculateTurnsToGoOut(bot, gameController),
        equals(0),
      );

      // Test with 1 non-three card (can go out immediately)
      bot.foot.add(PlayingCard(rank: CardRank.five, suit: Suit.hearts));
      expect(
        endGameManager.calculateTurnsToGoOut(bot, gameController),
        equals(1),
      );

      // Test with 1 three (must discard it)
      bot.foot.clear();
      bot.foot.add(PlayingCard(rank: CardRank.three, suit: Suit.hearts));
      expect(
        endGameManager.calculateTurnsToGoOut(bot, gameController),
        equals(1),
      );

      // Test with 2 threes (need 2 turns)
      bot.foot.add(PlayingCard(rank: CardRank.three, suit: Suit.diamonds));
      expect(
        endGameManager.calculateTurnsToGoOut(bot, gameController),
        equals(2),
      );
    });

    test('should return -1 when bot lacks required books', () {
      final bot = Player(id: '1', name: 'TestBot', type: PlayerType.bot);

      // Only has clean book, missing dirty book
      bot.melds.add(
        Meld.createMeld([
          PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.king, suit: Suit.clubs),
          PlayingCard(rank: CardRank.king, suit: Suit.spades),
          PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.king, suit: Suit.clubs),
        ])!,
      );

      bot.hasPickedUpFoot = true;

      final gameController = GameController(players: [bot]);
      final endGameManager = BotEndGameManager();

      expect(
        endGameManager.calculateTurnsToGoOut(bot, gameController),
        equals(-1),
      );
    });
  });
}
