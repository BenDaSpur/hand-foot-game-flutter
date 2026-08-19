import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/config/game_config.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/deck.dart';
import 'package:hand_foot_game_flutter/models/game_state.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Unlock discard fills short pile from draw pile', () {
    late List<Player> players;
    late GameState gameState;
    late Player player;

    setUp(() {
      players = [
        Player(id: '1', name: 'Player 1', type: PlayerType.human),
        Player(id: '2', name: 'Player 2', type: PlayerType.bot),
      ];
      gameState = GameState(players: players, deck: Deck(seed: 12345));
      player = gameState.currentPlayer;
      player.hasPlayedDown = true;
      player.dealHand(const [
        PlayingCard(suit: Suit.hearts, rank: CardRank.king),
        PlayingCard(suit: Suit.spades, rank: CardRank.king),
        PlayingCard(suit: Suit.clubs, rank: CardRank.ace),
      ]);
    });

    test('fills from the draw pile when discard has only the unlock card', () {
      gameState.discardPile
        ..clear()
        ..add(const PlayingCard(suit: Suit.diamonds, rank: CardRank.king));

      final initialHandSize = player.currentHand.length;
      final initialDeckSize = gameState.deck.size;

      expect(gameState.unlockDiscard(), isTrue);
      expect(player.melds, hasLength(1));
      expect(player.melds.first.cards, hasLength(3));
      expect(
        player.currentHand.length,
        equals(initialHandSize - 2 + GameConfig.additionalDiscardPickup),
      );
      expect(
        gameState.deck.size,
        equals(initialDeckSize - GameConfig.additionalDiscardPickup),
      );
      expect(gameState.discardPile, isEmpty);
      expect(
        player.newlyDrawnCardIndices,
        hasLength(GameConfig.additionalDiscardPickup),
      );
    });

    test(
      'takes remaining discard cards then fills the rest from the draw pile',
      () {
        gameState.discardPile
          ..clear()
          ..addAll(const [
            PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            PlayingCard(suit: Suit.spades, rank: CardRank.five),
            PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
          ]);

        final initialHandSize = player.currentHand.length;
        final initialDeckSize = gameState.deck.size;
        const fromDiscard = 2;
        const fromDeck = GameConfig.additionalDiscardPickup - fromDiscard;

        expect(gameState.unlockDiscard(), isTrue);
        expect(player.currentHand.length, equals(initialHandSize - 2 + 5));
        expect(gameState.deck.size, equals(initialDeckSize - fromDeck));
        expect(gameState.discardPile, isEmpty);
        expect(
          player.currentHand,
          containsAll(const [
            PlayingCard(suit: Suit.hearts, rank: CardRank.four),
            PlayingCard(suit: Suit.spades, rank: CardRank.five),
          ]),
        );
      },
    );

    test('does not draw from the deck when discard already has 5 extras', () {
      gameState.discardPile
        ..clear()
        ..addAll(const [
          PlayingCard(suit: Suit.hearts, rank: CardRank.four),
          PlayingCard(suit: Suit.spades, rank: CardRank.five),
          PlayingCard(suit: Suit.clubs, rank: CardRank.six),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.seven),
          PlayingCard(suit: Suit.hearts, rank: CardRank.eight),
          PlayingCard(suit: Suit.clubs, rank: CardRank.nine),
          PlayingCard(suit: Suit.diamonds, rank: CardRank.king),
        ]);

      final initialDeckSize = gameState.deck.size;

      expect(gameState.unlockDiscard(), isTrue);
      expect(gameState.deck.size, equals(initialDeckSize));
      expect(gameState.discardPile, hasLength(1));
      expect(gameState.discardPile.single.rank, CardRank.four);
      expect(
        player.newlyDrawnCardIndices,
        hasLength(GameConfig.additionalDiscardPickup),
      );
    });

    test('takes leftover draw cards when the deck cannot complete 5', () {
      while (gameState.deck.size > 2) {
        gameState.deck.drawCard();
      }
      gameState.discardPile
        ..clear()
        ..add(const PlayingCard(suit: Suit.diamonds, rank: CardRank.king));

      final initialHandSize = player.currentHand.length;

      expect(gameState.unlockDiscard(), isTrue);
      expect(player.currentHand.length, equals(initialHandSize - 2 + 2));
      expect(gameState.deck.isEmpty, isTrue);
      expect(gameState.phase, isNot(GamePhase.roundEnd));
    });
  });
}
