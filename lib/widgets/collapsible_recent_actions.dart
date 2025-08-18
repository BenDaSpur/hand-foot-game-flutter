import 'package:flutter/material.dart';
import '../models/game_state.dart';
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
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(UIConstants.defaultBorderRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with toggle
          InkWell(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.all(UIConstants.defaultPadding),
              child: Row(
                children: [
                  Icon(Icons.history, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: UIConstants.mediumSpacing),
                  Expanded(
                    child: Text(
                      isExpanded ? 'Recent Actions' : _getLastActionPreview(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.grey[700],
                  ),
                ],
              ),
            ),
          ),

          // Expandable actions list
          if (isExpanded) ...[
            const Divider(height: 1),
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
                      style: TextStyle(
                        fontSize: UIConstants.recentActionsFontSize,
                        color: Colors.grey[700],
                        height: UIConstants.recentActionsLineHeight,
                      ),
                      softWrap: true, // Enable word wrapping
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
