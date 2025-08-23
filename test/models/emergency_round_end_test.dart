import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/card.dart';

void main() {
  group('Emergency Round End Tests', () {
    test('should automatically end round when insufficient cards for draw', () {
      // Create game with minimal deck
      final players = [
        Player(id: '1', name: 'Player 1', type: PlayerType.human),
        Player(id: '2', name: 'Player 2', type: PlayerType.bot),
      ];
      final deck = Deck.fromCards([]);
      final gameState = GameState(players: players, deck: deck);

      // Setup initial game state
      gameState.startRound();
      gameState.phase = GamePhase.playing;
      gameState.turnPhase = TurnPhase.draw;

      // Verify initial state
      expect(gameState.phase, equals(GamePhase.playing));
      expect(gameState.deck.isEmpty, isTrue);

      // Attempt to draw from empty deck
      final success = gameState.drawFromDeck();

      // Should fail to draw
      expect(success, isFalse);

      // Should automatically end the round
      expect(gameState.phase, equals(GamePhase.roundEnd));

      // Check that emergency action was logged
      final actions = gameState.recentActions;
      expect(actions.isNotEmpty, isTrue);
      expect(
        actions.any((action) => action.message.contains('insufficient cards')),
        isTrue,
      );
      expect(
        actions.any((action) => action.message.contains('emergency round end')),
        isTrue,
      );
    });

    test('should calculate scores properly when round ends early', () {
      // Create game with players who have cards
      final players = [
        Player(id: '1', name: 'Player 1', type: PlayerType.human),
        Player(id: '2', name: 'Player 2', type: PlayerType.bot),
      ];

      // Give players some cards and melds to test scoring
      final testCards = [
        PlayingCard(rank: CardRank.king, suit: Suit.hearts),
        PlayingCard(rank: CardRank.queen, suit: Suit.spades),
      ];

      players[0].hand.addAll(testCards);
      players[1].hand.addAll(testCards);

      final deck = Deck.fromCards([]);
      final gameState = GameState(players: players, deck: deck);

      // Setup initial game state
      gameState.startRound();
      gameState.phase = GamePhase.playing;
      gameState.turnPhase = TurnPhase.draw;

      // Record initial scores
      final initialScores = players.map((p) => p.score).toList();

      // Attempt to draw from empty deck (triggers emergency round end)
      gameState.drawFromDeck();

      // Verify round ended and scores were calculated
      expect(gameState.phase, equals(GamePhase.roundEnd));

      // Scores should have been updated (likely negatively due to cards in hand)
      final updatedScores = players.map((p) => p.score).toList();
      expect(updatedScores, isNot(equals(initialScores)));
    });

    test('should advance to next round after emergency end', () {
      final players = [
        Player(id: '1', name: 'Player 1', type: PlayerType.human),
        Player(id: '2', name: 'Player 2', type: PlayerType.bot),
      ];

      // Give players some cards so deck can be replenished after round end
      // Need enough for: 2 players * (11 hand + 11 foot) + 1 discard + some remaining = 50+ cards
      final testCards = List.generate(
        60,
        (index) => PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
      );

      players[0].hand.addAll(testCards.take(15));
      players[0].foot.addAll(testCards.skip(15).take(15));
      players[1].hand.addAll(testCards.skip(30).take(15));
      players[1].foot.addAll(testCards.skip(45).take(15));

      final deck = Deck.fromCards([]);
      final gameState = GameState(players: players, deck: deck);

      gameState.startRound();
      gameState.phase = GamePhase.playing;
      gameState.turnPhase = TurnPhase.draw;

      final initialRound = gameState.round;

      // Trigger emergency round end
      gameState.drawFromDeck();

      // Verify we're in round end state
      expect(gameState.phase, equals(GamePhase.roundEnd));

      // Simulate advancing to next round
      gameState.resetForNewRound();

      // Should be in new round now
      expect(gameState.phase, equals(GamePhase.playing));
      expect(gameState.round, equals(initialRound + 1));
      expect(gameState.turnPhase, equals(TurnPhase.draw));

      // Deck should be replenished (after dealing, there should be some cards left)
      expect(gameState.deck.isEmpty, isFalse);
    });

    test('should not trigger emergency end when deck has sufficient cards', () {
      final players = [
        Player(id: '1', name: 'Player 1', type: PlayerType.human),
        Player(id: '2', name: 'Player 2', type: PlayerType.bot),
      ];

      // Create deck with enough cards
      final sufficientCards = List.generate(
        10,
        (index) => PlayingCard(rank: CardRank.ace, suit: Suit.hearts),
      );
      final deck = Deck.fromCards(sufficientCards);
      final gameState = GameState(players: players, deck: deck);

      gameState.startRound();
      gameState.phase = GamePhase.playing;
      gameState.turnPhase = TurnPhase.draw;

      // Should be able to draw normally
      final success = gameState.drawFromDeck();

      expect(success, isTrue);
      expect(gameState.phase, equals(GamePhase.playing)); // Still playing
      expect(
        gameState.turnPhase,
        equals(TurnPhase.meld),
      ); // Advanced to meld phase
    });
  });
}
