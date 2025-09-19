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

    test('Bot should prefer smaller meld over large clean meld for wild card', () {
      // Create a bot player with the same scenario as Carl
      final bot = Player(id: '2', name: 'Carl', type: PlayerType.bot);
      bot.hasPlayedDown = true;
      bot.hasPickedUpFoot = true;

      // Add melds exactly like Carl's scenario
      // Large clean Kings meld (6 cards)
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

      // Small clean 10s meld (3 cards)
      final tensMeld = Meld(
        rank: CardRank.ten,
        cards: [
          PlayingCard(rank: CardRank.ten, suit: Suit.hearts),
          PlayingCard(rank: CardRank.ten, suit: Suit.spades),
          PlayingCard(rank: CardRank.ten, suit: Suit.hearts),
        ],
      );

      bot.melds.addAll([kingsMeld, tensMeld]);

      // Add a wild card to bot's hand
      final wildCard = PlayingCard(rank: CardRank.two, suit: Suit.diamonds);
      bot.currentHand.add(wildCard);

      // Find all possible meld additions
      final meldOptions = analyzer.findCardsToAddToExistingMelds(
        bot,
        controller,
      );

      // Filter for wild card additions
      final wildCardOptions = meldOptions
          .where((option) => option['card'] == wildCard)
          .toList();

      expect(
        wildCardOptions.length,
        equals(2),
        reason: 'Wild card should be addable to both Kings and 10s melds',
      );

      // Sort by priority (highest first)
      wildCardOptions.sort((a, b) => b['priority'].compareTo(a['priority']));

      // The top priority should be the smaller 10s meld, not the large Kings meld
      final topChoice = wildCardOptions.first;
      final topChoiceMeld = topChoice['meld'] as Meld;

      expect(
        topChoiceMeld.rank,
        equals(CardRank.ten),
        reason:
            'Bot should prefer adding wild to smaller 10s meld instead of large Kings meld',
      );

      // Verify the Kings meld gets very negative priority due to protection
      final kingsOption = wildCardOptions.firstWhere(
        (option) => (option['meld'] as Meld).rank == CardRank.king,
      );
      final kingsOptionPriority = kingsOption['priority'] as int;

      expect(
        kingsOptionPriority,
        lessThan(-10000),
        reason: 'Large clean Kings meld should get massive negative priority',
      );
    });

    test(
      'Bot should still allow contaminating large clean meld if no alternatives',
      () {
        // Create bot with only one large clean meld and no alternatives
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

        // Should not be the massive negative value since no alternatives exist
        expect(
          priority,
          greaterThan(-50000),
          reason: 'Should allow contamination when no alternatives exist',
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
