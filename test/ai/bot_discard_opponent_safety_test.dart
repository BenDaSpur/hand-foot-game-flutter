@Tags(['discard_safety'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/ai/bot_discard_analyzer.dart';
import 'package:hand_foot_game_flutter/ai/bot_game_analyzer.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';

/// Regression tests for opponent-aware discard safety.
///
/// Analytics session 17849271160166016: 18 of 37 bot discards fed ranks the
/// human had already melded face-up (repeated fours/fives/jacks), enabling
/// three discard-pile unlocks and the human's clean books.
void main() {
  group('Opponent-aware discard safety', () {
    late GameController controller;
    late Player humanPlayer;
    late Player botPlayer;
    late BotDiscardAnalyzer discardAnalyzer;

    setUp(() {
      final players = [
        Player(id: '1', name: 'Human', type: PlayerType.human),
        Player(id: '2', name: 'Bot', type: PlayerType.bot),
      ];
      controller = GameController(players: players);
      controller.initializeGame();
      humanPlayer = players[0];
      botPlayer = players[1];
      discardAnalyzer = BotDiscardAnalyzer();
    });

    Meld humanFoursMeld() {
      return Meld(
        rank: CardRank.four,
        cards: [
          const PlayingCard(rank: CardRank.four, suit: Suit.spades),
          const PlayingCard(rank: CardRank.four, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.four, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.four, suit: Suit.clubs),
        ],
      );
    }

    test('analyzer avoids low-rank pair dump into opponent meld', () {
      // Human is visibly collecting fours and holds a large hand — the exact
      // production pattern that let the human unlock the pile three times.
      humanPlayer.melds.add(humanFoursMeld());
      humanPlayer.hand.clear();
      humanPlayer.dealHand(
        List.generate(
          15,
          (i) => PlayingCard(
            rank: CardRank.nine,
            suit: Suit.values[i % Suit.values.length],
          ),
        ),
      );

      botPlayer.hasPlayedDown = true;
      botPlayer.hand.clear();
      botPlayer.dealHand([
        const PlayingCard(rank: CardRank.four, suit: Suit.spades),
        const PlayingCard(rank: CardRank.four, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
        ...List.generate(
          12,
          (i) => PlayingCard(
            rank: CardRank.values[CardRank.ten.index - (i % 3)],
            suit: Suit.values[i % Suit.values.length],
          ),
        ),
      ]);

      final discard = discardAnalyzer.chooseCardToDiscard(
        botPlayer,
        controller.gameState,
      );

      expect(
        discard.rank,
        isNot(equals(CardRank.four)),
        reason:
            'Must not feed fours into the opponent\'s visible fours meld, '
            'even though pair-dumping low ranks is otherwise preferred',
      );
    });

    test('safe low-value discard skips opponent-melded ranks', () {
      humanPlayer.melds.add(humanFoursMeld());
      humanPlayer.melds.add(
        Meld(
          rank: CardRank.five,
          cards: [
            const PlayingCard(rank: CardRank.five, suit: Suit.spades),
            const PlayingCard(rank: CardRank.five, suit: Suit.hearts),
            const PlayingCard(rank: CardRank.five, suit: Suit.clubs),
          ],
        ),
      );

      botPlayer.hand.clear();
      botPlayer.dealHand([
        const PlayingCard(rank: CardRank.four, suit: Suit.hearts), // 5 pts
        const PlayingCard(rank: CardRank.five, suit: Suit.clubs), // 5 pts
        const PlayingCard(rank: CardRank.queen, suit: Suit.spades), // 10 pts
      ]);

      final discard = BotDiscardAnalyzer.chooseSafeLowValueDiscard(
        botPlayer,
        controller.gameState,
      );

      expect(
        discard.rank,
        equals(CardRank.queen),
        reason:
            'Queen is worth more points but is the only rank the human has '
            'not melded — safety beats point value',
      );
    });

    test('safe low-value discard still throws threes first', () {
      humanPlayer.melds.add(humanFoursMeld());

      botPlayer.hand.clear();
      botPlayer.dealHand([
        const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.four, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.queen, suit: Suit.spades),
      ]);

      final discard = BotDiscardAnalyzer.chooseSafeLowValueDiscard(
        botPlayer,
        controller.gameState,
      );

      expect(
        discard.rank,
        equals(CardRank.three),
        reason: 'Threes can never be melded, so they are always safe',
      );
    });

    test('falls back to lowest value when every rank is melded', () {
      humanPlayer.melds.add(humanFoursMeld());
      humanPlayer.melds.add(
        Meld(
          rank: CardRank.queen,
          cards: [
            const PlayingCard(rank: CardRank.queen, suit: Suit.spades),
            const PlayingCard(rank: CardRank.queen, suit: Suit.hearts),
            const PlayingCard(rank: CardRank.queen, suit: Suit.clubs),
          ],
        ),
      );

      botPlayer.hand.clear();
      botPlayer.dealHand([
        const PlayingCard(rank: CardRank.four, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.queen, suit: Suit.spades),
      ]);

      final discard = BotDiscardAnalyzer.chooseSafeLowValueDiscard(
        botPlayer,
        controller.gameState,
      );

      expect(
        discard.rank,
        equals(CardRank.four),
        reason: 'When nothing is safe, discard the lowest-value card',
      );
    });

    test('likelyNeededRanks now tracks any visible meld (size 3+)', () {
      humanPlayer.melds.add(
        Meld(
          rank: CardRank.jack,
          cards: [
            const PlayingCard(rank: CardRank.jack, suit: Suit.spades),
            const PlayingCard(rank: CardRank.jack, suit: Suit.hearts),
            const PlayingCard(rank: CardRank.jack, suit: Suit.clubs),
          ],
        ),
      );

      final gameAnalyzer = BotGameAnalyzer();
      gameAnalyzer.updateOpponentAnalysis(controller.gameState, botPlayer);

      final analysis = gameAnalyzer.opponentAnalysis[humanPlayer.id];
      expect(analysis, isNotNull);
      expect(
        analysis!.likelyNeededRanks,
        contains(CardRank.jack),
        reason:
            'A 3-card meld already reveals the rank the opponent collects — '
            'waiting for 6+ cards missed most feeding opportunities',
      );
    });
  });
}
