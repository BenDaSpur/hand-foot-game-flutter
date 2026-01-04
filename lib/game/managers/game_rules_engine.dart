import '../../models/player.dart';
import '../../models/game_state.dart';

/// Engine for validating Hand & Foot game rules.
///
/// This class encapsulates rule validation logic, separating game rules from
/// game state management. This makes rules easier to test, modify, and reason about.
///
/// The GameRulesEngine is stateless and operates on the game state to determine
/// if actions are valid according to the rules of Hand & Foot.
class GameRulesEngine {
  /// Validates if the current player can unlock the discard pile.
  ///
  /// Rules for unlocking discard pile:
  /// 1. Discard pile must not be empty
  /// 2. Player must not have already drawn from deck this turn
  /// 3. Top discard card must not be wild (2s or Jokers)
  /// 4. Top discard card must not be a 3 (3s cannot be melded)
  /// 5. Player must have already played down this round
  /// 6. Player must have at least 2 matching natural cards of the same rank as top discard
  ///
  /// Returns true if all conditions are met, false otherwise.
  static bool canUnlockDiscard(GameState gameState) {
    if (gameState.discardPile.isEmpty || gameState.hasDrawnFromDeck) {
      return false;
    }

    final topCard = gameState.topDiscard;
    if (topCard == null) {
      return false;
    }

    // Top card cannot be wild
    if (topCard.isWild) {
      return false;
    }

    // 3s cannot be melded, so discard pile cannot be unlocked when top card is a 3
    if (topCard.isThree) {
      return false;
    }

    final currentPlayer = gameState.currentPlayer;

    // Must have already met play-down requirement
    if (!currentPlayer.hasPlayedDown) {
      return false;
    }

    // Check if player has at least 2 matching natural cards
    final matchingCards = currentPlayer.currentHand
        .where((card) => card.rank == topCard.rank && !card.isWild)
        .toList();

    return matchingCards.length >= 2;
  }

  /// Validates if any player (other than the current player) can immediately unlock
  /// the discard pile with the newly discarded card.
  ///
  /// This is used to determine if immediate unlock is possible after a discard.
  ///
  /// Rules:
  /// 1. Discard pile must not be empty
  /// 2. Top discard card must not be wild
  /// 3. Any player (except current player) must have 2+ matching natural cards
  ///
  /// Returns true if any other player can unlock, false otherwise.
  static bool canAnyPlayerImmediatelyUnlock(GameState gameState) {
    if (gameState.discardPile.isEmpty) {
      return false;
    }

    final topCard = gameState.topDiscard;
    if (topCard == null || topCard.isWild) {
      return false;
    }

    for (int i = 0; i < gameState.players.length; i++) {
      if (i == gameState.currentPlayerIndex) {
        continue; // Skip current player
      }

      final player = gameState.players[i];
      final matchingCards = player.currentHand
          .where((card) => card.rank == topCard.rank && !card.isWild)
          .toList();

      if (matchingCards.length >= 2) {
        return true;
      }
    }

    return false;
  }

  /// Validates if a specific player can unlock the discard pile.
  ///
  /// Similar to [canUnlockDiscard] but checks a specific player instead of current player.
  /// Used for immediate unlock scenarios.
  ///
  /// Returns true if the player can unlock, false otherwise.
  static bool canPlayerUnlockDiscard(
    GameState gameState,
    Player player,
  ) {
    if (gameState.discardPile.isEmpty) {
      return false;
    }

    final topCard = gameState.topDiscard;
    if (topCard == null) {
      return false;
    }

    // Top card cannot be wild
    if (topCard.isWild) {
      return false;
    }

    // 3s cannot be melded
    if (topCard.isThree) {
      return false;
    }

    // Player must have already met play-down requirement
    if (!player.hasPlayedDown) {
      return false;
    }

    // Check if player has at least 2 matching natural cards
    final matchingCards = player.currentHand
        .where((card) => card.rank == topCard.rank && !card.isWild)
        .toList();

    return matchingCards.length >= 2;
  }

  /// Validates if the current player can end their turn.
  ///
  /// Rules:
  /// 1. Must be in discard phase
  /// 2. Player must have melded at least once this turn
  ///
  /// Returns true if turn can be ended, false otherwise.
  static bool canEndTurn(GameState gameState) {
    return gameState.turnPhase == TurnPhase.discard && gameState.hasMelded;
  }
}

