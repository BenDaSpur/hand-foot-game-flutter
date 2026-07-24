import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/ai/bot_meld_analyzer.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

void main() {
  group('Bot Clean Book Protection', () {
    late GameController controller;
    late BotMeldAnalyzer analyzer;

    setUp(() {
      final players = [
        Player(id: 'human', name: 'Human', type: PlayerType.human),
        Player(id: 'bot1', name: 'Bot1', type: PlayerType.bot),
      ];
      controller = GameController(players: players, seed: 42);
      analyzer = BotMeldAnalyzer();
    });

    test('Bot should prefer dirty meld over natural melds for wild card', () {
      // Without a clean book, wilds must go to already-dirty piles — never naturals.
      final bot = Player(id: '2', name: 'Carl', type: PlayerType.bot);
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;

      // Large natural Kings meld (6 cards) — must not contaminate
      final kingsMeld = Meld(
        rank: CardRank.king,
        cards: [
          PlayingCard(rank: CardRank.king, suit: Suit.spades),
          PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          PlayingCard(rank: CardRank.king, suit: Suit.clubs),
          PlayingCard(rank: CardRank.king, suit: Suit.hearts),
        ],
      );

      // Already-dirty 10s meld — preferred wild target
      final tensMeld = Meld(
        rank: CardRank.ten,
        cards: [
          PlayingCard(rank: CardRank.ten, suit: Suit.hearts),
          PlayingCard(rank: CardRank.ten, suit: Suit.spades),
          PlayingCard(rank: CardRank.ten, suit: Suit.hearts),
          PlayingCard(rank: CardRank.two, suit: Suit.clubs),
        ],
      );

      bot.melds.addAll([kingsMeld, tensMeld]);

      final wildCard = PlayingCard(rank: CardRank.two, suit: Suit.diamonds);
      bot.currentHand.add(wildCard);

      final meldOptions = analyzer.findCardsToAddToExistingMelds(
        bot,
        controller,
      );

      final wildCardOptions = meldOptions
          .where((option) => option['card'] == wildCard)
          .toList();

      expect(
        wildCardOptions.length,
        equals(2),
        reason: 'Wild card should be addable to both Kings and 10s melds',
      );

      wildCardOptions.sort((a, b) => b['priority'].compareTo(a['priority']));

      final topChoiceMeld = wildCardOptions.first['meld'] as Meld;
      expect(
        topChoiceMeld.rank,
        equals(CardRank.ten),
        reason: 'Bot should prefer adding wild to already-dirty 10s meld',
      );

      final kingsOption = wildCardOptions.firstWhere(
        (option) => (option['meld'] as Meld).rank == CardRank.king,
      );
      expect(
        kingsOption['priority'] as int,
        lessThanOrEqualTo(-50000),
        reason: 'Natural Kings meld must be hard-blocked without clean book',
      );
    });

    test(
      'Bot hard-blocks contaminating natural meld when no clean book exists',
      () {
        // Create bot with only one large natural meld and no clean book
        final bot = Player(id: '2', name: 'Carl', type: PlayerType.bot);
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;

        // Only Kings meld, no alternatives
        final kingsMeld = Meld(
          rank: CardRank.king,
          cards: [
            PlayingCard(rank: CardRank.king, suit: Suit.spades),
            PlayingCard(rank: CardRank.king, suit: Suit.hearts),
            PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
            PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
            PlayingCard(rank: CardRank.king, suit: Suit.clubs),
            PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          ],
        );

        bot.melds.add(kingsMeld);

        // Wild card that can only go to Kings meld
        final wildCard = PlayingCard(rank: CardRank.two, suit: Suit.diamonds);
        bot.currentHand.add(wildCard);

        final meldOptions = analyzer.findCardsToAddToExistingMelds(
          bot,
          controller,
        );
        final wildCardOptions = meldOptions
            .where((option) => option['card'] == wildCard)
            .toList();

        expect(
          wildCardOptions.length,
          equals(1),
          reason: 'Should find the Kings meld as only option',
        );

        final option = wildCardOptions.first;
        final priority = option['priority'] as int;

        // Clean-book-first: never spoil the only natural path when clean book missing
        expect(
          priority,
          lessThanOrEqualTo(-50000),
          reason: 'Must hard-block contamination until a clean book exists',
        );
      },
    );

    test(
      'Bot may contaminate extra natural meld only after clean book exists',
      () {
        final bot = Player(id: '2', name: 'Carl', type: PlayerType.bot);
        bot.hasPlayedDown = true;
        bot.hasPickedUpFoot = true;

        // Existing clean book (sevens)
        bot.melds.add(
          Meld(
            rank: CardRank.seven,
            cards: [
              PlayingCard(rank: CardRank.seven, suit: Suit.spades),
              PlayingCard(rank: CardRank.seven, suit: Suit.hearts),
              PlayingCard(rank: CardRank.seven, suit: Suit.diamonds),
              PlayingCard(rank: CardRank.seven, suit: Suit.clubs),
              PlayingCard(rank: CardRank.seven, suit: Suit.spades),
              PlayingCard(rank: CardRank.seven, suit: Suit.hearts),
              PlayingCard(rank: CardRank.seven, suit: Suit.diamonds),
            ],
          ),
        );

        // Only other meld is natural kings — wild has no dirty target
        bot.melds.add(
          Meld(
            rank: CardRank.king,
            cards: [
              PlayingCard(rank: CardRank.king, suit: Suit.spades),
              PlayingCard(rank: CardRank.king, suit: Suit.hearts),
              PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
              PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
              PlayingCard(rank: CardRank.king, suit: Suit.clubs),
              PlayingCard(rank: CardRank.king, suit: Suit.hearts),
            ],
          ),
        );

        final wildCard = PlayingCard(rank: CardRank.two, suit: Suit.diamonds);
        bot.currentHand.add(wildCard);

        expect(bot.hasCleanBook, isTrue);

        final meldOptions = analyzer.findCardsToAddToExistingMelds(
          bot,
          controller,
        );
        final wildCardOptions = meldOptions
            .where((option) => option['card'] == wildCard)
            .toList();

        expect(wildCardOptions, isNotEmpty);
        final priority = wildCardOptions.first['priority'] as int;
        expect(
          priority,
          greaterThan(-50000),
          reason:
              'With a clean book secured, contamination of another natural '
              'pile is allowed when no dirty alternative exists',
        );
      },
    );

    test('Bot should prefer already dirty melds over clean melds', () {
      final bot = Player(id: '2', name: 'Carl', type: PlayerType.bot);
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;

      // Clean Kings meld
      final cleanKingsMeld = Meld(
        rank: CardRank.king,
        cards: [
          PlayingCard(rank: CardRank.king, suit: Suit.spades),
          PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
        ],
      );

      // Already dirty Queens meld (same size)
      final dirtyQueensMeld = Meld(
        rank: CardRank.queen,
        cards: [
          PlayingCard(rank: CardRank.queen, suit: Suit.spades),
          PlayingCard(rank: CardRank.queen, suit: Suit.hearts),
          PlayingCard(rank: CardRank.two, suit: Suit.clubs), // Already has wild
        ],
      );

      bot.melds.addAll([cleanKingsMeld, dirtyQueensMeld]);

      final wildCard = PlayingCard(rank: CardRank.two, suit: Suit.diamonds);
      bot.currentHand.add(wildCard);

      final meldOptions = analyzer.findCardsToAddToExistingMelds(
        bot,
        controller,
      );
      final wildCardOptions = meldOptions
          .where((option) => option['card'] == wildCard)
          .toList();

      wildCardOptions.sort((a, b) => b['priority'].compareTo(a['priority']));

      final topChoice = wildCardOptions.first;
      final topChoiceMeld = topChoice['meld'] as Meld;

      expect(
        topChoiceMeld.rank,
        equals(CardRank.queen),
        reason:
            'Bot should prefer already dirty Queens meld over clean Kings meld',
      );
    });
  });
}
