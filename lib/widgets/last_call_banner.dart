import 'package:flutter/material.dart';
import '../constants/ui_constants.dart';
import '../game/game_action_feedback.dart';
import '../theme/balatro_theme.dart';

/// Persistent reminder while [GameState.lastCallActive] is true.
class LastCallBanner extends StatelessWidget {
  final bool isLocalPlayerTurn;

  const LastCallBanner({super.key, required this.isLocalPlayerTurn});

  @override
  Widget build(BuildContext context) {
    const urgencyColor = BalatroTheme.neonOrange;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: UIConstants.defaultMargin,
        vertical: UIConstants.smallSpacing,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            urgencyColor.withValues(alpha: 0.28),
            BalatroTheme.neonPink.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgencyColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: urgencyColor.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isLocalPlayerTurn ? Icons.timer : Icons.hourglass_bottom,
            color: urgencyColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  GameActionFeedback.lastCallBannerHeadline(
                    isLocalPlayerTurn: isLocalPlayerTurn,
                  ),
                  style: const TextStyle(
                    color: urgencyColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  GameActionFeedback.lastCallBannerBody(
                    isLocalPlayerTurn: isLocalPlayerTurn,
                  ),
                  style: const TextStyle(
                    color: BalatroTheme.primaryText,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
