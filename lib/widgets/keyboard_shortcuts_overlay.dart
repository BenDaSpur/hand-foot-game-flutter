import 'package:flutter/material.dart';
import '../constants/keyboard_shortcuts.dart';
import '../theme/balatro_theme.dart';

/// Compact WASD keyboard shortcuts help panel for desktop players.
class KeyboardShortcutsOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const KeyboardShortcutsOverlay({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          constraints: const BoxConstraints(maxHeight: 420),
          decoration: BoxDecoration(
            color: BalatroTheme.darkPurple.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BalatroTheme.glowColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: BalatroTheme.neonBlue.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.keyboard,
                      color: BalatroTheme.neonBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Keyboard Shortcuts',
                        style: TextStyle(
                          color: BalatroTheme.neonBlue,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: onDismiss,
                      tooltip: 'Close (H or Esc)',
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Left hand on WASD — right hand on mouse',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _WasdDiagram(),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection('Draw Phase', KeyboardShortcuts.drawPhase),
                      _buildSection('Meld Phase', KeyboardShortcuts.meldPhase),
                      _buildSection('Hand', KeyboardShortcuts.navigation),
                      _buildSection('Other', KeyboardShortcuts.utility),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<KeyboardShortcutEntry> entries) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: BalatroTheme.neonYellow,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          ...entries.map(_buildRow),
        ],
      ),
    );
  }

  Widget _buildRow(KeyboardShortcutEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: BalatroTheme.cardBorder),
            ),
            child: Text(
              entry.keyLabel,
              style: const TextStyle(
                color: BalatroTheme.neonGreen,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.action,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _WasdDiagram extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: KeyboardShortcuts.wasdLayout.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((keyLabel) {
              final label =
                  KeyboardShortcuts.wasdLayoutLabels[keyLabel] ?? keyLabel;
              final isWide = keyLabel == 'Space';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    Container(
                      width: isWide ? 72 : 36,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: BalatroTheme.cardBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: BalatroTheme.neonBlue),
                      ),
                      child: Text(
                        keyLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: isWide ? 72 : 36,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

/// Small header chip that opens the keyboard shortcuts overlay.
class KeyboardShortcutsHelpChip extends StatelessWidget {
  final VoidCallback onTap;

  const KeyboardShortcutsHelpChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: BalatroTheme.neonBlue.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: BalatroTheme.neonBlue.withValues(alpha: 0.6),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.keyboard, color: BalatroTheme.neonBlue, size: 14),
            SizedBox(width: 4),
            Text(
              'H',
              style: TextStyle(
                color: BalatroTheme.neonBlue,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
