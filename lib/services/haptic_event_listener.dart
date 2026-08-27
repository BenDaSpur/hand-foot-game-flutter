import 'dart:async';

import '../game/events/game_event.dart';
import '../game/events/game_event_bus.dart';
import '../models/player.dart';
import 'haptic_service.dart';

/// Listens to game events and plays haptic pulses for notable outcomes.
///
/// Immediate tap feedback (card select, action buttons) lives in the widgets.
/// This listener covers moments that are not a direct button press, or that
/// deserve a stronger pulse than a selection click.
class HapticEventListener {
  final GameEventBus eventBus;
  final HapticService hapticService;

  /// When set (multiplayer), player / next-player / winner pulses are limited
  /// to this identity. Solo games omit it and match [PlayerType.human].
  /// Round-end stays global either way.
  final String? localPlayerId;

  final List<StreamSubscription> _subscriptions = [];
  bool _disposed = false;

  HapticEventListener({
    required this.eventBus,
    required this.hapticService,
    this.localPlayerId,
  }) {
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    _subscriptions.add(
      eventBus.subscribeToType<MeldCreatedEvent>((event) {
        if (_disposed || !_isLocalActor(event.player)) {
          return;
        }
        if (event.meld.isBook) {
          hapticService.heavyImpact();
        } else {
          hapticService.mediumImpact();
        }
      }),
    );

    _subscriptions.add(
      eventBus.subscribeToType<CardAddedToMeldEvent>((event) {
        if (_disposed || !_isLocalActor(event.player)) {
          return;
        }
        if (event.meld.isBook && event.meld.cards.length == 7) {
          hapticService.heavyImpact();
        } else {
          hapticService.selectionClick();
        }
      }),
    );

    _subscriptions.add(
      eventBus.subscribeToType<DiscardPileUnlockedEvent>((event) {
        if (_disposed || !_isLocalActor(event.player)) {
          return;
        }
        hapticService.mediumImpact();
      }),
    );

    _subscriptions.add(
      eventBus.subscribeToType<TurnEndedEvent>((event) {
        if (_disposed) {
          return;
        }
        if (_isLocalActor(event.nextPlayer)) {
          hapticService.lightImpact();
        }
      }),
    );

    _subscriptions.add(
      eventBus.subscribeToType<RoundEndedEvent>((event) {
        if (_disposed) {
          return;
        }
        hapticService.mediumImpact();
      }),
    );

    _subscriptions.add(
      eventBus.subscribeToType<GameEndedEvent>((event) {
        if (_disposed) {
          return;
        }
        if (_isLocalActor(event.winner)) {
          hapticService.heavyImpact();
        } else {
          hapticService.lightImpact();
        }
      }),
    );

    _subscriptions.add(
      eventBus.subscribeToType<FootPickedUpEvent>((event) {
        if (_disposed || !_isLocalActor(event.player)) {
          return;
        }
        hapticService.mediumImpact();
      }),
    );

    _subscriptions.add(
      eventBus.subscribeToType<PlayerWentOutEvent>((event) {
        if (_disposed || !_isLocalActor(event.player)) {
          return;
        }
        hapticService.heavyImpact();
      }),
    );
  }

  bool _isLocalActor(Player? player) {
    if (player == null) {
      return false;
    }
    if (localPlayerId != null) {
      return player.id == localPlayerId;
    }
    return player.type == PlayerType.human;
  }

  /// Cancel all subscriptions.
  void dispose() {
    _disposed = true;
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
