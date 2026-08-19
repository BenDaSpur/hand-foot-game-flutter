import 'package:flutter/material.dart';
import '../models/game_state.dart';

/// Shared dialog for emergency round end scenarios
class EmergencyRoundEndDialog {
  static Future<void> show(
    BuildContext context, {
    EmergencyRoundEndReason reason = EmergencyRoundEndReason.insufficientCards,
    bool autoAdvance = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Round Ended',
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(color: Colors.orange),
        ),
        content: Text(_contentForReason(reason, autoAdvance: autoAdvance)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(autoAdvance ? 'Continue' : 'Continue to Next Round'),
          ),
        ],
      ),
    );
  }

  static String _contentForReason(
    EmergencyRoundEndReason reason, {
    required bool autoAdvance,
  }) {
    final nextRound = autoAdvance ? 'begin automatically' : 'begin shortly';
    switch (reason) {
      case EmergencyRoundEndReason.stalemate:
        return 'The round has ended early because players could only discard '
            '3s and the deck was too low to continue.\n\n'
            'All player scores have been calculated and the next round will '
            '$nextRound.';
      case EmergencyRoundEndReason.insufficientCards:
        return 'The round has ended early due to insufficient cards in the '
            'deck.\n\n'
            'All player scores have been calculated and the next round will '
            '$nextRound.';
    }
  }
}
