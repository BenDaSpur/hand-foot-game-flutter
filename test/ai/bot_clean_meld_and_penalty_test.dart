import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_config.dart';
import 'package:hand_foot_game_flutter/ai/bot_end_game_manager.dart';
import 'package:hand_foot_game_flutter/ai/bot_meld_analyzer.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Bot meld scoring — clean vs arbitrary list order', () {
    late BotMeldAnalyzer analyzer;

    setUp(() {
      analyzer = BotMeldAnalyzer();
    });

    test(
      'findBestMeld prefers all-natural meld when bot still needs a clean book',
      () {
        final dirtyBookCards = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.seven),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
          const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          const PlayingCard(rank: CardRank.joker, suit: null),
        ];

        final bot = Player(id: 'b', name: 'Bot', type: PlayerType.bot);
        bot.hasPlayedDown = true;
        bot.melds.add(Meld.createMeld(dirtyBookCards)!);

        final mixedJackMeld = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.jack),
          const PlayingCard(suit: Suit.spades, rank: CardRank.jack),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
        ];

        final cleanNineMeld = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
        ];

        final candidates = [mixedJackMeld, cleanNineMeld];

        final best = analyzer.findBestMeld(candidates, bot: bot);

        expect(best.any((c) => c.isWild), isFalse);
        expect(best.every((c) => c.rank == CardRank.nine), isTrue);
      },
    );
  });

  group('BotEndGameManager — meld additions use analyzer priorities', () {
    test('handleEndGame addToMeld uses same top pick as BotMeldAnalyzer', () {
      final analyzer = BotMeldAnalyzer();
      final endGameManager = BotEndGameManager(meldAnalyzer: analyzer);

      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      final controller = GameController(players: players);
      controller.initializeGame();

      final botPlayer = players[1];
      botPlayer.hasPlayedDown = true;
      botPlayer.hasPickedUpFoot = true;

      final sixQueens = [
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
        const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
      ];
      botPlayer.melds.add(Meld.createMeld(sixQueens)!);

      botPlayer.hand.clear();
      botPlayer.foot.clear();
      botPlayer.foot.addAll([
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
      ]);

      controller.gameState.currentPlayerIndex = 1;
      controller.gameState.turnPhase = TurnPhase.meld;

      final additions = analyzer.findCardsToAddToExistingMelds(
        botPlayer,
        controller,
      );
      expect(additions, isNotEmpty);

      final decision = endGameManager.handleEndGame(botPlayer, controller);
      expect(decision, isNotNull);
      expect(decision!.action, 'addToMeld');
      final chosen = decision.data as Map<String, dynamic>;
      // Delegates to [BotMeldAnalyzer.findCardsToAddToExistingMelds] — same top pick
      expect(chosen['card'], same(additions.first['card'] as PlayingCard));
    });
  });

  group('Aggressive go-out — opponent penalty heuristic', () {
    test(
      'handleEndGame pushes go-out when human has large unplayed-card penalty',
      () {
        final endGameManager = BotEndGameManager();

        final players = [
          Player(id: '1', name: 'Human', type: PlayerType.human),
          Player(id: '2', name: 'Bot', type: PlayerType.bot),
        ];

        final controller = GameController(players: players);
        controller.initializeGame();

        final human = players[0];
        final botPlayer = players[1];

        human.hand.clear();
        human.foot.clear();
        for (var i = 0; i < 11; i++) {
          human.hand.add(
            const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          );
        }
        for (var i = 0; i < 11; i++) {
          human.foot.add(
            const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          );
        }

        expect(
          human.calculateAllUnplayedCardsValue(),
          greaterThanOrEqualTo(
            BotConfig.aggressiveGoOutOpponentPenaltyThreshold,
          ),
        );

        final cleanBook = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.king),
          const PlayingCard(suit: Suit.spades, rank: CardRank.king),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.king),
        ];

        final dirtyBook = [
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.queen),
          const PlayingCard(suit: Suit.hearts, rank: CardRank.queen),
          const PlayingCard(suit: Suit.spades, rank: CardRank.queen),
          const PlayingCard(rank: CardRank.joker, suit: null),
        ];

        botPlayer.melds.add(Meld.createMeld(cleanBook)!);
        botPlayer.melds.add(Meld.createMeld(dirtyBook)!);

        botPlayer.hand.clear();
        botPlayer.foot.clear();
        botPlayer.foot.add(
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.four),
        );

        botPlayer.hasPlayedDown = true;
        botPlayer.hasPickedUpFoot = true;

        controller.gameState.currentPlayerIndex = 1;
        controller.gameState.turnPhase = TurnPhase.discard;

        final decision = endGameManager.handleEndGame(botPlayer, controller);
        expect(decision, isNotNull);
        expect(decision!.action, 'goOut');
      },
    );
  });
}
