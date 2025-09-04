import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';

void main() {
  group('Bot Competitive Enhancement Tests', () {
    test(
      'should attempt emergency go out when opponent has massive book advantage',
      () {
        // Create scenario from CSV: Human has 8+ books, bot has requirements but was not going out
        final humanPlayer = Player(
          id: '1',
          name: 'You',
          type: PlayerType.human,
        );
        final botPlayer = Player(
          id: '2',
          name: 'TestBot',
          type: PlayerType.bot,
        );

        final gameController = GameController(
          players: [humanPlayer, botPlayer],
        );
        final botAI = EnhancedBotAI();

        // Set up bot with going out requirements (books + foot)
        botPlayer.hasPlayedDown = true;
        botPlayer.hasPickedUpFoot = true;

        // Give bot clean and dirty books
        final cleanBook = Meld(
          rank: CardRank.king,
          cards: [
            const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
            const PlayingCard(rank: CardRank.king, suit: Suit.spades),
            const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
            const PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
            const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
            const PlayingCard(rank: CardRank.king, suit: Suit.spades),
            const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
          ],
          type: MeldType.natural,
        );

        final dirtyBook = Meld(
          rank: CardRank.queen,
          cards: [
            const PlayingCard(rank: CardRank.queen, suit: Suit.hearts),
            const PlayingCard(rank: CardRank.queen, suit: Suit.spades),
            const PlayingCard(rank: CardRank.queen, suit: Suit.clubs),
            const PlayingCard(rank: CardRank.queen, suit: Suit.diamonds),
            const PlayingCard(rank: CardRank.queen, suit: Suit.hearts),
            const PlayingCard(rank: CardRank.two, suit: Suit.spades), // Wild
            const PlayingCard(rank: CardRank.two, suit: Suit.clubs), // Wild
          ],
          type: MeldType.mixed,
        );

        botPlayer.melds.addAll([cleanBook, dirtyBook]);

        // Give bot empty hand (can go out immediately since no cards to discard)
        botPlayer.hand.clear();

        // Set up human with massive book advantage (simulate CSV scenario)
        humanPlayer.hasPlayedDown = true;
        humanPlayer.hasPickedUpFoot = true;
        humanPlayer.hand.addAll([
          const PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.ace, suit: Suit.spades),
        ]);

        // Give human 8 books (massive advantage)
        for (int i = 0; i < 8; i++) {
          final rank = CardRank.values[i % CardRank.values.length];
          if (rank == CardRank.three) continue; // Skip 3s

          final book = Meld(
            rank: rank,
            cards: List.generate(
              7,
              (index) => PlayingCard(rank: rank, suit: Suit.values[index % 4]),
            ),
            type: MeldType.natural,
          );
          humanPlayer.melds.add(book);
        }

        // Set turn to discard phase for bot
        gameController.gameState.turnPhase = TurnPhase.discard;
        gameController.gameState.currentPlayerIndex = 1; // Bot's turn

        // Bot should recognize competitive emergency and go out (empty hand)
        final decision = botAI.makeDecision(botPlayer, gameController);

        // Bot should go out immediately since it has empty hand and books
        expect(
          decision.action,
          equals('goOut'),
          reason:
              'Bot should go out immediately when it has empty hand and going out requirements',
        );
      },
    );

    test(
      'should discard 3s aggressively when bot has catastrophic 3s accumulation',
      () {
        // Create scenario: Bot has 10+ cards mostly 3s (like adaptive bot from CSV)
        final humanPlayer = Player(
          id: '1',
          name: 'You',
          type: PlayerType.human,
        );
        final botPlayer = Player(
          id: '2',
          name: 'TestBot',
          type: PlayerType.bot,
        );

        final gameController = GameController(
          players: [humanPlayer, botPlayer],
        );
        final botAI = EnhancedBotAI();

        // Set up AFTER game controller initialization to avoid auto-dealing overriding our setup
        gameController.gameState.phase = GamePhase.playing;
        gameController.gameState.currentPlayerIndex = 1;
        gameController.gameState.turnPhase = TurnPhase.discard;

        // Set up bot with going out requirements
        botPlayer.hasPlayedDown = true;
        // DON'T pick up foot yet - we want to control the hand directly
        botPlayer.hasPickedUpFoot = false;

        // Give bot required books
        final cleanBook = Meld(
          rank: CardRank.ace,
          cards: List.generate(
            7,
            (i) => PlayingCard(rank: CardRank.ace, suit: Suit.values[i % 4]),
          ),
          type: MeldType.natural,
        );

        final dirtyBook = Meld(
          rank: CardRank.king,
          cards: [
            const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
            const PlayingCard(rank: CardRank.king, suit: Suit.spades),
            const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
            const PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
            const PlayingCard(rank: CardRank.two, suit: Suit.hearts), // Wild
            const PlayingCard(rank: CardRank.two, suit: Suit.spades), // Wild
            const PlayingCard(rank: CardRank.two, suit: Suit.clubs), // Wild
          ],
          type: MeldType.mixed,
        );

        botPlayer.melds.addAll([cleanBook, dirtyBook]);

        // Clear hand and add 10 cards mostly 3s (catastrophic scenario from CSV)
        botPlayer.hand.clear();
        botPlayer.hand.addAll([
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.three, suit: Suit.spades),
          const PlayingCard(rank: CardRank.three, suit: Suit.clubs),
          const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.three, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.three, suit: Suit.spades),
          const PlayingCard(rank: CardRank.three, suit: Suit.clubs),
          const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.four, suit: Suit.hearts), // 1 non-3
          const PlayingCard(rank: CardRank.five, suit: Suit.spades), // 1 non-3
        ]);

        // Verify bot has the expected hand size
        expect(
          botPlayer.hand.length,
          equals(10),
          reason: 'Bot should have 10 cards for this test',
        );

        // Bot should recognize 3s catastrophe and discard 3s aggressively
        final decision = botAI.makeDecision(botPlayer, gameController);

        // Bot should discard a 3 (following rules) but with enhanced strategy
        expect(
          decision.action,
          equals('discard'),
          reason:
              'Bot should discard (following rules) when in discard phase, but prioritize 3s when in catastrophic situation',
        );

        // Verify it's discarding a 3 (worst penalty cards first)
        expect(
          (decision.data as PlayingCard).isThree,
          isTrue,
          reason:
              'Bot should prioritize discarding 3s when holding many penalty cards',
        );
      },
    );

    test('should rush to go out when opponent has book threat', () {
      // Test the _shouldRushToGoOut logic with book threat scenario
      final humanPlayer = Player(id: '1', name: 'You', type: PlayerType.human);
      final botPlayer = Player(id: '2', name: 'TestBot', type: PlayerType.bot);

      final gameController = GameController(players: [humanPlayer, botPlayer]);
      final botAI = EnhancedBotAI();

      // Set up bot with some books but not quite ready to go out immediately
      botPlayer.hasPlayedDown = true;
      botPlayer.hasPickedUpFoot = true;

      // Give bot required books
      final cleanBook = Meld(
        rank: CardRank.ace,
        cards: List.generate(
          7,
          (i) => PlayingCard(rank: CardRank.ace, suit: Suit.values[i % 4]),
        ),
        type: MeldType.natural,
      );

      final dirtyBook = Meld(
        rank: CardRank.king,
        cards: [
          const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          const PlayingCard(rank: CardRank.king, suit: Suit.spades),
          const PlayingCard(rank: CardRank.two, suit: Suit.clubs), // Wild
          const PlayingCard(rank: CardRank.two, suit: Suit.diamonds), // Wild
          const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
          const PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
          const PlayingCard(rank: CardRank.two, suit: Suit.hearts), // Wild
        ],
        type: MeldType.mixed,
      );

      botPlayer.melds.addAll([cleanBook, dirtyBook]);

      // Give bot empty hand to test immediate go out capability
      botPlayer.hand.clear();

      // Set up human with book threat (8+ books, small hand)
      humanPlayer.hasPlayedDown = true;
      humanPlayer.hasPickedUpFoot = true;
      humanPlayer.hand.addAll([
        const PlayingCard(rank: CardRank.seven, suit: Suit.hearts),
        const PlayingCard(rank: CardRank.eight, suit: Suit.spades),
        const PlayingCard(rank: CardRank.nine, suit: Suit.clubs),
      ]);

      // Give human 8 books (book threat scenario)
      for (int i = 0; i < 8; i++) {
        final rank = CardRank.values[(i + 2) % CardRank.values.length];
        if (rank == CardRank.three) continue;

        final book = Meld(
          rank: rank,
          cards: List.generate(
            7,
            (index) => PlayingCard(rank: rank, suit: Suit.values[index % 4]),
          ),
          type: MeldType.natural,
        );
        humanPlayer.melds.add(book);
      }

      // Set turn to discard phase (where go out can happen)
      gameController.gameState.turnPhase = TurnPhase.discard;
      gameController.gameState.currentPlayerIndex = 1;

      // Bot should go out immediately since it has empty hand and books
      final decision = botAI.makeDecision(botPlayer, gameController);

      // Bot should go out since it has no cards and meets requirements
      expect(
        decision.action,
        equals('goOut'),
        reason:
            'Bot should go out immediately when it has empty hand, books, and is in discard phase',
      );
    });
  });
}
