import '../config/game_config.dart';
import '../models/game_state.dart';
import '../models/player.dart';

/// Human-readable explanations for player actions the game refused to perform.
///
/// Both the singleplayer and multiplayer screens use these messages so a
/// rejected action always tells the player why instead of silently doing
/// nothing. The functions are pure and never throw: when no specific cause can
/// be identified they fall back to a generic message.
class GameActionFeedback {
  const GameActionFeedback._();

  /// Explains why the current player cannot take (unlock) the discard pile.
  ///
  /// Only meaningful when [GameState.canUnlockDiscard] is false.
  static String unlockDiscardBlockerMessage(GameState gameState) {
    final topCard = gameState.topDiscard;
    final currentPlayer = gameState.currentPlayer;

    // Checked before the phase check because taking the pile leaves the turn
    // in the meld phase, which would otherwise produce a misleading message.
    if (gameState.hasTakenDiscardThisTurn) {
      return 'You have already taken the discard pile this turn.';
    }
    if (gameState.turnPhase != TurnPhase.draw) {
      return 'You can only take the discard pile during the draw phase.';
    }
    if (gameState.hasDrawnFromDeck) {
      return 'You have already drawn this turn.';
    }
    if (gameState.discardPile.isEmpty) {
      return 'The discard pile is empty.';
    }
    if (topCard == null) {
      return 'Cannot take discard pile at this time.';
    }
    if (topCard.isWild) {
      return 'Cannot take discard pile when a wild card is on top.';
    }
    if (topCard.isThree) {
      return 'Cannot take discard pile when a 3 is on top.';
    }
    if (!currentPlayer.hasPlayedDown) {
      return 'You must play down first before taking the discard pile.';
    }

    final matchingCards = currentPlayer.currentHand
        .where((card) => card.rank == topCard.rank && !card.isWild)
        .length;
    if (matchingCards < GameConfig.minNaturalCardsForMeld) {
      return 'You need at least ${GameConfig.minNaturalCardsForMeld} '
          '${topCard.rank.name}s in your hand to take the discard.';
    }

    return 'Cannot take discard pile at this time.';
  }

  /// Explains why drawing from the deck was refused.
  static String drawFromDeckFailureMessage(GameState gameState) {
    if (gameState.phase == GamePhase.roundEnd ||
        gameState.phase == GamePhase.gameEnd) {
      return 'The round ended because the deck ran out of cards.';
    }
    if (gameState.hasDrawnFromDeck) {
      return 'You have already drawn this turn.';
    }
    if (gameState.turnPhase != TurnPhase.draw) {
      return 'You can only draw at the start of your turn.';
    }
    if (gameState.deck.isEmpty) {
      return 'Cannot draw from deck: The deck is empty!\n\n'
          'The round will continue until a player goes out or all players '
          'pass.';
    }
    if (gameState.deck.size < GameConfig.requiredDrawCount) {
      return 'Cannot draw from deck: Only ${gameState.deck.size} card(s) '
          'remaining.\n\n'
          'You must draw exactly ${GameConfig.requiredDrawCount} cards from '
          'the deck. Try taking the discard pile instead.';
    }
    return 'Unable to draw from the deck right now. Please try again.';
  }

  /// Explains why discarding was refused for the given [selectedCardCount].
  static String discardFailureMessage(
    GameState gameState, {
    required int selectedCardCount,
  }) {
    if (selectedCardCount == 0) {
      return 'Select a card from your hand to discard.';
    }
    if (selectedCardCount > 1) {
      return 'Select exactly one card to discard.';
    }
    if (gameState.turnPhase == TurnPhase.draw) {
      return 'You must draw before discarding.';
    }

    final currentPlayer = gameState.currentPlayer;
    if (wouldGoOutWithoutBooks(currentPlayer)) {
      return goOutBlockerMessage(currentPlayer);
    }

    // Discarding is legal in both the meld and discard phases, so a refusal
    // here means the selected card is no longer in hand — most often because
    // a server snapshot replaced it between selection and discard.
    return 'That card is no longer in your hand. Select another card to '
        'discard.';
  }

  /// Whether discarding would leave [player] out of cards without the books
  /// the rules require for going out.
  static bool wouldGoOutWithoutBooks(Player player) {
    return player.hasPickedUpFoot &&
        player.currentHand.length == 1 &&
        !player.canGoOutWithBooks;
  }

  /// Spells out which book [player] is still missing to be allowed to go out.
  static String goOutBlockerMessage(Player player) {
    final String missingBooks;
    if (!player.hasCleanBook && !player.hasDirtyBook) {
      missingBooks =
          'You need both a clean book (no wild cards) and a dirty book '
          '(with wild cards) to go out.';
    } else if (!player.hasCleanBook) {
      missingBooks = 'You need a clean book (no wild cards) to go out.';
    } else {
      missingBooks = 'You need a dirty book (with wild cards) to go out.';
    }

    return 'Discarding your last card would go out. $missingBooks';
  }

  /// Explains why a meld that would empty (or nearly empty) the foot without
  /// both books is refused.
  static String unfinishableMeldBlockerMessage(Player player) {
    final String missingBooks;
    if (!player.hasCleanBook && !player.hasDirtyBook) {
      missingBooks =
          'You need both a clean book (no wild cards) and a dirty book '
          '(with wild cards) to go out.';
    } else if (!player.hasCleanBook) {
      missingBooks = 'You need a clean book (no wild cards) to go out.';
    } else {
      missingBooks = 'You need a dirty book (with wild cards) to go out.';
    }

    return '$missingBooks Keep at least two cards so you can discard.';
  }

  /// Copy for the emergency stuck banner when the player cannot finish the turn.
  static String stuckWithoutBooksMessage(Player player) {
    return '${goOutBlockerMessage(player).replaceFirst('Discarding your last card would go out. ', '')} '
        'Undo a meld or skip your turn to continue.';
  }
}
