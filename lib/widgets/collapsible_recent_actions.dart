import 'package:flutter/material.dart';
import '../models/game_state.dart';

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
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with toggle
          InkWell(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(Icons.history, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 8),
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
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: gameState.recentActions.length,
                reverse: true,
                itemBuilder: (context, index) {
                  final action =
                      gameState.recentActions[gameState.recentActions.length -
                          1 -
                          index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      action.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                        height: 1.2, // Better line spacing for readability
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
    return preview.length > 40 ? '${preview.substring(0, 40)}...' : preview;
  }
}
