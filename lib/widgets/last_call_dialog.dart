import 'package:flutter/material.dart';
import '../game/game_action_feedback.dart';
import '../theme/balatro_theme.dart';

/// Blocking alert shown when the stock cannot support another required draw,
/// or when a 3s stalemate is one rotation away from ending the round.
class LastCallDialog {
  static Future<void> showEmptyDeck(
    BuildContext context, {
    required bool isLocalPlayerTurn,
  }) {
    return _show(
      context,
      title: GameActionFeedback.lastCallTitle,
      body: GameActionFeedback.lastCallMessage(
        isLocalPlayerTurn: isLocalPlayerTurn,
      ),
      actionLabel: isLocalPlayerTurn ? 'Play Cards' : 'OK',
      icon: Icons.warning_amber_rounded,
    );
  }

  static Future<void> showStalemateWarning(BuildContext context) {
    return _show(
      context,
      title: GameActionFeedback.stalemateWarningTitle,
      body: GameActionFeedback.stalemateWarningMessage(),
      actionLabel: 'OK',
      icon: Icons.info_outline,
    );
  }

  static Future<void> _show(
    BuildContext context, {
    required String title,
    required String body,
    required String actionLabel,
    required IconData icon,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.neonOrange, width: 2),
        ),
        title: Row(
          children: [
            Icon(icon, color: BalatroTheme.neonOrange, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: BalatroTheme.neonOrange,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          body,
          style: const TextStyle(color: BalatroTheme.primaryText, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              actionLabel,
              style: const TextStyle(
                color: BalatroTheme.neonOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
