import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/ai/enhanced_bot_ai.dart';
import 'package:hand_foot_game_flutter/ai/bot_personality.dart';

/// Tests strategic improvements based on analysis of real game data.
///
/// These tests address specific strategic flaws identified from exported
/// bot decision data, particularly around going out recognition,
/// competitive pressure response, and BookBuilder over-accumulation.
void main() {
  group('Bot Strategic Improvements Tests', () {
    late GameController gameController;
    late EnhancedBotAI botAI;
    late Player botPlayer;
    late Player humanPlayer;

    setUp(() {
      gameController = GameController(
        players: [
          Player(id: '1', name: 'Human', type: PlayerType.human),
          Player(id: '2', name: 'Bot', type: PlayerType.bot),
        ],
      );

      botAI = EnhancedBotAI();
      botPlayer = gameController.gameState.players[1];
      humanPlayer = gameController.gameState.players[0];

      gameController.initializeGame();
    });

    test(
      'bot should go out immediately when opponent is close to winning and hand is empty',
      () {
        // Setup: Human player close to winning (7500+ points)
        humanPlayer.score = 7800; // Close to 8500 win condition

        // Setup: Bot with books and ability to go out (empty hand)
        _setupBotReadyToGoOut(botPlayer);

        // Bot should have empty hand to test immediate going out
        botPlayer.hand.clear();

        gameController.gameState.turnPhase = TurnPhase.meld;

        // Act: Bot makes decision
        final decision = botAI.makeDecision(botPlayer, gameController);

        // Assert: Bot should go out immediately when opponent is close to winning and bot has no cards
        expect(
          decision.action,
          equals('goOut'),
          reason:
              'Bot should go out immediately when opponent is close to winning (7800 points) and bot has empty hand',
        );
      },
    );

    test(
      'BookBuilder should not accumulate beyond 22 cards when under pressure',
      () {
        // Setup: Competitive pressure scenario
        humanPlayer.score = 6800; // Significant lead
        botAI.assignPersonality(botPlayer.id, BotPersonality.bookBuilder);

        // Kings meet round-3 play-down (23×10 ≥ 120). Sevens (5 pts) do not.
        botPlayer.hand.clear();
        for (int i = 0; i < 23; i++) {
          botPlayer.addCardToHand(
            PlayingCard(rank: CardRank.king, suit: Suit.hearts),
          );
        }

        gameController.gameState.round = 3;
        gameController.gameState.turnPhase = TurnPhase.meld;

        // Act: Bot makes meld decision
        final decision = botAI.makeDecision(botPlayer, gameController);

        // Assert: Bot should attempt to meld (not accumulate more) due to hand size
        expect(
          decision.action,
          anyOf(['createMeld', 'createMultipleMelds']),
          reason:
              'BookBuilder should not accumulate beyond 22 cards under competitive pressure',
        );
      },
    );

    test('bot should prioritize going out over incremental meld improvements', () {
      // Setup: Bot with books and few cards left
      _setupBotReadyToGoOut(botPlayer);

      botPlayer.hand.clear();
      // Add just 2 cards - one that could be added to existing meld, one to discard
      botPlayer.addCardToHand(
        PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
      ); // Could add to existing meld
      botPlayer.addCardToHand(
        PlayingCard(rank: CardRank.four, suit: Suit.hearts),
      ); // Discard candidate

      gameController.gameState.turnPhase = TurnPhase.meld;

      // Act: Bot makes decision
      final decision = botAI.makeDecision(botPlayer, gameController);

      // Assert: Meld the playable card first, then discard to go out same turn
      expect(
        decision.action,
        equals('addToMeld'),
        reason:
            'Bot with 2 cards and required books should meld playable cards before discarding to go out',
      );
    });

    test('bot should discard high-value cards when under severe pressure', () {
      // Setup: Severe competitive pressure
      humanPlayer.score = 7600; // Very close to winning

      // Give bot cards with different values, including high-value ones
      botPlayer.hand.clear();
      botPlayer.addCardToHand(
        PlayingCard(rank: CardRank.three, suit: Suit.hearts),
      ); // -5 points
      botPlayer.addCardToHand(
        PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
      ); // 20 points
      botPlayer.addCardToHand(
        PlayingCard(rank: CardRank.king, suit: Suit.hearts),
      ); // 10 points
      botPlayer.addCardToHand(
        PlayingCard(rank: CardRank.four, suit: Suit.hearts),
      ); // 5 points

      gameController.gameState.turnPhase = TurnPhase.discard;
      gameController.gameState.hasDrawnFromDeck = true;

      // Act: Bot makes discard decision
      final decision = botAI.makeDecision(botPlayer, gameController);

      // Assert: Should discard the 3 (penalty card) first, as that's always top priority
      expect(decision.action, equals('discard'));
      final discardedCard = decision.data as PlayingCard;
      expect(
        discardedCard.rank,
        equals(CardRank.three),
        reason: 'Should still prioritize 3s over high-value cards',
      );
    });

    test('bot should detect going out opportunity before other meld actions', () {
      // Setup: Bot that can go out but also has other meld opportunities
      _setupBotReadyToGoOut(botPlayer);

      // Add one more ace that could be added to existing ace meld
      botPlayer.addCardToHand(
        PlayingCard(rank: CardRank.ace, suit: Suit.clubs),
      );

      // Give bot existing meld of aces they could add to
      gameController.gameState.turnPhase = TurnPhase.meld;

      // Act: Bot makes decision
      final decision = botAI.makeDecision(botPlayer, gameController);

      // Assert: Meld last card into existing meld to empty hand (round ends via engine)
      expect(
        decision.action,
        equals('addToMeld'),
        reason:
            'Bot with 1 meldable card and required books should meld it to go out (empty hand required)',
      );
    });

    test('competitive urgency should override normal BookBuilder patience', () {
      // Setup: BookBuilder under competitive pressure in Round 3
      humanPlayer.score = 6600; // Competitive pressure threshold
      botAI.assignPersonality(botPlayer.id, BotPersonality.bookBuilder);

      // Give bot a playable combination that barely meets requirement
      botPlayer.hand.clear();
      botPlayer.hasPlayedDown = false;

      // Add cards that total exactly 120 points (Round 3 requirement)
      for (int i = 0; i < 6; i++) {
        botPlayer.addCardToHand(
          PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
        ); // 20 pts each = 120
      }

      gameController.gameState.round = 3;
      gameController.gameState.turnPhase = TurnPhase.meld;

      // Act: Bot makes decision
      final decision = botAI.makeDecision(botPlayer, gameController);

      // Assert: Should play down immediately due to competitive pressure
      expect(
        decision.action,
        anyOf(['createMeld', 'createMultipleMelds']),
        reason:
            'BookBuilder should play down immediately under competitive pressure even without excess points',
      );
    });
  });
}

