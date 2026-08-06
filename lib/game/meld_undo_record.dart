import '../models/card.dart';
import '../models/meld.dart';

/// One reverseable meld action (or batch) recorded for the current turn.
class MeldUndoRecord {
  /// Cards to return to the player's current hand (or hand if undoing foot pickup).
  final List<PlayingCard> cardsReturnedToHand;

  /// When non-null, restore the player's melds from this snapshot (batch undo).
  final List<Meld>? meldsSnapshotBefore;

  /// Index of the meld that was created or modified (single-action undo).
  final int? meldIndex;

  /// True when the action created a brand-new meld (remove it on undo).
  final bool wasNewMeld;

  /// True when this action set [Player.hasPlayedDown].
  final bool unsetPlayedDown;

  /// True when this action set [Player.hasPickedUpFoot].
  final bool unsetPickedUpFoot;

  const MeldUndoRecord({
    required this.cardsReturnedToHand,
    this.meldsSnapshotBefore,
    this.meldIndex,
    this.wasNewMeld = false,
    this.unsetPlayedDown = false,
    this.unsetPickedUpFoot = false,
  });
}
