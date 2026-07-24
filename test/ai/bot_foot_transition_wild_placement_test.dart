import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_end_game_manager.dart';
import 'package:hand_foot_game_flutter/ai/bot_foot_transition_manager.dart';
import 'package:hand_foot_game_flutter/ai/bot_meld_analyzer.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

/// Regression tests for wild-card placement during foot transition.
///
/// Analytics session 17849271160166016: at foot transition a bot dumped
/// 2♦ + Joker onto its only clean 3-ace meld (its sole clean-book lane)
/// even though multiple already-dirty melds had wild capacity. With no
/// clean book the bot could never go out.
void main() {
  group('Foot transition wild placement', () {
    late BotFootTransitionManager transitionManager;
    late GameController gameController;
    late Player botPlayer;

    Meld cleanAcesMeld() {
      return Meld(
        rank: CardRank.ace,
        cards: [
          const PlayingCard(rank: CardRank.ace, suit: Suit.spades),
          const PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
        ],
      );
    }

    Meld dirtySevensMeld() {
      return Meld(
        rank: CardRank.seven,
        cards: [
          const PlayingCard(rank: CardRank.seven, suit: Suit.clubs),
          const PlayingCard(rank: CardRank.seven, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.seven, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.two, suit: Suit.clubs),
        ],
      );
    }

    setUp(() {
      transitionManager = BotFootTransitionManager();

      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];

      gameController = GameController(players: players);
      gameController.initializeGame();
      botPlayer = players[1];
      botPlayer.hasPlayedDown = true;
      botPlayer.hasPickedUpFoot = false;

      gameController.gameState.currentPlayerIndex = 1;
      gameController.gameState.turnPhase = TurnPhase.discard;
    });

    test('wild goes to already-dirty meld, never the clean-book lane', () {
      botPlayer.melds.addAll([cleanAcesMeld(), dirtySevensMeld()]);

      botPlayer.hand.clear();
      botPlayer.dealHand([
        const PlayingCard(rank: CardRank.two, suit: Suit.diamonds), // wild
        const PlayingCard(rank: CardRank.four, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.eight, suit: Suit.clubs),
        const PlayingCard(rank: CardRank.nine, suit: Suit.diamonds),
      ]);

      final decision = transitionManager.handleFootTransition(
        botPlayer,
        gameController,
      );

      expect(decision, isNotNull);
      expect(
        decision!.action,
        equals('addToMeld'),
        reason: 'Bot should dump the wild into a meld while transitioning',
      );

      final addition = decision.data as Map<String, dynamic>;
      final targetMeld = addition['meld'] as Meld;
      final card = addition['card'] as PlayingCard;

      expect(card.isWild, isTrue);
      expect(
        targetMeld.rank,
        equals(CardRank.seven),
        reason:
            'Wild must go to the already-dirty sevens meld, not the clean '
            'aces meld (the only clean-book lane)',
      );
    });

    test('wild is held (not dumped on clean meld) when no dirty target', () {
      botPlayer.melds.add(cleanAcesMeld());

      botPlayer.hand.clear();
      botPlayer.dealHand([
        const PlayingCard(rank: CardRank.two, suit: Suit.diamonds), // wild
        const PlayingCard(rank: CardRank.four, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.eight, suit: Suit.clubs),
      ]);

      final decision = transitionManager.handleFootTransition(
        botPlayer,
        gameController,
      );

      expect(decision, isNotNull);
      expect(
        decision!.action,
        equals('discard'),
        reason:
            'With no clean book and no dirty wild target, the bot must '
            'discard instead of poisoning its clean aces meld',
      );

      final discarded = decision.data as PlayingCard;
      expect(
        discarded.isWild,
        isFalse,
        reason: 'The wild should be held, not thrown away',
      );
      expect(
        BotMeldAnalyzer.isAllNatural(botPlayer.melds.first),
        isTrue,
        reason: 'Clean aces meld must remain natural',
      );
    });

    test('analyzer hard-blocks wild onto naturals-only meld even after a clean '
        'book exists, while a dirty meld has capacity', () {
      final analyzer = BotMeldAnalyzer();
      final bot = Player(id: '2', name: 'Bot', type: PlayerType.bot);
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;

      // Completed clean book (sevens)
      bot.melds.add(
        Meld(
          rank: CardRank.seven,
          cards: List.generate(
            7,
            (i) => PlayingCard(
              rank: CardRank.seven,
              suit: Suit.values[i % Suit.values.length],
            ),
          ),
        ),
      );
      // Clean 3-ace meld (second clean-book lane)
      bot.melds.add(cleanAcesMeld());
      // Dirty kings meld with wild capacity
      bot.melds.add(
        Meld(
          rank: CardRank.king,
          cards: [
            const PlayingCard(rank: CardRank.king, suit: Suit.spades),
            const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
            const PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
            const PlayingCard(rank: CardRank.two, suit: Suit.hearts),
          ],
        ),
      );

      final wildCard = const PlayingCard(
        rank: CardRank.two,
        suit: Suit.diamonds,
      );
      bot.currentHand.add(wildCard);

      expect(bot.hasCleanBook, isTrue);

      final options = analyzer.findCardsToAddToExistingMelds(
        bot,
        gameController,
      );
      final wildOptions = options
          .where((option) => option['card'] == wildCard)
          .toList();

      final acesOption = wildOptions.firstWhere(
        (option) => (option['meld'] as Meld).rank == CardRank.ace,
      );
      expect(
        acesOption['priority'] as int,
        lessThanOrEqualTo(-50000),
        reason:
            'Naturals-only aces meld must stay hard-blocked while the '
            'dirty kings meld can accept the wild',
      );

      wildOptions.sort((a, b) => b['priority'].compareTo(a['priority']));
      expect(
        (wildOptions.first['meld'] as Meld).rank,
        equals(CardRank.king),
        reason: 'Dirty kings meld must be the preferred wild target',
      );
    });

    test('go-out paths never dump a wild onto the bot\'s only clean book', () {
      // Found via full-game simulation: with both books secured and 1-2
      // cards left, the go-out optimizer added a wild to the completed
      // clean book, flipping it dirty and revoking go-out eligibility.
      final bot = Player(id: '2', name: 'Bot', type: PlayerType.bot);
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;

      final cleanBook = Meld(
        rank: CardRank.seven,
        cards: List.generate(
          7,
          (i) => PlayingCard(
            rank: CardRank.seven,
            suit: Suit.values[i % Suit.values.length],
          ),
        ),
      );
      final dirtyBook = Meld(
        rank: CardRank.king,
        cards: [
          const PlayingCard(rank: CardRank.king, suit: Suit.spades),
          const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
          const PlayingCard(rank: CardRank.king, suit: Suit.spades),
          const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.two, suit: Suit.hearts),
        ],
      );
      bot.melds.addAll([cleanBook, dirtyBook]);
      expect(bot.canGoOutWithBooks, isTrue);

      const wildCard = PlayingCard(rank: CardRank.two, suit: Suit.diamonds);

      expect(
        BotEndGameManager.wouldDestroyOnlyCleanBook(bot, cleanBook, wildCard),
        isTrue,
        reason: 'Wild onto the only clean book revokes go-out eligibility',
      );
      expect(
        BotEndGameManager.wouldDestroyOnlyCleanBook(bot, dirtyBook, wildCard),
        isFalse,
        reason: 'Wild onto an already-dirty book is safe',
      );
      expect(
        BotEndGameManager.isSafeAddToMeld(bot, {
          'meldIndex': 0,
          'card': wildCard,
        }),
        isFalse,
        reason: 'Safety gate must reject additions that break go-out books',
      );
    });
  });
}
