/// Normalized analytics field helpers.
String? drawSourceFromAction(String action) {
  switch (action) {
    case 'drawFromDeck':
      return 'deck';
    case 'drawFromDiscard':
      return 'discard';
    case 'unlockDiscardPile':
      return 'unlock';
    default:
      return null;
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
