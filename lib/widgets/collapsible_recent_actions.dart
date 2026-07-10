import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/balatro_theme.dart';
import '../constants/ui_constants.dart';

class CollapsibleRecentActions extends StatelessWidget {
  final GameState gameState;
  final bool isExpanded;
  final VoidCallback onToggle;

  const CollapsibleRecentActions({
    super.key,
    required this.gameState,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (gameState.recentActions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: UIConstants.defaultMargin),
      decoration: BoxDecoration(
        color: BalatroTheme.darkPurple.withValues(alpha: 0.8),
        border: Border.all(
          color: BalatroTheme.glowColor.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(UIConstants.defaultBorderRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.all(UIConstants.defaultPadding),
              child: Row(
                children: [
                  const Icon(
                    Icons.history,
                    size: 16,
                    color: BalatroTheme.glowColor,
                  ),
                  const SizedBox(width: UIConstants.mediumSpacing),
                  Expanded(
                    child: Text(
                      isExpanded ? 'Recent Actions' : _getLastActionPreview(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: BalatroTheme.secondaryText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: BalatroTheme.glowColor,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(color: BalatroTheme.glowColor, height: 1),
            Container(
              constraints: const BoxConstraints(
                maxHeight: UIConstants.recentActionsMaxHeight,
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: UIConstants.defaultPadding,
                  vertical: UIConstants.smallSpacing,
                ),
                itemCount: gameState.recentActions.length,
                reverse: true,
                itemBuilder: (context, index) {
                  final action =
                      gameState.recentActions[gameState.recentActions.length -
                          1 -
                          index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: UIConstants.recentActionsVerticalPadding,
                    ),
                    child: Text(
                      action.toString(),
                      style: const TextStyle(
                        fontSize: UIConstants.recentActionsFontSize,
                        color: BalatroTheme.secondaryText,
                        height: UIConstants.recentActionsLineHeight,
                      ),
                      softWrap: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getLastActionPreview() {
    if (gameState.recentActions.isEmpty) {
      return 'No recent actions';
    }
    final lastAction = gameState.recentActions.last;
    final preview = lastAction.toString();
    return preview.length > UIConstants.recentActionsPreviewLength
        ? '${preview.substring(0, UIConstants.recentActionsPreviewLength)}...'
        : preview;
  }
}
