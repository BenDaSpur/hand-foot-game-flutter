import 'dart:async';
import '../game/events/game_event.dart';
import '../game/events/game_event_bus.dart';
import '../utils/debug_logger.dart';
import 'game_analytics_logger.dart';
import 'analytics_batcher.dart';

/// Service that listens to game events and handles logging and analytics.
///
/// This demonstrates the event-driven architecture by decoupling
/// logging and analytics from game logic.
class GameEventListener {
  final GameEventBus _eventBus;
  final List<StreamSubscription> _subscriptions = [];
  bool _isDisposed = false;

  GameEventListener(this._eventBus);

  /// Start listening to game events
  void startListening() {
    if (_isDisposed) return;

    // Subscribe to all events for logging
    _subscriptions.add(_eventBus.subscribe(_handleEvent));

    // Subscribe to specific event types for analytics
    _subscriptions.add(
      _eventBus.subscribeToType<CardDrawnEvent>(_handleCardDrawn),
    );
    _subscriptions.add(
      _eventBus.subscribeToType<MeldCreatedEvent>(_handleMeldCreated),
    );
    _subscriptions.add(
      _eventBus.subscribeToType<PlayerWentOutEvent>(_handlePlayerWentOut),
    );
    _subscriptions.add(
      _eventBus.subscribeToType<GameEndedEvent>(_handleGameEnded),
    );
    _subscriptions.add(
      _eventBus.subscribeToType<TurnEndedEvent>(_handleTurnEnded),
    );
    _subscriptions.add(
      _eventBus.subscribeToType<DiscardPileUnlockedEvent>(
        _handleDiscardPileUnlocked,
      ),
    );
  }

  /// Handle any game event for general logging
  void _handleEvent(GameEvent event) {
    if (_isDisposed) return;

    DebugLogger.debug('Game Event: ${event.eventType} - ${event.toString()}');
  }

  /// Handle card drawn events for analytics
  void _handleCardDrawn(CardDrawnEvent event) {
    if (_isDisposed) return;

    GameAnalyticsLogger.handleCardDrawnForOutcomes(event);

    GameAnalyticsLogger.logGameEvent(
      eventType: 'card_drawn',
      playerId: event.player?.id ?? 'unknown',
      playerType: event.player?.type,
      eventData: {
        'from_deck': event.fromDeck,
        'drawSource': event.fromDeck ? 'deck' : 'discard',
        'card_count': event.cards.length,
        'card_ranks': event.cards.map((card) => card.rank.name).toList(),
        'card_suits': event.cards
            .map((card) => card.suit?.name ?? 'joker')
            .toList(),
        'card_rank': event.card.rank.name,
        'card_suit': event.card.suit?.name ?? 'joker',
        'player_name': event.player?.name ?? 'unknown',
      },
    );
  }

  /// Handle meld created events for analytics
  void _handleMeldCreated(MeldCreatedEvent event) {
    if (_isDisposed) return;

    GameAnalyticsLogger.logGameEvent(
      eventType: 'meld_created',
      playerId: event.player?.id ?? 'unknown',
      playerType: event.player?.type,
      eventData: {
        'meld_size': event.cards.length,
        'meld_points': event.cards.fold<int>(
          0,
          (sum, card) => sum + card.pointValue,
        ),
        'player_name': event.player?.name ?? 'unknown',
      },
    );
  }

  /// Handle discard pile unlocked events for analytics
  void _handleDiscardPileUnlocked(DiscardPileUnlockedEvent event) {
    if (_isDisposed) return;

    GameAnalyticsLogger.handleDiscardPileUnlockedForOutcomes(event);

    GameAnalyticsLogger.logGameEvent(
      eventType: 'discard_pile_unlocked',
      playerId: event.player?.id ?? 'unknown',
      playerType: event.player?.type,
      eventData: {
        'drawSource': 'unlock',
        'cards_taken': event.handPickupCards.length,
        'hand_pickup_count': event.handPickupCards.length,
        'melded_count': event.meldedCards.length,
        'meld_index': event.meldIndex,
        'card_ranks': event.handPickupCards.map((c) => c.rank.name).toList(),
        'melded_ranks': event.meldedCards.map((c) => c.rank.name).toList(),
        'player_name': event.player?.name ?? 'unknown',
      },
    );
  }

  /// Handle player went out events
  void _handlePlayerWentOut(PlayerWentOutEvent event) {
    if (_isDisposed) return;

    GameAnalyticsLogger.logGameEvent(
      eventType: 'player_went_out',
      playerId: event.player?.id ?? 'unknown',
      playerType: event.player?.type,
      eventData: {
        'round': event.roundNumber,
        'player_name': event.player?.name ?? 'unknown',
      },
    );
  }

  /// Handle game ended events
  void _handleGameEnded(GameEndedEvent event) {
    if (_isDisposed) return;

    GameAnalyticsLogger.logGameEvent(
      eventType: 'game_ended',
      playerId: event.winner.id,
      playerType: event.winner.type,
      eventData: {
        'winner': event.winner.name,
        'final_score': event.finalScores[event.winner] ?? 0,
      },
    );
  }

  /// Handle turn ended events
  void _handleTurnEnded(TurnEndedEvent event) {
    if (_isDisposed) return;

    GameAnalyticsLogger.finalizeTurn(event);
    AnalyticsBatcher.flushOnTurnCompletion();

    DebugLogger.debug(
      'Turn ended: ${event.player?.name} -> ${event.nextPlayer?.name ?? "none"}',
    );
  }

  /// Stop listening and dispose resources
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
