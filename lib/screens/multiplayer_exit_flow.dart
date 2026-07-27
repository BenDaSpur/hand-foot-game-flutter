import 'package:flutter/material.dart';
import '../models/multiplayer_lifecycle.dart';
import '../services/multiplayer_resume_service.dart';
import '../theme/balatro_theme.dart';
import 'main_menu_screen.dart';

/// Shared leave/cancel teardown helpers for multiplayer lobby and game screens.
class MultiplayerExitFlow {
  const MultiplayerExitFlow._();

  static String messageForLifecycleEvent(MultiplayerLifecycleEvent event) {
    return event == MultiplayerLifecycleEvent.gameCancelled
        ? 'The host ended this game.'
        : 'This game was ended by the host.';
  }

  /// Clears resume data, shows a themed ended dialog, then returns to main menu.
  ///
  /// Returns `false` when [alreadyExiting] was already true (no-op).
  static Future<bool> handleRemoteGameEnded({
    required BuildContext context,
    required bool alreadyExiting,
    required VoidCallback markExiting,
    required String message,
    required Color dialogBackground,
    required BorderSide dialogBorder,
  }) async {
    if (alreadyExiting) {
      return false;
    }
    markExiting();
    await MultiplayerResumeService.clearActiveGame();

    if (!context.mounted) {
      return true;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: dialogBorder,
        ),
        title: const Text(
          'Game Ended',
          style: TextStyle(
            color: BalatroTheme.neonPink,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );

    if (!context.mounted) {
      return true;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainMenuScreen()),
      (route) => false,
    );
    return true;
  }

  static void goToMainMenu(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainMenuScreen()),
      (route) => false,
    );
  }
}
