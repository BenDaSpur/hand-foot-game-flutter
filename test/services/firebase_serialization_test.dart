import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/services/firebase_service.dart';

void main() {
  group('Firebase game state serialization', () {
    test('round-trips a full game state through Firestore maps', () {
      final playerA = Player(
        id: 'player-a',
        name: 'Alice',
        type: PlayerType.human,
      );
      final playerB = Player(
        id: 'player-b',
        name: 'Bob',
        type: PlayerType.human,
      );

      playerA.hand.addAll([
        const PlayingCard(suit: Suit.hearts, rank: CardRank.ace),
        const PlayingCard(suit: Suit.spades, rank: CardRank.king),
      ]);
      playerA.foot.addAll([
        const PlayingCard(suit: Suit.clubs, rank: CardRank.queen),
      ]);
      playerA.melds.add(
        Meld(
          rank: CardRank.seven,
          cards: [
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.seven),
            const PlayingCard(suit: Suit.spades, rank: CardRank.seven),
          ],
        ),
      );
      playerA.score = 120;
      playerA.hasPlayedDown = true;
      playerA.hasPickedUpFoot = false;

      playerB.hand.addAll([
        const PlayingCard(suit: Suit.clubs, rank: CardRank.jack),
      ]);

      final deck = Deck.createHandAndFootDeck(2, seed: 424242);
      deck.drawCard();

      final original = GameState(
        players: [playerA, playerB],
        deck: deck,
        discardPile: [
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
        ],
        currentPlayerIndex: 1,
        phase: GamePhase.playing,
        turnPhase: TurnPhase.meld,
        round: 2,
        discardPileFrozen: true,
        hasDrawnFromDeck: true,
        hasMelded: false,
      );
      original.recentActions.add(
        GameAction(message: 'Alice drew from deck', playerName: 'Alice'),
      );

      final serialized = FirebaseService.gameStateToMapForTesting(original);
      final restored = FirebaseService.gameStateFromMapForTesting(serialized);

      expect(restored.players.length, 2);
      expect(restored.players[0].id, 'player-a');
      expect(restored.players[0].hand.length, 2);
      expect(restored.players[0].foot.length, 1);
      expect(restored.players[0].melds.length, 1);
      expect(restored.players[0].score, 120);
      expect(restored.players[0].hasPlayedDown, isTrue);
      expect(restored.players[1].hand.length, 1);

      expect(restored.deck.size, original.deck.size);
      expect(restored.discardPile.length, 1);
      expect(restored.currentPlayerIndex, 1);
      expect(restored.phase, GamePhase.playing);
      expect(restored.turnPhase, TurnPhase.meld);
      expect(restored.round, 2);
      expect(restored.discardPileFrozen, isTrue);
      expect(restored.hasDrawnFromDeck, isTrue);
      expect(restored.hasMelded, isFalse);
      expect(restored.recentActions.length, 1);
      expect(restored.recentActions.first.playerName, 'Alice');
    });

    test('round-trips final-turn-after-go-out fields', () {
      final playerA = Player(
        id: 'player-a',
        name: 'Alice',
        type: PlayerType.human,
      );
      final playerB = Player(
        id: 'player-b',
        name: 'Bob',
        type: PlayerType.human,
      );

      final original = GameState(
        players: [playerA, playerB],
        deck: Deck.createHandAndFootDeck(2, seed: 7),
        phase: GamePhase.playing,
        turnPhase: TurnPhase.meld,
        currentPlayerIndex: 1,
        finalTurnPhaseActive: true,
        playerWhoWentOutIndex: 0,
        playersAwaitingFinalTurn: {1},
      );

      final serialized = FirebaseService.gameStateToMapForTesting(original);

      expect(serialized['finalTurnPhaseActive'], isTrue);
      expect(serialized['playerWhoWentOutIndex'], 0);
      expect(serialized['playersAwaitingFinalTurn'], [1]);

      final restored = FirebaseService.gameStateFromMapForTesting(serialized);

      expect(restored.finalTurnPhaseActive, isTrue);
      expect(restored.playerWhoWentOutIndex, 0);
      expect(restored.playersAwaitingFinalTurn, {1});
      expect(restored.currentPlayerIndex, 1);
    });

    test('round-trips last-call and stalemate pending flags', () {
      final playerA = Player(
        id: 'player-a',
        name: 'Alice',
        type: PlayerType.human,
      );
      final playerB = Player(
        id: 'player-b',
        name: 'Bob',
        type: PlayerType.human,
      );

      final original = GameState(
        players: [playerA, playerB],
        deck: Deck.createHandAndFootDeck(2, seed: 19),
        phase: GamePhase.playing,
        turnPhase: TurnPhase.meld,
      );
      original.lastCallActive = true;
      original.lastCallAlertPending = true;
      original.stalemateAlertPending = true;

      final serialized = FirebaseService.gameStateToMapForTesting(original);

      expect(serialized['lastCallActive'], isTrue);
      expect(serialized['lastCallAlertPending'], isTrue);
      expect(serialized['stalemateAlertPending'], isTrue);

      final restored = FirebaseService.gameStateFromMapForTesting(serialized);

      expect(restored.lastCallActive, isTrue);
      expect(restored.lastCallAlertPending, isTrue);
      expect(restored.stalemateAlertPending, isTrue);

      serialized
        ..remove('lastCallActive')
        ..remove('lastCallAlertPending')
        ..remove('stalemateAlertPending');
      final legacy = FirebaseService.gameStateFromMapForTesting(serialized);
      expect(legacy.lastCallActive, isFalse);
      expect(legacy.lastCallAlertPending, isFalse);
      expect(legacy.stalemateAlertPending, isFalse);
    });

    test('defaults missing final-turn fields for legacy documents', () {
      final playerA = Player(
        id: 'player-a',
        name: 'Alice',
        type: PlayerType.human,
      );
      final playerB = Player(
        id: 'player-b',
        name: 'Bob',
        type: PlayerType.human,
      );

      final legacy = GameState(
        players: [playerA, playerB],
        deck: Deck.createHandAndFootDeck(2, seed: 11),
        phase: GamePhase.playing,
      );
      final serialized = FirebaseService.gameStateToMapForTesting(legacy)
        ..remove('finalTurnPhaseActive')
        ..remove('playerWhoWentOutIndex')
        ..remove('playersAwaitingFinalTurn');

      final restored = FirebaseService.gameStateFromMapForTesting(serialized);

      expect(restored.finalTurnPhaseActive, isFalse);
      expect(restored.playerWhoWentOutIndex, isNull);
      expect(restored.playersAwaitingFinalTurn, isEmpty);
    });
  });
}