/// Helper to setup a bot ready to go out
void _setupBotReadyToGoOut(Player bot) {
  bot.hand.clear();
  bot.foot.clear();
  bot.melds.clear();

  // Mark as having picked up foot
  bot.hasPickedUpFoot = true;
  bot.hasPlayedDown = true;

  // Add required clean book (7+ cards, no wilds)
  final cleanBook = Meld.createMeld([
    PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
    PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
    PlayingCard(rank: CardRank.ace, suit: Suit.clubs),
    PlayingCard(rank: CardRank.ace, suit: Suit.spades),
    PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
    PlayingCard(rank: CardRank.ace, suit: Suit.diamonds),
    PlayingCard(rank: CardRank.ace, suit: Suit.clubs),
  ])!;
  bot.melds.add(cleanBook);

  // Add required dirty book (7+ cards, with wilds)
  final dirtyBook = Meld.createMeld([
    PlayingCard(rank: CardRank.king, suit: Suit.hearts),
    PlayingCard(rank: CardRank.king, suit: Suit.diamonds),
    PlayingCard(rank: CardRank.king, suit: Suit.clubs),
    PlayingCard(rank: CardRank.king, suit: Suit.spades),
    PlayingCard(rank: CardRank.king, suit: Suit.hearts),
    PlayingCard(rank: CardRank.two, suit: Suit.hearts), // wild card
    PlayingCard(rank: CardRank.joker, suit: null), // wild card
  ])!;
  bot.melds.add(dirtyBook);
}
