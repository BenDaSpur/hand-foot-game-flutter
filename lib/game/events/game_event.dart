import '../../models/card.dart';
import '../../models/player.dart';
import '../../models/meld.dart';

/// Base class for all game events.
///
/// Events represent significant state changes in the game and enable
/// decoupled communication between components (logging, analytics, UI updates, undo/redo).
abstract class GameEvent {
  /// Timestamp when the event occurred
  final DateTime timestamp;

  /// Player who triggered the event (null for system events)
  final Player? player;

  GameEvent({DateTime? timestamp, this.player})
    : timestamp = timestamp ?? DateTime.now();

  /// Event type identifier for filtering and routing
  String get eventType;

  @override
  String toString() => '$eventType(${player?.name ?? 'system'})';
}

/// Event fired when a card is drawn from the deck
class CardDrawnEvent extends GameEvent {
  final List<PlayingCard> cards;
  final bool fromDeck; // true if from deck, false if from discard pile

  /// Backward-compatible accessor for single-card consumers.
  PlayingCard get card => cards.last;

  CardDrawnEvent({
    required this.cards,
    required this.fromDeck,
    required super.player,
    super.timestamp,
  });

  @override
  String get eventType => 'CardDrawn';
}

/// Event fired when a card is discarded
class CardDiscardedEvent extends GameEvent {
  final PlayingCard card;

  CardDiscardedEvent({
    required this.card,
    required super.player,
    super.timestamp,
  });

  @override
  String get eventType => 'CardDiscarded';
}

/// Event fired when a new meld is created
class MeldCreatedEvent extends GameEvent {
  final Meld meld;
  final List<PlayingCard> cards;

  MeldCreatedEvent({
    required this.meld,
    required this.cards,
    required super.player,
    super.timestamp,
  });

  @override
  String get eventType => 'MeldCreated';
}

/// Event fired when a card is added to an existing meld
class CardAddedToMeldEvent extends GameEvent {
  final int meldIndex;
  final PlayingCard card;
  final Meld meld;

  CardAddedToMeldEvent({
    required this.meldIndex,
    required this.card,
    required this.meld,
    required super.player,
    super.timestamp,
  });

  @override
  String get eventType => 'CardAddedToMeld';
}

/// Event fired when discard pile is unlocked
class DiscardPileUnlockedEvent extends GameEvent {
  /// Up to 5 additional cards added to the player's hand.
  final List<PlayingCard> handPickupCards;

  /// The 2 matching naturals from hand plus the top discard card melded.
  final List<PlayingCard> meldedCards;

  /// Index of the meld that received the unlock cards.
  final int meldIndex;

  /// Backward-compatible alias for hand pickup cards only.
  List<PlayingCard> get cardsTaken => handPickupCards;

  DiscardPileUnlockedEvent({
    required this.handPickupCards,
    required this.meldedCards,
    required this.meldIndex,
    required super.player,
    super.timestamp,
  });

  @override
  String get eventType => 'DiscardPileUnlocked';
}

/// Event fired when a player's turn ends
class TurnEndedEvent extends GameEvent {
  final int turnNumber;
  final Player? nextPlayer;

  TurnEndedEvent({
    required this.turnNumber,
    this.nextPlayer,
    required super.player,
    super.timestamp,
  });

  @override
  String get eventType => 'TurnEnded';
}

/// Event fired when a round ends
class RoundEndedEvent extends GameEvent {
  final int roundNumber;
  final Map<Player, int> roundScores;

  RoundEndedEvent({
    required this.roundNumber,
    required this.roundScores,
    super.timestamp,
  }) : super(player: null); // Round end is a system event

  @override
  String get eventType => 'RoundEnded';
}

/// Event fired when a round starts
class RoundStartedEvent extends GameEvent {
  final int roundNumber;

  RoundStartedEvent({required this.roundNumber, super.timestamp})
    : super(player: null); // Round start is a system event

  @override
  String get eventType => 'RoundStarted';
}

/// Event fired when a player goes out (wins the round)
class PlayerWentOutEvent extends GameEvent {
  final int roundNumber;

  PlayerWentOutEvent({
    required this.roundNumber,
    required super.player,
    super.timestamp,
  });

  @override
  String get eventType => 'PlayerWentOut';
}

/// Event fired when the game ends
class GameEndedEvent extends GameEvent {
  final Player winner;
  final Map<Player, int> finalScores;

  GameEndedEvent({
    required this.winner,
    required this.finalScores,
    super.timestamp,
  }) : super(player: null); // Game end is a system event

  @override
  String get eventType => 'GameEnded';
}

/// Event fired when a player picks up their foot
class FootPickedUpEvent extends GameEvent {
  FootPickedUpEvent({required super.player, super.timestamp});

  @override
  String get eventType => 'FootPickedUp';
}

/// Event fired when a player plays down (meets initial meld requirement)
class PlayedDownEvent extends GameEvent {
  final int pointsPlayed;

  PlayedDownEvent({
    required this.pointsPlayed,
    required super.player,
    super.timestamp,
  });

  @override
  String get eventType => 'PlayedDown';
}
