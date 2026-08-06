import '../config/game_config.dart';
import '../models/card.dart';
import '../models/game_state.dart';
import '../models/meld.dart';
import '../models/player.dart';

/// Shared guards that prevent players from melding into an unfinishable
/// go-out state (0–1 foot cards without both clean and dirty books).
class GoOutGuards {
  const GoOutGuards._();

  /// True when removing [cardsRemoved] from the foot would leave 0–1 cards
  /// while the player still cannot go out with books.
  ///
  /// [modifiedMeldIndex] / [projectedModifiedMeld] project an add-to-meld.
  /// [additionalNewMelds] project newly created melds.
  static bool wouldLeaveUnfinishableAfterMeld({
    required Player player,
    required int cardsRemoved,
    int? modifiedMeldIndex,
    Meld? projectedModifiedMeld,
    List<Meld>? additionalNewMelds,
  }) {
    if (!player.hasPickedUpFoot) {
      return false;
    }

    final remaining = player.currentHand.length - cardsRemoved;
    if (remaining > 1) {
      return false;
    }

    return !_wouldHaveBothBooks(
      player: player,
      modifiedMeldIndex: modifiedMeldIndex,
      projectedModifiedMeld: projectedModifiedMeld,
      additionalNewMelds: additionalNewMelds,
    );
  }

  /// True when playing [cards] as a create-or-add meld would leave the foot
  /// unfinishable without books.
  static bool wouldCreateMeldLeaveUnfinishable(
    Player player,
    List<PlayingCard> cards,
  ) {
    if (!player.hasPickedUpFoot || cards.isEmpty) {
      return false;
    }

    final naturalCards = cards.where((card) => !card.isWild).toList();
    if (naturalCards.isEmpty) {
      return false;
    }

    final rank = naturalCards.first.rank;
    final existingIndex = player.findMeldByRank(rank);

    if (existingIndex != -1) {
      final existing = player.melds[existingIndex];
      final projected = Meld.createMeld([...existing.cards, ...cards]);
      return wouldLeaveUnfinishableAfterMeld(
        player: player,
        cardsRemoved: cards.length,
        modifiedMeldIndex: existingIndex,
        projectedModifiedMeld: projected,
      );
    }

    final proposed = Meld.createMeld(cards);
    if (proposed == null) {
      return false;
    }

    return wouldLeaveUnfinishableAfterMeld(
      player: player,
      cardsRemoved: cards.length,
      additionalNewMelds: [proposed],
    );
  }

  /// True when adding [card] to [meldIndex] would leave the foot unfinishable.
  static bool wouldAddToMeldLeaveUnfinishable(
    Player player,
    int meldIndex,
    PlayingCard card,
  ) {
    return wouldAddCardsToMeldLeaveUnfinishable(player, meldIndex, [card]);
  }

  /// True when adding all of [cards] to [meldIndex] in one selection would
  /// leave the foot unfinishable. Projects the full selection before any add.
  static bool wouldAddCardsToMeldLeaveUnfinishable(
    Player player,
    int meldIndex,
    List<PlayingCard> cards,
  ) {
    if (!player.hasPickedUpFoot || cards.isEmpty) {
      return false;
    }
    if (meldIndex < 0 || meldIndex >= player.melds.length) {
      return false;
    }

    final meld = player.melds[meldIndex];
    final projected = Meld.createMeld([...meld.cards, ...cards]);
    return wouldLeaveUnfinishableAfterMeld(
      player: player,
      cardsRemoved: cards.length,
      modifiedMeldIndex: meldIndex,
      projectedModifiedMeld: projected,
    );
  }

  /// True when a multi-meld batch would leave the foot unfinishable.
  static bool wouldMultiMeldLeaveUnfinishable(
    Player player,
    List<List<PlayingCard>> allMeldCards,
  ) {
    if (!player.hasPickedUpFoot || allMeldCards.isEmpty) {
      return false;
    }

    final totalRemoved = allMeldCards.fold<int>(
      0,
      (sum, cards) => sum + cards.length,
    );
    final remaining = player.currentHand.length - totalRemoved;
    if (remaining > 1) {
      return false;
    }

    final projectedMelds = player.melds
        .map((meld) => Meld(rank: meld.rank, cards: List.from(meld.cards)))
        .toList();

    for (final cards in allMeldCards) {
      final naturalCards = cards.where((card) => !card.isWild).toList();
      if (naturalCards.isEmpty) {
        continue;
      }

      final rank = naturalCards.first.rank;
      final existingIndex = projectedMelds.indexWhere(
        (meld) => meld.rank == rank,
      );

      if (existingIndex != -1) {
        projectedMelds[existingIndex].cards.addAll(cards);
      } else {
        final created = Meld.createMeld(cards);
        if (created != null) {
          projectedMelds.add(created);
        }
      }
    }

    var hasClean = false;
    var hasDirty = false;
    for (final meld in projectedMelds) {
      if (meld.cards.length < GameConfig.bookSize) {
        continue;
      }
      if (meld.cards.any((card) => card.isWild)) {
        hasDirty = true;
      } else {
        hasClean = true;
      }
    }

    return !(hasClean && hasDirty);
  }

  /// Human soft-lock: on foot, cannot go out with books, in meld phase, and
  /// either empty-handed or holding a single undiscardable last card.
  static bool isHumanStuckWithoutGoOut({
    required GameState gameState,
    required Player humanPlayer,
    required Player currentPlayer,
  }) {
    if (currentPlayer.id != humanPlayer.id) {
      return false;
    }
    if (currentPlayer.type != PlayerType.human) {
      return false;
    }
    if (gameState.turnPhase != TurnPhase.meld) {
      return false;
    }
    if (!humanPlayer.hasPickedUpFoot) {
      return false;
    }
    if (humanPlayer.canGoOutWithBooks) {
      return false;
    }

    return humanPlayer.currentHand.isEmpty ||
        humanPlayer.currentHand.length == 1;
  }

  static bool _wouldHaveBothBooks({
    required Player player,
    int? modifiedMeldIndex,
    Meld? projectedModifiedMeld,
    List<Meld>? additionalNewMelds,
  }) {
    var hasClean = false;
    var hasDirty = false;

    for (var i = 0; i < player.melds.length; i++) {
      final meld = (modifiedMeldIndex == i && projectedModifiedMeld != null)
          ? projectedModifiedMeld
          : player.melds[i];
      if (meld.cards.length < GameConfig.bookSize) {
        continue;
      }
      if (meld.cards.any((card) => card.isWild)) {
        hasDirty = true;
      } else {
        hasClean = true;
      }
    }

    if (additionalNewMelds != null) {
      for (final meld in additionalNewMelds) {
        if (meld.cards.length < GameConfig.bookSize) {
          continue;
        }
        if (meld.cards.any((card) => card.isWild)) {
          hasDirty = true;
        } else {
          hasClean = true;
        }
      }
    }

    return hasClean && hasDirty;
  }
}
