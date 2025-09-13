import 'package:flutter/material.dart';

/// Shared dialog for emergency round end scenarios
class EmergencyRoundEndDialog {
  static void show(
    BuildContext context, {
    required VoidCallback onContinue,
    bool autoAdvance = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Round Ended',
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(color: Colors.orange),
        ),
        content: Text(
          'The round has ended early due to insufficient cards in the deck.\n\n'
          'All player scores have been calculated and the next round will '
          '${autoAdvance ? 'begin automatically' : 'begin shortly'}.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onContinue();
            },
            child: Text(autoAdvance ? 'Continue' : 'Continue to Next Round'),
          ),
        ],
      ),
    );
  }
}
