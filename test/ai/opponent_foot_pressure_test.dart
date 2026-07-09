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
  group('Opponent foot pressure', () {
    late EnhancedBotAI botAI;
    late GameController gameController;
    late Player human;
    late Player bot;

    setUp(() {
      botAI = EnhancedBotAI(seed: 42);
      human = Player(id: 'human', name: 'You', type: PlayerType.human);
      bot = Player(id: 'bot', name: 'Clara', type: PlayerType.bot);
      gameController = GameController(players: [human, bot], seed: 42);
      gameController.initializeGame();
      botAI.assignPersonality(bot.id, BotPersonality.conservative);
      bot.hasPlayedDown = true;
      gameController.gameState.currentPlayerIndex = 1;
      gameController.gameState.turnPhase = TurnPhase.meld;
      gameController.gameState.hasDrawnFromDeck = true;
    });

    test('melds aggressively when human is on foot instead of holding', () {
      human.hasPickedUpFoot = true;
      // >5 foot cards avoids _isCompetitivelyThreatened "close to going out".
      human.dealFoot([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ace),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ace),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
      ]);
      // Match meld count so meld-gap competitive threat does not trigger.
      human.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
          const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.ten),
        ])!,
      );

      bot.dealHand([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
        const PlayingCard(suit: Suit.spades, rank: CardRank.six),
      ]);
      bot.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ])!,
      );

      final handSizeGap = bot.currentHand.length - human.currentHand.length;
      final meldGap = human.melds.length - bot.melds.length;
      expect(human.hasPickedUpFoot, isTrue);
      expect(human.currentHand.length, greaterThan(5));
      expect(handSizeGap, lessThan(BotConfig.competitiveThreatHandSizeGap));
      expect(meldGap, lessThan(3));

      final decision = botAI.makeDecision(bot, gameController);

      expect(decision.action, isNot('noMeld'));
      expect(
        decision.action,
        anyOf('createMeld', 'addToMeld', 'createMultipleMelds'),
      );
    });
  });
}
