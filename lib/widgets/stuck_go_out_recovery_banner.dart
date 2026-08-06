import 'package:flutter/material.dart';
import '../game/game_action_feedback.dart';
import '../models/player.dart';

/// Banner shown when a human cannot discard or go out after melding down
/// without both books. Offers undo (when available) and skip-turn recovery.
class StuckGoOutRecoveryBanner extends StatelessWidget {
  final Player humanPlayer;
  final VoidCallback? onUndo;
  final VoidCallback onSkipTurn;

  const StuckGoOutRecoveryBanner({
    super.key,
    required this.humanPlayer,
    this.onUndo,
    required this.onSkipTurn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red),
      ),
      child: Column(
        children: [
          Text(
            GameActionFeedback.stuckWithoutBooksMessage(humanPlayer),
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onUndo != null)
                ElevatedButton(
                  onPressed: onUndo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Undo Meld'),
                ),
              ElevatedButton(
                onPressed: onSkipTurn,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Skip Turn (Emergency Recovery)'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
