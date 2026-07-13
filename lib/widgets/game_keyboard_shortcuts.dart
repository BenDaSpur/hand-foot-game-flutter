import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_state.dart';

/// Callbacks invoked by keyboard shortcuts.
class GameKeyboardActions {
  final VoidCallback onDrawFromDeck;
  final VoidCallback? onUnlockDiscard;
  final VoidCallback onOpenMeldModal;
  final VoidCallback onDiscard;
  final VoidCallback onClearSelection;
  final VoidCallback onSortHand;
  final VoidCallback onToggleSelectFocused;
  final VoidCallback onFocusPrevious;
  final VoidCallback onFocusNext;
  final VoidCallback onShowScoreboard;
  final VoidCallback onToggleHelp;

  const GameKeyboardActions({
    required this.onDrawFromDeck,
    required this.onUnlockDiscard,
    required this.onOpenMeldModal,
    required this.onDiscard,
    required this.onClearSelection,
    required this.onSortHand,
    required this.onToggleSelectFocused,
    required this.onFocusPrevious,
    required this.onFocusNext,
    required this.onShowScoreboard,
    required this.onToggleHelp,
  });
}

/// Read-only state needed to decide which shortcuts apply.
class GameKeyboardContext {
  final TurnPhase turnPhase;
  final bool canUnlockDiscard;
  final int selectedCardCount;
  final int handLength;
  final int? focusedCardIndex;
  final bool isHumanTurn;
  final bool isAnimating;
  final bool hasInteractedSinceDraw;
  final bool isHelpVisible;

  const GameKeyboardContext({
    required this.turnPhase,
    required this.canUnlockDiscard,
    required this.selectedCardCount,
    required this.handLength,
    required this.focusedCardIndex,
    required this.isHumanTurn,
    required this.isAnimating,
    required this.hasInteractedSinceDraw,
    this.isHelpVisible = false,
  });
}

/// Returns true when the key is H or ? (shift+/).
bool isHelpToggleKey(KeyDownEvent event) {
  if (event.logicalKey == LogicalKeyboardKey.keyH) {
    return true;
  }
  return event.character == '?';
}

/// Pure keyboard handler for unit testing.
KeyEventResult handleGameKeyboardEvent({
  required KeyEvent event,
  required GameKeyboardContext context,
  required GameKeyboardActions actions,
}) {
  if (event is! KeyDownEvent) {
    return KeyEventResult.ignored;
  }

  final key = event.logicalKey;

  if (isHelpToggleKey(event)) {
    actions.onToggleHelp();
    return KeyEventResult.handled;
  }

  if (context.isHelpVisible && key == LogicalKeyboardKey.escape) {
    actions.onToggleHelp();
    return KeyEventResult.handled;
  }

  if (context.isAnimating) {
    return KeyEventResult.ignored;
  }

  if (!context.isHumanTurn) {
    return KeyEventResult.ignored;
  }

  // W = Draw from deck
  if (key == LogicalKeyboardKey.keyW) {
    if (context.turnPhase == TurnPhase.draw) {
      actions.onDrawFromDeck();
      return KeyEventResult.handled;
    }
  }

  // Q = Take discard pile
  if (key == LogicalKeyboardKey.keyQ) {
    if (context.turnPhase == TurnPhase.draw &&
        context.canUnlockDiscard &&
        actions.onUnlockDiscard != null) {
      actions.onUnlockDiscard!();
      return KeyEventResult.handled;
    }
  }

  // E = Open Play Cards modal
  if (key == LogicalKeyboardKey.keyE) {
    if (context.turnPhase == TurnPhase.meld) {
      actions.onOpenMeldModal();
      return KeyEventResult.handled;
    }
  }

  // Space / Enter = Discard
  if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter) {
    if (context.turnPhase == TurnPhase.meld &&
        context.selectedCardCount == 1 &&
        context.hasInteractedSinceDraw) {
      actions.onDiscard();
      return KeyEventResult.handled;
    }
  }

  // A = Focus previous card
  if (key == LogicalKeyboardKey.keyA) {
    if (context.handLength > 0) {
      actions.onFocusPrevious();
      return KeyEventResult.handled;
    }
  }

  // D = Focus next card
  if (key == LogicalKeyboardKey.keyD) {
    if (context.handLength > 0) {
      actions.onFocusNext();
      return KeyEventResult.handled;
    }
  }

  // F = Toggle select on focused card
  if (key == LogicalKeyboardKey.keyF) {
    if (context.handLength > 0 && context.focusedCardIndex != null) {
      actions.onToggleSelectFocused();
      return KeyEventResult.handled;
    }
  }

  // S = Sort hand
  if (key == LogicalKeyboardKey.keyS) {
    actions.onSortHand();
    return KeyEventResult.handled;
  }

  // C / Esc = Clear selection
  if (key == LogicalKeyboardKey.keyC || key == LogicalKeyboardKey.escape) {
    if (context.selectedCardCount > 0) {
      actions.onClearSelection();
      return KeyEventResult.handled;
    }
  }

  // R = Scoreboard
  if (key == LogicalKeyboardKey.keyR) {
    actions.onShowScoreboard();
    return KeyEventResult.handled;
  }

  return KeyEventResult.ignored;
}

/// Wraps [child] with keyboard focus and routes key events to [handleGameKeyboardEvent].
class GameKeyboardShortcuts extends StatefulWidget {
  final Widget child;
  final GameKeyboardContext Function() getContext;
  final GameKeyboardActions actions;
  final bool enabled;

  const GameKeyboardShortcuts({
    super.key,
    required this.child,
    required this.getContext,
    required this.actions,
    this.enabled = true,
  });

  @override
  State<GameKeyboardShortcuts> createState() => _GameKeyboardShortcutsState();
}

class _GameKeyboardShortcutsState extends State<GameKeyboardShortcuts> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled) {
      return KeyEventResult.ignored;
    }
    return handleGameKeyboardEvent(
      event: event,
      context: widget.getContext(),
      actions: widget.actions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }
}

/// Moves keyboard focus to the previous card index (wraps at 0).
int? focusPreviousCardIndex({
  required int? currentIndex,
  required int handLength,
}) {
  if (handLength <= 0) {
    return null;
  }
  if (currentIndex == null) {
    return handLength - 1;
  }
  if (currentIndex <= 0) {
    return handLength - 1;
  }
  return currentIndex - 1;
}

/// Moves keyboard focus to the next card index (wraps at end).
int? focusNextCardIndex({required int? currentIndex, required int handLength}) {
  if (handLength <= 0) {
    return null;
  }
  if (currentIndex == null) {
    return 0;
  }
  if (currentIndex >= handLength - 1) {
    return 0;
  }
  return currentIndex + 1;
}
