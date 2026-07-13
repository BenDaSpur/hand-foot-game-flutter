/// A single keyboard shortcut entry for help UI and tooltips.
class KeyboardShortcutEntry {
  final String keyLabel;
  final String action;
  final String? phase;

  const KeyboardShortcutEntry({
    required this.keyLabel,
    required this.action,
    this.phase,
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
    ),
    KeyboardShortcutEntry(
      keyLabel: takeDiscardKey,
      action: 'Take discard pile',
      phase: 'Draw',
    ),
  ];

  static const List<KeyboardShortcutEntry> meldPhase = [
    KeyboardShortcutEntry(
      keyLabel: playCardsKey,
      action: 'Open Play Cards',
      phase: 'Meld',
    ),
    KeyboardShortcutEntry(
      keyLabel: discardKey,
      action: 'Discard / Go to Foot / Go Out',
      phase: 'Meld',
    ),
    KeyboardShortcutEntry(
      keyLabel: discardAltKey,
      action: 'Same as Space',
      phase: 'Meld',
    ),
  ];

  static const List<KeyboardShortcutEntry> navigation = [
    KeyboardShortcutEntry(keyLabel: prevCardKey, action: 'Focus previous card'),
    KeyboardShortcutEntry(keyLabel: nextCardKey, action: 'Focus next card'),
    KeyboardShortcutEntry(
      keyLabel: toggleSelectKey,
      action: 'Toggle select focused card',
    ),
    KeyboardShortcutEntry(keyLabel: sortKey, action: 'Sort hand by rank'),
    KeyboardShortcutEntry(keyLabel: clearKey, action: 'Clear selection'),
    KeyboardShortcutEntry(keyLabel: 'Esc', action: 'Clear selection'),
  ];

  static const List<KeyboardShortcutEntry> utility = [
    KeyboardShortcutEntry(keyLabel: scoreboardKey, action: 'Open scoreboard'),
    KeyboardShortcutEntry(
      keyLabel: helpKey,
      action: 'Toggle keyboard shortcuts help',
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
