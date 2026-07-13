import 'package:flutter/services.dart';

/// A single keyboard shortcut entry for help UI, tooltips, and dispatch.
class KeyboardShortcutEntry {
  final String keyLabel;
  final String action;
  final String? phase;
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

  static const List<KeyboardShortcutEntry> drawPhase = [
    KeyboardShortcutEntry(
      keyLabel: drawKey,
      action: 'Draw from deck',
      phase: 'Draw',
      logicalKey: LogicalKeyboardKey.keyW,
    ),
    KeyboardShortcutEntry(
      keyLabel: takeDiscardKey,
      action: 'Take discard pile',
      phase: 'Draw',
      logicalKey: LogicalKeyboardKey.keyQ,
    ),
  ];

  static const List<KeyboardShortcutEntry> meldPhase = [
    KeyboardShortcutEntry(
      keyLabel: playCardsKey,
      action: 'Open Play Cards',
      phase: 'Meld',
      logicalKey: LogicalKeyboardKey.keyE,
    ),
    KeyboardShortcutEntry(
      keyLabel: discardKey,
      action: 'Discard / Go to Foot / Go Out',
      phase: 'Meld',
      logicalKey: LogicalKeyboardKey.space,
    ),
    KeyboardShortcutEntry(
      keyLabel: discardAltKey,
      action: 'Same as Space',
      phase: 'Meld',
      logicalKey: LogicalKeyboardKey.enter,
    ),
  ];

  static const List<KeyboardShortcutEntry> navigation = [
    KeyboardShortcutEntry(
      keyLabel: prevCardKey,
      action: 'Focus previous card',
      logicalKey: LogicalKeyboardKey.keyA,
    ),
    KeyboardShortcutEntry(
      keyLabel: nextCardKey,
      action: 'Focus next card',
      logicalKey: LogicalKeyboardKey.keyD,
    ),
    KeyboardShortcutEntry(
      keyLabel: toggleSelectKey,
      action: 'Toggle select focused card',
      logicalKey: LogicalKeyboardKey.keyF,
    ),
    KeyboardShortcutEntry(
      keyLabel: sortKey,
      action: 'Sort hand by rank',
      logicalKey: LogicalKeyboardKey.keyS,
    ),
    KeyboardShortcutEntry(
      keyLabel: clearKey,
      action: 'Clear selection',
      logicalKey: LogicalKeyboardKey.keyC,
    ),
    KeyboardShortcutEntry(
      keyLabel: 'Esc',
      action: 'Clear selection',
      logicalKey: LogicalKeyboardKey.escape,
    ),
  ];

  static const List<KeyboardShortcutEntry> utility = [
    KeyboardShortcutEntry(
      keyLabel: scoreboardKey,
      action: 'Open scoreboard',
      logicalKey: LogicalKeyboardKey.keyR,
    ),
    KeyboardShortcutEntry(
      keyLabel: helpKey,
      action: 'Toggle keyboard shortcuts help',
      logicalKey: LogicalKeyboardKey.keyH,
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

  /// Canonical draw binding (W).
  static final LogicalKeyboardKey draw = drawPhase.first.logicalKey!;

  /// Canonical take-discard binding (Q).
  static final LogicalKeyboardKey takeDiscard = drawPhase[1].logicalKey!;

  /// Canonical play-cards binding (E).
  static final LogicalKeyboardKey playCards = meldPhase.first.logicalKey!;

  /// Discard primary binding (Space).
  static final LogicalKeyboardKey discard = meldPhase[1].logicalKey!;

  /// Discard alternate binding (Enter).
  static final LogicalKeyboardKey discardAlt = meldPhase[2].logicalKey!;

  /// Focus previous card (A).
  static final LogicalKeyboardKey prevCard = navigation[0].logicalKey!;

  /// Focus next card (D).
  static final LogicalKeyboardKey nextCard = navigation[1].logicalKey!;

  /// Toggle select focused card (F).
  static final LogicalKeyboardKey toggleSelect = navigation[2].logicalKey!;

  /// Sort hand (S).
  static final LogicalKeyboardKey sort = navigation[3].logicalKey!;

  /// Clear selection (C).
  static final LogicalKeyboardKey clear = navigation[4].logicalKey!;

  /// Clear / dismiss (Esc).
  static final LogicalKeyboardKey escape = navigation[5].logicalKey!;

  /// Scoreboard (R).
  static final LogicalKeyboardKey scoreboard = utility.first.logicalKey!;

  /// Help overlay (H).
  static final LogicalKeyboardKey help = utility[1].logicalKey!;

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
