import 'package:flutter/services.dart';
import '../models/game_state.dart';

/// A single keyboard shortcut entry for help UI, tooltips, and dispatch.
class KeyboardShortcutEntry {
  final String keyLabel;
  final String action;
  final TurnPhase? phase;
  final LogicalKeyboardKey? logicalKey;

  const KeyboardShortcutEntry({
    required this.keyLabel,
    required this.action,
    this.phase,
    this.logicalKey,
  });
}

/// Canonical WASD-centric keyboard shortcuts for desktop/web play.
class KeyboardShortcuts {
  KeyboardShortcuts._();

  static const String drawKey = 'W';
  static const String takeDiscardKey = 'Q';
  static const String playCardsKey = 'E';
  static const String discardKey = 'Space';
  static const String discardAltKey = 'Enter';
  static const String prevCardKey = 'A';
  static const String nextCardKey = 'D';
  static const String toggleSelectKey = 'F';
  static const String sortKey = 'S';
  static const String clearKey = 'C';
  static const String scoreboardKey = 'R';
  static const String helpKey = 'H';

  /// Canonical draw binding (W).
  static const LogicalKeyboardKey draw = LogicalKeyboardKey.keyW;

  /// Canonical take-discard binding (Q).
  static const LogicalKeyboardKey takeDiscard = LogicalKeyboardKey.keyQ;

  /// Canonical play-cards binding (E).
  static const LogicalKeyboardKey playCards = LogicalKeyboardKey.keyE;

  /// Discard primary binding (Space).
  static const LogicalKeyboardKey discard = LogicalKeyboardKey.space;

  /// Discard alternate binding (Enter).
  static const LogicalKeyboardKey discardAlt = LogicalKeyboardKey.enter;

  /// Focus previous card (A).
  static const LogicalKeyboardKey prevCard = LogicalKeyboardKey.keyA;

  /// Focus next card (D).
  static const LogicalKeyboardKey nextCard = LogicalKeyboardKey.keyD;

  /// Toggle select focused card (F).
  static const LogicalKeyboardKey toggleSelect = LogicalKeyboardKey.keyF;

  /// Sort hand (S).
  static const LogicalKeyboardKey sort = LogicalKeyboardKey.keyS;

  /// Clear selection (C).
  static const LogicalKeyboardKey clear = LogicalKeyboardKey.keyC;

  /// Clear / dismiss (Esc).
  static const LogicalKeyboardKey escape = LogicalKeyboardKey.escape;

  /// Scoreboard (R).
  static const LogicalKeyboardKey scoreboard = LogicalKeyboardKey.keyR;

  /// Help overlay (H).
  static const LogicalKeyboardKey help = LogicalKeyboardKey.keyH;

  static const List<KeyboardShortcutEntry> drawPhase = [
    KeyboardShortcutEntry(
      keyLabel: drawKey,
      action: 'Draw from deck',
      phase: TurnPhase.draw,
      logicalKey: draw,
    ),
    KeyboardShortcutEntry(
      keyLabel: takeDiscardKey,
      action: 'Take discard pile',
      phase: TurnPhase.draw,
      logicalKey: takeDiscard,
    ),
  ];

  static const List<KeyboardShortcutEntry> meldPhase = [
    KeyboardShortcutEntry(
      keyLabel: playCardsKey,
      action: 'Open Play Cards',
      phase: TurnPhase.meld,
      logicalKey: playCards,
    ),
    KeyboardShortcutEntry(
      keyLabel: discardKey,
      action: 'Discard / Go to Foot / Go Out',
      phase: TurnPhase.meld,
      logicalKey: discard,
    ),
    KeyboardShortcutEntry(
      keyLabel: discardAltKey,
      action: 'Same as Space',
      phase: TurnPhase.meld,
      logicalKey: discardAlt,
    ),
  ];

  static const List<KeyboardShortcutEntry> navigation = [
    KeyboardShortcutEntry(
      keyLabel: prevCardKey,
      action: 'Focus previous card',
      logicalKey: prevCard,
    ),
    KeyboardShortcutEntry(
      keyLabel: nextCardKey,
      action: 'Focus next card',
      logicalKey: nextCard,
    ),
    KeyboardShortcutEntry(
      keyLabel: toggleSelectKey,
      action: 'Toggle select focused card',
      logicalKey: toggleSelect,
    ),
    KeyboardShortcutEntry(
      keyLabel: sortKey,
      action: 'Sort hand by rank',
      logicalKey: sort,
    ),
    KeyboardShortcutEntry(
      keyLabel: clearKey,
      action: 'Clear selection',
      logicalKey: clear,
    ),
    KeyboardShortcutEntry(
      keyLabel: 'Esc',
      action: 'Clear selection',
      logicalKey: escape,
    ),
  ];

  static const List<KeyboardShortcutEntry> utility = [
    KeyboardShortcutEntry(
      keyLabel: scoreboardKey,
      action: 'Open scoreboard',
      logicalKey: scoreboard,
    ),
    KeyboardShortcutEntry(
      keyLabel: helpKey,
      action: 'Toggle keyboard shortcuts help',
      logicalKey: help,
    ),
    KeyboardShortcutEntry(
      keyLabel: '?',
      action: 'Toggle keyboard shortcuts help',
    ),
  ];

  static const List<KeyboardShortcutEntry> all = [
    ...drawPhase,
    ...meldPhase,
    ...navigation,
    ...utility,
  ];

  /// WASD layout rows for the help overlay diagram.
  static const List<List<String>> wasdLayout = [
    ['Q', 'W', 'E'],
    ['A', 'S', 'D'],
    ['F', 'C', 'Space'],
  ];

  static const Map<String, String> wasdLayoutLabels = {
    'Q': 'Take discard',
    'W': 'Draw',
    'E': 'Play Cards',
    'A': 'Prev card',
    'S': 'Sort',
    'D': 'Next card',
    'F': 'Toggle select',
    'C': 'Clear',
    'Space': 'Discard',
  };

  static String tooltipSuffix(String key) => ' ($key)';
}
