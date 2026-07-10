import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_config.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Aggressive hand-to-foot rush', () {
    late EnhancedBotAI botAI;
    late GameController gameController;
    late Player human;
    late Player bob;

    setUp(() {
      botAI = EnhancedBotAI(seed: 577904);
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bob = Player(id: 'bob', name: 'Bob', type: PlayerType.bot);
      gameController = GameController(players: [human, bob], seed: 577904);
      gameController.initializeGame();
      botAI.assignPersonality(bob.id, BotPersonality.aggressive);
      bob.hasPlayedDown = true;
      gameController.gameState.currentPlayerIndex = 1;
      gameController.gameState.turnPhase = TurnPhase.meld;
      gameController.gameState.hasDrawnFromDeck = true;
    });

    test('melds instead of holding when opponent is on foot with 7 cards', () {
      human.hasPickedUpFoot = true;
      human.dealFoot([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ]);

      bob.hand.clear();
      bob.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        const PlayingCard(suit: Suit.spades, rank: CardRank.five),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
      ]);
      bob.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ])!,
      );

      expect(bob.currentHand.length, 7);
      expect(human.hasPickedUpFoot, isTrue);

      final decision = botAI.makeDecision(bob, gameController);

      expect(decision.action, isNot('noMeld'));
      expect(
        decision.action,
        anyOf('createMeld', 'addToMeld', 'createMultipleMelds'),
      );
    });

    test('melds aggressively with 3 cards when opponent is on foot', () {
      human.hasPickedUpFoot = true;
      human.dealFoot([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ]);

      bob.hand.clear();
      bob.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
      ]);
      bob.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ])!,
      );

      final decision = botAI.makeDecision(bob, gameController);

      expect(decision.action, isNot('noMeld'));
      expect(
        decision.action,
        anyOf('createMeld', 'addToMeld', 'createMultipleMelds'),
      );
    });

    test('aggressive bot with 5 cards melds without opponent on foot', () {
      bob.hand.clear();
      bob.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
      ]);
      bob.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ])!,
      );

      expect(bob.currentHand.length, 5);
      expect(
        bob.currentHand.length,
        lessThanOrEqualTo(BotConfig.handToFootRushAggressiveThreshold),
      );

      final decision = botAI.makeDecision(bob, gameController);

      expect(decision.action, isNot('noMeld'));
      expect(
        decision.action,
        anyOf('createMeld', 'addToMeld', 'createMultipleMelds'),
      );
    });
  });
}
