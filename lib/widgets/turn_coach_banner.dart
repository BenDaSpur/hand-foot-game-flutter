import 'package:material_ui/material_ui.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../theme/balatro_theme.dart';

/// Compact next-action coach for first-session human turns.
class TurnCoachBanner extends StatelessWidget {
  final GameState gameState;
  final Player localPlayer;
  final VoidCallback? onDismiss;

  const TurnCoachBanner({
    super.key,
    required this.gameState,
    required this.localPlayer,
    this.onDismiss,
  });

  static String messageFor({
    required TurnPhase phase,
    required bool hasPlayedDown,
    required int playDownRequirement,
  }) {
    switch (phase) {
      case TurnPhase.draw:
        return 'Start your turn — draw 2 cards (or take the discard if allowed).';
      case TurnPhase.meld:
        if (!hasPlayedDown) {
          return 'Play Cards to lay melds. Round needs '
              '$playDownRequirement points to play down.';
        }
        return 'Add to melds or discard one card to end your turn.';
      case TurnPhase.discard:
        return 'Select one card and tap Discard.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = messageFor(
      phase: gameState.turnPhase,
      hasPlayedDown: localPlayer.hasPlayedDown,
      playDownRequirement: gameState.playDownRequirement,
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: BalatroTheme.darkPurple,
          border: Border.all(
            color: BalatroTheme.neonBlue.withValues(alpha: 0.7),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.lightbulb_outline,
                color: BalatroTheme.neonBlue,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'NEXT STEP',
                    style: TextStyle(
                      color: BalatroTheme.neonBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: BalatroTheme.primaryText,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18),
                color: BalatroTheme.secondaryText,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Hide tips',
              ),
          ],
        ),
      ),
    );
  }
}
