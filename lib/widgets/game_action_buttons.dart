import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';

class GameActionButtons extends StatelessWidget {
  final GameState gameState;
  final Player humanPlayer;
  final List<int> selectedCardIndices;
  final VoidCallback onDrawFromDeck;
  final VoidCallback? onUnlockDiscard;
  final VoidCallback onShowAdvancedMeldSelector;
  final VoidCallback? onDiscard;
  final VoidCallback onClearSelection;

  const GameActionButtons({
    super.key,
    required this.gameState,
    required this.humanPlayer,
    required this.selectedCardIndices,
    required this.onDrawFromDeck,
    required this.onUnlockDiscard,
    required this.onShowAdvancedMeldSelector,
    required this.onDiscard,
    required this.onClearSelection,
  });

  bool get _hasSelectedCard => selectedCardIndices.length == 1;

  String get _discardButtonText {
    if (_hasSelectedCard && humanPlayer.currentHand.length == 1) {
      return humanPlayer.hasPickedUpFoot ? 'Go Out' : 'Go to Foot';
    }
    return 'Discard';
  }

  Color? get _discardButtonColor {
    if (_hasSelectedCard && humanPlayer.currentHand.length == 1) {
      return humanPlayer.hasPickedUpFoot ? Colors.orange : Colors.blue;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (gameState.currentPlayer.type != PlayerType.human) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.amber),
            ),
            const SizedBox(height: 16),
            Text(
              'Waiting for ${gameState.currentPlayer.name} to play...',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        children: [
          if (gameState.turnPhase == TurnPhase.draw) ...[
            ElevatedButton(
              onPressed: onDrawFromDeck,
              child: const Text('Draw from Deck'),
            ),
            if (onUnlockDiscard != null)
              ElevatedButton(
                onPressed: onUnlockDiscard,
                child: const Text('Take Discard Pile'),
              ),
          ],
          if (gameState.turnPhase == TurnPhase.meld) ...[
            ElevatedButton(
              onPressed: onShowAdvancedMeldSelector,
              child: const Text('Play Cards'),
            ),
            ElevatedButton(
              onPressed: _hasSelectedCard ? onDiscard : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _discardButtonColor,
              ),
              child: Text(_discardButtonText),
            ),
            if (selectedCardIndices.isNotEmpty)
              ElevatedButton(
                onPressed: onClearSelection,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                child: const Text('Clear Selection'),
              ),
          ],
        ],
      ),
    );
  }
}
