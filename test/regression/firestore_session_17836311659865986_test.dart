import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_config.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

/// Regression tests from Firestore session_17836311659865986 (gameSeed 782846).
///
/// Round 1 scores: human 3325, Alex (adaptive) 1140, Carl (conservative) 1185.
/// Failure modes: foot hoarding, dirty-book inflation, draw loops with 10+ cards.
void main() {
  group('Firestore session_17836311659865986 regressions', () {
    const sessionSeed = 782846;

    late EnhancedBotAI botAI;
    late GameController gameController;
    late Player human;
    late Player carl;
    late Player alex;

    setUp(() {
      botAI = EnhancedBotAI(seed: sessionSeed);
      human = Player(id: '1', name: 'You', type: PlayerType.human);
      carl = Player(id: '3', name: 'Carl', type: PlayerType.bot);
      alex = Player(id: '2', name: 'Alex', type: PlayerType.bot);
      gameController = GameController(
        players: [human, alex, carl],
        seed: sessionSeed,
      );
      gameController.initializeGame();
      botAI.assignPersonality(carl.id, BotPersonality.conservative);
      botAI.assignPersonality(alex.id, BotPersonality.adaptive);
      gameController.gameState.turnPhase = TurnPhase.meld;
      gameController.gameState.hasDrawnFromDeck = true;
    });

    void setupFootPlayer(Player bot, List<PlayingCard> footCards) {
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;
      bot.foot.clear();
      bot.foot.addAll(footCards);
      gameController.gameState.currentPlayerIndex = gameController
          .gameState
          .players
          .indexWhere((p) => p.id == bot.id);
    }

    test(
      'Carl conservative melds on foot with 11 cards (session draw-loop fix)',
      () {
        setupFootPlayer(carl, [
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
          const PlayingCard(suit: Suit.clubs, rank: CardRank.eight),
        ]);
        carl.melds.add(
          Meld.createMeld([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
            const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          ])!,
        );

        expect(
          carl.currentHand.length,
          greaterThanOrEqualTo(BotConfig.footPhaseAggressiveMeldingThreshold),
        );

        final decision = botAI.makeDecision(carl, gameController);

        expect(decision.action, isNot('noMeld'));
        expect(
          decision.action,
          anyOf('createMeld', 'addToMeld', 'createMultipleMelds'),
        );
      },
    );

    test('Alex adaptive builds clean book instead of growing dirty piles', () {
      setupFootPlayer(alex, [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.four),
        const PlayingCard(suit: Suit.spades, rank: CardRank.four),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.four),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
        const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ten),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.two),
      ]);
      alex.melds.addAll([
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.two),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
        ])!,
        Meld.createMeld([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
        ])!,
      ]);

      final decision = botAI.makeDecision(alex, gameController);

      expect(decision.action, isNot('noMeld'));
      if (decision.action == 'createMeld') {
        final meld = decision.data as List<PlayingCard>;
        expect(meld.any((c) => c.isWild), isFalse);
      }
    });
  });
}
