import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/game_config.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Empty-deck last call', () {
    late GameState gameState;
    late Player human;
    late Player carl;
    late Player alex;

    setUp(() {
      human = Player(id: '1', name: 'You', type: PlayerType.human);
      carl = Player(id: '2', name: 'Carl', type: PlayerType.bot);
      alex = Player(id: '3', name: 'Alex', type: PlayerType.bot);
      gameState = GameState(
        players: [human, carl, alex],
        deck: Deck.createHandAndFootDeck(3, seed: 864877),
      );
      gameState.startRound();
      gameState.dealCards();
      human.hasPlayedDown = true;
      carl.hasPlayedDown = true;
      alex.hasPlayedDown = true;
    });

    void drainDeckTo(int remaining) {
      while (gameState.deck.size > remaining) {
        gameState.deck.drawCard();
      }
    }

    test('canFulfillRequiredDraw accounts for a reshuffle after discard', () {
      drainDeckTo(0);
      gameState.discardPile
        ..clear()
        ..add(const PlayingCard(rank: CardRank.three, suit: Suit.hearts));

      expect(gameState.canFulfillRequiredDraw(), isFalse);
      expect(gameState.canFulfillRequiredDraw(extraDiscardCards: 1), isFalse);

      gameState.discardPile.add(
        const PlayingCard(rank: CardRank.three, suit: Suit.diamonds),
      );
      expect(gameState.canFulfillRequiredDraw(), isFalse);

      gameState.discardPile.add(
        const PlayingCard(rank: CardRank.three, suit: Suit.clubs),
      );
      expect(gameState.canFulfillRequiredDraw(), isTrue);
    });

    test('drawing the last two cards with one discard raises last call '
        '(session_17871568416581658)', () {
      drainDeckTo(GameConfig.requiredDrawCount);
      gameState.discardPile
        ..clear()
        ..add(const PlayingCard(rank: CardRank.three, suit: Suit.hearts));
      gameState.turnPhase = TurnPhase.draw;
      gameState.hasDrawnFromDeck = false;
      gameState.phase = GamePhase.playing;

      expect(gameState.drawFromDeck(), isTrue);
      expect(gameState.deck.isEmpty, isTrue);
      expect(gameState.lastCallActive, isTrue);
      expect(gameState.lastCallAlertPending, isTrue);
      expect(
        gameState.recentActions.any(
          (action) => action.message.contains('LAST CALL'),
        ),
        isTrue,
      );
      expect(gameState.phase, GamePhase.playing);
      expect(gameState.turnPhase, TurnPhase.meld);

      expect(gameState.consumeLastCallAlert(), isTrue);
      expect(gameState.lastCallAlertPending, isFalse);
      expect(gameState.consumeLastCallAlert(), isFalse);

      final throwaway = const PlayingCard(
        rank: CardRank.three,
        suit: Suit.spades,
      );
      human.hand.add(throwaway);
      expect(gameState.discard(throwaway), isTrue);
      expect(gameState.phase, GamePhase.playing);
      expect(gameState.lastCallActive, isTrue);
      expect(gameState.currentPlayer, carl);
      expect(gameState.turnPhase, TurnPhase.draw);

      expect(gameState.drawFromDeck(), isFalse);
      expect(gameState.phase, GamePhase.roundEnd);
      expect(
        gameState.emergencyRoundEndReason,
        EmergencyRoundEndReason.insufficientCards,
      );
    }, tags: ['regression']);

    test('does not raise last call when the next draw can still reshuffle', () {
      drainDeckTo(GameConfig.requiredDrawCount);
      gameState.discardPile
        ..clear()
        ..addAll(const [
          PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
          PlayingCard(rank: CardRank.king, suit: Suit.spades),
          PlayingCard(rank: CardRank.queen, suit: Suit.clubs),
        ]);
      gameState.turnPhase = TurnPhase.draw;
      gameState.hasDrawnFromDeck = false;

      expect(gameState.drawFromDeck(), isTrue);
      expect(gameState.lastCallActive, isFalse);
      expect(gameState.lastCallAlertPending, isFalse);
      expect(gameState.phase, GamePhase.playing);
    });

    test('startRound clears last-call flags', () {
      gameState.lastCallActive = true;
      gameState.lastCallAlertPending = true;
      gameState.startRound();
      expect(gameState.lastCallActive, isFalse);
      expect(gameState.lastCallAlertPending, isFalse);
    });
  });
}
