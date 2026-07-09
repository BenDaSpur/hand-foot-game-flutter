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
  group('Foot phase melding improvements', () {
    late EnhancedBotAI botAI;
    late GameController gameController;
    late Player human;
    late Player bot;

    setUp(() {
      botAI = EnhancedBotAI(seed: 42);
      human = Player(id: '1', name: 'You', type: PlayerType.human);
      bot = Player(id: '2', name: 'Carl', type: PlayerType.bot);
      gameController = GameController(players: [human, bot], seed: 42);
      gameController.initializeGame();
      botAI.assignPersonality(bot.id, BotPersonality.conservative);
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;
      gameController.gameState.currentPlayerIndex = 1;
      gameController.gameState.turnPhase = TurnPhase.meld;
      gameController.gameState.hasDrawnFromDeck = true;
    });

    void dealBotFoot(List<PlayingCard> cards) {
      bot.foot.clear();
      bot.foot.addAll(cards);
    }

    test('conservative bot melds instead of holding with 10+ foot cards', () {
      dealBotFoot([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        const PlayingCard(suit: Suit.spades, rank: CardRank.five),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.six),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.six),
        const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
      ]);
      bot.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ])!,
      );

      expect(
        bot.currentHand.length,
        greaterThanOrEqualTo(BotConfig.footPhaseAggressiveMeldingThreshold),
      );

      final decision = botAI.makeDecision(bot, gameController);

      expect(decision.action, isNot('noMeld'));
      expect(
        decision.action,
        anyOf('createMeld', 'addToMeld', 'createMultipleMelds'),
      );
    });

    test(
      'bot on foot with dirty books creates clean meld when naturals available',
      () {
        // Alex-style: two dirty books, missing clean book
        dealBotFoot([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          const PlayingCard(suit: Suit.spades, rank: CardRank.four),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.three),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
          const PlayingCard(suit: Suit.spades, rank: CardRank.three),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.three),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.three),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        ]);

        final dirtySeven = Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.two),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
        ])!;
        final dirtyNine = Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.two),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
        ])!;
        bot.melds.addAll([dirtySeven, dirtyNine]);

        expect(bot.hasDirtyBook, isTrue);
        expect(bot.hasCleanBook, isFalse);

        final decision = botAI.makeDecision(bot, gameController);

        expect(decision.action, isNot('noMeld'));
        if (decision.action == 'createMeld') {
          final meld = decision.data as List<PlayingCard>;
          expect(meld.any((c) => c.isWild), isFalse);
        }
      },
    );

    test('bot on foot melds aggressively when human threatens go-out', () {
      human.hasPickedUpFoot = true;
      human.foot.clear();
      human.foot.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        const PlayingCard(suit: Suit.spades, rank: CardRank.joker),
      ]);
      human.melds.addAll([
        Meld.createMeld(
          List.generate(
            7,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.four),
          ),
        )!,
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
          const PlayingCard(suit: Suit.spades, rank: CardRank.five),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
        ])!,
        Meld.createMeld(
          List.generate(
            7,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.king),
          ),
        )!,
        Meld.createMeld(
          List.generate(
            7,
            (i) => PlayingCard(suit: Suit.values[i % 4], rank: CardRank.seven),
          ),
        )!,
      ]);

      dealBotFoot([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.ten),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
        const PlayingCard(suit: Suit.spades, rank: CardRank.ten),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.eight),
      ]);
      bot.melds.add(
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        ])!,
      );

      final decision = botAI.makeDecision(bot, gameController);

      expect(decision.action, isNot('noMeld'));
      expect(
        decision.action,
        anyOf('createMeld', 'addToMeld', 'createMultipleMelds'),
      );
    });
  });
}
