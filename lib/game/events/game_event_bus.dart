import 'dart:async';
import 'game_event.dart';

/// Central event bus for game events.
///
/// This class provides a publish-subscribe pattern for game events,
/// enabling decoupled communication between components:
/// - Logging and analytics can subscribe to events
/// - UI can react to events for updates
/// - Undo/redo systems can track events
/// - Testing can verify event sequences
///
/// Thread-safe and supports multiple subscribers.
class GameEventBus {
  final StreamController<GameEvent> _eventController =
      StreamController<GameEvent>.broadcast();

  bool _isDisposed = false;

  /// Stream of all game events
  Stream<GameEvent> get events => _eventController.stream;

  /// Publish an event to all subscribers
  void publish(GameEvent event) {
    if (_isDisposed) {
      return; // Silently ignore events after disposal
    }

    try {
      _eventController.add(event);
    } catch (e) {
      // Log error but don't throw - event bus should be resilient
      print('Error publishing event: $e');
    }
  }

  /// Subscribe to all events
  StreamSubscription<GameEvent> subscribe(
    void Function(GameEvent) onEvent, {
    bool Function(GameEvent)? filter,
  }) {
    var stream = events;
    if (filter != null) {
      stream = stream.where(filter);
    }
    return stream.listen(onEvent);
  }

  /// Subscribe to events of a specific type
  StreamSubscription<T> subscribeToType<T extends GameEvent>(
    void Function(T) onEvent,
  ) {
    return events.where((event) => event is T).cast<T>().listen(onEvent);
  }

  /// Subscribe to events matching a predicate
  StreamSubscription<GameEvent> subscribeWhere(
    bool Function(GameEvent) predicate,
    void Function(GameEvent) onEvent,
  ) {
    return events.where(predicate).listen(onEvent);
  }

  /// Get a stream filtered by event type name
  Stream<GameEvent> eventsOfType(String eventType) {
    return events.where((event) => event.eventType == eventType);
  }

  /// Dispose the event bus and close all streams
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
      _eventController.close();
    }
  }
}

/// Global singleton event bus instance
/// Can be overridden for testing
GameEventBus gameEventBus = GameEventBus();
