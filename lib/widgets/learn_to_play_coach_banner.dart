import 'package:flutter/material.dart';

import '../theme/balatro_theme.dart';
import '../tutorial/learn_to_play_step.dart';

/// Coach banner shown during Learn to Play steps.
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
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BalatroTheme.darkPurple.withValues(alpha: 0.95),
          border: Border.all(
            color: BalatroTheme.glowColor.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: BalatroTheme.glowColor.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
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
                    color: BalatroTheme.accentText,
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
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: BalatroTheme.mediumPurple,
                color: BalatroTheme.neonGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              step.coachMessage,
              style: const TextStyle(
                color: BalatroTheme.primaryText,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            if (showContinue && onContinue != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: onContinue,
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
