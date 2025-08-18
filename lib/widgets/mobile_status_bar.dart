import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/balatro_theme.dart';
import '../constants/ui_constants.dart';

class MobileStatusBar extends StatelessWidget {
  final GameState gameState;
  final bool isExpanded;
  final VoidCallback onToggle;

  const MobileStatusBar({
    super.key,
    required this.gameState,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < UIConstants.smallScreenBreakpoint;

    return Container(
      margin: const EdgeInsets.all(UIConstants.defaultMargin),
      decoration: BalatroTheme.glowDecoration(
        backgroundColor: BalatroTheme.darkPurple,
        glowColor: BalatroTheme.glowColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Always visible: Current player and phase
          Container(
            padding: const EdgeInsets.all(UIConstants.statusBarPadding),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildCompactChip(
                        gameState.currentPlayer.name,
                        BalatroTheme.neonPink,
                        icon: Icons.person,
                      ),
                      const SizedBox(width: UIConstants.mediumSpacing),
                      _buildCompactChip(
                        gameState.turnPhase.name.toUpperCase(),
                        BalatroTheme.neonBlue,
                        icon: Icons.play_arrow,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onToggle,
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: BalatroTheme.glowColor,
                    size: UIConstants.statusBarIconSize,
                  ),
                  tooltip: isExpanded ? 'Show less' : 'Show more info',
                ),
              ],
            ),
          ),

          // Expandable section with additional info
          if (isExpanded) ...[
            const Divider(color: BalatroTheme.glowColor, height: 1),
            Container(
              padding: const EdgeInsets.all(UIConstants.statusBarPadding),
              child: isSmallScreen
                  ? _buildVerticalLayout()
                  : _buildHorizontalLayout(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerticalLayout() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCompactChip(
                'Play Down: ${gameState.playDownRequirement}',
                BalatroTheme.neonOrange,
                icon: Icons.casino,
              ),
            ),
            const SizedBox(width: UIConstants.mediumSpacing),
            Expanded(
              child: _buildCompactChip(
                'Deck: ${gameState.deck.size}',
                BalatroTheme.neonYellow,
                icon: Icons.style,
              ),
            ),
          ],
        ),
        if (gameState.topDiscard != null) ...[
          const SizedBox(height: UIConstants.mediumSpacing),
          _buildCompactChip(
            'Top: ${gameState.topDiscard!.displayName}',
            BalatroTheme.neonGreen,
            icon: Icons.visibility,
          ),
        ],
      ],
    );
  }

  Widget _buildHorizontalLayout() {
    return Wrap(
      spacing: UIConstants.mediumSpacing,
      runSpacing: UIConstants.mediumSpacing,
      children: [
        _buildCompactChip(
          'Play Down: ${gameState.playDownRequirement}',
          BalatroTheme.neonOrange,
          icon: Icons.casino,
        ),
        _buildCompactChip(
          'Deck: ${gameState.deck.size}',
          BalatroTheme.neonYellow,
          icon: Icons.style,
        ),
        if (gameState.topDiscard != null)
          _buildCompactChip(
            'Top: ${gameState.topDiscard!.displayName}',
            BalatroTheme.neonGreen,
            icon: Icons.visibility,
          ),
      ],
    );
  }

  Widget _buildCompactChip(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.defaultPadding,
        vertical: UIConstants.smallSpacing,
      ),
      decoration: BalatroTheme.glowDecoration(
        glowColor: color,
        backgroundColor: BalatroTheme.darkPurple.withValues(
          alpha: UIConstants.semiTransparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: UIConstants.statusBarIconSize, color: color),
            const SizedBox(width: UIConstants.smallSpacing),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: UIConstants.statusBarCompactChipFontSize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
