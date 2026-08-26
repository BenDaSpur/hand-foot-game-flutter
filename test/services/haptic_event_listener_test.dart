import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/events/game_event.dart';
import 'package:hand_foot_game_flutter/game/events/game_event_bus.dart';
import 'package:hand_foot_game_flutter/models/card.dart';
import 'package:hand_foot_game_flutter/models/meld.dart';
import 'package:hand_foot_game_flutter/models/player.dart';
import 'package:hand_foot_game_flutter/services/haptic_event_listener.dart';
import 'package:hand_foot_game_flutter/services/haptic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameEventBus eventBus;
  late HapticService hapticService;
  late HapticEventListener listener;
  late Player human;
  late Player bot;

  Meld kingMeld({int count = 3}) {
    return Meld(
      rank: CardRank.king,
      cards: List.generate(
        count,
        (_) => const PlayingCard(rank: CardRank.king, suit: Suit.hearts),
      ),
    );
  }

  setUp(() {
    eventBus = GameEventBus();
    hapticService = HapticService();
    hapticService.resetForTest();
    listener = HapticEventListener(
      eventBus: eventBus,
      hapticService: hapticService,
    );
    human = Player(id: 'p1', name: 'You', type: PlayerType.human);
    bot = Player(id: 'p2', name: 'Bob', type: PlayerType.bot);
  });

  tearDown(() {
    listener.dispose();
    eventBus.dispose();
  });

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  group('HapticEventListener', () {
    test('plays medium impact when a human creates a non-book meld', () async {
      eventBus.publish(
        MeldCreatedEvent(
          meld: kingMeld(),
          cards: kingMeld().cards,
          player: human,
        ),
      );
      await flush();

      expect(hapticService.debugPlayed, [HapticKind.medium]);
    });

    test('plays heavy impact when a human completes a book', () async {
      eventBus.publish(
        MeldCreatedEvent(
          meld: kingMeld(count: 7),
          cards: kingMeld(count: 7).cards,
          player: human,
        ),
      );
      await flush();

      expect(hapticService.debugPlayed, [HapticKind.heavy]);
    });

    test('ignores bot meld events', () async {
      eventBus.publish(
        MeldCreatedEvent(
          meld: kingMeld(),
          cards: kingMeld().cards,
          player: bot,
        ),
      );
      await flush();

      expect(hapticService.debugPlayed, isEmpty);
    });

    test(
      'plays selection when a human adds a card to a non-book meld',
      () async {
        eventBus.publish(
          CardAddedToMeldEvent(
            meldIndex: 0,
            card: const PlayingCard(rank: CardRank.king, suit: Suit.spades),
            meld: kingMeld(count: 4),
            player: human,
          ),
        );
        await flush();

        expect(hapticService.debugPlayed, [HapticKind.selection]);
      },
    );

    test('plays heavy impact when adding a card completes a book', () async {
      eventBus.publish(
        CardAddedToMeldEvent(
          meldIndex: 0,
          card: const PlayingCard(rank: CardRank.king, suit: Suit.clubs),
          meld: kingMeld(count: 7),
          player: human,
        ),
      );
      await flush();

      expect(hapticService.debugPlayed, [HapticKind.heavy]);
    });

    test('plays medium impact when a human unlocks the discard pile', () async {
      eventBus.publish(
        DiscardPileUnlockedEvent(
          handPickupCards: const [],
          meldedCards: kingMeld().cards,
          meldIndex: 0,
          player: human,
        ),
      );
      await flush();

      expect(hapticService.debugPlayed, [HapticKind.medium]);
    });

    test('plays light impact when it becomes the human turn', () async {
      eventBus.publish(
        TurnEndedEvent(turnNumber: 2, nextPlayer: human, player: bot),
      );
      await flush();

      expect(hapticService.debugPlayed, [HapticKind.light]);
    });

    test('plays medium impact on foot pickup and round end', () async {
      eventBus.publish(FootPickedUpEvent(player: human));
      eventBus.publish(RoundEndedEvent(roundNumber: 1, roundScores: {}));
      await flush();

      expect(hapticService.debugPlayed, [HapticKind.medium, HapticKind.medium]);
    });

    test('plays heavy impact when the human goes out or wins', () async {
      eventBus.publish(PlayerWentOutEvent(roundNumber: 1, player: human));
      eventBus.publish(
        GameEndedEvent(winner: human, finalScores: {human: 1000}),
      );
      await flush();

      expect(hapticService.debugPlayed, [HapticKind.heavy, HapticKind.heavy]);
    });

    test('plays light impact when a bot wins the game', () async {
      eventBus.publish(GameEndedEvent(winner: bot, finalScores: {bot: 2000}));
      await flush();

      expect(hapticService.debugPlayed, [HapticKind.light]);
    });

    test('does not play after dispose', () async {
      listener.dispose();
      eventBus.publish(FootPickedUpEvent(player: human));
      await flush();

      expect(hapticService.debugPlayed, isEmpty);
    });

    test('does not play when haptics are disabled', () async {
      await hapticService.setHapticsEnabled(false);
      hapticService.debugPlayed.clear();

      eventBus.publish(FootPickedUpEvent(player: human));
      await flush();

      expect(hapticService.debugPlayed, isEmpty);
    });
  });
}
