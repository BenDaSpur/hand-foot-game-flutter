/// Normalized analytics field helpers.
String? drawSourceFromAction(String action) {
  switch (action) {
    case 'drawFromDeck':
    case 'card_drawn':
      {
        return 'deck';
      }
    case 'drawFromDiscard':
      {
        return 'discard';
      }
    case 'unlockDiscardPile':
    case 'discard_pile_unlocked':
      {
        return 'unlock';
      }
    default:
      {
        return null;
      }
  }
}

/// Whether an action/event type represents a meld creation.
bool isMeldCreationAction(String action) {
  return action == 'createMeld' ||
      action == 'createMultipleMelds' ||
      action == 'meld_created';
}

/// Whether an action/event type represents a discard.
bool isDiscardAction(String action) {
  return action == 'discardCard';
}

/// Event-bus events already tracked via human/bot decision logs.
bool shouldSkipEventBusTurnTracking(String eventType) {
  return eventType == 'card_drawn' ||
      eventType == 'meld_created' ||
      eventType == 'discard_pile_unlocked';
}
