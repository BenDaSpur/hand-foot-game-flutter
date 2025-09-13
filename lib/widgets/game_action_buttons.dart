import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../config/game_config.dart';

class GameActionButtons extends StatelessWidget {
  final GameState gameState;
  final Player humanPlayer;
  final List<int> selectedCardIndices;
  final VoidCallback onDrawFromDeck;
  final VoidCallback? onUnlockDiscard;
  final VoidCallback onShowAdvancedMeldSelector;
  final VoidCallback? onDiscard;
  final VoidCallback onClearSelection;
  final String? currentUserId; // For multiplayer turn detection

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
    this.currentUserId, // Optional - for multiplayer
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

  /// Check if it's the current user's turn (works for both single-player and multiplayer)
  bool get _isCurrentUserTurn {
    if (currentUserId != null) {
      // Multiplayer: check if current player is this user
      return gameState.currentPlayer.id == currentUserId;
    } else {
      // Single-player: check if current player is human
      return gameState.currentPlayer.type == PlayerType.human;
    }
  }

  /// Get user-friendly description of current turn phase
  String _getTurnPhaseDescription() {
    switch (gameState.turnPhase) {
      case TurnPhase.draw:
        return 'draw cards';
      case TurnPhase.meld:
        return 'play cards or discard';
      case TurnPhase.discard:
        return 'discard a card';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCurrentUserTurn) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.amber),
            ),
            const SizedBox(height: 16),
            Text(
              'Waiting for ${gameState.currentPlayer.name} to ${_getTurnPhaseDescription()}...',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.amber),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Build buttons based on turn phase with compact sizing for mobile
    final buttons = <Widget>[];

    if (gameState.turnPhase == TurnPhase.draw) {
      buttons.add(
        _buildCompactButton(
          onPressed: onDrawFromDeck,
          text: 'Draw from deck',
          context: context,
        ),
      );
      if (onUnlockDiscard != null) {
        buttons.add(
          _buildCompactButton(
            onPressed: onUnlockDiscard,
            text: 'Take Discard',
            context: context,
          ),
        );
      }
    }

    if (gameState.turnPhase == TurnPhase.meld) {
      buttons.add(
        _buildCompactButton(
          onPressed: onShowAdvancedMeldSelector,
          text: 'Play Cards',
          backgroundColor: const Color(
            0xFF16c79a,
          ), // Neon green for meld action
          context: context,
        ),
      );
      buttons.add(
        _buildCompactButton(
          onPressed: _hasSelectedCard ? onDiscard : null,
          text: _discardButtonText,
          backgroundColor:
              _discardButtonColor ??
              const Color(0xFFe94560), // Neon pink for discard
          context: context,
        ),
      );
      if (selectedCardIndices.isNotEmpty) {
        buttons.add(
          _buildCompactButton(
            onPressed: onClearSelection,
            text: 'Clear',
            backgroundColor: Colors.grey,
            context: context,
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: buttons
            .map(
              (button) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: button,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  /// Build a compact button sized appropriately for mobile screens
  Widget _buildCompactButton({
    required VoidCallback? onPressed,
    required String text,
    required BuildContext context,
    Color? backgroundColor,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < GameConfig.tabletPortraitBreakpoint;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 8 : 12,
          horizontal: isSmallScreen ? 8 : 16,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontSize: isSmallScreen ? 12 : 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
