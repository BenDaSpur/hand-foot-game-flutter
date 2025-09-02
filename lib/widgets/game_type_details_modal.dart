import 'package:flutter/material.dart';
import '../config/game_type_config.dart';
import '../theme/balatro_theme.dart';

/// Detailed modal showing complete game type configuration and rules.
///
/// Displays comprehensive information about a selected game type including
/// all rule variations, scoring differences, and gameplay mechanics.
class GameTypeDetailsModal extends StatelessWidget {
  final GameType gameType;
  final GameTypeConfig config;

  const GameTypeDetailsModal({
    super.key,
    required this.gameType,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final displayInfo = config.getDisplayInfo();
    final specialRules = displayInfo['specialRules'] as List<String>;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        decoration: BoxDecoration(
          color: BalatroTheme.darkPurple,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BalatroTheme.glowColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: BalatroTheme.glowColor.withValues(alpha: 0.2),
              blurRadius: 12,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getDifficultyColor(
                  config.difficultyLabel,
                ).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getGameTypeIcon(gameType),
                    color: _getDifficultyColor(config.difficultyLabel),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          config.description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(
                        config.difficultyLabel,
                      ).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getDifficultyColor(config.difficultyLabel),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      config.difficultyLabel,
                      style: TextStyle(
                        color: _getDifficultyColor(config.difficultyLabel),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Game Setup
                    _buildSection('Game Setup', Icons.settings, [
                      _buildInfoRow('Deck Count', displayInfo['deckCount']),
                      _buildInfoRow('Hand Size', displayInfo['handSize']),
                      _buildInfoRow(
                        'Max Rounds',
                        config.maxRounds == 0
                            ? 'Unlimited'
                            : '${config.maxRounds}',
                      ),
                      if (config.turnTimeLimit != Duration.zero)
                        _buildInfoRow(
                          'Turn Limit',
                          '${config.turnTimeLimit.inSeconds} seconds',
                        ),
                    ]),

                    const SizedBox(height: 16),

                    // Scoring System
                    _buildSection('Scoring System', Icons.score, [
                      _buildInfoRow(
                        'Play-down Start',
                        displayInfo['playDownStart'],
                      ),
                      _buildInfoRow(
                        'Win Condition',
                        displayInfo['winCondition'],
                      ),
                      _buildInfoRow(
                        'Clean Book Bonus',
                        '${config.cleanBookBonus} pts',
                      ),
                      _buildInfoRow(
                        'Dirty Book Bonus',
                        '${config.dirtyBookBonus} pts',
                      ),
                      _buildInfoRow(
                        'Going Out Bonus',
                        '${config.goingOutBonus} pts',
                      ),
                      if (config.penaltyMultiplier != 1.0)
                        _buildInfoRow(
                          'Penalty Multiplier',
                          '${config.penaltyMultiplier}×',
                        ),
                    ]),

                    if (specialRules.isNotEmpty) ...[
                      const SizedBox(height: 16),

                      // Special Rules
                      _buildSection(
                        'Special Rules',
                        Icons.rule,
                        specialRules
                            .map((rule) => _buildRuleBullet(rule))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: BalatroTheme.glowColor, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: BalatroTheme.neonBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: BalatroTheme.neonBlue,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BalatroTheme.deepPurple.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: BalatroTheme.glowColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: BalatroTheme.neonYellow,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleBullet(String rule) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 8),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: BalatroTheme.neonOrange,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              rule,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
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

  IconData _getGameTypeIcon(GameType gameType) {
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

  /// Show the game type details modal.
  static void show(BuildContext context, GameType gameType) {
    showDialog(
      context: context,
      builder: (context) => GameTypeDetailsModal(
        gameType: gameType,
        config: GameTypeConfig.forType(gameType),
      ),
    );
  }
}
