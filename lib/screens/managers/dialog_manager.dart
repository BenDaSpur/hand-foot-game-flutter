import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/player.dart';
import '../../models/card.dart';
import '../../models/game_state.dart';
import '../../game/game_controller.dart';
import '../../widgets/advanced_meld_selector.dart';
import '../../widgets/emergency_round_end_dialog.dart';
import '../../widgets/last_call_dialog.dart';
import '../../widgets/scoreboard_modal.dart';
import '../../constants/keyboard_shortcuts.dart';
import '../../theme/balatro_theme.dart';
import '../../utils/game_responsive_layout.dart';

/// Manages all dialogs and modals for the game screen.
///
/// This class handles the presentation of various dialogs including
/// error dialogs, game end dialogs, meld selectors, and info modals.
/// Extracted from GameScreen to improve code organization.
class DialogManager {
  final BuildContext context;
  final GameController gameController;
  final Function() onStateChanged;
  final Function() onNewGame;
  final Function() onReturnToMenu;

  DialogManager({
    required this.context,
    required this.gameController,
    required this.onStateChanged,
    required this.onNewGame,
    required this.onReturnToMenu,
  });

  /// Show error dialog with themed styling
  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: BalatroTheme.heartsColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: BalatroTheme.heartsColor,
                shadows: [
                  Shadow(
                    color: BalatroTheme.heartsColor.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  /// Show critical error dialog with recovery options
  void showCriticalErrorDialog(String error, VoidCallback onRecover) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.heartsColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning,
              color: BalatroTheme.heartsColor,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(
              'CRITICAL ERROR',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: BalatroTheme.heartsColor,
                shadows: [
                  Shadow(
                    color: BalatroTheme.heartsColor.withValues(alpha: 0.8),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A critical error occurred that may prevent the game from continuing normally.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BalatroTheme.deepPurple.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: BalatroTheme.heartsColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                error,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: onRecover,
            child: const Text(
              'Try Recovery',
              style: TextStyle(color: BalatroTheme.neonYellow),
            ),
          ),
          TextButton(
            onPressed: onNewGame,
            child: const Text(
              'New Game',
              style: TextStyle(color: BalatroTheme.neonGreen),
            ),
          ),
          TextButton(
            onPressed: onReturnToMenu,
            child: const Text(
              'Main Menu',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  /// Show new game confirmation dialog
  void showNewGameConfirmation(VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(Icons.refresh, color: BalatroTheme.neonYellow, size: 28),
            const SizedBox(width: 12),
            Text(
              'New Game',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: BalatroTheme.neonYellow,
                shadows: [
                  Shadow(
                    color: BalatroTheme.neonYellow.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to start a new game? Current progress will be lost.',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text(
              'Start New Game',
              style: TextStyle(color: BalatroTheme.heartsColor),
            ),
          ),
        ],
      ),
    );
  }

  /// Show game end dialog when someone reaches winning score
  void showGameEndDialog(Player winner, List<Player> players) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.emoji_events,
              color: BalatroTheme.neonYellow,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(
              'GAME WINNER!',
              style: TextStyle(
                color: BalatroTheme.neonYellow,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: BalatroTheme.neonYellow.withValues(alpha: 0.8),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${winner.name} wins with ${winner.score} points!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Final Scores:',
              style: const TextStyle(
                color: BalatroTheme.neonPink,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...players.map(
              (player) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${player.name}: ${player.score}',
                  style: TextStyle(
                    color: player == winner
                        ? BalatroTheme.neonGreen
                        : Colors.white70,
                    fontWeight: player == winner
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onNewGame();
            },
            child: const Text(
              'New Game',
              style: TextStyle(color: BalatroTheme.neonGreen),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              showScoreboard();
            },
            child: const Text(
              'Scoreboard',
              style: TextStyle(color: BalatroTheme.neonPink),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onReturnToMenu();
            },
            child: const Text(
              'Exit',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  /// Show detailed scoreboard with round-by-round breakdown
  void showScoreboard() {
    showDialog(
      context: context,
      builder: (context) =>
          ScoreboardModal(gameState: gameController.gameState),
    );
  }

  /// Show scoreboard after a round ends and wait until the user dismisses it.
  Future<void> showRoundEndScoreboard() {
    final completedRound = gameController.gameState.round - 1;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ScoreboardModal(
        gameState: gameController.gameState,
        completedRoundNumber: completedRound < 1 ? 1 : completedRound,
        showContinueButton: true,
      ),
    );
  }

  /// Show emergency round end dialog and wait until the user dismisses it.
  Future<void> showEmergencyRoundEndDialog({EmergencyRoundEndReason? reason}) {
    return EmergencyRoundEndDialog.show(
      context,
      reason:
          reason ??
          gameController.gameState.emergencyRoundEndReason ??
          EmergencyRoundEndReason.insufficientCards,
    );
  }

  /// Warn that this is the last playable turn before an empty-deck end.
  Future<void> showLastCallAlert({required bool isLocalPlayerTurn}) {
    return LastCallDialog.showEmptyDeck(
      context,
      isLocalPlayerTurn: isLocalPlayerTurn,
    );
  }

  /// Warn that another rotation of 3-discards will end the round.
  Future<void> showStalemateWarningAlert() {
    return LastCallDialog.showStalemateWarning(context);
  }

  /// Show advanced meld selector modal
  void showAdvancedMeldSelector({
    required Function(List<List<int>>) onMeldsCreated,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdvancedMeldSelector(
        player: gameController.gameState.currentPlayer,
        playDownRequirement: gameController.gameState.playDownRequirement,
        onCancel: () {
          Navigator.of(context).pop();
        },
        onConfirm: (meldIndices) {
          Navigator.of(context).pop();
          onMeldsCreated(meldIndices);
        },
      ),
    );
  }

  /// Show wild card confirmation for meld creation
  void showWildCardConfirmation({
    required List<PlayingCard> selectedCards,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    final wildCards = selectedCards.where((card) => card.isWild).toList();
    final naturalCards = selectedCards.where((card) => !card.isWild).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.auto_fix_high,
              color: BalatroTheme.neonYellow,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Wild Card Meld',
              style: TextStyle(
                color: BalatroTheme.neonYellow,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: BalatroTheme.neonYellow.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Creating meld with ${wildCards.length} wild card(s) and ${naturalCards.length} natural card(s).',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BalatroTheme.deepPurple.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: BalatroTheme.glowColor.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'Wild cards (2s and Jokers) can substitute for natural cards, but wild cards cannot exceed natural cards in any meld.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onCancel();
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: BalatroTheme.heartsColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: const Text(
              'Create Meld',
              style: TextStyle(color: BalatroTheme.neonGreen),
            ),
          ),
        ],
      ),
    );
  }

  /// Show exported game dialog
  void showExportedGameDialog(String gameStateBase64) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(Icons.download, color: BalatroTheme.neonGreen, size: 28),
            const SizedBox(width: 12),
            Text(
              'Game Exported',
              style: TextStyle(
                color: BalatroTheme.neonGreen,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: BalatroTheme.neonGreen.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your game save has been copied to the clipboard. Share this text to transfer your game to another device:',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text(
                'This compact save uses an optimized format for easy sharing. Mobile/desktop versions use gzip compression for maximum size reduction.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.maxFinite,
                height: 300,
                child: SingleChildScrollView(
                  child: SelectableText(
                    gameStateBase64,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  /// Show load game dialog
  void showLoadGameDialog(Function(String) onLoadJson) {
    showDialog(
      context: context,
      builder: (dialogContext) => _LoadGameSaveDialog(
        onLoadJson: (inputText) {
          Navigator.of(dialogContext).pop();
          onLoadJson(inputText);
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
        onEmptyLoad: () {
          showErrorDialog('Please paste a valid game save (Base64 or JSON).');
        },
      ),
    );
  }

  /// Show how to play dialog with bot personality information
  void showHowToPlayDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BalatroTheme.darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.help_outline,
              color: BalatroTheme.neonPink,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'How to Play',
              style: TextStyle(
                color: BalatroTheme.neonPink,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: BalatroTheme.neonPink.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRulesSection(),
                const SizedBox(height: 20),
                _buildKeyboardShortcutsSection(),
                const SizedBox(height: 20),
                _buildPersonalitiesSection(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Got it!',
              style: TextStyle(color: BalatroTheme.neonBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Game Rules',
          style: TextStyle(
            color: BalatroTheme.neonYellow,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildRuleItem('🎯', 'Goal', 'Be first to reach 8,500 points!'),
        _buildRuleItem('📋', 'Melds', 'Groups of 3+ cards of same rank'),
        _buildRuleItem(
          '📚',
          'Books',
          '7+ card melds (500 pts clean, 300 pts dirty)',
        ),
        _buildRuleItem(
          '🃏',
          'Wild Cards',
          '2s and Jokers substitute for naturals',
        ),
        _buildRuleItem('🚫', 'Restrictions', 'Wilds ≤ naturals in any meld'),
        _buildRuleItem('🎲', 'Play Down', 'Round 1: 60 pts, +30 each round'),
        _buildRuleItem('🏁', 'Going Out', 'Need both clean AND dirty book'),
      ],
    );
  }

  Widget _buildKeyboardShortcutsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Keyboard Shortcuts (Desktop)',
          style: TextStyle(
            color: BalatroTheme.neonGreen,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Left hand on WASD — right hand on mouse. Press H in-game for the full overlay.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ...KeyboardShortcuts.wasdLayout.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: row.map((keyLabel) {
                final action =
                    KeyboardShortcuts.wasdLayoutLabels[keyLabel] ?? keyLabel;
                return Text(
                  '[$keyLabel] $action',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                );
              }).toList(),
            ),
          );
        }),
        const SizedBox(height: 8),
        ...KeyboardShortcuts.utility.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '[${entry.keyLabel}] ${entry.action}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPersonalitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bot Personalities',
          style: TextStyle(
            color: BalatroTheme.neonBlue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildPersonalityDescription(
          Icons.security,
          'Conservative',
          'Plays cautiously, holds cards longer, avoids risky moves',
        ),
        _buildPersonalityDescription(
          Icons.flash_on,
          'Aggressive',
          'Quick play-downs, frequent unlocks, takes more risks',
        ),
        _buildPersonalityDescription(
          Icons.library_books,
          'Book Builder',
          'Focuses on completing books for maximum point bonuses',
        ),
        _buildPersonalityDescription(
          Icons.psychology,
          'Adaptive',
          'Changes strategy based on game state and opponent threats',
        ),
      ],
    );
  }

  Widget _buildRuleItem(String emoji, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: description,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityDescription(
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: BalatroTheme.neonPink, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      color: BalatroTheme.neonPink,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: description,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Owns the save-text controller so it is disposed with the dialog route,
/// not via a racing [Future.then] (hot reload / rebuild safe).
class _LoadGameSaveDialog extends StatefulWidget {
  final ValueChanged<String> onLoadJson;
  final VoidCallback onCancel;
  final VoidCallback onEmptyLoad;

  const _LoadGameSaveDialog({
    required this.onLoadJson,
    required this.onCancel,
    required this.onEmptyLoad,
  });

  @override
  State<_LoadGameSaveDialog> createState() => _LoadGameSaveDialogState();
}

class _LoadGameSaveDialogState extends State<_LoadGameSaveDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasted = data?.text?.trim() ?? '';
    if (!mounted) {
      return;
    }
    if (pasted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Clipboard is empty',
            style: TextStyle(color: BalatroTheme.snackBarContentOnDark),
          ),
          backgroundColor: BalatroTheme.neonBlue,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _textController
      ..text = pasted
      ..selection = TextSelection.collapsed(offset: pasted.length);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isPhone = GameResponsiveLayout.isPhone(screenSize.width);
    final contentHeight = (screenSize.height * (isPhone ? 0.28 : 0.35)).clamp(
      180.0,
      isPhone ? 240.0 : 300.0,
    );

    return AlertDialog(
      backgroundColor: BalatroTheme.darkPurple,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BalatroTheme.glowColor, width: 2),
      ),
      titlePadding: EdgeInsets.fromLTRB(24, isPhone ? 16 : 24, 8, 8),
      contentPadding: EdgeInsets.fromLTRB(24, 8, 24, isPhone ? 8 : 16),
      actionsPadding: EdgeInsets.fromLTRB(16, 0, 16, isPhone ? 12 : 16),
      title: Row(
        children: [
          const Icon(Icons.upload, color: BalatroTheme.glowColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isPhone ? 'Load Save' : 'Load Game Save',
              style: TextStyle(
                color: BalatroTheme.glowColor,
                fontSize: isPhone ? 18 : 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: BalatroTheme.glowColor.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Paste from clipboard',
            onPressed: _pasteFromClipboard,
            icon: const Icon(
              Icons.content_paste,
              color: BalatroTheme.glowColor,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: contentHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPhone
                  ? 'Paste your game save (compact, base64, or JSON):'
                  : 'Paste your game save (supports all formats: ultra-compact, base64, or JSON):',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Paste your game save here...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: BalatroTheme.glowColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: BalatroTheme.glowColor.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: BalatroTheme.glowColor,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: BalatroTheme.deepPurple.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text(
            'Cancel',
            style: TextStyle(color: BalatroTheme.heartsColor),
          ),
        ),
        TextButton(
          onPressed: () {
            final inputText = _textController.text.trim();
            if (inputText.isNotEmpty) {
              widget.onLoadJson(inputText);
            } else {
              widget.onEmptyLoad();
            }
          },
          child: const Text(
            'Load Game',
            style: TextStyle(color: BalatroTheme.neonGreen),
          ),
        ),
      ],
    );
  }
}
