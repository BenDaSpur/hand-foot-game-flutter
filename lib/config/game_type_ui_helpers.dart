import 'package:flutter/material.dart';
import 'game_type_config.dart';
import '../theme/balatro_theme.dart';

/// Shared UI helper methods for game type selection and details.
///
/// Provides consistent styling and behavior across different game type
/// components by centralizing common UI logic.
class GameTypeUIHelpers {
  /// Get the theme color for a difficulty level.
  static Color getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return BalatroTheme.neonGreen;
      case 'medium':
        return BalatroTheme.neonYellow;
      case 'hard':
        return BalatroTheme.neonOrange;
      case 'expert':
        return BalatroTheme.neonPink;
      default:
        return BalatroTheme.glowColor;
    }
  }

  /// Get the icon for a specific game type.
  static IconData getGameTypeIcon(GameType gameType) {
    switch (gameType) {
      case GameType.classic:
        return Icons.casino;
      case GameType.strict:
        return Icons.rule;
      case GameType.marathon:
        return Icons.timeline;
      case GameType.speed:
        return Icons.speed;
      case GameType.highStakes:
        return Icons.trending_up;
    }
  }
}
