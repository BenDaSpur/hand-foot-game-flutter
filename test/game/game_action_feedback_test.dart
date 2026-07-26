import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/game_action_feedback.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  GameState buildGameState() {
    final players = [
      Player(id: 'alice', name: 'Alice', type: PlayerType.human),
      Player(id: 'bob', name: 'Bob', type: PlayerType.human),
    ];
    return GameState(
      players: players,
      deck: Deck.createHandAndFootDeck(players.length, seed: 99),
      phase: GamePhase.playing,
    );
  }

  group('unlockDiscardBlockerMessage', () {
    test('explains an empty discard pile', () {
      final gameState = buildGameState();

      expect(
        GameActionFeedback.unlockDiscardBlockerMessage(gameState),
        'The discard pile is empty.',
      );
    });

    test('explains a wild card on top', () {
      final gameState = buildGameState();
      gameState.discardPile.add(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.two),
      );

      expect(
        GameActionFeedback.unlockDiscardBlockerMessage(gameState),
        contains('wild card'),
      );
    });

    test('explains a 3 on top', () {
      final gameState = buildGameState();
      gameState.discardPile.add(
        const PlayingCard(suit: Suit.hearts, rank: CardRank.three),
      );

      expect(
        GameActionFeedback.unlockDiscardBlockerMessage(gameState),
        contains('3 is on top'),
      );
    });

    test('explains that the player has not played down yet', () {
      final gameState = buildGameState();
      gameState.discardPile.add(
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      );

      expect(
        GameActionFeedback.unlockDiscardBlockerMessage(gameState),
        contains('play down first'),
      );
    });

    test('explains a missing pair of matching naturals', () {
      final gameState = buildGameState();
      gameState.discardPile.add(
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      );
      final alice = gameState.players[0];
      alice.hasPlayedDown = true;
      alice.dealHand(const [
        PlayingCard(suit: Suit.hearts, rank: CardRank.king),
      ]);

      expect(
        GameActionFeedback.unlockDiscardBlockerMessage(gameState),
        contains('at least 2 kings'),
      );
    });

    test('explains that the draw phase is over', () {
      final gameState = buildGameState();
      gameState.turnPhase = TurnPhase.meld;
      gameState.hasDrawnFromDeck = true;

      expect(
        GameActionFeedback.unlockDiscardBlockerMessage(gameState),
        contains('draw phase'),
      );
    });
  });

  group('drawFromDeckFailureMessage', () {
    test('explains an already-drawn turn', () {
      final gameState = buildGameState();
      gameState.hasDrawnFromDeck = true;

      expect(
        GameActionFeedback.drawFromDeckFailureMessage(gameState),
        contains('already drawn'),
      );
    });

    test('explains an empty deck', () {
      final gameState = buildGameState();
      gameState.deck.replaceCards(const []);

      expect(
        GameActionFeedback.drawFromDeckFailureMessage(gameState),
        contains('deck is empty'),
      );
    });

    test('explains a deck with too few cards left', () {
      final gameState = buildGameState();
      gameState.deck.replaceCards(const [
        PlayingCard(suit: Suit.hearts, rank: CardRank.four),
      ]);

      expect(
        GameActionFeedback.drawFromDeckFailureMessage(gameState),
        contains('Only 1 card(s) remaining'),
      );
    });

    test('explains an ended round', () {
      final gameState = buildGameState();
      gameState.phase = GamePhase.roundEnd;

      expect(
        GameActionFeedback.drawFromDeckFailureMessage(gameState),
        contains('round ended'),
      );
    });
  });

  group('discardFailureMessage', () {
    test('asks for a selection when nothing is selected', () {
      final gameState = buildGameState();

      expect(
        GameActionFeedback.discardFailureMessage(
          gameState,
          selectedCardCount: 0,
        ),
        contains('Select a card'),
      );
    });

    test('asks for exactly one card when several are selected', () {
      final gameState = buildGameState();

      expect(
        GameActionFeedback.discardFailureMessage(
          gameState,
          selectedCardCount: 3,
        ),
        contains('exactly one card'),
      );
    });

    test('explains that the draw comes first', () {
      final gameState = buildGameState();

      expect(
        GameActionFeedback.discardFailureMessage(
          gameState,
          selectedCardCount: 1,
        ),
        contains('must draw'),
      );
    });

    test('explains a stale selection during the discard phase', () {
      final gameState = buildGameState();
      gameState.turnPhase = TurnPhase.discard;
      gameState.currentPlayer.dealHand(const [
        PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        PlayingCard(suit: Suit.spades, rank: CardRank.queen),
      ]);

      expect(
        GameActionFeedback.discardFailureMessage(
          gameState,
          selectedCardCount: 1,
        ),
        contains('no longer in your hand'),
      );
    });

    test('names the missing books when the discard would go out', () {
      final gameState = buildGameState();
      gameState.turnPhase = TurnPhase.meld;

      final player = gameState.currentPlayer;
      // On the foot with a single card left, so this discard would go out.
      player.dealFoot(const [
        PlayingCard(suit: Suit.hearts, rank: CardRank.king),
      ]);
      player.hasPickedUpFoot = true;

      expect(GameActionFeedback.wouldGoOutWithoutBooks(player), isTrue);

      final message = GameActionFeedback.discardFailureMessage(
        gameState,
        selectedCardCount: 1,
      );
      expect(message, contains('would go out'));
      expect(message, contains('clean book'));
      expect(message, contains('dirty book'));
    });

    test('does not claim a go-out problem for an ordinary discard', () {
      final gameState = buildGameState();
      gameState.turnPhase = TurnPhase.meld;
      gameState.currentPlayer.dealHand(const [
        PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        PlayingCard(suit: Suit.spades, rank: CardRank.queen),
      ]);

      expect(
        GameActionFeedback.wouldGoOutWithoutBooks(gameState.currentPlayer),
        isFalse,
      );
      expect(
        GameActionFeedback.discardFailureMessage(
          gameState,
          selectedCardCount: 1,
        ),
        isNot(contains('go out')),
      );
    });
  });

  group('unlockDiscardBlockerMessage after taking the pile', () {
    test('says the pile was already taken this turn', () {
      final gameState = buildGameState();
      gameState.turnPhase = TurnPhase.meld;
      gameState.hasTakenDiscardThisTurn = true;
      gameState.discardPile.add(
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      );

      expect(
        GameActionFeedback.unlockDiscardBlockerMessage(gameState),
        'You have already taken the discard pile this turn.',
      );
    });
  });
}
