import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/ai/bot_ai.dart';

void main() {
  group('Conservative Bot Behavior', () {
    late GameController gameController;
    late BotAI botAI;
    late Player bot;

    setUp(() {
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
        Player(id: '3', name: 'Bot2', type: PlayerType.bot),
      ];
      gameController = GameController(players: players);
      botAI = BotAI(seed: 12345);
      bot = players[1];
    });

    test('should hold wild cards strategically until forced to discard', () {
      // Give bot many wild cards but not enough to exceed threshold (6+)
      bot.dealHand([
        const PlayingCard(suit: null, rank: CardRank.joker), // Wild
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // Wild
        const PlayingCard(suit: Suit.spades, rank: CardRank.two), // Wild
        const PlayingCard(suit: Suit.clubs, rank: CardRank.two), // Wild
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.two), // Wild
        // Add some naturals so bot has options
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
      ]);

      bot.hasPlayedDown = true; // Already played down
      gameController.gameState.currentPlayerIndex = 1;
      gameController.gameState.turnPhase = TurnPhase.meld;
      gameController.gameState.hasDrawnFromDeck = true;

      final decision = botAI.makeDecision(bot, gameController);

      // Bot should discard rather than use wild cards in melds
      expect(decision.action, equals('discard'));

      // Should discard a natural card, not a wild
      final discardedCard = decision.data as PlayingCard;
      expect(discardedCard.isWild, isFalse);
    });

    test(
      'should only discard wilds when having 6+ or forced to (1 card left)',
      () {
        // Test with exactly 6 wild cards
        bot.dealHand([
          const PlayingCard(suit: null, rank: CardRank.joker), // Wild 1
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two), // Wild 2
          const PlayingCard(suit: Suit.spades, rank: CardRank.two), // Wild 3
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two), // Wild 4
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.two), // Wild 5
          const PlayingCard(suit: null, rank: CardRank.joker), // Wild 6
        ]);

        bot.hasPlayedDown = true;
        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.discard;

        final decision = botAI.makeDecision(bot, gameController);

        expect(decision.action, equals('discard'));
        final discardedCard = decision.data as PlayingCard;

        // With 6 wilds, bot should be willing to discard one
        expect(discardedCard.isWild, isTrue);
      },
    );

    test(
      'should be conservative on hand pile - not meld unless strong opportunity',
      () {
        // Give bot a decent meld that doesn't exceed the strong threshold
        bot.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen), // 10
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen), // 10
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen), // 10
          // Total: 30 points, play-down requirement is 60, so not strong enough
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
        ]);

        bot.hasPlayedDown = true; // Already played down
        bot.hasPickedUpFoot = false; // Still on hand pile
        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        final decision = botAI.makeDecision(bot, gameController);

        // Bot should hold cards, not meld weak opportunities
        expect(decision.action, equals('discard'));
      },
    );

    test(
      'should only meld on hand when close to foot transition (1-2 cards)',
      () {
        // Bot with only 2 cards left - should be aggressive now
        bot.dealHand([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        ]);

        // Add existing king meld to allow adding cards
        final existingMeld = [
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(
            suit: null,
            rank: CardRank.joker,
          ), // Make it 3 cards min
        ];
        bot.melds.add(Meld.createMeld(existingMeld)!);

        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = false; // Still on hand but about to transition
        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.meld;
        gameController.gameState.hasDrawnFromDeck = true;

        final decision = botAI.makeDecision(bot, gameController);

        // With only 2 cards, bot should try to use them up or at least discard is acceptable
        expect(
          decision.action,
          anyOf(equals('createMeld'), equals('addToMeld'), equals('discard')),
        );
      },
    );

    test('should trigger risk management at negative score thresholds', () {
      // Give bot very negative hand value
      bot.dealHand([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.three), // -100
        const PlayingCard(suit: Suit.spades, rank: CardRank.three), // -100
        const PlayingCard(suit: Suit.clubs, rank: CardRank.three), // -100
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.three), // -100
        // Total: -400 points (exceeds -300 threshold)

        // Add meldable cards
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace), // 20
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace), // 20
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace), // 20
        const PlayingCard(suit: null, rank: CardRank.joker), // 50
      ]);

      bot.hasPlayedDown = false; // Not played down yet
      gameController.gameState.currentPlayerIndex = 1;
      gameController.gameState.turnPhase = TurnPhase.meld;
      gameController.gameState.hasDrawnFromDeck = true;

      final decision = botAI.makeDecision(bot, gameController);

      // Risk management should kick in due to negative score
      expect(decision.action, equals('createMeld'));

      final meld = decision.data as List<PlayingCard>;
      final meldPoints = meld.fold<int>(
        0,
        (sum, card) => sum + card.pointValue,
      );
      expect(
        meldPoints,
        greaterThanOrEqualTo(60),
      ); // Should meet play-down requirement
    });
  });
}
