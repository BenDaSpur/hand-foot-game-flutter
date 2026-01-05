import 'dart:async';
import '../game/events/game_event.dart';
import '../game/events/game_event_bus.dart';
import '../models/player.dart';
import 'sound_service.dart';

/// Listens to game events and plays appropriate sound effects.
class SoundEventListener {
  final GameEventBus eventBus;
  final SoundService soundService;
  final List<StreamSubscription> _subscriptions = [];
  bool _disposed = false;

  SoundEventListener({required this.eventBus, required this.soundService}) {
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    // Card drawn - only play for human players
    _subscriptions.add(
      eventBus.subscribeToType<CardDrawnEvent>((event) {
        if (_disposed) return;
        if (event.player?.type == PlayerType.human) {
          soundService.playCardDraw();
        }
      }),
    );

    // Card discarded
    _subscriptions.add(
      eventBus.subscribeToType<CardDiscardedEvent>((event) {
        if (_disposed) return;
        soundService.playCardDiscard();
      }),
    );

    // Meld created
    _subscriptions.add(
      eventBus.subscribeToType<MeldCreatedEvent>((event) {
        if (_disposed) return;
        if (event.meld.isBook) {
          soundService.playBookCompleted();
        } else {
          soundService.playMeldCreated();
        }
      }),
    );

    // Card added to meld - check if it completed a book
    _subscriptions.add(
      eventBus.subscribeToType<CardAddedToMeldEvent>((event) {
        if (_disposed) return;
        if (event.meld.isBook && event.meld.cards.length == 7) {
          // Just completed a book!
          soundService.playBookCompleted();
        }
      }),
    );

    // Discard pile unlocked
    _subscriptions.add(
      eventBus.subscribeToType<DiscardPileUnlockedEvent>((event) {
        if (_disposed) return;
        soundService.playUnlockDiscard();
      }),
    );

    // Turn ended - play sound when it becomes human's turn
    _subscriptions.add(
      eventBus.subscribeToType<TurnEndedEvent>((event) {
        if (_disposed) return;
        if (event.nextPlayer?.type == PlayerType.human) {
          soundService.playYourTurn();
        }
      }),
    );

    // Round ended
    _subscriptions.add(
      eventBus.subscribeToType<RoundEndedEvent>((event) {
        if (_disposed) return;
        soundService.playRoundComplete();
      }),
    );

    // Game ended
    _subscriptions.add(
      eventBus.subscribeToType<GameEndedEvent>((event) {
        if (_disposed) return;
        // Check if human won
        if (event.winner.type == PlayerType.human) {
          soundService.playVictory();
        } else {
          soundService.playGameOver();
        }
      }),
    );

    // Foot picked up
    _subscriptions.add(
      eventBus.subscribeToType<FootPickedUpEvent>((event) {
        if (_disposed) return;
        soundService.playFootPickup();
      }),
    );
  }

  /// Dispose all subscriptions
  void dispose() {
    _disposed = true;
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
