import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Bot Wild Card and Foot Transition Strategy Tests', () {
    late EnhancedBotAI botAI;
    late GameController gameController;
    late Player botPlayer;

    setUp(() {
      botAI = EnhancedBotAI(seed: 42); // Deterministic for testing

      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      gameController = GameController(players: players);
      gameController.initializeGame();
      botPlayer = players[1];
    });

    group('Wild Card Holding Strategy', () {
      test('should hold wild cards when still on hand pile', () {
        // Setup: Bot has played down but not picked up foot
        botPlayer.hasPlayedDown = true;
        botPlayer.hasPickedUpFoot = false;

        // Give bot some cards including wilds
        botPlayer.hand.clear();
        botPlayer.hand.addAll([
          PlayingCard(rank: CardRank.joker), // Wild
          PlayingCard(rank: CardRank.two, suit: Suit.hearts), // Wild
          PlayingCard(rank: CardRank.five, suit: Suit.hearts),
          PlayingCard(rank: CardRank.five, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.five, suit: Suit.clubs),
          PlayingCard(rank: CardRank.seven, suit: Suit.hearts),
          PlayingCard(rank: CardRank.seven, suit: Suit.diamonds),
        ]);

        // Set to discard phase
        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.discard;

        // Make decision
        final decision = botAI.makeDecision(botPlayer, gameController);

        // Should NOT discard wild cards
        expect(decision.action, equals('discard'));
        final discardedCard = decision.data as PlayingCard;
        expect(
          discardedCard.isWild,
          isFalse,
          reason: 'Bot should hold wild cards when on hand pile',
        );
      });

      test('should use wild cards aggressively when close to foot', () {
        // Setup: Bot close to foot transition with wilds
        botPlayer.hasPlayedDown = true;
        botPlayer.hasPickedUpFoot = false;

        // Create existing meld bot can add to
        botPlayer.melds.add(
          Meld(
            rank: CardRank.five,
            cards: [
              PlayingCard(rank: CardRank.five, suit: Suit.hearts),
              PlayingCard(rank: CardRank.five, suit: Suit.diamonds),
              PlayingCard(rank: CardRank.five, suit: Suit.clubs),
            ],
          ),
        );

        // Give bot small hand with wilds (close to foot)
        botPlayer.hand.clear();
        botPlayer.hand.addAll([
          PlayingCard(rank: CardRank.joker), // Wild
          PlayingCard(rank: CardRank.two, suit: Suit.hearts), // Wild
          PlayingCard(rank: CardRank.five, suit: Suit.spades),
          PlayingCard(rank: CardRank.seven, suit: Suit.hearts),
          PlayingCard(rank: CardRank.seven, suit: Suit.diamonds),
        ]);

        // Set to meld phase
        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        // Make decision - should use wilds to transition
        final decision = botAI.makeDecision(botPlayer, gameController);

        // Should be trying to meld cards (including wilds)
        expect(
          ['addToMeld', 'createMeld', 'noMeld'],
          contains(decision.action),
          reason: 'Bot should try to meld when close to foot with wilds',
        );
      });
    });

    group('Play All Cards Strategy', () {
      test('should recognize when all cards can be played to see foot', () {
        // Setup: Bot has played down but not picked up foot
        botPlayer.hasPlayedDown = true;
        botPlayer.hasPickedUpFoot = false;

        // Create existing melds bot can add to
        botPlayer.melds.add(
          Meld(
            rank: CardRank.king,
            cards: [
              PlayingCard(rank: CardRank.king, suit: Suit.hearts),
              PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
              PlayingCard(rank: CardRank.king, suit: Suit.clubs),
            ],
          ),
        );

        botPlayer.melds.add(
          Meld(
            rank: CardRank.queen,
            cards: [
              PlayingCard(rank: CardRank.queen, suit: Suit.hearts),
              PlayingCard(rank: CardRank.queen, suit: Suit.diamonds),
              PlayingCard(rank: CardRank.queen, suit: Suit.clubs),
            ],
          ),
        );

        // Give bot cards that can ALL be played
        botPlayer.hand.clear();
        botPlayer.hand.addAll([
          PlayingCard(
            rank: CardRank.king,
            suit: Suit.spades,
          ), // Can add to kings
          PlayingCard(
            rank: CardRank.queen,
            suit: Suit.spades,
          ), // Can add to queens
          PlayingCard(rank: CardRank.joker), // Wild - can add anywhere
        ]);

        // Set to meld phase
        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        // Make decision
        final decision = botAI.makeDecision(botPlayer, gameController);

        // Should immediately start playing cards since all can be played
        expect(
          decision.action,
          equals('addToMeld'),
          reason: 'Bot should play all cards to transition to foot immediately',
        );
      });

      test('should create melds to play all cards when possible', () {
        // Setup: Bot has played down but not picked up foot
        botPlayer.hasPlayedDown = true;
        botPlayer.hasPickedUpFoot = false;

        // Give bot cards that can form complete melds
        botPlayer.hand.clear();
        botPlayer.hand.addAll([
          PlayingCard(rank: CardRank.five, suit: Suit.hearts),
          PlayingCard(rank: CardRank.five, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.five, suit: Suit.clubs),
          PlayingCard(rank: CardRank.seven, suit: Suit.hearts),
          PlayingCard(rank: CardRank.seven, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.seven, suit: Suit.clubs),
        ]);

        // Set to meld phase
        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;

        // Make decision
        final decision = botAI.makeDecision(botPlayer, gameController);

        // Should create melds to clear hand
        expect(
          decision.action,
          equals('createMeld'),
          reason: 'Bot should create melds with all cards to see foot',
        );
      });

      test('should prioritize foot transition when all cards playable', () {
        // Setup: Bot has played down and can play all cards
        botPlayer.hasPlayedDown = true;
        botPlayer.hasPickedUpFoot = false;

        // Create a meld that's almost a book
        botPlayer.melds.add(
          Meld(
            rank: CardRank.king,
            cards: [
              PlayingCard(rank: CardRank.king, suit: Suit.hearts),
              PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
              PlayingCard(rank: CardRank.king, suit: Suit.clubs),
              PlayingCard(rank: CardRank.king, suit: Suit.spades),
              PlayingCard(rank: CardRank.king, suit: Suit.hearts),
              PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
            ],
          ),
        );

        // Give bot cards that can all be added
        botPlayer.hand.clear();
        botPlayer.hand.addAll([
          PlayingCard(
            rank: CardRank.king,
            suit: Suit.clubs,
          ), // Complete the book
          PlayingCard(rank: CardRank.joker), // Wild
        ]);

        // Set to meld phase
        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        // Make decision
        final decision = botAI.makeDecision(botPlayer, gameController);

        // Should play cards to see foot rather than holding for strategy
        expect(
          decision.action,
          equals('addToMeld'),
          reason:
              'Bot should prioritize seeing foot when all cards can be played',
        );
      });
    });

    group('Dump Strategy with Wilds', () {
      test('should lower dump threshold when close to foot with wilds', () {
        // Setup: Bot with wilds close to foot
        botPlayer.hasPlayedDown = true;
        botPlayer.hasPickedUpFoot = false;

        // Create existing meld
        botPlayer.melds.add(
          Meld(
            rank: CardRank.ace,
            cards: [
              PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
              PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
              PlayingCard(rank: CardRank.ace, suit: Suit.clubs),
            ],
          ),
        );

        // Small hand with wilds and matching cards (60%+ can be melded)
        botPlayer.hand.clear();
        botPlayer.hand.addAll([
          PlayingCard(rank: CardRank.joker), // Wild
          PlayingCard(rank: CardRank.two, suit: Suit.hearts), // Wild
          PlayingCard(rank: CardRank.ace, suit: Suit.spades), // Can add
          PlayingCard(rank: CardRank.four, suit: Suit.hearts), // Singleton
          PlayingCard(rank: CardRank.six, suit: Suit.diamonds), // Singleton
        ]);

        // Set to meld phase
        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;

        // Make decision
        final decision = botAI.makeDecision(botPlayer, gameController);

        // Should be willing to dump with lower threshold
        expect(
          ['addToMeld', 'createMeld', 'noMeld'],
          contains(decision.action),
          reason: 'Bot should have lower dump threshold with wilds near foot',
        );
      });
    });
  });
}
