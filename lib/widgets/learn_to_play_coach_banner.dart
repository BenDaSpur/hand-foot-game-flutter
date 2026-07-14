import 'package:flutter/material.dart';

import '../theme/balatro_theme.dart';
import '../tutorial/learn_to_play_step.dart';

/// Dedicated coach row for Learn to Play.
///
/// Lives in the parent [Column] above the game board (not a Stack overlay), so
/// it never covers the deck, scores, or melds.
class LearnToPlayCoachBanner extends StatelessWidget {
  final LearnToPlayStep step;
  final double progress;
  final VoidCallback? onContinue;
  final bool showContinue;

  const LearnToPlayCoachBanner({
    super.key,
    required this.step,
    required this.progress,
    this.onContinue,
    this.showContinue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BalatroTheme.deepPurple,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: BalatroTheme.darkPurple,
          border: Border.all(
            color: BalatroTheme.neonBlue.withValues(alpha: 0.7),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  step.phase == LearnToPlayPhase.howToWin
                      ? 'HOW TO WIN'
                      : 'BASICS',
                  style: const TextStyle(
                    color: BalatroTheme.neonBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  step.title,
                  style: const TextStyle(
                    color: BalatroTheme.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: BalatroTheme.mediumPurple,
                color: BalatroTheme.neonGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              step.coachMessage,
              style: const TextStyle(
                color: BalatroTheme.primaryText,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (showContinue && onContinue != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
