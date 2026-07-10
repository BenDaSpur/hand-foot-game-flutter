import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/events/game_event.dart';
import 'package:hand_foot_game_flutter/game/events/game_event_bus.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/player.dart';

void main() {
  group('Card draw events', () {
    test('CardDrawnEvent.card returns null for empty cards list', () {
      final player = Player(id: 'human', name: 'You', type: PlayerType.human);
      final event = CardDrawnEvent(cards: [], fromDeck: true, player: player);

      expect(event.card, isNull);
      expect(event.cards, isEmpty);
    });

    test('CardDrawnEvent publishes all drawn cards from deck', () async {
      final eventBus = GameEventBus();
      final capturedEvents = <GameEvent>[];
      final subscription = eventBus.subscribe(capturedEvents.add);
      addTearDown(subscription.cancel);

      final players = [
        Player(id: 'human', name: 'You', type: PlayerType.human),
        Player(id: 'bot', name: 'Bot', type: PlayerType.bot),
      ];
      final controller = GameController(players: players, eventBus: eventBus);
      controller.initializeGame();
      await Future<void>.delayed(Duration.zero);

      final human = players.first;

      final success = controller.drawFromDeck();
      await Future<void>.delayed(Duration.zero);

      expect(success, isTrue);
      expect(human.newlyDrawnCardIndices, hasLength(2));
      expect(capturedEvents.whereType<CardDrawnEvent>(), hasLength(1));

      final event = capturedEvents.whereType<CardDrawnEvent>().first;
      expect(event.fromDeck, isTrue);
      expect(event.cards, hasLength(2));
      expect(event.card, equals(event.cards.last));
      expect(event.card, isNotNull);
      expect(event.cards.every(human.currentHand.contains), isTrue);
    });

    test(
      'DiscardPileUnlockedEvent publishes meld and hand pickup cards',
      () async {
        final eventBus = GameEventBus();
        final capturedEvents = <GameEvent>[];
        final subscription = eventBus.subscribe(capturedEvents.add);
        addTearDown(subscription.cancel);

        final players = [
          Player(id: 'human', name: 'You', type: PlayerType.human),
          Player(id: 'bot', name: 'Bot', type: PlayerType.bot),
        ];
        final controller = GameController(players: players, eventBus: eventBus);
        controller.initializeGame();
        await Future<void>.delayed(Duration.zero);

        final human = players.first;
        final gameState = controller.gameState;

        human.hasPlayedDown = true;
        gameState.discardPile
          ..clear()
          ..addAll([
            const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
            const PlayingCard(suit: Suit.spades, rank: CardRank.five),
            const PlayingCard(suit: Suit.diamonds, rank: CardRank.five),
            const PlayingCard(suit: Suit.hearts, rank: CardRank.five),
            const PlayingCard(suit: Suit.clubs, rank: CardRank.five),
            const PlayingCard(suit: Suit.spades, rank: CardRank.nine),
          ]);

        human.currentHand.addAll([
          const PlayingCard(suit: Suit.hearts, rank: CardRank.nine),
          const PlayingCard(suit: Suit.diamonds, rank: CardRank.nine),
        ]);

        final success = controller.unlockDiscardPile();
        await Future<void>.delayed(Duration.zero);

        expect(success, isTrue);
        expect(
          capturedEvents.whereType<DiscardPileUnlockedEvent>(),
          hasLength(1),
        );

        final event = capturedEvents
            .whereType<DiscardPileUnlockedEvent>()
            .first;
        expect(event.meldedCards, hasLength(3));
        expect(event.meldedCards.last.rank, CardRank.nine);
        expect(event.handPickupCards, isNotEmpty);
        expect(event.handPickupCards.length, lessThanOrEqualTo(5));
        expect(event.cardsTaken, equals(event.handPickupCards));
        expect(event.meldIndex, greaterThanOrEqualTo(0));

        for (final card in event.handPickupCards) {
          expect(human.currentHand.contains(card), isTrue);
        }
      },
    );
  });
}
